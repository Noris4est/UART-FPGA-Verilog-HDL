module UART_FPGA_RX 
  #(
  parameter UART_BAUD_RATE							=9600,
  //baud 
  parameter CLOCK_FREQUENCY						=50000000,
  //frequency IN_CLOCK
  parameter PARITY									=1,
  //parameter of parity bit in package
  //PARITY==0	:	package without parity bit
  //PARITY==1	:	package contains parity bit
  //PARITY==2	:	package contains odd bit
  parameter NUM_OF_DATA_BITS_IN_PACK			=8,//number of data bits in package
  parameter CLKS_PER_BIT_LOG_2					=$clog2(CLOCK_FREQUENCY/UART_BAUD_RATE), 
  //the number of bits for the register of the main counter
  parameter NUM_OF_DATA_BITS_IN_PACK_LOG_2	=$clog2(NUM_OF_DATA_BITS_IN_PACK)
  //the number of bits for the register of bit counter 
  )
  (
   input        											IN_CLOCK,			//input clock
   input       											IN_RX_SERIAL,		//UART RX port
   output reg   											OUT_RX_DATA_READY,//set brifely when a data package is received
   output reg   [NUM_OF_DATA_BITS_IN_PACK-1:0] 	OUT_RX_DATA,		//received data package 
	output reg   											OUT_RX_ERROR		//read error indicator
   );
  localparam CLKS_PER_BIT 		  = CLOCK_FREQUENCY/UART_BAUD_RATE ;
  //the number of IN_CLOCK cycles of the main generator 
  //for the transmission of one data bit
  
  //finit state machine 
  localparam STATE_WAIT         = 3'b000;//state wait start bit
  //состояние ожидания старт-бита на линии 
  localparam STATE_RX_START_BIT = 3'b001;//state wait half start bit to chack bus status again
  //состояние приема старт-бита
  localparam STATE_RX_DATA_BITS = 3'b010;//state package read
  //состояние считывания информационных битов
  localparam STATE_RX_STOP_BIT  = 3'b011;//state wait stop bit
  //состояние считывания стоп-бита
  localparam STATE_RX_PARITY_BIT= 3'b100;//state wait and check parity bit
  //состояние считывания бита четности/нечетности
  //internal registers//внутренние регистры
  
  reg [CLKS_PER_BIT_LOG_2:0]							REG_CLOCK_COUNT;	//main counter 
  reg [NUM_OF_DATA_BITS_IN_PACK_LOG_2:0]     	REG_BIT_INDEX;		//bit index counter 
  reg [2:0]    											REG_STATE;			//this register contains FSM state
  //определение начальных начальных значений регистров
  initial begin
		//initial output registers
		OUT_RX_DATA_READY								=0;
		OUT_RX_DATA										=0;
		OUT_RX_ERROR									=0;
		//initial internal registers
		REG_CLOCK_COUNT								=0;
		REG_BIT_INDEX									=0;
		REG_STATE										=STATE_WAIT;
  end
  
  always @(posedge IN_CLOCK)
  begin
		case (REG_STATE)
			STATE_WAIT:
         begin
            OUT_RX_DATA_READY				<= 1'b0;
            OUT_RX_ERROR			  		<= 0;
            if (IN_RX_SERIAL == 1'b0)          // start bit detected//обнаружен старт-бит
					REG_STATE <= STATE_RX_START_BIT;
         end
         STATE_RX_START_BIT :
         begin
				if (REG_CLOCK_COUNT == CLKS_PER_BIT/2-2)
				/*
				Повторное считывание состояние линии для 
				проверки действительности начала передачи.
				Если на линии все еще низкий уровень сигнала, то
				приемник продолжает работать в стандартном режиме,
				тогда автомат переходит в состояние чтения информационных бит.
				Если на линии высокий сигнал, то оъявляется ошибка инициализации
				транзакции. Приемник переходит в состояние ожидания. 
				*/
            begin
					if (IN_RX_SERIAL == 1'b0)
						begin
							REG_CLOCK_COUNT <= 0;  
							REG_STATE      <= STATE_RX_DATA_BITS;
                  end
               else
						   REG_STATE      <= STATE_WAIT; 
            end
            else REG_CLOCK_COUNT <= REG_CLOCK_COUNT + 1; 
         end 
         STATE_RX_DATA_BITS://состояние считывания информационных бит
         begin
				if (REG_CLOCK_COUNT < CLKS_PER_BIT-1)//классический счетчик
                REG_CLOCK_COUNT <= REG_CLOCK_COUNT + 1;
            else
            begin
					REG_CLOCK_COUNT          	<= 0;
               OUT_RX_DATA[REG_BIT_INDEX] <= IN_RX_SERIAL;//считывается очередной бит
               if (REG_BIT_INDEX < NUM_OF_DATA_BITS_IN_PACK-1)
						REG_BIT_INDEX <= REG_BIT_INDEX + 1;
               else
					begin
						REG_BIT_INDEX <= 0;
						if(PARITY!=0)//следующие состояние зависит от параметра четности
							REG_STATE   <= STATE_RX_PARITY_BIT;
						else
							REG_STATE   <= STATE_RX_STOP_BIT;
               end
            end
         end 
         STATE_RX_PARITY_BIT://чтение бита четности
			begin
				if (REG_CLOCK_COUNT < CLKS_PER_BIT-1)//классический счетчик
					REG_CLOCK_COUNT <= REG_CLOCK_COUNT + 1;
            else
				begin
					REG_CLOCK_COUNT <= 0;
					REG_STATE   <= STATE_RX_STOP_BIT;
					case(PARITY)	//проверка правильности приема пакета по биту четности
						1:OUT_RX_ERROR<=((sum_of_bits(OUT_RX_DATA)+IN_RX_SERIAL)%2==0) ?0:1;//если последний бит-бит четности
						2:OUT_RX_ERROR<=((sum_of_bits(OUT_RX_DATA)+IN_RX_SERIAL)%2==0)?1:0;//если последний бит-бит нечетности
					endcase	
				end
			end
			STATE_RX_STOP_BIT://состояние считывания стоп-бита
         begin
				if (REG_CLOCK_COUNT < CLKS_PER_BIT-1)
					REG_CLOCK_COUNT <= REG_CLOCK_COUNT + 1;
				else
				begin
					if(IN_RX_SERIAL)
					begin
						if(!OUT_RX_ERROR)
							OUT_RX_DATA_READY    <= 1'b1;
						REG_CLOCK_COUNT 			<= 0;//обнуление счетчика
						REG_STATE   			   <= STATE_WAIT;
					end
					else
					begin
						OUT_RX_ERROR				<=1;//если на линии не высокий сигнал, то ошибка
						REG_STATE					<=STATE_WAIT;//автомат переходит в состояние ожидания
						REG_CLOCK_COUNT			<=0;//обнуляется счетчик
					end
				end
			end               
         default :
				REG_STATE <= STATE_WAIT;//при аномальном значении REG_STATE переход в состояние ожидания
      endcase
  end   
  function [NUM_OF_DATA_BITS_IN_PACK_LOG_2:0] sum_of_bits;//функция суммирует биты в регистре
  //this function sums the bits in a register
		input [NUM_OF_DATA_BITS_IN_PACK-1:0] value;
		reg[NUM_OF_DATA_BITS_IN_PACK_LOG_2:0] sum;
		reg[NUM_OF_DATA_BITS_IN_PACK_LOG_2:0] i;
		begin
			sum=0;
			for (i=0;i<NUM_OF_DATA_BITS_IN_PACK;i=i+1)
				sum=sum+value[i];	
			sum_of_bits=sum;
		end
	endfunction   
endmodule 