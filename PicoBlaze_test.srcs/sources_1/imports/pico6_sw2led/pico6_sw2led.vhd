--
-- Library declarations
--
-- Standard IEEE libraries
--
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
--
--
-------------------------------------------------------------------------------------------
--
--

entity pico6_sw2led is
  Port (     led1 : out std_logic_vector(7 downto 0);
             led2 : out std_logic_vector(7 downto 0);
          switch1 : in std_logic_vector(7 downto 0);
          switch2 : in std_logic_vector(7 downto 0);
         reset_b : in std_logic;
             clk : in std_logic);
  end pico6_sw2led;

--
-------------------------------------------------------------------------------------------
--
-- Start of test architecture
--
architecture Behavioral of pico6_sw2led is
--
-------------------------------------------------------------------------------------------
--
-- Components
--
-------------------------------------------------------------------------------------------
--

--
-- declaration of KCPSM6
--

  component kcpsm6 
    generic(                 hwbuild : std_logic_vector(7 downto 0) := X"00";
                    interrupt_vector : std_logic_vector(11 downto 0) := X"3FF";
             scratch_pad_memory_size : integer := 64);
    port (                   address : out std_logic_vector(11 downto 0);
                         instruction : in std_logic_vector(17 downto 0);
                         bram_enable : out std_logic;
                             in_port : in std_logic_vector(7 downto 0);
                            out_port : out std_logic_vector(7 downto 0);
                             port_id : out std_logic_vector(7 downto 0);
                        write_strobe : out std_logic;
                      k_write_strobe : out std_logic;
                         read_strobe : out std_logic;
                           interrupt : in std_logic;
                       interrupt_ack : out std_logic;
                               sleep : in std_logic;
                               reset : in std_logic;
                                 clk : in std_logic);
  end component;


--
-- Development Program Memory
--

  component sw2led_ctrl
    generic(             C_FAMILY : string := "7S"; 
                C_RAM_SIZE_KWORDS : integer := 1;
             C_JTAG_LOADER_ENABLE : integer := 0);
    Port (      address : in std_logic_vector(11 downto 0);
            instruction : out std_logic_vector(17 downto 0);
                 enable : in std_logic;
                    rdl : out std_logic;                    
                    clk : in std_logic);
  end component;
  
  

-------------------------------------------------------------------------------------------
--
-- Signals
--
-------------------------------------------------------------------------------------------
--
--
-- Signals used to connect KCPSM6
--
signal              address : std_logic_vector(11 downto 0);
signal          instruction : std_logic_vector(17 downto 0);
signal          bram_enable : std_logic;
signal              in_port : std_logic_vector(7 downto 0);
signal             out_port : std_logic_vector(7 downto 0);
signal              port_id : std_logic_vector(7 downto 0);
signal         write_strobe : std_logic;
signal       k_write_strobe : std_logic;
signal          read_strobe : std_logic;
signal            interrupt : std_logic := '0';
signal        interrupt_ack : std_logic;
signal         kcpsm6_sleep : std_logic;
signal         kcpsm6_reset : std_logic;
signal                  rdl : std_logic;
--
--
--
-------------------------------------------------------------------------------------------
--
-- Start of circuit description
--
-------------------------------------------------------------------------------------------
--
begin

  --
  -----------------------------------------------------------------------------------------
  -- Instantiate KCPSM6 and connect to program ROM
  -----------------------------------------------------------------------------------------
  --
  -- The generics can be defined as required. In this case the 'hwbuild' value is used to 
  -- define a version using the ASCII code for the desired letter and the interrupt vector
  -- has been set to 3C0 to provide 64 instructions for an Interrupt Service Routine (ISR)
  -- before reaching the end of a 1K memory 
  -- 
  --




  processor: kcpsm6
    generic map (                 hwbuild => X"41",    -- 41 hex is ASCII character "A"
                         interrupt_vector => X"3C0",   
                  scratch_pad_memory_size => 64)
    port map(      address => address,
               instruction => instruction,
               bram_enable => bram_enable,
                   port_id => port_id,
              write_strobe => write_strobe,
            k_write_strobe => k_write_strobe,
                  out_port => out_port,
               read_strobe => read_strobe,
                   in_port => in_port,
                 interrupt => interrupt,
             interrupt_ack => interrupt_ack,
                     sleep => kcpsm6_sleep,
                     reset => kcpsm6_reset,
                       clk => clk);
 

  --
  -- Reset by press button (active Low) or JTAG Loader enabled Program Memory 
  -- 

  kcpsm6_reset <= rdl or not(reset_b);


  -- 
  -- Unused signals tied off until required.
  -- Tying to other signals used to minimise warning messages.
  --

  kcpsm6_sleep <= write_strobe and k_write_strobe;  -- Always '0'


  --  
  -- Development Program Memory 
  --   JTAG Loader enabled for rapid code development. 
  --

  program_rom: sw2led_ctrl
    generic map(             C_FAMILY => "7S", 
                    C_RAM_SIZE_KWORDS => 1,
                 C_JTAG_LOADER_ENABLE => 1)
    port map(      address => address,      
               instruction => instruction,
                    enable => bram_enable,
                       rdl => rdl,
                       clk => clk);

  --
   -----------------------------------------------------------------------------------------
  -- General Purpose Input Ports. 
  -----------------------------------------------------------------------------------------
  --
  -- Two input ports are used with the UART macros. The first is used to monitor the flags
  -- on both the UART transmitter and receiver. The second is used to read the data from 
  -- the UART receiver. Note that the read also requires a 'buffer_read' pulse to be 
  -- generated.
  --
  -- This design includes a third input port to read 8 general purpose switches.
  --

  input_ports: process(clk)
  begin
    if clk'event and clk = '1' then
      case port_id(1 downto 0) is
       
       -- Read 8 general purpose switches at port address 02 hex
        when "01" =>       in_port <= switch1;
        when "10" =>       in_port <= switch2;

        -- Don't Care for unused case(s) ensures minimum logic implementation  

        when others =>    in_port <= "XXXXXXXX";  

      end case;

    end if;
  end process input_ports;

  --
  -----------------------------------------------------------------------------------------
  -- General Purpose Output Ports 
  -----------------------------------------------------------------------------------------
  --
  -- In this simple example there are two output ports. 
  --   A simple output port used to control a set of 8 general purpose LEDs.
  --   A port used to write data directly to the FIFO buffer within 'uart_tx6' macro.
  --

  --
  -- LEDs are connected to a typical KCPSM6 output port. 
  --  i.e. A register and associated decode logic to enable data capture.
  -- 

  output_ports: process(clk)
  begin
    if clk'event and clk = '1' then
      -- 'write_strobe' is used to qualify all writes to general output ports.
      if write_strobe = '1' then

        -- Write to LEDs at port address 02 hex
        if port_id(1) = '1' then
          led1 <= out_port;
        end if;
        if port_id(2) = '1' then
          led2 <= out_port;
        end if;

      end if;
    end if; 
  end process output_ports;

  --
  -----------------------------------------------------------------------------------------
  --

end Behavioral;

-------------------------------------------------------------------------------------------
--
-- END OF FILE pico6_sw2led.vhd
--
-------------------------------------------------------------------------------------------
