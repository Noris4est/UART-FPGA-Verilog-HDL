module UART_TX_RX_MODULE
#(
	parameter UART_BAUD_RATE				=	9600,//битрейт передачи
   parameter CLOCK_FREQUENCY				=	50000000,//частота тактового сигнала IN_CLOCK
   parameter PARITY							=	1,//Параметр бита четности/нечетности
   parameter NUM_OF_DATA_BITS_IN_PACK	=	8,//число информационных бит в пакете 
	parameter NUMBER_STOP_BITS				=	2//число стоп-битов а пакете
)
(
	input       IN_CLOCK,											//тактовый сигнал
   input       IN_TX_LAUNCH,										//сигнальная линия для инициализации передачи
   input [NUM_OF_DATA_BITS_IN_PACK-1:0] IN_TX_DATA, 		//вектор данных для передачи при следующей транзакции
	//данный вектор защелкивается во внутреннем регистре модуля при иниализации передачи.
	
   output   OUT_TX_ACTIVE,											//сигнальная линия активности передаточного узла TX
   output   OUT_TX_DONE,											//сигнальная линия окончания передачи пакета
	output  	OUT_TX_STOP_BIT_ACTIVE,								//сигнальная линия передачи стоп бита модулем TX
	output 	OUT_TX_START_BIT_ACTIVE,							//сигнальная линия передачи старт бита модулем TX
   output   OUT_RX_DATA_READY,									//сигнальная линия готовности данных OUT_RX_DATA приемника 
   output   [NUM_OF_DATA_BITS_IN_PACK-1:0] OUT_RX_DATA,	//вектор данных, принятый приемником RX 
	output   OUT_RX_ERROR,											//сигнальная линия ошибки приема последнего пакета
	
	
	input        IN_RX_SERIAL,		//RX
	output 	    OUT_TX_SERIAL		//TX
);
	
	localparam NUM_OF_DATA_BITS_IN_PACK_LOG_2=$clog2(NUM_OF_DATA_BITS_IN_PACK) ;
	localparam CLKS_PER_BIT_LOG_2=$clog2(NUMBER_STOP_BITS*CLOCK_FREQUENCY/UART_BAUD_RATE);

	UART_FPGA_TX #(
		.UART_BAUD_RATE(UART_BAUD_RATE),
		.CLOCK_FREQUENCY(CLOCK_FREQUENCY),
		.PARITY(PARITY),
		.CLKS_PER_BIT_LOG_2(CLKS_PER_BIT_LOG_2),
		.NUM_OF_DATA_BITS_IN_PACK(NUM_OF_DATA_BITS_IN_PACK),
		.NUM_OF_DATA_BITS_IN_PACK_LOG_2(NUM_OF_DATA_BITS_IN_PACK_LOG_2),
		.NUMBER_STOP_BITS(NUMBER_STOP_BITS)
	)
	TX
	(
		.IN_CLOCK(IN_CLOCK),
		.IN_TX_LAUNCH(IN_TX_LAUNCH),
		.IN_TX_DATA(IN_TX_DATA),
		.OUT_TX_ACTIVE(OUT_TX_ACTIVE),
		.OUT_TX_SERIAL(OUT_TX_SERIAL),
		.OUT_TX_DONE(OUT_TX_DONE),
		.OUT_TX_STOP_BIT_ACTIVE(OUT_TX_STOP_BIT_ACTIVE),
		.OUT_TX_START_BIT_ACTIVE(OUT_TX_START_BIT_ACTIVE)
	);//подключение модуля TX
	
	UART_FPGA_RX #(
		.UART_BAUD_RATE(UART_BAUD_RATE),
		.CLOCK_FREQUENCY(CLOCK_FREQUENCY),
		.PARITY(PARITY),
		.CLKS_PER_BIT_LOG_2(CLKS_PER_BIT_LOG_2),
		.NUM_OF_DATA_BITS_IN_PACK(NUM_OF_DATA_BITS_IN_PACK),
		.NUM_OF_DATA_BITS_IN_PACK_LOG_2(NUM_OF_DATA_BITS_IN_PACK_LOG_2)
	)
	RX
	(
		.IN_CLOCK(IN_CLOCK),
		.IN_RX_SERIAL(IN_RX_SERIAL),
		.OUT_RX_DATA_READY(OUT_RX_DATA_READY),
		.OUT_RX_DATA(OUT_RX_DATA),
		.OUT_RX_ERROR(OUT_RX_ERROR)
	); //подключение модуля RX
	
endmodule
