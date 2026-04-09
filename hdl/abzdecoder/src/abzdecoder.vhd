---------------------------------------------------------------------------------------------------
-- Copyright (c) 2025 Stefan Stähhli
---------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------
-- Description
---------------------------------------------------------------------------------------------------
-- This entity implements the Position Decoder for quadrature encoders with index pulse.
-- It decodes the A and B signals to determine position and uses the Z signal to reset the position
-- counter. A simple cross correlation filter is applied to the A and B signals to reduce noise.

---------------------------------------------------------------------------------------------------
-- Libraries
---------------------------------------------------------------------------------------------------
library IEEE;
    use IEEE.STD_LOGIC_1164.ALL;
    use IEEE.NUMERIC_STD.ALL;
    use IEEE.MATH_REAL.ALL;

library olo;
    use olo.olo_base_pkg_math.all;
    use olo.en_cl_fix_pkg.all;

---------------------------------------------------------------------------------------------------
-- Entity Declaration
---------------------------------------------------------------------------------------------------
entity ABZDecoder is
    generic (
        DataWidth_g : natural;
        IncrementsPerRevolution_g : natural
    );
    port (
        Clk         : in    std_logic;
        Rst         : in    std_logic;
        A           : in    std_logic;
        B           : in    std_logic;
        Z           : in    std_logic;
        Valid       : in    std_logic;
        Referenced  : out   std_logic;
        Position    : out   std_logic_vector(DataWidth_g-1 downto 0);
        Ready       : out   std_logic
    );
end ABZDecoder;

---------------------------------------------------------------------------------------------------
-- Architecture Declaration
---------------------------------------------------------------------------------------------------
architecture rtl of ABZDecoder is
    
    constant PosCountDataWith_c  : natural       := log2ceil(IncrementsPerRevolution_g*4);

    constant ScalarReal_c        : real          := 2.0**real(DataWidth_g)/real(IncrementsPerRevolution_g*4);
    constant ScalarIntBits_c     : natural       := natural(max(0, log2ceil(integer(ScalarReal_c))));
    
    constant FixFormatPosCount_c : FixFormat_t   := (0, PosCountDataWith_c, 0);
    constant FixFormatScalar_c   : FixFormat_t   := (0, ScalarIntBits_c, DataWidth_g - ScalarIntBits_c);
    constant FixFormatOut_c      : FixFormat_t   := (0, DataWidth_g, 0);

    constant Scalar_c            : std_logic_vector(cl_fix_width(FixFormatScalar_c)-1 downto 0) := cl_fix_from_real(ScalarReal_c, FixFormatScalar_c);

    constant PipelineStages_c    : natural       := 2;
    
    type TwoProcess_r is record
        PosCount    : unsigned(PosCountDataWith_c-1 downto 0);
        A           : std_logic_vector(1 downto 0);
        B           : std_logic_vector(1 downto 0);
        Z           : std_logic_vector(1 downto 0);
        Valid       : std_logic_vector(1 downto 0);
        UpDown      : std_logic; -- '1' for counting up, '0' for counting down
        Pulse       : std_logic;
        Referenced  : std_logic_vector(PipelineStages_c-1 downto 0);
        Position    : std_logic_vector(DataWidth_g-1 downto 0);
        Ready       : std_logic_vector(PipelineStages_c-1 downto 0);
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

        -- Decode position changes
        v.A := r.A(0) & A;
        v.B := r.B(0) & B;
        v.Z := r.Z(0) & Z;
        v.Valid := r.Valid(0) & Valid;
        if (r.Valid(r.Valid'high) = '1') then
            v.Pulse := '0';
            if (r.A(1) /= r.A(0)) then
                v.Pulse := '1';
                -- A edge detected
                if (r.A(0) /= r.B(0)) then
                    -- Counting up on edge of A
                    v.UpDown := '1';
                else
                    -- Counting down on edge of A
                    v.UpDown := '0';
                end if;
            end if;
            if (r.B(1) /= r.B(0)) then
                v.Pulse := '1';
                -- B edge detected
                if (r.B(0) = r.A(0)) then
                    -- Counting up on edge of B
                    v.UpDown := '1';
                else
                    -- Counting down on edge of B
                    v.UpDown := '0';
                end if;
            end if;

            -- Update position
            if r.Pulse = '1' then
                if r.UpDown = '1' then
                    v.PosCount := unsigned(signed(r.PosCount) + to_signed(1, r.PosCount'length));
                else
                    v.PosCount := unsigned(signed(r.PosCount) - to_signed(1, r.PosCount'length));
                end if;
            end if;

            -- Handle index pulse
            -- Rising Edge of Z when counting up
            -- Falling Edge of Z when counting down
            if ((r.UpDown = '1' and r.Z(1) = '0' and r.Z(0) = '1') or 
                (r.UpDown = '0' and r.Z(0) = '0' and r.Z(1) = '1')) then
                -- Rising edge of Z detected when counting up
                v.PosCount := (others => '0');
                v.Referenced(0) := '1';
            end if;
        end if;
        v.Referenced(1) := r.Referenced(0);
        
        -- Scale Position
        v.Position := cl_fix_mult(std_logic_vector(r.PosCount), FixFormatPosCount_c, Scalar_c, FixFormatScalar_c, FixFormatOut_c, saturate => Sat_s);

        -- Shift ready bits through pipeline
        v.Ready := r.Ready(r.Ready'high-1 downto 0) & r.Valid(r.Valid'high);

        r_next <= v;

    end process p_combinatorial;

    -----------------------------------------------------------------------------------------------
    -- Outputs
    -----------------------------------------------------------------------------------------------
    Referenced <= r.Referenced(r.Referenced'high);
    Position <= r.Position;
    Ready <= r.Ready(r.Ready'high);

    -----------------------------------------------------------------------------------------------
    -- Sequential Proccess
    -----------------------------------------------------------------------------------------------
    p_seq : process (Clk) is
    begin
        if rising_edge(Clk) then
            r <= r_next;
            if Rst = '1' then
                r.Referenced <= (others => '0');
                r.PosCount <= (others => '0');
                r.Ready <= (others => '0');
            end if;
        end if;
    end process;

end architecture;