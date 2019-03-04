--Jeffrey Ryan
--Custom IP core for servo motor controller
--Embedded Systems Design I

library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;
    
entity servo_controller is 
    PORT(
        I_CLK_50            :   in  std_logic;
        I_CLK_50_RSI_N      :   in  std_logic;
        
        I_WE                :   in  std_logic;
        I_WRITE_DATA        :   in  std_logic_vector(31 downto 0);
        I_ADDRESS           :   in  std_logic;
        
        O_IRQ               :   out std_logic;
        O_PWM               :   out std_logic
    );
end entity servo_controller;

architecture rtl of servo_controller is

type soft_ram is array (1 downto 0) of std_logic_vector(31 downto 0);
signal s_ram                 :   soft_ram;

signal s_write_data          :   std_logic_vector(31 downto 0);
signal s_address             :   std_logic_vector(1 downto 0);
signal s_we                  :   std_logic;
signal s_minimum_pwm         :   unsigned(31 downto 0);
signal s_maximum_pwm         :   unsigned(31 downto 0);

signal s_irq                 :   std_logic;

signal s_pwm_count           :   unsigned(31 downto 0);

signal s_100ms_strobe_timing :   unsigned(31 downto 0);
signal s_100ms_strobe        :   std_logic;

signal s_current_pwm         :   unsigned(31 downto 0);
signal s_arm_direction       :   std_logic;

signal s_pwm_out             :   std_logic;

begin
----------------------------------------------------------------------------------------------------
SYNCH_INC_SIGNALS   :   process(I_CLK_50, I_CLK_50_RSI_N)
begin
    if (I_CLK_50_RSI_N = '0') then
        s_write_data    <= (others => '0');
        s_address       <= (others => '0');
        s_we            <= '0';
    
    elsif (rising_edge(I_CLK_50)) then
        s_write_data    <= I_WRITE_DATA;
        s_address       <= '0' & I_ADDRESS;
        s_we            <= I_WE;
    end if;
end process SYNCH_INC_SIGNALS;
----------------------------------------------------------------------------------------------------
IRQ_CONTROL :   process(I_CLK_50, I_CLK_50_RSI_N)
begin
    if (I_CLK_50_RSI_N = '0') then
        s_irq       <= '0';
        
    elsif (rising_edge(I_CLK_50)) then
        if ((s_current_pwm = s_minimum_pwm) or (s_current_pwm = s_maximum_pwm)) then
            s_irq   <= '1';
        elsif (s_we = '1') then
            s_irq   <= '0';
        end if;
    end if;
end process IRQ_CONTROL;
O_IRQ               <= s_irq;
----------------------------------------------------------------------------------------------------
WRITE_TO_RAM    :   process(I_CLK_50, I_CLK_50_RSI_N)
	constant C_DEFAULT_MIN	:	unsigned(31 downto 0) := to_unsigned(5, 32);
	constant C_DEFAULT_MAX	:	unsigned(31 downto 0) := to_unsigned(15, 32);
begin
    if(I_CLK_50_RSI_N = '0') then
        s_ram(0)                                       <= std_logic_vector(C_DEFAULT_MIN);
        s_ram(1)                                       <= std_logic_vector(C_DEFAULT_MAX);
        
    elsif (rising_edge(I_CLK_50)) then
        if (s_we = '1') then
            s_ram(to_integer(unsigned(s_address)))  <= s_write_data;
        end if;
    end if;
end process WRITE_TO_RAM;
-- Asynchronously pass the minimum and maximum values into their appropriate vectors
s_minimum_pwm <= unsigned(s_ram(0));
s_maximum_pwm <= unsigned(s_ram(1));
----------------------------------------------------------------------------------------------------
PWM_TIMING  :   process(I_CLK_50, I_CLK_50_RSI_N)
    constant C_20MS_PERIOD : unsigned(31 downto 0) := to_unsigned(30, 32); --50MHZ clock = 20ns period.  20ns * 1,000,000 = 20ms.
begin
    if (I_CLK_50_RSI_N = '0') then
        s_pwm_count     <= (others => '1');
        
    elsif (rising_edge(I_CLK_50)) then
        if (s_pwm_count = C_20MS_PERIOD) then
            s_pwm_count <= (others => '0');
        else
            s_pwm_count <= s_pwm_count + 1;
        end if;
    end if;
end process PWM_TIMING;
----------------------------------------------------------------------------------------------------
--100ms strobe.  The strobe dictates when the s_current_pwm signal increments or decrements.
STROBE_100MS    :   process(I_CLK_50, I_CLK_50_RSI_N)
    constant C_100MS    :   unsigned(31 downto 0) := to_unsigned(30, 32); --50MHz clock = 20ns period.  20ns * 5,000,000 = 100ms
begin
    if (I_CLK_50_RSI_N = '0') then
        s_100ms_strobe_timing       <= (others => '0');
        s_100ms_strobe              <= '0';
        
    elsif (rising_edge(I_CLK_50)) then
        if (s_100ms_strobe_timing = C_100MS) then
            s_100ms_strobe_timing   <= (others => '0');
            s_100ms_strobe          <= '1';
        else
            s_100ms_strobe_timing   <= s_100ms_strobe_timing + 1;
            s_100ms_strobe          <= '0';
        end if;
    end if;
end process STROBE_100MS;
----------------------------------------------------------------------------------------------------
--s_arm_direction = '1' then move min to max
--s_arm_direction = '0' then move max to min
PULSE_WIDTH_MODULATOR   :   process(I_CLK_50, I_CLK_50_RSI_N)
	constant C_DEFAULT_PWM	:	unsigned(31 downto 0) := to_unsigned(6, 32);
begin
    if (I_CLK_50_RSI_N = '0') then
        s_current_pwm       <= C_DEFAULT_PWM;
        s_arm_direction     <= '1';
        
    elsif (rising_edge(I_CLK_50)) then
        if (s_arm_direction = '1') then
            if (s_current_pwm = unsigned(s_maximum_pwm)) then
                s_current_pwm   <= s_current_pwm - 1;
                s_arm_direction <= '0';
            elsif (s_100ms_strobe = '1') then
                s_current_pwm   <= s_current_pwm + 1;
                s_arm_direction <= s_arm_direction;                
            else
                s_current_pwm   <= s_current_pwm;
                s_arm_direction <= s_arm_direction;
            end if;
        else
            if (s_current_pwm = unsigned(s_minimum_pwm)) then
                s_current_pwm   <= s_current_pwm + 1;
                s_arm_direction <= '1';
            elsif (s_100ms_strobe = '1') then
                s_current_pwm   <= s_current_pwm - 1;
                s_arm_direction <= s_arm_direction;                
            else
                s_current_pwm   <= s_current_pwm;
                s_arm_direction <= s_arm_direction;
            end if;
        end if;
    end if;
end process PULSE_WIDTH_MODULATOR;
----------------------------------------------------------------------------------------------------
PWM_OUTPUT  :   process(I_CLK_50, I_CLK_50_RSI_N)
begin
    if (I_CLK_50_RSI_N = '0') then
        s_pwm_out          <= '0';
        
    elsif (rising_edge(I_CLK_50)) then
        if (s_pwm_count < s_current_pwm) then
            s_pwm_out      <= '1';
        else
            s_pwm_out      <= '0';
        end if;
    end if;
end process PWM_OUTPUT;
O_PWM                      <= s_pwm_out;
----------------------------------------------------------------------------------------------------
end architecture rtl;