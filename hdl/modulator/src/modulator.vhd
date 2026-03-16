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
    -- 
    constant TableWidth_c      : integer       := minimum(LutWidth_g, DataWidth_g-2);
    constant TableSize_c       : natural       := 2**(TableWidth_c);
    constant FixFormat_c       : FixFormat_t   := (1, 0, DataWidth_g-1);
    constant RemainderFormat_c : FixFormat_t   := (0, 0, DataWidth_g-2-TableWidth_c);
    constant A90Deg_c          : natural       := (2**(DataWidth_g)-1)/4;

    -- define discrete sSine values of one quarter period (= table size)
    constant Sin_c : natural := 0;
    constant Cos_c : natural := 1;
    
    type SinCos_t is array (Sin_c to Cos_c) of std_logic_vector(cl_fix_width(FixFormat_c)-1 downto 0);
    type SinCosRemainder_t is array (Sin_c to Cos_c) of std_logic_vector(cl_fix_width(RemainderFormat_c)-1 downto 0);
	type Lut_t is array (0 to TableSize_c-1) of SinCos_t;
    signal Lut_c : Lut_t;

    impure function LookupFromQuadrant(idx : std_logic_vector; quadrant : std_logic_vector)
    return SinCos_t is
        variable lut_index : integer;
        variable lut_value : SinCos_t := (others => (others => '0'));
    begin
        lut_index := to_integer(unsigned(idx));
        case quadrant is
            when "00" =>
                lut_value(Sin_c) := Lut_c(lut_index)(Sin_c);
                lut_value(Cos_c) := Lut_c(lut_index)(Cos_c);
            when "01" =>
                lut_value(Sin_c) := Lut_c(lut_index)(Cos_c);
                lut_value(Cos_c) := not Lut_c(lut_index)(Sin_c);
            when "10" =>
                lut_value(Sin_c) := not Lut_c(lut_index)(Sin_c);
                lut_value(Cos_c) := not Lut_c(lut_index)(Cos_c);
            when "11" =>
                lut_value(Sin_c) := not Lut_c(lut_index)(Cos_c);
                lut_value(Cos_c) := Lut_c(lut_index)(Sin_c);
            when others =>   
        end case;
        return lut_value;
    end function LookupFromQuadrant;

    procedure Lookup(
        variable angle         : in    std_logic_vector;
        variable lut_value     : out   SinCos_t;
        signal   lut_value_reg : in    SinCos_t;
        variable segment       : out   SinCos_t;
        signal   segment_reg   : in    SinCos_t;
        variable remainder     : out   std_logic_vector;
        signal   remainder_reg : in    std_logic_vector;
        variable result        : out   SinCos_t
    ) is
        
        alias quadrant : std_logic_vector(1 downto 0)
            is angle(DataWidth_g-1 downto DataWidth_g-2);
        alias idx : std_logic_vector(TableWidth_c-1 downto 0)
            is angle(DataWidth_g-3 downto DataWidth_g-2-TableWidth_c);
        alias remainder_slice : std_logic_vector(cl_fix_width(RemainderFormat_c)-1 downto 0)
            is angle(cl_fix_width(RemainderFormat_c)-1 downto 0);

        variable segment_angle : std_logic_vector(DataWidth_g-1 downto 0);
        alias segment_lut_angle : std_logic_vector(TableWidth_c-1+2 downto 0)
            is segment_angle(DataWidth_g-1 downto DataWidth_g-2-TableWidth_c);
        alias segment_quadrant : std_logic_vector(1 downto 0)
            is segment_angle(DataWidth_g-1 downto DataWidth_g-2);
        alias segment_idx : std_logic_vector(TableWidth_c-1 downto 0)
            is segment_angle(DataWidth_g-3 downto DataWidth_g-2-TableWidth_c);

    begin

        lut_value := LookupFromQuadrant(idx, quadrant);
        
        segment_angle := angle;
        segment_lut_angle := std_logic_vector(unsigned(segment_lut_angle) + 1);
        segment := LookupFromQuadrant(segment_idx, segment_quadrant);

        remainder := remainder_slice;

        for i in Sin_c to Cos_c loop
            result(i) := cl_fix_add(
                lut_value_reg(i), FixFormat_c,
                cl_fix_mult(
                    remainder_reg, RemainderFormat_c,
                    cl_fix_sub(segment_reg(i), FixFormat_c, lut_value_reg(i), FixFormat_c, FixFormat_c), FixFormat_c,
                    FixFormat_c), FixFormat_c,
                FixFormat_c);
        end loop;

    end procedure Lookup;
    
    type TwoProcess_r is record
        LutVal    : SinCos_t;
        LinearSeg : SinCos_t;
        Remainder : std_logic_vector(cl_fix_width(RemainderFormat_c)-1 downto 0);
        SinCos    : SinCos_t;
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
        Lut_c(i)(0) <= cl_fix_from_real(sin(2.0*MATH_PI*real(i+1)/real(4*TableSize_c)),FixFormat_c);
        Lut_c(i)(1) <= cl_fix_from_real(cos(2.0*MATH_PI*real(i+1)/real(4*TableSize_c)),FixFormat_c);
    end generate table;

    -----------------------------------------------------------------------------------------------
    -- Combinatorial Proccess
    -----------------------------------------------------------------------------------------------
    p_combinatorial: process(all) is
        variable v : TwoProcess_r;
        variable Angle_v : std_logic_vector(DataWidth_g-1 downto 0);
    begin
        -- *** hold variables stable ***
        v := r;

        -- Assign signal to variable, modelsim cant handle this otherwise
        Angle_v := Angle;
        Lookup(
            Angle_v,
            v.LutVal, r.LutVal,
            v.LinearSeg, r.LinearSeg,
            v.Remainder, r.Remainder,
            v.SinCos);

        r_next <= v;
    end process p_combinatorial;

    -----------------------------------------------------------------------------------------------
    -- Outputs
    -----------------------------------------------------------------------------------------------
    Sine   <= std_logic_vector(r.SinCos(Sin_c));
    Cosine <= std_logic_vector(r.SinCos(Cos_c));

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