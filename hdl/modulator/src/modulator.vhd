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
    -- we store only 1/4 of the values
    --   sin(a) = sin(a)        for a in [0,90)
    --   sin(a) = -sin(180 - a) for a in [90,180)
    --   sin(a) = -sin(a - 180) for a in [180,270)
    --   sin(a) = sin(360 - a)  for a in [270,360)
    -- same for cose, but shifted by 90 degrees
    constant TableWidth_c        : integer       := minimum(LutWidth_g, DataWidth_g-2);
    constant TableSize_c         : natural       := 2**(TableWidth_c);
    constant FixFormat_c         : FixFormat_t   := (1, 0, DataWidth_g-1);
    constant RemainderFormat_c   : FixFormat_t   := (0, 0, DataWidth_g-2-TableWidth_c);
    constant LutAngleIncrement_c : unsigned(DataWidth_g-1 downto 0) := to_unsigned(2**(DataWidth_g-2-TableWidth_c), DataWidth_g);
    
    -- define discrete sSine values of one quarter period (= table size)
    type LutEntry_t is record
        Sine : std_logic_vector(cl_fix_width(FixFormat_c)-1 downto 0);
        Cosine : std_logic_vector(cl_fix_width(FixFormat_c)-1 downto 0);
    end record;
    
	type Lut_t is array (0 to TableSize_c-1) of LutEntry_t;
    signal Lut_c : Lut_t;

    type Linear_t is record
        Sine : std_logic_vector(cl_fix_width(RemainderFormat_c)-1 downto 0);
        Cosine : std_logic_vector(cl_fix_width(RemainderFormat_c)-1 downto 0);
    end record;

    impure function Lookup(lut_angle : unsigned)
    return LutEntry_t is
        variable lut_index : integer;
        variable lut_value : LutEntry_t;
        
        alias quadrant : unsigned(1 downto 0)
            is lut_angle(DataWidth_g-1 downto DataWidth_g-2);
        alias idx : unsigned(TableWidth_c-1 downto 0)
            is lut_angle(DataWidth_g-3 downto DataWidth_g-2-TableWidth_c);
    begin
        lut_index := to_integer(idx);
        case quadrant is
            when "00" =>
                lut_value.Sine := Lut_c(lut_index).Sine;
                lut_value.Cosine := Lut_c(lut_index).Cosine;
            when "01" =>
                lut_value.Sine := Lut_c(lut_index).Cosine;
                lut_value.Cosine := not Lut_c(lut_index).Sine;
            when "10" =>
                lut_value.Sine := not Lut_c(lut_index).Sine;
                lut_value.Cosine := not Lut_c(lut_index).Cosine;
            when "11" =>
                lut_value.Sine := not Lut_c(lut_index).Cosine;
                lut_value.Cosine := Lut_c(lut_index).Sine;
            when others =>   
        end case;
        return lut_value;
    end function Lookup;
    
    type TwoProcess_r is record
        LutVal     : LutEntry_t;
        NextLutVal : LutEntry_t;
        Remainder  : std_logic_vector(cl_fix_width(RemainderFormat_c)-1 downto 0);
        Sum        : LutEntry_t;
    end record;

    signal r, r_next : TwoProcess_r;

begin
  	
    -----------------------------------------------------------------------------------------------
    -- LUT
    -----------------------------------------------------------------------------------------------
    -- create array with values for sin
    -- cos will be determined with sin(a) --> cos(a) = sin(90-a)
    assert TableWidth_c > 0
      report "LUT size must be greater than 0"
      severity error;

    assert TableWidth_c = LutWidth_g
      report "LUT width is truncated to " & integer'image(TableWidth_c) & " bits"
        & " instead of " & integer'image(LutWidth_g) & " bits"
        & " due to DataWidth_g of " & integer'image(DataWidth_g) & " bits"
      severity warning;

    table : for i in Lut_c'range generate
        Lut_c(i).Sine <= cl_fix_from_real(sin(2.0*MATH_PI*real(i+1)/real(4*TableSize_c)),FixFormat_c);
        Lut_c(i).Cosine <= cl_fix_from_real(cos(2.0*MATH_PI*real(i+1)/real(4*TableSize_c)),FixFormat_c);
    end generate table;

    -----------------------------------------------------------------------------------------------
    -- Combinatorial Proccess
    -----------------------------------------------------------------------------------------------
    p_combinatorial: process(all) is
        variable v : TwoProcess_r;
        variable current_angle : unsigned(DataWidth_g-1 downto 0);
        variable next_angle : unsigned(DataWidth_g-1 downto 0);
        alias remainder_slice : unsigned(cl_fix_width(RemainderFormat_c)-1 downto 0)
            is current_angle(cl_fix_width(RemainderFormat_c)-1 downto 0);
    begin
        -- *** hold variables stable ***
        v := r;

        current_angle := unsigned(Angle);
        v.LutVal := Lookup(current_angle);
        
        next_angle := unsigned(Angle) + LutAngleIncrement_c;
        v.NextLutVal := Lookup(next_angle);

        v.Remainder := std_logic_vector(remainder_slice);

        v.Sum.Sine := cl_fix_add(
            r.LutVal.Sine, FixFormat_c,
            cl_fix_mult(
                r.Remainder, RemainderFormat_c,
                cl_fix_sub(r.NextLutVal.Sine, FixFormat_c, r.LutVal.Sine, FixFormat_c, FixFormat_c), FixFormat_c,
                FixFormat_c), FixFormat_c,
            FixFormat_c);

        v.Sum.Cosine := cl_fix_add(
            r.LutVal.Cosine, FixFormat_c,
            cl_fix_mult(
                r.Remainder, RemainderFormat_c,
                cl_fix_sub(r.NextLutVal.Cosine, FixFormat_c, r.LutVal.Cosine, FixFormat_c, FixFormat_c), FixFormat_c,
                FixFormat_c), FixFormat_c,
            FixFormat_c);

        r_next <= v;
    end process p_combinatorial;

    -----------------------------------------------------------------------------------------------
    -- Outputs
    -----------------------------------------------------------------------------------------------
    Sine   <= std_logic_vector(r.Sum.Sine);
    Cosine <= std_logic_vector(r.Sum.Cosine);

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