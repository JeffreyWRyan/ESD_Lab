library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
  
entity servo_controller_tb is
end entity servo_controller_tb;

architecture test_bench of servo_controller_tb is

component servo_controller
  port(
    I_CLK_50      :  in std_logic;
    I_CLK_50_RSI_N:  in std_logic;
    
    I_WE          :  in std_logic;
    I_WRITE_DATA  :  in std_logic_vector(31 downto 0);
    I_ADDRESS     :  in std_logic;
    
    O_IRQ         : out std_logic;
    O_PWM         : out std_logic
  );
end component servo_controller;

signal s_clk_50     : std_logic := '0';
signal s_clk_50_rsi : std_logic := '0';

signal s_we         : std_logic;
signal s_write_data : std_logic_vector(31 downto 0);
signal s_address    : std_logic;

signal s_irq        : std_logic := '0';
signal s_pwm        : std_logic;

begin

UUT : servo_controller
  port map(
    I_CLK_50      => s_clk_50,
    I_CLK_50_RSI_N=> s_clk_50_rsi,
    
    I_WE          => s_we,
    I_WRITE_DATA  => s_write_data,
    I_ADDRESS     => s_address,
    
    O_IRQ         => s_irq,
    O_PWM         => s_pwm
  );

CLOCKING_AND_RESET  : process
  constant C_PERIOD : time  :=  5ns;
begin
  wait for C_PERIOD;
  s_clk_50_rsi  <= '1';
  s_clk_50      <= not s_clk_50;
end process CLOCKING_AND_RESET;

IRQ_PROC  : process
begin 
  wait until s_irq = '1';
  s_address    <= '0';
  s_write_data <= (others => '0');
  s_we         <= '1';
  wait until s_irq = '0';
  s_we         <= '0';
end process IRQ_PROC;
end architecture test_bench;