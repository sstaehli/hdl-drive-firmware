---------------------------------------------------------------------------------------------------
-- Copyright (c) 2025 Stefan StÃ¤hli
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
    use olo.olo_fix_pkg.all;

---------------------------------------------------------------------------------------------------
-- Entity Declaration
---------------------------------------------------------------------------------------------------
entity PositionDecoder is
    generic (
        DataWidth_g : natural;
        Resolution_g : natural;
        RefPulseWidthIncrements_g : natural;
        FilterLengthClkCycles_g : natural
    );
    port (
        Clk         : in    std_logic;
        Rst         : in    std_logic;
        A           : in    std_logic;
        B           : in    std_logic;
        Z           : in    std_logic;
        Position    : out   std_logic_vector(DataWidth_g-1 downto 0)
    );
end PositionDecoder;

---------------------------------------------------------------------------------------------------
-- Architecture Declaration
---------------------------------------------------------------------------------------------------
architecture rtl of PositionDecoder is

    constant FixFormat_c        : FixFormat_t   := (1, 0, DataWidth_g-1);
    constant PopCountStages_c   : natural       := log2(real(FilterLengthClkCycles_g));
    constant Correlator_c       : std_logic_vector(FilterLengthClkCycles_g-1 downto 0) :=
        (FilterLengthClkCycles_g-1 downto (FilterLengthClkCycles_g/2) => '1', (FilterLengthClkCycles_g/2)-1 downto 0 => '0');
    constant ThresholdRE_c      : unsigned      := to_unsigned(7*FilterLengthClkCycles_g/8);
    constant ThresholdFE_c      : unsigned      := to_unsigned(1*FilterLengthClkCycles_g/8);
    

    type PopCount_t is array (0 to PopCountStages_c, 0 to FilterLengthClkCycles_g/2) of unsigned(FilterLengthClkCycles_g-1 downto 0);
    
    type TwoProcess_r is record
        A           : std_logic_vector(FilterLengthClkCycles_g-1 downto 0);
        B           : std_logic_vector(FilterLengthClkCycles_g-1 downto 0);
        Z           : std_logic_vector(FilterLengthClkCycles_g-1 downto 0);
        PosCount    : unsigned(DataWidth_g-1 downto 0);
        MatchA      : unsigned(FilterLengthClkCycles_g-1 downto 0);
        MatchB      : unsigned(FilterLengthClkCycles_g-1 downto 0);
        MatchZ      : unsigned(FilterLengthClkCycles_g-1 downto 0);
        MatchCountA : PopCount_t;
        MatchCountB : PopCount_t;
        MatchCountZ : PopCount_t;
        AFiltered   : std_logic_vector(1 downto 0);
        BFiltered   : std_logic_vector(1 downto 0);
        ZFiltered   : std_logic_vector(1 downto 0);
    end record;

    signal r, r_next : TwoProcess_r;

    procedure popCountTree(
        variable matchIn_v : in unsigned;
        signal matchCount : in PopCount_t;
        variable matchCount_v : inout PopCount_t 
    ) is
        variable reductionTree_v : natural  := (FilterLengthClkCycles_g/2);
    begin
        for branch in 0 to reductionTree_v-1 loop
            matchCount_v(0, branch) := unsigned'(0 => matchIn_v(2*branch)) + unsigned'(0 => matchIn_v(2*branch+1));
            reductionTree_v := reductionTree_v / 2;
        end loop;
        for stage in 1 to PopCountStages_c-1 loop
            for branch in 0 to reductionTree_v-2 loop
                matchCount_v(stage, branch) := matchCount(stage-1, 2*branch) + matchCount(stage-1, 2*branch+1);
            end loop;
            reductionTree_v := reductionTree_v / 2;
        end loop;
    end procedure popCountTree;

begin

    -- Assert that filter length can be efficiently implemented 
    assert FilterLengthClkCycles_g >= 2
        report "FilterLengthClkCycles_g must be at least 2" severity failure;
    assert isPower2(FilterLengthClkCycles_g)
        report "FilterLengthClkCycles_g must be a power of 2" severity failure;

    -----------------------------------------------------------------------------------------------
    -- Combinatorial Proccess
    -----------------------------------------------------------------------------------------------
    p_combinatorial: process(all) is
        variable v : TwoProcess_r;
        variable reductionTree_v : natural;
        variable Increment_v : signed(DataWidth_g-1 downto 0);
    begin        
        -- *** hold variables stable ***
        v := r;
    
        -- Shift in new samples
        v.A := v.A(FilterLengthClkCycles_g-2 downto 0) & A;
        v.B := v.B(FilterLengthClkCycles_g-2 downto 0) & B;
        v.Z := v.Z(FilterLengthClkCycles_g-2 downto 0) & Z;

        -- Correlate A, B, Z with edge correlator
        v.MatchA := unsigned(r.A xnor Correlator_c);
        v.MatchB := unsigned(r.B xnor Correlator_c);
        v.MatchZ := unsigned(r.Z xnor Correlator_c);

        -- Popcount A, B, Z in tree structure
        popCountTree(v.MatchA, r.MatchCountA, v.MatchCountA);
        popCountTree(v.MatchB, r.MatchCountB, v.MatchCountB);
        popCountTree(v.MatchZ, r.MatchCountZ, v.MatchCountZ);

        -- Update filtered signals based on popcount results
        if (r.MatchCountA(PopCountStages_c-1, 0) >= ThresholdRE_c) then
            v.AFiltered(0) := '1';
        elsif (r.MatchCountA(PopCountStages_c-1, 0) <= ThresholdFE_c) then
            v.AFiltered(0) := '0';
        end if;
        v.AFiltered(1) := r.AFiltered(0);
        if (r.MatchCountB(PopCountStages_c-1, 0) >= ThresholdRE_c) then
            v.BFiltered(0) := '1';
        elsif (r.MatchCountB(PopCountStages_c-1, 0) <= ThresholdFE_c) then
            v.BFiltered(0) := '0';
        end if;
        v.BFiltered(1) := r.BFiltered(0);
        if (r.MatchCountZ(PopCountStages_c-1, 0) >= ThresholdRE_c) then
            v.ZFiltered(0) := '1';
        elsif (r.MatchCountZ(PopCountStages_c-1, 0) <= ThresholdFE_c) then
            v.ZFiltered(0) := '0';
        end if;
        v.ZFiltered(1) := r.ZFiltered(0);

        -- Decode position changes
        Increment_v := (others => '0');
        if (r.AFiltered(1) /= r.AFiltered(0)) then
            -- A edge detected
            if (r.AFiltered(0) = r.BFiltered(0)) then
                Increment_v := "1";
            else
                -- Counting down on edge of A
                Increment_v := "-1";
            end if;
        end if;
        if (r.BFiltered(1) /= r.BFiltered(0)) then
            -- B edge detected
            if (r.BFiltered(0) /= r.AFiltered(0)) then
                -- Counting up on edge of B
                Increment_v := "1";
            else
                -- Counting down on edge of B
                Increment_v := "-1";
            end if;
        end if;

        -- Update position
        v.PosCount := unsigned(signed(r.PosCount) + Increment_v);

        -- Handle index pulse
        if (r.ZFiltered(1) = '0' and r.ZFiltered(0) = '1') then
            -- Rising edge of Z detected when counting up
            if Increment_v > 0 then
                v.PosCount := not(to_unsigned(RefPulseWidthIncrements_g/2-1, DataWidth_g));
            end if;
            -- Rising edge of Z detected when counting down
            if (Increment_v < 0) then
                v.PosCount := to_unsigned(RefPulseWidthIncrements_g/2, DataWidth_g);
            end if;
        end if;

            -- Rising edge of Z detected, reset positi
        r_next <= v;

    end process p_combinatorial;

    -----------------------------------------------------------------------------------------------
    -- Outputs
    -----------------------------------------------------------------------------------------------

    -----------------------------------------------------------------------------------------------
    -- Sequential Proccess
    -----------------------------------------------------------------------------------------------
    p_seq : process (Clk) is
    begin
        if rising_edge(Clk) then
            r <= r_next;
            if Rst = '1' then
                r.Position <= (others => '0');
                r
            else
            end if;
        end if;
    end process;

end architecture;