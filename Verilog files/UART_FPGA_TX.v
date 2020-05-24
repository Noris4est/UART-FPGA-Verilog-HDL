module UART_FPGA_TX 
  #(
	parameter UART_BAUD_RATE=9600,//baud
   parameter CLOCK_FREQUENCY=50000000,//IN_CLOCK frequency
   parameter PARITY=1,
	//parameter of parity bit in package
	//PARITY==0	:	package without parity bit
	//PARITY==1	:	package contains parity bit
	//PARITY==2	:	package contains odd bit
   parameter NUM_OF_DATA_BITS_IN_PACK=8,
	//number of data bits in package
	parameter NUMBER_STOP_BITS=2,
	//number of stop bits in package
	parameter CLKS_PER_BIT_LOG_2=$clog2(CLOCK_FREQUENCY/UART_BAUD_RATE),
	//the number of bits for the register of the main counter
	parameter NUM_OF_DATA_BITS_IN_PACK_LOG_2=$clog2(NUM_OF_DATA_BITS_IN_PACK)
	//the number of bits for the register of bit counter 
	) 
  (
   input       									IN_CLOCK,			//input clock							
   input       									IN_TX_LAUNCH,		//input launch port
   input [NUM_OF_DATA_BITS_IN_PACK-1:0] 	IN_TX_DATA,			//input data package for transmit  	
   output reg  									OUT_TX_ACTIVE,		//output TX bus active
   output reg  									OUT_TX_SERIAL,		//output TX port
   output reg  									OUT_TX_DONE,		//briefly set when packet transfer ends
	output reg 										OUT_STOP_BIT_ACTIVE,	//set when a start bit is transmitted
	output reg										OUT_START_BIT_ACTIVE	//set when a stop bit is transmitted
   );
  //finit state machine (FSM)
  localparam CLKS_PER_BIT = CLOCK_FREQUENCY/UART_BAUD_RATE ;
  //the number of IN_CLOCK cycles of the main generator 
  //for the transmission of one data bit
  
  localparam STATE_WAIT         = 3'b000;//wait set IN_TX_LAUNCH
  localparam STATE_TX_START_BIT = 3'b001;//transmit start bit
  localparam STATE_TX_DATA_BITS = 3'b010;//transmit data bits
  localparam STATE_PARITY_BIT   = 3'b101;//transmit parity bit
  localparam STATE_TX_STOP_BIT  = 3'b011;//transmit stop bit
  
  reg [2:0]    									REG_STATE;//FSM state register		
  reg [CLKS_PER_BIT_LOG_2:0]    				REG_CLOCK_COUNT;//main counter register			
  reg [NUM_OF_DATA_BITS_IN_PACK_LOG_2:0]  REG_BIT_INDEX;//bit counter register  			
  reg [NUM_OF_DATA_BITS_IN_PACK-1:0]		REG_TX_DATA;//transmit data package register 			
  reg 												REG_FLAG_DONE_TRANSACTION;
  
  
  initial begin
		//initial internal registers
		REG_STATE   					= STATE_WAIT;
		REG_CLOCK_COUNT				= 0;
		REG_BIT_INDEX  				= 0;
		REG_TX_DATA		 				= 0;
		REG_FLAG_DONE_TRANSACTION	= 0;
		
		//initial output registers
		OUT_TX_ACTIVE					= 0;
		OUT_TX_SERIAL					= 1;
		OUT_TX_DONE						= 0;
		OUT_STOP_BIT_ACTIVE			= 0;
		OUT_START_BIT_ACTIVE			= 0;
  end
  
  always @(posedge IN_CLOCK)
  begin 
      case (REG_STATE)
        STATE_WAIT ://состояние ожидания
        begin
				/*
				Формирование короткого (на один такт основного генератора)
				импульса- индикатора 
				окончания элементарной транзакции
				*/
				if(REG_FLAG_DONE_TRANSACTION==1) 
				begin 
					OUT_TX_DONE      				<= 1'b1;  
					OUT_TX_ACTIVE   				<= 1'b0;
					REG_FLAG_DONE_TRANSACTION	<= 0;
				end 
				else	
					OUT_TX_DONE     				<= 1'b0;
				
				OUT_STOP_BIT_ACTIVE				<=	0;
				OUT_TX_SERIAL  			   	<= 1'b1;         
            if (IN_TX_LAUNCH == 1'b1) //Начало передачи данных 
            begin
					OUT_TX_DONE      				<= 1'b0;  
					OUT_TX_ACTIVE					<= 1'b1;
					REG_TX_DATA   					<= IN_TX_DATA;//защелкивание данных
					REG_STATE  	  					<= STATE_TX_START_BIT;//смена состояния автомата
					OUT_TX_SERIAL 					<= 1'b0;//линия TX притягивается к нулю в соответствии с протоколом
					OUT_START_BIT_ACTIVE			<= 1;
            end
		  end 
        STATE_TX_START_BIT ://состояние передачи старт-бита (линия держится в нуляе на время одного тайм-слота)
        begin
				if (REG_CLOCK_COUNT < CLKS_PER_BIT-2)//классический счетчик
					REG_CLOCK_COUNT <= REG_CLOCK_COUNT + 1'b1;
            else
				begin
					REG_CLOCK_COUNT 	<= 0;
					REG_STATE     		<= STATE_TX_DATA_BITS; //по окончании счета смена состояния автомата
				end
        end      
        STATE_TX_DATA_BITS ://состояние передачи информационных битов
        begin
				OUT_START_BIT_ACTIVE	<=	0;
            OUT_TX_SERIAL <= REG_TX_DATA[REG_BIT_INDEX];//заряжается/держится конкретный бит на линию TX  
            if (REG_CLOCK_COUNT < CLKS_PER_BIT-1) //классический счетчик 
                REG_CLOCK_COUNT <= REG_CLOCK_COUNT + 1'b1;           
            else
				begin
					REG_CLOCK_COUNT <= 0;
               if (REG_BIT_INDEX < NUM_OF_DATA_BITS_IN_PACK-1'b1)
					/*
					По окончаии счета идет проверка номера бита в пакете данных.
					Если номер не больше, чем уговоренный объем пакета,
					то индекс бита увеличится
					*/
						REG_BIT_INDEX <= REG_BIT_INDEX + 1'b1;                                   
					else
               begin
						/*
						Если был отправлен последний бит, 
						то посылка информационных бит окончена.
						В таком случае индекс битов обнуляется.
						Далее состояние автомата напрямую зависит от параметра 
						PARITY. Автомат далее переходит либо в состояние 
						передачи стоп-бита
						*/
						REG_BIT_INDEX <= 0;
						if(PARITY==0)
							REG_STATE   <= STATE_TX_STOP_BIT;
						else
							REG_STATE   <= STATE_PARITY_BIT;
               end
				end
        end 
        STATE_PARITY_BIT://состояние отправки старт- бита
		  begin
				case(PARITY) //на линию ставится бит в зависимости от параметра четности
					1: OUT_TX_SERIAL <= (sum_of_bits(REG_TX_DATA)%2==0)? 0:1'b1;
					2: OUT_TX_SERIAL <= (sum_of_bits(REG_TX_DATA)%2==0)? 1'b1:0;
				endcase
		      if (REG_CLOCK_COUNT < CLKS_PER_BIT-1) //один тайм-слот
					REG_CLOCK_COUNT 	<= REG_CLOCK_COUNT + 1'b1;         
            else
            begin
                REG_CLOCK_COUNT 	<= 0;
                REG_STATE     	<= STATE_TX_STOP_BIT;
            end
	     end
        STATE_TX_STOP_BIT ://состояние отправки стоп-бита
        begin
				OUT_STOP_BIT_ACTIVE<=1;
				OUT_TX_SERIAL <= 1'b1;//На линию ставится высокий сигнал (1)
            if (REG_CLOCK_COUNT < CLKS_PER_BIT*NUMBER_STOP_BITS-1'b1) //классический счетчик            
					REG_CLOCK_COUNT <= REG_CLOCK_COUNT + 1'b1;              
            else
            begin
					REG_FLAG_DONE_TRANSACTION		<=	1;//транзакция считается законченной 
               REG_CLOCK_COUNT 					<= 0;//счетчик обнуляется
               REG_STATE     						<= STATE_WAIT;//автомат переходит в состояние ожидания
            end
        end            
        default :
          REG_STATE <= STATE_WAIT; //при аномальном уровне REG_STATE.     
      endcase
  end
  function [NUM_OF_DATA_BITS_IN_PACK_LOG_2:0] sum_of_bits;//функция суммирует компоненты регистра 
  //this function sums the bits in a register
		input [NUM_OF_DATA_BITS_IN_PACK-1:0] value;
		reg[NUM_OF_DATA_BITS_IN_PACK_LOG_2:0] sum;
		reg[NUM_OF_DATA_BITS_IN_PACK_LOG_2:0] i;
		begin
			sum=0;
			for (i=0;i<=NUM_OF_DATA_BITS_IN_PACK-1'b1;i=i+1'b1)
				sum=sum+value[i];
			sum_of_bits=sum;
		end
  endfunction
endmodule
