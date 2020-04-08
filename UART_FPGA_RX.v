module UART_FPGA_RX 
  #(
  parameter UART_BAUD_RATE=9600,//битрейт передачи данных
  parameter CLOCK_FREQUENCY=50000000,//частота генератора i_clock
  parameter PARITY=1,//параметр бита четности.0-без бита четности. 1-бит четности. 2-бит нечетности.
  parameter CLKS_PER_BIT_LOG_2=$clog2(CLOCK_FREQUENCY/UART_BAUD_RATE), //число бит -1, которое будет выделено под регистр, в котором будет вестись счет тактов генератора
  parameter NUM_OF_DATA_BITS_IN_PACK=8,//число информационных бит в пакете.
  parameter NUM_OF_DATA_BITS_IN_PACK_LOG_2=$clog2(NUM_OF_DATA_BITS_IN_PACK)
  )
  (
   input        IN_CLOCK,												//входной тактовый сигнал
   input        IN_RX_SERIAL,											//линия RX, с которой модуль будет считывать информацию
   output reg   OUT_RX_DATA_READY,									//сигнал, который сообщает об окончании процесса приема пакета
   output reg   [NUM_OF_DATA_BITS_IN_PACK-1:0] OUT_RX_DATA=0,	//принятые данные
	output reg   OUT_RX_ERROR=0//индикатор ошибки приема данных-определяется по биту четности. Если PARITY=0, то этот выход не несет информации.
   );
	
  parameter CLKS_PER_BIT = CLOCK_FREQUENCY/UART_BAUD_RATE ;//тактов основного генератора за один переданный бит
  parameter STATE_WAIT         = 3'b000;//состояние ожидания посылки.RX подвешена к высокому потенциалу.
  parameter STATE_RX_START_BIT = 3'b001;//состояние отсчета до половины старт-бита, чтоб удостовериться в его действительности.
  parameter STATE_RX_DATA_BITS = 3'b010;//состояние приема пакета данных
  parameter STATE_RX_STOP_BIT  = 3'b011;//состояние ожидания стоп-бита
  parameter STATE_RX_PARITY_BIT= 3'b100;//состояние ожидания юита четности/нечетности
  
  reg [CLKS_PER_BIT_LOG_2:0]REG_CLOCK_COUNT = 0;//регистр счетчика тактов основного генератора
  reg [NUM_OF_DATA_BITS_IN_PACK_LOG_2:0]     REG_BIT_INDEX    			  = 0;//регистр под индекс бита в регистре при считывании
  reg [2:0]     REG_STATE     				  = 0;//регистр состояния конечного автомата
  always @(posedge IN_CLOCK)
  begin
		case (REG_STATE)//состояние ожидания
			STATE_WAIT:
         begin
            OUT_RX_DATA_READY			<= 1'b0;
            OUT_RX_ERROR			  		<=0;
            if (IN_RX_SERIAL == 1'b0)          // старт бит обнаружен
					REG_STATE <= STATE_RX_START_BIT;
         end
         STATE_RX_START_BIT :
         begin
				if (REG_CLOCK_COUNT == CLKS_PER_BIT/2-2)
            begin
					if (IN_RX_SERIAL == 1'b0)
						begin
							REG_CLOCK_COUNT <= 0;  
							REG_STATE     <= STATE_RX_DATA_BITS;
                  end
               else
						   REG_STATE <= STATE_WAIT;//если сигнал старт бита не подтвердился, то переход в состояние ожидания 
            end
            else REG_CLOCK_COUNT <= REG_CLOCK_COUNT + 1;
              
         end 
         STATE_RX_DATA_BITS:
         begin
				if (REG_CLOCK_COUNT < CLKS_PER_BIT-1)
                REG_CLOCK_COUNT <= REG_CLOCK_COUNT + 1;
            else
            begin
					REG_CLOCK_COUNT          	<= 0;
               OUT_RX_DATA[REG_BIT_INDEX] <= IN_RX_SERIAL;
               if (REG_BIT_INDEX < NUM_OF_DATA_BITS_IN_PACK-1)
						REG_BIT_INDEX <= REG_BIT_INDEX + 1;
               else
						begin
							REG_BIT_INDEX <= 0;
							if(PARITY!=0)
								REG_STATE   <= STATE_RX_PARITY_BIT;
							else
								REG_STATE   <= STATE_RX_STOP_BIT;
                  end
            end
         end 
         STATE_RX_PARITY_BIT:
			begin
				if (REG_CLOCK_COUNT < CLKS_PER_BIT-1)
					REG_CLOCK_COUNT <= REG_CLOCK_COUNT + 1;
            else
					begin
						REG_CLOCK_COUNT <= 0;
						REG_STATE   <= STATE_RX_STOP_BIT;
						case(PARITY)
							1:OUT_RX_ERROR<=((sum_of_bits(OUT_RX_DATA)+IN_RX_SERIAL)%2==0) ?0:1;//если последний бит-бит четности
							2:OUT_RX_ERROR<=((sum_of_bits(OUT_RX_DATA)+IN_RX_SERIAL)%2==0)?1:0;//если последний бит-бит нечетности
						endcase	
				  end
				end
			STATE_RX_STOP_BIT :
         begin
				if (REG_CLOCK_COUNT < CLKS_PER_BIT-1)
					REG_CLOCK_COUNT <= REG_CLOCK_COUNT + 1;
				else
					begin
						if(IN_RX_SERIAL)
						begin
							if(!OUT_RX_ERROR)
							OUT_RX_DATA_READY       <= 1'b1;
							REG_CLOCK_COUNT 			<= 0;
							REG_STATE   			   <= STATE_WAIT;
						end
						else
						begin
							OUT_RX_ERROR				<=1;
							REG_STATE					<=STATE_WAIT;
							REG_CLOCK_COUNT			<=0;
						end
					end
			end               
        default :
				REG_STATE <= STATE_WAIT;
      endcase
  end   
  function [NUM_OF_DATA_BITS_IN_PACK_LOG_2:0] sum_of_bits;//функция подсчета суммы бит в пакете 
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