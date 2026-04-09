---------------------------------------------------------------------------------------------------
-- Copyright (c) 2026 Stefan Stähhli
---------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------
-- Description
---------------------------------------------------------------------------------------------------
-- This entity implements a combined Sine and Cosine generator using a lookup table with optional
-- linear interpolation.

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
entity BitFilter is
    generic (
        FilterLengthSamples_g : natural;
        FilterThreshold_g : natural
    );
    port (
        Clk          : in    std_logic;
        Rst          : in    std_logic;
        BitIn        : in    std_logic;
        BitOut       : out   std_logic;
        Ready        : out   std_logic
    );
end BitFilter;

---------------------------------------------------------------------------------------------------
-- Architecture Declaration
---------------------------------------------------------------------------------------------------
architecture rtl of BitFilter is

    function CreateCorrelator return std_logic_vector is
        variable result : std_logic_vector(FilterLengthSamples_g-1 downto 0);
    begin
        -- Upper half: '0'
        for i in FilterLengthSamples_g-1 downto FilterLengthSamples_g/2 loop
            result(i) := '0';
        end loop;
        -- Lower half: '1'
        for i in FilterLengthSamples_g/2 - 1 downto 0 loop
            result(i) := '1';
        end loop;
        return result;
    end function;

    constant Correlator_c        : std_logic_vector(FilterLengthSamples_g-1 downto 0) := CreateCorrelator;
    constant RedTreeStages_c     : natural := log2ceil(FilterLengthSamples_g);
    constant ThresholdH_c        : natural := FilterLengthSamples_g - FilterThreshold_g;
    constant ThresholdL_c        : natural := 0 + FilterThreshold_g;
    
    
    function RedTreeElemets(branches : natural) return natural is
        variable branches_v : natural;
    begin
        branches_v := (branches+1)/2;
        if branches_v = 1 then
            return 1;
        else
            return branches_v + RedTreeElemets(branches_v);
        end if;
    end function;

    type PopCount_t is array (0 to RedTreeElemets(FilterLengthSamples_g)-1) of natural range 0 to FilterLengthSamples_g;

    type TwoProcess_r is record
        BitIn       : std_logic_vector(FilterLengthSamples_g-1+1 downto 0);
        XCor        : std_logic_vector(FilterLengthSamples_g-1 downto 0);
        EdgeCount   : PopCount_t;
        OneCount    : PopCount_t;
        BitOut      : std_logic;
        Ready       : std_logic_vector(FilterLengthSamples_g + RedTreeStages_c downto 0);
    end record;

    signal r, r_next : TwoProcess_r;

begin

    -- Assert that filter length can be efficiently implemented
    assert FilterLengthSamples_g >= 8
        report "FilterLengthSamples_g must be at least 8" severity failure;
    assert FilterThreshold_g < FilterLengthSamples_g/2
        report "FilterThreshold_g must be lower than half of the filter length" severity failure;
    assert isPower2(FilterLengthSamples_g)
        report "FilterLengthSamples_g must be a power of 2" severity failure;

    -----------------------------------------------------------------------------------------------
    -- Combinatorial Proccess
    -----------------------------------------------------------------------------------------------
    p_combinatorial: process(all) is
        variable v : TwoProcess_r;
        variable reductionTree_v : natural;
        variable stageIndex_v    : natural;
    begin
        -- *** hold variables stable ***
        v := r;
    
        -- Shift in new samples
        v.BitIn := r.BitIn(FilterLengthSamples_g-1 downto 0) & BitIn;

        -- Correlate with edge correlator
        v.XCor := r.BitIn(FilterLengthSamples_g-1 downto 0) xnor Correlator_c;

        -- Popcount in tree structure
        reductionTree_v := (FilterLengthSamples_g/2);
        stageIndex_v    := 0;
        for branch in 0 to reductionTree_v-1 loop
            with r.XCor(2*branch+1 downto 2*branch) select
                v.EdgeCount(branch) :=
                    2 when "11",
                    1 when "01",
                    1 when "10",
                    0 when others;
            with r.BitIn(2*branch+2 downto 2*branch+1) select
                v.OneCount(branch) :=
                    2 when "11",
                    1 when "01",
                    1 when "10",
                    0 when others;
        end loop;
        while reductionTree_v > 0 loop
            stageIndex_v := stageIndex_v + reductionTree_v;
            for branch in 0 to reductionTree_v/2 - 1 loop
                v.EdgeCount(stageIndex_v + branch) :=
                    r.EdgeCount(stageIndex_v + (2*branch) - reductionTree_v) +
                    r.EdgeCount(stageIndex_v + (2*branch) - reductionTree_v + 1);
                v.OneCount(stageIndex_v + branch) :=
                    r.OneCount(stageIndex_v + (2*branch) - reductionTree_v) +
                    r.OneCount(stageIndex_v + (2*branch) - reductionTree_v + 1);
            end loop;
            reductionTree_v := reductionTree_v/2;
        end loop;

        -- Update filtered signals based on popcount results
        if r.Ready(r.Ready'high-1) = '1' then
            if (r.EdgeCount(r.EdgeCount'right) >= ThresholdH_c) then
                v.BitOut := '1';
            elsif (r.EdgeCount(r.EdgeCount'right) <= ThresholdL_c) then
                v.BitOut := '0';
            end if;
            if r.OneCount(r.OneCount'right) >= ThresholdH_c then
                v.BitOut := '1';       
            elsif r.OneCount(r.OneCount'right) <= ThresholdL_c then
                v.BitOut := '0';
            end if;
        end if;

        -- Update ready signal
        v.Ready := r.Ready(r.Ready'high-1 downto 0) & '1';

        r_next <= v;

    end process p_combinatorial;

    -----------------------------------------------------------------------------------------------
    -- Outputs
    -----------------------------------------------------------------------------------------------
    BitOut <= r.BitOut;
    Ready <= r.Ready(r.Ready'high);

    -----------------------------------------------------------------------------------------------
    -- Sequential Proccess
    -----------------------------------------------------------------------------------------------
    p_seq : process (Clk) is
    begin
        if rising_edge(Clk) then
            r <= r_next;
            if Rst = '1' then          
                r.Ready <= (others => '0');
            end if;
        end if;
    end process;

end architecture;
