module UART_TX_RX_MASSIV_MODULE
#(
	parameter UART_BAUD_RATE				=	9600,//битрейт передачи
   parameter CLOCK_FREQUENCY				=	50000000,//частота сигнала IN_CLOCK
   parameter PARITY							=	1,//параметр бита четности
   parameter NUM_OF_DATA_BITS_IN_PACK	=	8,//кол-во информационных бит в элементарной транзакции
	parameter NUMBER_STOP_BITS				=	2,//кол-во стоп-битов 
	parameter TX_MASSIV_DEEP				=	4,//глубина буфера TX
	parameter RX_MASSIV_DEEP				=	4,//глубина буфера RX	
	parameter RX_MASSIV_DEEP_LOG_2=$clog2(RX_MASSIV_DEEP),//определение размерности соответствующих регистров
	parameter TX_MASSIV_DEEP_LOG_2=$clog2(TX_MASSIV_DEEP)
)
(
	input IN_CLOCK,//входной тактовый сигнал
	input wire [NUM_OF_DATA_BITS_IN_PACK*TX_MASSIV_DEEP-1:0] IN_TX_DATA_MASSIV,//входной массив данных для передачи
	
	input [TX_MASSIV_DEEP_LOG_2:0] IN_TX_NUMBER_OF_PACKS_TO_SEND,//число пакетов, которые нужно отправить при следующей инициализации транзакции
	input IN_TX_LAUNCH,//сигнальная линия инициализации транзакции
	
	output reg OUT_TX_ACTIVE,//сигнальная линия занятости узла TX
	output reg OUT_TX_DONE,//сигнальная линия окончания передачи модулем TX
	
	input IN_RX_CLEAR_BUFFER,//сигнальная линия для очистки буфера принятых бит
	output reg [NUM_OF_DATA_BITS_IN_PACK*RX_MASSIV_DEEP-1:0] OUT_RX_DATA_MASSIV,//выходной вектор принятых данных
	output reg OUT_RX_ERROR,//сигнальная линия ошибки приема
	output reg [RX_MASSIV_DEEP_LOG_2:0] OUT_RX_NUM_OF_DATA_PACKS_READY,//число принятых пакетов с момента последней очистки буфера
	
	output 		TX_PORT,//TX
	input			RX_PORT//RX
	
);
	wire [NUM_OF_DATA_BITS_IN_PACK-1:0] IN_UART_TX_DATA;
	wire [NUM_OF_DATA_BITS_IN_PACK-1:0] OUT_UART_RX_DATA;
	UART_TX_RX_MODULE 
	#(
		.UART_BAUD_RATE(UART_BAUD_RATE),
		.CLOCK_FREQUENCY(CLOCK_FREQUENCY),
		.PARITY(PARITY),
		.NUM_OF_DATA_BITS_IN_PACK(NUM_OF_DATA_BITS_IN_PACK),
		.NUMBER_STOP_BITS(NUMBER_STOP_BITS)
	)
	UART
	(
		.IN_CLOCK(IN_CLOCK),
		.IN_TX_LAUNCH(IN_UART_TX_LAUNCH),
		.IN_TX_DATA(IN_UART_TX_DATA),
		.OUT_TX_ACTIVE(OUT_UART_TX_ACTIVE),
		.OUT_TX_DONE(OUT_UART_TX_DONE),
		.OUT_TX_STOP_BIT_ACTIVE(OUT_UART_TX_STOP_BIT_ACTIVE),
		.OUT_TX_START_BIT_ACTIVE(OUT_UART_TX_START_BIT_ACTIVE),
		.OUT_RX_DATA_READY(OUT_UART_RX_DATA_READY),
		.OUT_RX_DATA(OUT_UART_RX_DATA),
		.OUT_RX_ERROR(OUT_UART_RX_ERROR),
		.IN_RX_SERIAL(RX_PORT),
		.OUT_TX_SERIAL(TX_PORT)
		
	);
	//состояния автомата для передачи пакетов 
	localparam STATE_WAIT				=	2'b00;
	localparam STATE_WRITE_PACKS		=	2'b01;
	localparam STATE_WAIT_UART_DONE	=	2'b10;
	
	localparam NUM_OF_DATA_BITS_IN_PACK_LOG_2=$clog2(NUM_OF_DATA_BITS_IN_PACK);
	
	reg	[1:0]		REG_TX_FSM_STATE;//состояние автомата для переачи данных 
	reg [RX_MASSIV_DEEP_LOG_2:0] REG_RX_PACK_COUNT;//счетчик приема пакетов
	reg [TX_MASSIV_DEEP_LOG_2:0] REG_TX_PACK_COUNT;//счетчик отправки пакетов
	reg	[NUM_OF_DATA_BITS_IN_PACK*TX_MASSIV_DEEP-1:0] REG_TX_DATA_MASSIV ;
	reg	[TX_MASSIV_DEEP_LOG_2:0] REG_TX_NUMBER_OF_PACKS_TO_SEND;
	reg FIRST_CLOCK_AFTER_WRITE_PACK;
	reg [NUM_OF_DATA_BITS_IN_PACK-1:0] REG_UART_TX_DATA;
	reg REG_UART_TX_LAUNCH;
	assign IN_UART_TX_DATA=REG_UART_TX_DATA;
	assign IN_UART_TX_LAUNCH=REG_UART_TX_LAUNCH;
	initial begin
		OUT_TX_ACTIVE=0;
		OUT_TX_DONE=0;
		REG_TX_FSM_STATE=STATE_WAIT;
		REG_RX_PACK_COUNT=0;
		REG_TX_PACK_COUNT=0;
		FIRST_CLOCK_AFTER_WRITE_PACK=0;
		OUT_RX_NUM_OF_DATA_PACKS_READY=0;
		OUT_RX_ERROR=0;
		OUT_RX_DATA_MASSIV=0;
	end
	always @(posedge IN_CLOCK)
	begin
		case(REG_TX_FSM_STATE)
			STATE_WAIT:
			begin
				if(FIRST_CLOCK_AFTER_WRITE_PACK)
				begin
					FIRST_CLOCK_AFTER_WRITE_PACK<=0;
					OUT_TX_DONE<=1;
				end
				else
					OUT_TX_DONE<=0;			
				OUT_TX_ACTIVE<=0;
				REG_TX_PACK_COUNT<=0;
				if(IN_TX_LAUNCH&&IN_TX_NUMBER_OF_PACKS_TO_SEND!=0)
				begin
					REG_TX_FSM_STATE<=STATE_WRITE_PACKS;
					OUT_TX_ACTIVE<=1;
					REG_TX_DATA_MASSIV=IN_TX_DATA_MASSIV;
					if(IN_TX_NUMBER_OF_PACKS_TO_SEND>TX_MASSIV_DEEP)
						REG_TX_NUMBER_OF_PACKS_TO_SEND=TX_MASSIV_DEEP;
					else
						REG_TX_NUMBER_OF_PACKS_TO_SEND<=IN_TX_NUMBER_OF_PACKS_TO_SEND;
					REG_UART_TX_DATA=IN_TX_DATA_MASSIV[NUM_OF_DATA_BITS_IN_PACK-1:0];
					REG_TX_PACK_COUNT<=0;
				end	
			end
			STATE_WRITE_PACKS:
			begin
				if (REG_TX_PACK_COUNT==0)
				begin
					REG_UART_TX_LAUNCH<=1;
					REG_TX_PACK_COUNT=1;
				end
				if(OUT_UART_TX_START_BIT_ACTIVE)
					REG_UART_TX_LAUNCH<=0;
				if(REG_TX_PACK_COUNT<=REG_TX_NUMBER_OF_PACKS_TO_SEND)
					begin
						if(OUT_UART_TX_STOP_BIT_ACTIVE)
						begin
								REG_UART_TX_DATA=sel_part_vector(REG_TX_DATA_MASSIV,REG_TX_PACK_COUNT);
								REG_TX_FSM_STATE<=STATE_WAIT_UART_DONE;
						end
					end
					else
					begin
						REG_TX_FSM_STATE<=STATE_WAIT;
						FIRST_CLOCK_AFTER_WRITE_PACK<=1;
						REG_UART_TX_LAUNCH<=0;
					end
			end
			STATE_WAIT_UART_DONE:
			begin
				if(!OUT_UART_TX_ACTIVE)
				begin
					if(REG_TX_NUMBER_OF_PACKS_TO_SEND!=REG_TX_PACK_COUNT)
						REG_UART_TX_LAUNCH<=1;
					REG_TX_PACK_COUNT<=REG_TX_PACK_COUNT+1;
					REG_TX_FSM_STATE<=STATE_WRITE_PACKS;
				end
			end
		endcase
	end
	always@(posedge OUT_UART_RX_DATA_READY or posedge IN_RX_CLEAR_BUFFER)
	begin
		if(IN_RX_CLEAR_BUFFER)
		begin
			OUT_RX_NUM_OF_DATA_PACKS_READY<=1;
			OUT_RX_ERROR<=0;
			OUT_RX_DATA_MASSIV<=0;
		end
		else
		begin
			if (OUT_RX_NUM_OF_DATA_PACKS_READY<RX_MASSIV_DEEP)
				OUT_RX_NUM_OF_DATA_PACKS_READY=OUT_RX_NUM_OF_DATA_PACKS_READY+1;
			else 
				OUT_RX_NUM_OF_DATA_PACKS_READY=1;//для избежания переполнения буфера
			OUT_RX_DATA_MASSIV=ins_pack_in_vector(OUT_RX_DATA_MASSIV,OUT_UART_RX_DATA,OUT_RX_NUM_OF_DATA_PACKS_READY-1);
			OUT_RX_ERROR=OUT_UART_RX_ERROR|OUT_RX_ERROR;
		end
	end
	//функция- сепаратор пакета из вектора
	function [NUM_OF_DATA_BITS_IN_PACK-1:0] sel_part_vector;
		input [NUM_OF_DATA_BITS_IN_PACK*TX_MASSIV_DEEP-1:0] vector;
		input [TX_MASSIV_DEEP_LOG_2:0] index;
		reg [NUM_OF_DATA_BITS_IN_PACK_LOG_2:0] i;
		reg [NUM_OF_DATA_BITS_IN_PACK-1:0] buffer;
		begin
			for(i=0;i<NUM_OF_DATA_BITS_IN_PACK;i=i+1)
				buffer[i]=vector[i+index*NUM_OF_DATA_BITS_IN_PACK];
			sel_part_vector=buffer;
		end
	endfunction
	//функция- интегратор пакета в вектор
	function [NUM_OF_DATA_BITS_IN_PACK*RX_MASSIV_DEEP-1:0] ins_pack_in_vector;
		input [NUM_OF_DATA_BITS_IN_PACK*RX_MASSIV_DEEP-1:0] vector;
		input [NUM_OF_DATA_BITS_IN_PACK-1:0] pack;
		input [TX_MASSIV_DEEP_LOG_2:0] index;
		reg [NUM_OF_DATA_BITS_IN_PACK*RX_MASSIV_DEEP-1:0] vector_buf;
		reg [NUM_OF_DATA_BITS_IN_PACK_LOG_2:0] i;
		begin
			vector_buf=vector;
			for(i=0;i<NUM_OF_DATA_BITS_IN_PACK;i=i+1)
				vector_buf[i+index*NUM_OF_DATA_BITS_IN_PACK]=pack[i];
			ins_pack_in_vector=vector_buf;
		end
	endfunction
endmodule
