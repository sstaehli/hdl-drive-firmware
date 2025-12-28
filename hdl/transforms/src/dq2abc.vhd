---------------------------------------------------------------------------------------------------
-- Copyright (c) 2025 Stefan Stähli
---------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------
-- Description
---------------------------------------------------------------------------------------------------
-- This entity implements the Clark-PArke and D/Q transformed rquired for
-- field-oriented control (FOC).

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
entity dq2abc is
    generic ( 
        DataWidth_g : natural
    );    
    port (
        -- Control Signals
        Clk         : in    std_logic;
        Rst         : in    std_logic;

        -- Modulator Inputs
        Sine        : in    std_logic_vector(DataWidth_g-1 downto 0);
        Cosine      : in    std_logic_vector(DataWidth_g-1 downto 0);
        -- DQ Inputs
        Strobe      : in    std_logic; -- new sample available
        D           : in    std_logic_vector(DataWidth_g-1 downto 0);
        Q           : in    std_logic_vector(DataWidth_g-1 downto 0);
        -- DQ Outputs
        Valid       : out   std_logic; -- output data valid
        A           : out   std_logic_vector(DataWidth_g-1 downto 0);
        B           : out   std_logic_vector(DataWidth_g-1 downto 0);
        C           : out   std_logic_vector(DataWidth_g-1 downto 0)
    );
end dq2abc;

---------------------------------------------------------------------------------------------------
-- Architecture Declaration
---------------------------------------------------------------------------------------------------
architecture rtl of dq2abc is

    -- *** Constants ***
    constant FixFormat_c : FixFormat_t := (1, 0, DataWidth_g-1);
    constant FixFormatInt_c : FixFormat_t := cl_fix_add_fmt(FixFormat_c, FixFormat_c);

    constant Mtx11_c : std_logic_vector(cl_fix_width(FixFormat_c)-1 downto 0) := cl_fix_from_real(1.0           , FixFormat_c); -- = 1
    constant Mtx12_c : std_logic_vector(cl_fix_width(FixFormat_c)-1 downto 0) := cl_fix_from_real(0.0           , FixFormat_c); -- = 0
    constant Mtx21_c : std_logic_vector(cl_fix_width(FixFormat_c)-1 downto 0) := cl_fix_from_real(-0.5          , FixFormat_c); -- = 1/2
    constant Mtx22_c : std_logic_vector(cl_fix_width(FixFormat_c)-1 downto 0) := cl_fix_from_real(sqrt(3.0)/2.0 , FixFormat_c); -- = sqrt(3)/2
    constant Mtx31_c : std_logic_vector(cl_fix_width(FixFormat_c)-1 downto 0) := cl_fix_from_real(-0.5          , FixFormat_c); -- = 1/2
    constant Mtx32_c : std_logic_vector(cl_fix_width(FixFormat_c)-1 downto 0) := cl_fix_from_real(-sqrt(3.0)/2.0, FixFormat_c); -- = -sqrt(3)/2
    
    constant NumStages_c : integer := 2; -- processing takes 2 pipeline stages

    type TwoProcess_r is record
        Alpha : std_logic_vector(cl_fix_width(FixFormatInt_c)-1 downto 0);
        Beta : std_logic_vector(cl_fix_width(FixFormatInt_c)-1 downto 0);
        Valid : std_logic_vector(NumStages_c-1 downto 0);
        A : std_logic_vector(cl_fix_width(FixFormat_c)-1 downto 0);
        B : std_logic_vector(cl_fix_width(FixFormat_c)-1 downto 0);
        C : std_logic_vector(cl_fix_width(FixFormat_c)-1 downto 0);
    end record;

    signal r, r_next : TwoProcess_r;

begin

    -----------------------------------------------------------------------------------------------
    -- Combinatorial Proccess
    -----------------------------------------------------------------------------------------------
    p_combinatorial: process(all) is
        variable v : TwoProcess_r;
        variable Sine_v      : std_logic_vector(cl_fix_width(FixFormat_c)-1 downto 0);
        variable Cosine_v    : std_logic_vector(cl_fix_width(FixFormat_c)-1 downto 0);
        variable MinusSine_v : std_logic_vector(cl_fix_width(FixFormat_c)-1 downto 0);
    begin
        -- *** hold variables stable ***
        v := r;

        -- *** Default Values ***

        -- inverse parke transform (pipeline stage 1)
        Sine_v := cl_fix_resize(Sine, FixFormat_c, FixFormat_c);
        Cosine_v := cl_fix_resize(Cosine, FixFormat_c, FixFormat_c);
        MinusSine_v := cl_fix_neg(Sine, FixFormat_c, FixFormat_c, saturate => Sat_s); 

        v.Alpha := cl_fix_add(
            cl_fix_mult(
                Cosine_v, FixFormat_c,
                D, FixFormat_c,
                FixFormatInt_c
            ), FixFormatInt_c,
            cl_fix_mult(
                MinusSine_v, FixFormat_c,
                Q, FixFormat_c,
                FixFormatInt_c
            ), FixFormatInt_c,
            FixFormatInt_c
        );

        v.Beta := cl_fix_add(
            cl_fix_mult(
                Sine_v, FixFormat_c,
                D, FixFormat_c,
                FixFormatInt_c
            ), FixFormatInt_c,
            cl_fix_mult(
                Cosine_v, FixFormat_c,
                Q, FixFormat_c,
                FixFormatInt_c
            ), FixFormatInt_c,
            FixFormatInt_c
        );

        -- inv Clarke Transformation (pipeline stage 2)
        v.A := cl_fix_add(
            cl_fix_mult(
                Mtx11_c, FixFormat_c,
                r.Alpha, FixFormatInt_c,
                FixFormatInt_c
            ), FixFormatInt_c,
            cl_fix_mult(
                Mtx12_c, FixFormat_c,
                r.Beta, FixFormatInt_c,
                FixFormatInt_c
            ), FixFormatInt_c,
            FixFormat_c,
            saturate => Sat_s
        );
  
        v.B := cl_fix_add(
            cl_fix_mult(
                Mtx21_c, FixFormat_c,
                r.Alpha, FixFormatInt_c,
                FixFormatInt_c
            ), FixFormatInt_c,
            cl_fix_mult(
                Mtx22_c, FixFormat_c,
                r.Beta, FixFormat_c,
                FixFormatInt_c
            ), FixFormatInt_c,
            FixFormat_c,
            saturate => Sat_s
        );

        v.C := cl_fix_add(
            cl_fix_mult(
                Mtx31_c, FixFormat_c,
                r.Alpha, FixFormatInt_c,
                FixFormatInt_c
            ), FixFormat_c,
            cl_fix_mult(
                Mtx32_c, FixFormat_c,
                r.Beta, FixFormatInt_c,
                FixFormatInt_c
            ), FixFormatInt_c,
            FixFormat_c,
            saturate => Sat_s
        );

        v.Valid := r.Valid(r.Valid'left-1 downto 0) & Strobe;

        r_next <= v;
    end process p_combinatorial;

    -----------------------------------------------------------------------------------------------
    -- Outputs
    -----------------------------------------------------------------------------------------------
    Valid <= r.Valid(r.Valid'left);
    A <= r.A;
    B <= r.B;
    C <= r.C;

    -----------------------------------------------------------------------------------------------
    -- Sequential Proccess
    -----------------------------------------------------------------------------------------------
    p_seq : process (Clk) is
    begin
        if rising_edge(Clk) then
            r <= r_next;
            if Rst = '1' then
                r.Valid <= (others => '0');
                r.A <= (others => '0');
                r.B <= (others => '0');
                r.C <= (others => '0');
            end if;
        end if;
    end process;

end architecture;