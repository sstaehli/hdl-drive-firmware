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
entity ABZDecoder is
    generic (
        DataWidth_g : natural;
        IncrementsPerRevolution_g : natural;
        FilterLengthClkCycles_g : natural
    );
    port (
        Clk         : in    std_logic;
        Rst         : in    std_logic;
        A           : in    std_logic;
        B           : in    std_logic;
        Z           : in    std_logic;
        Referenced  : out   std_logic;
        Position    : out   std_logic_vector(DataWidth_g-1 downto 0)
    );
end ABZDecoder;

---------------------------------------------------------------------------------------------------
-- Architecture Declaration
---------------------------------------------------------------------------------------------------
architecture rtl of ABZDecoder is

    function CreateCorrelator return std_logic_vector is
        variable result : std_logic_vector(FilterLengthClkCycles_g-1 downto 0);
    begin
        -- Upper half: '1'
        for i in FilterLengthClkCycles_g-1 downto FilterLengthClkCycles_g/2 loop
            result(i) := '1';
        end loop;
        -- Lower half: '0'
        for i in FilterLengthClkCycles_g/2 - 1 downto 0 loop
            result(i) := '0';
        end loop;
        return result;
    end function;

    constant Correlator_c        : std_logic_vector(FilterLengthClkCycles_g-1 downto 0) := CreateCorrelator;
    constant FilterCountWidth_c  : natural       := natural(log2ceil(FilterLengthClkCycles_g));
    constant ThresholdRE_c       : unsigned(FilterCountWidth_c-1 downto 0) := to_unsigned(7*FilterLengthClkCycles_g/8, FilterCountWidth_c);
    constant ThresholdFE_c       : unsigned(FilterCountWidth_c-1 downto 0) := to_unsigned(1*FilterLengthClkCycles_g/8, FilterCountWidth_c);

    constant PosCountDataWith_c  : natural       := log2ceil(IncrementsPerRevolution_g*4);

    constant ScalarReal_c        : real          := (2.0**real(DataWidth_g)-1.0)/real(IncrementsPerRevolution_g*4);
    constant ScalarIntBits_c     : natural       := natural(max(0, log2ceil(integer(ScalarReal_c))));
    
    constant FixFormatPosCount_c : FixFormat_t   := (0, PosCountDataWith_c, 0);
    constant FixFormatScalar_c   : FixFormat_t   := (0, ScalarIntBits_c, DataWidth_g - ScalarIntBits_c);
    constant FixFormatOut_c      : FixFormat_t   := (0, DataWidth_g, 0);

    constant Scalar_c          : std_logic_vector(cl_fix_width(FixFormatScalar_c)-1 downto 0) := cl_fix_from_real(ScalarReal_c, FixFormatScalar_c);

    constant PopCountStages_c    : natural       := natural(log2(real(FilterLengthClkCycles_g)));

    function ReductionTreeElementCount(branches : natural) return natural is
    begin
        if branches = 1 then
            return 1;
        else
            return branches + ReductionTreeElementCount((branches+1)/2);
        end if;
    end function;

    type PopCount_t is array (0 to ReductionTreeElementCount(FilterLengthClkCycles_g)-1) of unsigned(FilterLengthClkCycles_g-1 downto 0);
    
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
        Referenced  : std_logic;
        Position    : std_logic_vector(DataWidth_g-1 downto 0);
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
            with matchIn_v(2*branch+1 downto 2*branch) select
                matchCount_v(branch) := to_unsigned(2, 16) when "11",
                                        to_unsigned(1, 16) when "01",
                                        to_unsigned(1, 16) when "10",
                                        to_unsigned(0, 16) when others;
        end loop;
        for stage in 1 to PopCountStages_c-1 loop
            for branch in 0 to reductionTree_v/2-1 loop
                matchCount_v(stage*reductionTree_v + branch) :=
                    matchCount((stage-1)*reductionTree_v + 2*branch)
                    + matchCount((stage-1)*reductionTree_v + 2*branch+1);
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
        variable increment_v : signed(DataWidth_g-1 downto 0);
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
        if (r.MatchCountA(r.MatchCountA'right) >= ThresholdRE_c) then
            v.AFiltered(0) := '1';
        elsif (r.MatchCountA(r.MatchCountA'right) <= ThresholdFE_c) then
            v.AFiltered(0) := '0';
        end if;
        v.AFiltered(1) := r.AFiltered(0);
        if (r.MatchCountB(r.MatchCountB'right) >= ThresholdRE_c) then
            v.BFiltered(0) := '1';
        elsif (r.MatchCountB(r.MatchCountB'right) <= ThresholdFE_c) then
            v.BFiltered(0) := '0';
        end if;
        v.BFiltered(1) := r.BFiltered(0);
        if (r.MatchCountZ(r.MatchCountZ'right) >= ThresholdRE_c) then
            v.ZFiltered(0) := '1';
        elsif (r.MatchCountZ(r.MatchCountZ'right) <= ThresholdFE_c) then
            v.ZFiltered(0) := '0';
        end if;
        v.ZFiltered(1) := r.ZFiltered(0);

        -- Decode position changes
        increment_v := (others => '0');
        if (r.AFiltered(1) /= r.AFiltered(0)) then
            -- A edge detected
            if (r.AFiltered(0) = r.BFiltered(0)) then
                increment_v := "1";
            else
                -- Counting down on edge of A
                increment_v := "-1";
            end if;
        end if;
        if (r.BFiltered(1) /= r.BFiltered(0)) then
            -- B edge detected
            if (r.BFiltered(0) /= r.AFiltered(0)) then
                -- Counting up on edge of B
                increment_v := "1";
            else
                -- Counting down on edge of B
                increment_v := "-1";
            end if;
        end if;

        -- Update position
        v.PosCount := unsigned(signed(r.PosCount) + increment_v);

        -- Handle index pulse
        -- Rising Edge of Z when counting up
        -- Falling Edge of Z when counting down
        if ((increment_v > 0 and r.ZFiltered(1) = '0' and r.ZFiltered(0) = '1') or 
            (increment_v < 0 and r.ZFiltered(0) = '0' and r.ZFiltered(1) = '1')) then
            -- Rising edge of Z detected when counting up
            v.PosCount := (others => '0') ;
            v.Referenced := '1';
        end if;
        
        -- Scale Position
        v.Position := cl_fix_mult(std_logic_vector(r.PosCount), FixFormatPosCount_c, Scalar_c, FixFormatScalar_c, FixFormatOut_c, saturate => Sat_s);

        r_next <= v;

    end process p_combinatorial;

    -----------------------------------------------------------------------------------------------
    -- Outputs
    -----------------------------------------------------------------------------------------------
    Referenced <= r.Referenced;
    Position <= r.Position;

    -----------------------------------------------------------------------------------------------
    -- Sequential Proccess
    -----------------------------------------------------------------------------------------------
    p_seq : process (Clk) is
        variable resetBit_v : std_logic := '0';
        variable reductionTree_v : natural  := (FilterLengthClkCycles_g/2);
    begin
        if rising_edge(Clk) then
            r <= r_next;
            if Rst = '1' then
                -- Reset inputs with alternating bits to bias the correlator
                for bits in r.A'range loop
                    r.A(bits) <= resetBit_v;
                    r.B(bits) <= resetBit_v;
                    r.Z(bits) <= resetBit_v;
                    resetBit_v := not resetBit_v;
                end loop;
                r.MatchA <= (others => '0');
                r.MatchB <= (others => '0');
                r.MatchZ <= (others => '0');
                for i in r.MatchCountA'range loop
                    r.MatchCountA(i) <= (others => '0');
                    r.MatchCountB(i) <= (others => '0');
                    r.MatchCountZ(i) <= (others => '0');
                end loop;
                r.PosCount <= (others => '0');
                r.Position <= (others => '0');
                r.Referenced <= '0';
            else
            end if;
        end if;
    end process;

end architecture;