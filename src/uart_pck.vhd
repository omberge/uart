library ieee;
		use ieee.std_logic_1164.all;
		use ieee.numeric_std.all;

package uart_pck is

  constant c_Startbit                      : std_logic := '0';
  constant c_Stopbit                       : std_logic := '1';
  constant c_NoOfStartbits                 : natural   := 1;

  constant c_RxReadyStr                    : integer   := 7;
  constant c_TxDoneStr                     : integer   := 6;
  constant c_RxFifoFull                    : integer   := 5;
  constant c_RxFifoHalfFull                : integer   := 4;
  constant c_RxFifoDataPresent             : integer   := 3;
  constant c_TxFifoFull                    : integer   := 2;
  constant c_TxFifoHalfFull                : integer   := 1;
  constant c_TxFifoDataPresent             : integer   := 0;

end package uart_pck;
