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
entity dqTransform is
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
        -- ABC Inputs
        Strobe      : in    std_logic; -- new sample available
        A           : in    std_logic_vector(DataWidth_g-1 downto 0);
        B           : in    std_logic_vector(DataWidth_g-1 downto 0);
        C           : in    std_logic_vector(DataWidth_g-1 downto 0);
        -- DQ Outputs
        Valid       : out   std_logic; -- output data valid
        D           : out   std_logic_vector(DataWidth_g-1 downto 0);
        Q           : out   std_logic_vector(DataWidth_g-1 downto 0);
        DC          : out   std_logic_vector(DataWidth_g-1 downto 0)
    );
end dqTransform;

---------------------------------------------------------------------------------------------------
-- Architecture Declaration
---------------------------------------------------------------------------------------------------
architecture rtl of dqTransform is

    -- *** Constants ***
    constant FixFormat_c : FixFormat_t := (1, 0, DataWidth_g-1);
    constant IntFixFormat_c : FixFormat_t := (1, 1, DataWidth_g);
    
    constant cMtxPrescaler : real := 2.0/3.0; -- 2/3

    constant MtxCPA1_c : std_logic_vector(cl_fix_width(FixFormat_c)-1 downto 0) := cl_fix_from_real(cMtxPrescaler * (           1.0), FixFormat_c); -- = 2/3
    constant MtxCPA2_c : std_logic_vector(cl_fix_width(FixFormat_c)-1 downto 0) := cl_fix_from_real(cMtxPrescaler * (          -0.5), FixFormat_c); -- = -1/3
    constant MtxCPA3_c : std_logic_vector(cl_fix_width(FixFormat_c)-1 downto 0) := cl_fix_from_real(cMtxPrescaler * (          -0.5), FixFormat_c); -- = -1/3

    constant MtxCPB1_c : std_logic_vector(cl_fix_width(FixFormat_c)-1 downto 0) := cl_fix_from_real(cMtxPrescaler * (           0.0), FixFormat_c); -- = 0
    constant MtxCPB2_c : std_logic_vector(cl_fix_width(FixFormat_c)-1 downto 0) := cl_fix_from_real(cMtxPrescaler * ( sqrt(3.0)/2.0), FixFormat_c); -- = srt(3)/3
    constant MtxCPB3_c : std_logic_vector(cl_fix_width(FixFormat_c)-1 downto 0) := cl_fix_from_real(cMtxPrescaler * (-sqrt(3.0)/2.0), FixFormat_c); -- = -sqrt(3)/3
    
    constant MtxCPC1_c : std_logic_vector(cl_fix_width(FixFormat_c)-1 downto 0) := cl_fix_from_real(cMtxPrescaler * (           0.5), FixFormat_c); -- = 1/3
    constant MtxCPC2_c : std_logic_vector(cl_fix_width(FixFormat_c)-1 downto 0) := cl_fix_from_real(cMtxPrescaler * (           0.5), FixFormat_c); -- = 1/3
    constant MtxCPC3_c : std_logic_vector(cl_fix_width(FixFormat_c)-1 downto 0) := cl_fix_from_real(cMtxPrescaler * (           0.5), FixFormat_c); -- = 1/3

    constant NumStages_c : integer := 2; -- processing takes 3 pipeline stages (Valid on 4th edge after strobe)
    
    type SummandArray_t is array (0 to 2) of std_logic_vector(cl_fix_width(IntFixFormat_c)-1 downto 0);

    type TwoProcess_r is record
        Alpha : SummandArray_t;
        AlphaSum : std_logic_vector(cl_fix_width(IntFixFormat_c)-1 downto 0);
        Beta : SummandArray_t;
        BetaSum : std_logic_vector(cl_fix_width(IntFixFormat_c)-1 downto 0);
        Gamma : SummandArray_t;
        GammaSum : std_logic_vector(cl_fix_width(IntFixFormat_c)-1 downto 0);
        MtxDQA1 : std_logic_vector(cl_fix_width(IntFixFormat_c)-1 downto 0);
        MtxDQA2 : std_logic_vector(cl_fix_width(IntFixFormat_c)-1 downto 0);
        MtxDQB1 : std_logic_vector(cl_fix_width(IntFixFormat_c)-1 downto 0);
        MtxDQB2 : std_logic_vector(cl_fix_width(IntFixFormat_c)-1 downto 0);
        Valid : std_logic_vector(NumStages_c downto 0);
        D : std_logic_vector(cl_fix_width(FixFormat_c)-1 downto 0);
        Q : std_logic_vector(cl_fix_width(FixFormat_c)-1 downto 0);
        DC : std_logic_vector(cl_fix_width(FixFormat_c)-1 downto 0);
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

        -- clarke transform (pipeline stage 1)
        v.Alpha(0) := cl_fix_mult(MtxCPA1_c, FixFormat_c, A, FixFormat_c, IntFixFormat_c);
        v.Alpha(1) := cl_fix_mult(MtxCPA2_c, FixFormat_c, B, FixFormat_c, IntFixFormat_c);
        v.Alpha(2) := cl_fix_mult(MtxCPA3_c, FixFormat_c, C, FixFormat_c, IntFixFormat_c);

        v.Beta(0)  := cl_fix_mult(MtxCPB1_c, FixFormat_c, A, FixFormat_c, IntFixFormat_c);
        v.Beta(1)  := cl_fix_mult(MtxCPB2_c, FixFormat_c, B, FixFormat_c, IntFixFormat_c);
        v.Beta(2)  := cl_fix_mult(MtxCPB3_c, FixFormat_c, C, FixFormat_c, IntFixFormat_c);
        
        v.Gamma(0) := cl_fix_mult(MtxCPC1_c, FixFormat_c, A, FixFormat_c, IntFixFormat_c);
        v.Gamma(1) := cl_fix_mult(MtxCPC2_c, FixFormat_c, B, FixFormat_c, IntFixFormat_c);
        v.Gamma(2) := cl_fix_mult(MtxCPC3_c, FixFormat_c, C, FixFormat_c, IntFixFormat_c);

        -- simplified park transform (pipeline stage 1)
        v.MtxDQA1 := cl_fix_resize(Cosine, FixFormat_c, IntFixFormat_c);
        v.MtxDQA2 := cl_fix_resize(Sine, FixFormat_c, IntFixFormat_c);
        v.MtxDQB1 := cl_fix_neg(Sine, FixFormat_c, IntFixFormat_c);
        v.MtxDQB2 := cl_fix_resize(Cosine, FixFormat_c, IntFixFormat_c);

        -- clarke transform sumup (pipeline stage 2)
        v.AlphaSum := cl_fix_add(
            cl_fix_add(
                r.Alpha(0), IntFixFormat_c,
                r.Alpha(1), IntFixFormat_c,
                IntFixFormat_c), IntFixFormat_c,
            r.Alpha(2), IntFixFormat_c,
            IntFixFormat_c);
            
        v.BetaSum  := cl_fix_add(
            cl_fix_add(
                r.Beta(0), IntFixFormat_c,
                r.Beta(1), IntFixFormat_c,
                IntFixFormat_c), IntFixFormat_c,
            r.Beta(2), IntFixFormat_c,
            IntFixFormat_c);

        v.GammaSum := cl_fix_add(
            cl_fix_add(
                r.Gamma(0), IntFixFormat_c,
                r.Gamma(1), IntFixFormat_c,
                IntFixFormat_c), IntFixFormat_c,
            r.Gamma(2), IntFixFormat_c,
            IntFixFormat_c);

        -- calc outputs
        v.D := cl_fix_add(
            cl_fix_mult(r.MtxDQA1, IntFixFormat_c, r.AlphaSum, IntFixFormat_c, IntFixFormat_c), IntFixFormat_c, 
            cl_fix_mult(r.MtxDQA2, IntFixFormat_c, r.BetaSum, IntFixFormat_c, IntFixFormat_c), IntFixFormat_c, 
            FixFormat_c);
        v.Q := cl_fix_add(
            cl_fix_mult(r.MtxDQB1, IntFixFormat_c, r.AlphaSum, IntFixFormat_c, IntFixFormat_c), IntFixFormat_c, 
            cl_fix_mult(r.MtxDQB2, IntFixFormat_c, r.BetaSum, IntFixFormat_c, IntFixFormat_c), IntFixFormat_c, 
            FixFormat_c);
        v.DC := cl_fix_resize(r.GammaSum, IntFixFormat_c, FixFormat_c);

        v.Valid := r.Valid(r.Valid'left-1 downto 0) & Strobe;

        r_next <= v;
    end process p_combinatorial;

    -----------------------------------------------------------------------------------------------
    -- Outputs
    -----------------------------------------------------------------------------------------------
    Valid <= r.Valid(r.Valid'left);
    D <= r.D;
    Q <= r.Q;
    DC <= r.DC;

    -----------------------------------------------------------------------------------------------
    -- Sequential Proccess
    -----------------------------------------------------------------------------------------------
    p_seq : process (Clk) is
    begin
        if rising_edge(Clk) then
            r <= r_next;
            if Rst = '1' then
                r.Valid <= (others => '0');
                r.D <= (others => '0');
                r.Q <= (others => '0');
                r.DC <= (others => '0');
            end if;
        end if;
    end process;

end architecture;