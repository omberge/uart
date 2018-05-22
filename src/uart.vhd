library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;
    
library work;
  use work.uart_pck.all;

entity uart is
  generic(
    c_FifoSize                      : integer := 0
  );
  port(
    -- Clock and Reset
    i_Clk                           : in  std_logic;
    i_Rst                           : in  std_logic;
    -- Registers
    i_TxBaudDivisor                 : in  std_logic_vector;
    i_TxData                        : in  std_logic_vector;
    i_TxDataWr                      : in  std_logic;
    i_RxBaudDivisor                 : in  std_logic_vector;
    o_RxData                        : out std_logic_vector;
    i_RxDataRd                      : in  std_logic;
    o_RxDataWakeup                  : out std_logic_vector(7 downto 0);
    o_Status                        : out std_logic_vector;
    -- Serial Communication (Uart)
    o_UartTx                        : out std_logic;
    i_UartRx                        : in  std_logic
  );
end entity;

architecture rtl of uart is

begin

-- *****************************************************************************
-- * p_Tx
-- *****************************************************************************
  g_p_Tx: if true generate
    constant c_NoOfTxDatabits                : natural := i_TxData'LENGTH;
    constant c_NoOfTxStopbits                : natural := 1;
    signal TxShiftReg                      : std_logic_vector(i_TxData'LEFT+1 downto 0);
    signal TxBaudCnt                       : unsigned        (i_TxBaudDivisor'RANGE);
    signal TxBitCnt                        : integer range -1 to c_NoOfStartbits+c_NoOfTxDatabits+c_NoOfTxStopbits-1;
    signal TxFifoDataPresent               : std_logic;
  begin
    p_Tx: process(i_Rst, i_Clk)
    begin
      if rising_edge(i_Clk) then
        o_Status(c_TxDoneStr) <= '0';

        if i_TxDataWr = '1' then
          TxShiftReg <= i_TxData & c_Startbit;
          TxBaudCnt <= to_unsigned(0, TxBaudCnt'LENGTH);
          TxBitCnt <= c_NoOfStartbits+c_NoOfTxDatabits+c_NoOfTxStopbits-1;
          TxFifoDataPresent <= '1';

        elsif TxFifoDataPresent = '1' then
          TxBaudCnt <= TxBaudCnt + 1;
          if TxBaudCnt = unsigned(i_TxBaudDivisor) then
            TxBaudCnt <= to_unsigned(0, TxBaudCnt'LENGTH);
            TxBitCnt <= TxBitCnt - 1;
            if TxBitCnt = 0 then
              TxFifoDataPresent <= '0';
              o_Status(c_TxDoneStr) <= '1';
            end if;
            TxShiftReg <= c_Stopbit & TxShiftReg(TxShiftReg'LEFT downto TxShiftReg'RIGHT+1);
          end if;
        end if;

      end if;

      if i_Rst = '1' then
        TxShiftReg <= (others => c_Stopbit);
        TxFifoDataPresent <= '0';
      end if;

    end process;

    o_Status(c_TxFifoFull)        <= TxFifoDataPresent;
    o_Status(c_TxFifoHalfFull)    <= TxFifoDataPresent;
    o_Status(c_TxFifoDataPresent) <= TxFifoDataPresent;
    o_UartTx <= TxShiftReg(TxShiftReg'RIGHT);

  end generate;
  

-- *****************************************************************************
-- * p_Rx
-- *****************************************************************************
  g_p_Rx: if true generate
    constant c_NoOfRxDatabits                : natural := o_RxData'LENGTH;
    constant c_NoOfRxStopbits                : natural := 1;

    signal UartRx_d                        : std_logic_vector( 2 downto  0);
    signal RxShiftReg                      : std_logic_vector(o_RxData'LEFT+1 downto 0);
    signal RxBaudCnt                       : unsigned        (i_RxBaudDivisor'RANGE);
    signal RxBitCnt                        : integer range -1 to c_NoOfStartbits+c_NoOfRxDatabits+c_NoOfRxStopbits-1;
    signal RxDataInProgress                : std_logic;
    signal RxFifoDataPresent               : std_logic;
    signal RxReadyStr                      : std_logic;
    signal RxData                          : std_logic_vector(o_RxData'RANGE);

  begin
    p_Rx: process(i_Rst, i_Clk)
    begin
      if rising_edge(i_Clk) then
        RxReadyStr <= '0';
        
        UartRx_d <= i_UartRx & UartRx_d(UartRx_d'LEFT downto UartRx_d'RIGHT+1);

        if UartRx_d(UartRx_d'LEFT-1 downto UartRx_d'RIGHT) = "01" and RxDataInProgress = '0' then

          RxDataInProgress <= '1';
          RxBaudCnt <= unsigned(i_RxBaudDivisor)/2;
          RxBitCnt <= c_NoOfStartbits+c_NoOfRxDatabits+c_NoOfRxStopbits-1;
          
        elsif RxDataInProgress = '1' then
        
          RxBaudCnt <= RxBaudCnt - 1;
          if RxBaudCnt = 0 then
            RxBaudCnt <= unsigned(i_RxBaudDivisor);
            RxShiftReg <= UartRx_d(UartRx_d'RIGHT) & RxShiftReg(RxShiftReg'LEFT downto RxShiftReg'RIGHT+1);
            RxBitCnt <= RxBitCnt - 1;
            if RxBitCnt = 0 then
              if RxShiftReg(RxShiftReg'RIGHT) = c_Startbit and UartRx_d(UartRx_d'RIGHT) = c_Stopbit then
                RxReadyStr <= '1';
                RxData <= RxShiftReg(RxShiftReg'LEFT downto RxShiftReg'RIGHT+1);
                RxFifoDataPresent <= '1';
              end if;
              RxDataInProgress <= '0';
              RxShiftReg <= (others => c_Stopbit);
            end if;
          end if;
          
          if i_RxDataRd = '1' then
            RxFifoDataPresent <= '0';
          end if;
          
        end if;
      end if;

      if i_Rst = '1' then
        RxReadyStr <= '0';
        UartRx_d <= (others => c_Stopbit);
        RxDataInProgress <= '0';
        RxBitCnt <= 0;
        RxFifoDataPresent <= '0';
        for i in RxData'RANGE loop
          RxData(i) <= '0';
        end loop;
      end if;

    end process;
    
    o_RxDataWakeup <= RxData;

    g_Fifo: if c_FifoSize /= 0 generate
      signal l_FifoEmpty                     : std_logic;
      signal l_FifoFull                      : std_logic;
    begin
      Fifo_0: entity work.Fifo
      generic map(
        c_Fwft                          => true                            ,
        c_FifoDepth                     => c_FifoSize                      
      )
      port map(
        i_Clk                           => i_Clk                           ,
        i_Rst                           => i_Rst                           ,
        i_WriteStr                      => RxReadyStr                      ,
        i_DataIn                        => RxData                          ,
        i_ReadStr                       => i_RxDataRd                      ,
        o_DataOut                       => o_RxData                        ,
        o_Empty                         => l_FifoEmpty                     ,
        o_Full                          => l_FifoFull                      
      );
      
      o_Status(c_RxFifoDataPresent) <= not l_FifoEmpty;
      o_Status(c_RxFifoHalfFull)    <= not l_FifoEmpty;
      o_Status(c_RxFifoFull)        <= l_FifoFull;
      o_Status(c_RxReadyStr)        <= RxReadyStr;
    end generate g_Fifo;
    
    g_NoFifo: if c_FifoSize = 0 generate
      o_Status(c_RxFifoDataPresent) <= RxFifoDataPresent;
      o_Status(c_RxFifoHalfFull)    <= RxFifoDataPresent;
      o_Status(c_RxFifoFull)        <= RxFifoDataPresent;
      o_Status(c_RxReadyStr)        <= RxReadyStr;
      o_RxData <= RxData;
    end generate g_NoFifo;

  end generate;

end architecture rtl;
