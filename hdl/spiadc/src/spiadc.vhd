---------------------------------------------------------------------------------------------------
-- Copyright (c) 2025 Stefan Stähli
---------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------
-- Description
---------------------------------------------------------------------------------------------------
-- This entity implements the SPI ADC interface to read three-phase voltages
-- and the DC bus voltage from an external ADC via SPI.

---------------------------------------------------------------------------------------------------
-- Libraries
---------------------------------------------------------------------------------------------------
library IEEE;
    use IEEE.STD_LOGIC_1164.ALL;
    use IEEE.NUMERIC_STD.ALL;
    use IEEE.MATH_REAL.ALL;

---------------------------------------------------------------------------------------------------
-- Entity Declaration
---------------------------------------------------------------------------------------------------
entity SpiAdc is
    generic (
        DataWidth_g : natural;
        ClockFrequenceyMHz_g : natural
    );
    port (
        Clk     : in std_logic;
        Rst     : in std_logic;
        Trigger : in std_logic;
        CS_N    : out std_logic;
        SCLK    : out std_logic;
        MISO    : in std_logic_vector(3 downto 0);
        Valid   : out std_logic;
        U       : out std_logic_vector(DataWidth_g-1 downto 0);
        V       : out std_logic_vector(DataWidth_g-1 downto 0);
        W       : out std_logic_vector(DataWidth_g-1 downto 0);
        VBus    : out std_logic_vector(DataWidth_g-1 downto 0)
    );
end SpiAdc;

---------------------------------------------------------------------------------------------------
-- Architecture Declaration
---------------------------------------------------------------------------------------------------
architecture rtl of SpiAdc is

    constant TConvNs_c : natural := 1200; -- MCP331X1-05 conversion time in ns
    
    type State_t is (IDLE_s, CONVERT_s, READ_s, PROCESS_s);

    type TwoProcess_r is record
        State       : State_t;
        CS_N        : std_logic;
        SCLK        : std_logic;
        Valid       : std_logic;
        Timer       : natural;
        BitCounter  : natural;
        Sum         : unsigned(DataWidth_g + 2 downto 0);
        RawU        : std_logic_vector(DataWidth_g-1 downto 0);
        RawV        : std_logic_vector(DataWidth_g-1 downto 0);
        RawW        : std_logic_vector(DataWidth_g-1 downto 0);
        RawVbus     : std_logic_vector(DataWidth_g-1 downto 0);
        U           : std_logic_vector(DataWidth_g+2+1-1 downto 0);
        V           : std_logic_vector(DataWidth_g+2+1-1 downto 0);
        W           : std_logic_vector(DataWidth_g+2+1-1 downto 0);
        VBus        : std_logic_vector(DataWidth_g-1 downto 0);
    end record;

    signal r, r_next : TwoProcess_r;

begin

    -----------------------------------------------------------------------------------------------
    -- Combinatorial Proccess
    -----------------------------------------------------------------------------------------------
    p_combinatorial: process(all) is
        variable v : TwoProcess_r;
    begin        
        -- *** hold variables stable ***
        v := r;

        -- *** Default Values ***
        v.CS_N := '0';
        v.SCLK := '0';
        v.Timer := 0;
        v.Valid := '0';

        -- Conversion start (Pulse >= 10 ns)
        if r.State = IDLE_s and Trigger = '1'then
            v.CS_N := '1';
            v.Timer := 0;
            v.State := CONVERT_s;
        end if;

        -- CS Low (1200 ns after CNVST RE for MCP331X1-05 or 580 ns after CNVST RE for MCP331X1-10)
        if r.State = CONVERT_s then
            if r.Timer = (ClockFrequenceyMhz_g * TConvNs_c / 1000)  then -- 1200 ns
                v.State := READ_s;
            else
                v.Timer := r.Timer + 1;
                v.CS_N := '1';
            end if;
        end if;

        -- Driving SCLK, reading data on MISO, MSB first
        if r.State = READ_s then
            if r.BitCounter < (DataWidth_g) then
                v.SCLK := not r.SCLK;
                if r.SCLK = '1' then -- Read data on rising edge
                    v.RawU := r.RawU(DataWidth_g-2 downto 0) & MISO(0);
                    v.RawV := r.RawV(DataWidth_g-2 downto 0) & MISO(1);
                    v.RawW := r.RawW(DataWidth_g-2 downto 0) & MISO(2);
                    v.RawVbus := r.RawVbus(DataWidth_g-2 downto 0) & MISO(3);
                    v.BitCounter := r.BitCounter + 1;
                end if;
            else
                v.BitCounter := 0;
                v.State := PROCESS_s;
            end if;
        end if;

        if r.State = PROCESS_s then
            v.Valid := '1';
            v.State := IDLE_s;
        end if;

        -- average current calc (pipeline stage 1)
        v.Sum := resize(unsigned(r.RawU), v.Sum'length)
            + resize(unsigned(r.RawV), v.Sum'length)
            + resize(unsigned(r.RawW), v.Sum'length);

        -- phase current calc (pipeline stage 2)
        -- round by adding 2**(2-1) = 2
        v.U := std_logic_vector(resize(unsigned(r.RawU) * 3 + 2 - r.Sum, v.U'length));
        v.V := std_logic_vector(resize(unsigned(r.RawV) * 3 + 2 - r.Sum, v.V'length));
        v.W := std_logic_vector(resize(unsigned(r.RawW) * 3 + 2 - r.Sum, v.W'length));

        -- DC bus voltage passthrough
        v.VBus := r.RawVbus;

        -- Generate Valid when all data is read
        r_next <= v;
    end process p_combinatorial;

    -----------------------------------------------------------------------------------------------
    -- Outputs
    -----------------------------------------------------------------------------------------------
    Valid <= r.Valid;
    CS_N <= r.CS_N;
    SCLK <= r.SCLK;
    U <= r.U(DataWidth_g+2-1 downto 2);
    V <= r.V(DataWidth_g+2-1 downto 2);
    W <= r.W(DataWidth_g+2-1 downto 2);
    VBus <= r.VBus;

    -----------------------------------------------------------------------------------------------
    -- Sequential Proccess
    -----------------------------------------------------------------------------------------------
    p_seq : process (Clk) is
    begin
        if rising_edge(Clk) then
            r <= r_next;
            if Rst = '1' then
                r.State <= IDLE_s;  
                r.Timer <= 0;
                r.RawU <= (others => '0');
                r.RawV <= (others => '0');
                r.RawW <= (others => '0');
                r.RawVbus <= (others => '0');
                r.U <= (others => '0');
                r.V <= (others => '0');
                r.W <= (others => '0');
                r.VBus <= (others => '0');
                r.CS_N <= '0';
                r.SCLK <= '0';
                r.Valid <= '0';
            end if;
        end if;
    end process;

end architecture;