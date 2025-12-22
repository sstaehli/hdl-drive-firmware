---------------------------------------------------------------------------------------------------
-- Copyright (c) 2025 Stefan Stähli
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
  use olo.en_cl_fix_pkg.all;
  use olo.olo_fix_pkg.all;

---------------------------------------------------------------------------------------------------
-- Entity Declaration
---------------------------------------------------------------------------------------------------
entity Modulator is
    generic (
        DataWidth_g  : natural;
        LutWidth_g   : natural
    );
    port (
        Clk          : in    std_logic;
        Angle        : in    std_logic_vector(DataWidth_g-1 downto 0); -- fix_fmt(1,0,datawidth-1) / signed
        Sine         : out   std_logic_vector(DataWidth_g-1 downto 0); -- fix_fmt(1,0,datawidth-1) / signed
        Cosine       : out   std_logic_vector(DataWidth_g-1 downto 0) -- fix_fmt(1,0,datawidth-1) / signed
    );
end Modulator;

---------------------------------------------------------------------------------------------------
-- Architecture Declaration
---------------------------------------------------------------------------------------------------
architecture rtl of Modulator is
    
    -- since the fix format we use is signed, the table is half the size of the value range
    -- sin(-a) = sin(360-a)
    constant SinTableWidth_c    : integer       := minimum(LutWidth_g, DataWidth_g-1);
    constant SinTableSize_c     : natural       := 2**(SinTableWidth_c);
    constant FixFormat_c        : FixFormat_t   := (1, 0, DataWidth_g-1);
    constant RemainderFormat_c  : FixFormat_t   := (0, 0, DataWidth_g-1-SinTableWidth_c);
    constant A90Deg_c           : natural       := (2**(DataWidth_g-1)-1)/4;

    -- define discrete sSine values of one whole period (= table size)
	type SinLut_t is array (0 to SinTableSize_c-1) of std_logic_vector(cl_fix_width(FixFormat_c)-1 downto 0);
	signal SinTable : SinLut_t;
    
    type TwoProcess_r is record
        Angle           : std_logic_vector(DataWidth_g-1 downto 0);
        SineLutVal      : unsigned(cl_fix_width(FixFormat_c)-1 downto 0);
        SineLinearSeg   : unsigned(cl_fix_width(FixFormat_c)-1 downto 0);
        CosineLutVal    : unsigned(cl_fix_width(FixFormat_c)-1 downto 0);
        CosineLinearSeg : unsigned(cl_fix_width(FixFormat_c)-1 downto 0);
        Sine            : unsigned(cl_fix_width(FixFormat_c)-1 downto 0);
        Cosine          : unsigned(cl_fix_width(FixFormat_c)-1 downto 0);
    end record;

    signal r, r_next : TwoProcess_r;

begin
  	
    -----------------------------------------------------------------------------------------------
    -- LUT
    -----------------------------------------------------------------------------------------------
    -- create array with sSine values for sin
    -- cos will be determined with sin(a) --> cos(a) = sin(90-a)
    assert SinTableWidth_c > 2
      report "LUT size must be greater or equal to 3"
      severity error;

    table : for i in 0 to SinTableSize_c-1 generate
        SinTable(i) <= cl_fix_from_real(sin(2.0*MATH_PI*real(i)/real(SinTableSize_c)),FixFormat_c);
    end generate table;

    -----------------------------------------------------------------------------------------------
    -- Combinatorial Proccess
    -----------------------------------------------------------------------------------------------
    p_combinatorial: process(all) is
        variable v : TwoProcess_r;
        
        -- lut table indizes, make use of the wrapping with vector size
        variable vSinFullIndex, vCosFullIndex : unsigned(DataWidth_g-2 downto 0);
        alias aSinTableIndex : unsigned(SinTableWidth_c-1 downto 0)
            is vSinFullIndex(DataWidth_g-2 downto DataWidth_g-1-SinTableWidth_c);
        alias aCosTableIndex : unsigned(SinTableWidth_c-1 downto 0)
            is vCosFullIndex(DataWidth_g-2 downto DataWidth_g-1-SinTableWidth_c);
        
        -- interpolation
        alias aRemainder : std_logic_vector(DataWidth_g-2-SinTableWidth_c downto 0)
            is Angle(DataWidth_g-2-SinTableWidth_c downto 0);

    begin
        -- *** hold variables stable ***
        v := r;

        -- *** Default Values ***
        -- sin index is directly coupled to the angle
        vSinFullIndex := unsigned(Angle(vSinFullIndex'range));
        
        -- cos index is 90-angle
        vCosFullIndex := to_unsigned(A90Deg_c,vCosFullIndex'length) - unsigned(Angle(vCosFullIndex'range));

        -- lookup sin/cos in table
        v.SineLutVal := unsigned(SinTable(to_integer(aSinTableIndex)));
        v.CosineLutVal := unsigned(SinTable(to_integer(aCosTableIndex+1)));

        -- delta is always 0 if table is same width as angle input
        v.SineLinearSeg := (others => '0');
        v.CosineLinearSeg := (others => '0');

        -- otherwise calc remainder for sin/cos interpolation        
        if ((DataWidth_g-1) > SinTableWidth_c) then
            -- pipeline stage 1: calculate delta
            -- take next index, subract current index and interpolate
            v.SineLinearSeg := unsigned(SinTable(to_integer(aSinTableIndex+1))) - unsigned(SinTable(to_integer(aSinTableIndex)));
            -- cos table pointer rotataes opposite to sSine (90° -> - <- alpha)
            v.CosineLinearSeg := unsigned(SinTable(to_integer(aCosTableIndex))) - unsigned(SinTable(to_integer(aCosTableIndex+1)));    
        end if;
            
        v.Sine := r.SineLutVal + unsigned(cl_fix_mult(
                std_logic_vector(r.SineLinearSeg), FixFormat_c,
                aRemainder, RemainderFormat_c,
                FixFormat_c));
        v.Cosine := r.CosineLutVal + unsigned(cl_fix_mult(
                std_logic_vector(r.CosineLinearSeg), FixFormat_c,
                aRemainder, RemainderFormat_c,
                FixFormat_c));

        r_next <= v;
    end process p_combinatorial;

    -----------------------------------------------------------------------------------------------
    -- Outputs
    -----------------------------------------------------------------------------------------------
    Sine   <= std_logic_vector(r.Sine);
    Cosine <= std_logic_vector(r.Cosine);

    -----------------------------------------------------------------------------------------------
    -- Sequential Proccess
    -----------------------------------------------------------------------------------------------
    p_seq : process (Clk) is
    begin
        if rising_edge(Clk) then
            r <= r_next;
        end if;
    end process;

end architecture;