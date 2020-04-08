`timescale 1ns/1ps
module UART_TX_RX_MODULE_TB2#(
	parameter UART_BAUD_RATE				=	9600,
   parameter CLOCK_FREQUENCY				=	38400,
   parameter PARITY							=	2,
   parameter NUM_OF_DATA_BITS_IN_PACK	=	8,
	parameter NUMBER_STOP_BITS				=	1
);
localparam PERIOD_IN_CLOCK_NS=1000000000/CLOCK_FREQUENCY;
//Входы
reg IN_CLOCK_1, IN_CLOCK_2;
reg IN_TX_LAUNCH_1, IN_TX_LAUNCH_2;
reg [NUM_OF_DATA_BITS_IN_PACK-1:0] IN_TX_DATA_1, IN_TX_DATA_2;
//Выходы
wire OUT_TX_ACTIVE_1, OUT_TX_ACTIVE_2;
wire OUT_TX_DONE_1, OUT_TX_DONE_2;
wire OUT_TX_STOP_BIT_ACTIVE_1, OUT_TX_STOP_BIT_ACTIVE_2;
wire OUT_TX_START_BIT_ACTIVE_1, OUT_TX_START_BIT_ACTIVE_2;
wire OUT_RX_DATA_READY_1,	OUT_RX_DATA_READY_2;
wire [NUM_OF_DATA_BITS_IN_PACK-1:0] OUT_RX_DATA_1, OUT_RX_DATA_2;
wire OUT_RX_ERROR_1,OUT_RX_ERROR_2;

wire BUS_TRANSMIT_1_TO_2, BUS_TRANSMIT_2_TO_1;


	UART_TX_RX_MODULE #(
		.UART_BAUD_RATE(UART_BAUD_RATE),
		.CLOCK_FREQUENCY(CLOCK_FREQUENCY),
		.PARITY(PARITY),
		.NUM_OF_DATA_BITS_IN_PACK(NUM_OF_DATA_BITS_IN_PACK),
		.NUMBER_STOP_BITS(NUMBER_STOP_BITS)
	)
	UTRM_1
	(
		.IN_CLOCK(IN_CLOCK_1),
		.IN_TX_LAUNCH(IN_TX_LAUNCH_1),
		.IN_TX_DATA(IN_TX_DATA_1),
		
		.OUT_TX_ACTIVE(OUT_TX_ACTIVE_1),
		.OUT_TX_DONE(OUT_TX_DONE_1),
		.OUT_TX_STOP_BIT_ACTIVE(OUT_TX_STOP_BIT_ACTIVE_1),
		.OUT_TX_START_BIT_ACTIVE(OUT_TX_START_BIT_ACTIVE_1),
		.OUT_RX_DATA_READY(OUT_RX_DATA_READY_1),
		.OUT_RX_DATA(OUT_RX_DATA_1),
		.OUT_RX_ERROR(OUT_RX_ERROR_1),
		
		.IN_RX_SERIAL(BUS_TRANSMIT_2_TO_1),
		.OUT_TX_SERIAL(BUS_TRANSMIT_1_TO_2)
	);
	
	UART_TX_RX_MODULE #(
		.UART_BAUD_RATE(UART_BAUD_RATE),
		.CLOCK_FREQUENCY(CLOCK_FREQUENCY),
		.PARITY(PARITY),
		.NUM_OF_DATA_BITS_IN_PACK(NUM_OF_DATA_BITS_IN_PACK),
		.NUMBER_STOP_BITS(NUMBER_STOP_BITS)
	)
	UTRM_2
	(
		.IN_CLOCK(IN_CLOCK_2),
		.IN_TX_LAUNCH(IN_TX_LAUNCH_2),
		.IN_TX_DATA(IN_TX_DATA_2),
		
		.OUT_TX_ACTIVE(OUT_TX_ACTIVE_2),
		.OUT_TX_DONE(OUT_TX_DONE_2),
		.OUT_TX_STOP_BIT_ACTIVE(OUT_TX_STOP_BIT_ACTIVE_2),
		.OUT_TX_START_BIT_ACTIVE(OUT_TX_START_BIT_ACTIVE_2),
		.OUT_RX_DATA_READY(OUT_RX_DATA_READY_2),
		.OUT_RX_DATA(OUT_RX_DATA_2),
		.OUT_RX_ERROR(OUT_RX_ERROR_2),
		
		.IN_RX_SERIAL(BUS_TRANSMIT_1_TO_2),
		.OUT_TX_SERIAL(BUS_TRANSMIT_2_TO_1)
	);
	always 
	begin
		#(PERIOD_IN_CLOCK_NS/2)
		IN_CLOCK_1=!IN_CLOCK_1;
		IN_CLOCK_2=!IN_CLOCK_2;
	end
	initial begin
		IN_CLOCK_1=1'b1;IN_CLOCK_2=1'b0;
		IN_TX_LAUNCH_1=0;IN_TX_LAUNCH_2=0;
		IN_TX_DATA_1=8'bz;IN_TX_DATA_2=8'bz;
		#(PERIOD_IN_CLOCK_NS*10)
		IN_TX_DATA_1=8'b11001101;
		#(PERIOD_IN_CLOCK_NS*12)
		IN_TX_LAUNCH_1=1'b1;
		#(PERIOD_IN_CLOCK_NS*12)
		IN_TX_LAUNCH_1=1'b0;//убираем
		#(PERIOD_IN_CLOCK_NS*20)
		IN_TX_DATA_1=8'bz;

	end
	
	initial begin
		@(posedge OUT_RX_DATA_READY_2)
			begin
				IN_TX_DATA_2=OUT_RX_DATA_2; //заряжаем принятые данные, чтоб отправить обратно
				#(PERIOD_IN_CLOCK_NS*25)
				IN_TX_LAUNCH_2=1'b1;
				#(PERIOD_IN_CLOCK_NS*25)
				IN_TX_LAUNCH_2=1'b0;
				#(PERIOD_IN_CLOCK_NS*20)
				IN_TX_DATA_2=8'bz;
			end
	end

endmodule 