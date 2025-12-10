library IEEE;
  use IEEE.STD_LOGIC_1164.ALL;
  use IEEE.NUMERIC_STD.ALL;
  use IEEE.MATH_REAL.ALL; 

library olo;
  use olo.en_cl_fix_pkg.all;
  use olo.olo_fix_pkg.all;

entity dqTransform is
    generic ( 
        gDataWidth : natural := 12);
    port (  clk : in std_logic;
            reset_n : in std_logic;
            iSin : in std_logic_vector(gDataWidth-1 downto 0);
            iCos : in std_logic_vector(gDataWidth-1 downto 0);
            iA : in std_logic_vector(gDataWidth-1 downto 0);
            iB : in std_logic_vector(gDataWidth-1 downto 0);
            iC : in std_logic_vector(gDataWidth-1 downto 0);
            oD : out std_logic_vector(gDataWidth-1 downto 0);
            oQ : out std_logic_vector(gDataWidth-1 downto 0);
            oDC : out std_logic_vector(gDataWidth-1 downto 0);
            iStrobe : in std_logic; -- new sample available
            oReady : out std_logic);
end dqTransform;

architecture Behavioral of dqTransform is

    constant cFixFmt : FixFormat_t := (1, 0, gDataWidth-1);
    constant cFixFmtInt : FixFormat_t := (1, 1, gDataWidth);
    
    -- matrix coefficients
    constant cMtxPrescaler : real := 2.0/3.0; -- 2/3

    constant cMtxCPA1 : std_logic_vector(cl_fix_width(cFixFmt)-1 downto 0) := cl_fix_from_real(cMtxPrescaler * (           1.0), cFixFmt); -- = 2/3
    constant cMtxCPA2 : std_logic_vector(cl_fix_width(cFixFmt)-1 downto 0) := cl_fix_from_real(cMtxPrescaler * (          -0.5), cFixFmt); -- = -1/3
    constant cMtxCPA3 : std_logic_vector(cl_fix_width(cFixFmt)-1 downto 0) := cl_fix_from_real(cMtxPrescaler * (          -0.5), cFixFmt); -- = -1/3

    constant cMtxCPB1 : std_logic_vector(cl_fix_width(cFixFmt)-1 downto 0) := cl_fix_from_real(cMtxPrescaler * (           0.0), cFixFmt); -- = 0
    constant cMtxCPB2 : std_logic_vector(cl_fix_width(cFixFmt)-1 downto 0) := cl_fix_from_real(cMtxPrescaler * ( sqrt(3.0)/2.0), cFixFmt); -- = srt(3)/3
    constant cMtxCPB3 : std_logic_vector(cl_fix_width(cFixFmt)-1 downto 0) := cl_fix_from_real(cMtxPrescaler * (-sqrt(3.0)/2.0), cFixFmt); -- = -sqrt(3)/3
    
    constant cMtxCPC1 : std_logic_vector(cl_fix_width(cFixFmt)-1 downto 0) := cl_fix_from_real(cMtxPrescaler * (           0.5), cFixFmt); -- = 1/3
    constant cMtxCPC2 : std_logic_vector(cl_fix_width(cFixFmt)-1 downto 0) := cl_fix_from_real(cMtxPrescaler * (           0.5), cFixFmt); -- = 1/3
    constant cMtxCPC3 : std_logic_vector(cl_fix_width(cFixFmt)-1 downto 0) := cl_fix_from_real(cMtxPrescaler * (           0.5), cFixFmt); -- = 1/3

    signal sSin, sCos : std_logic_vector(cl_fix_width(cFixFmt)-1 downto 0) := (others => '0');
    signal sA, sB, sC : std_logic_vector(gDataWidth-1 downto 0) := (others => '0');

    type tSummandArray is array (0 to 2) of std_logic_vector(cl_fix_width(cFixFmtInt)-1 downto 0);
    signal sAlpha, sAlpha_f, sBeta, sBeta_f, sGamma, sGamma_f : tSummandArray := (others => (others => '0'));
    signal sAlphaSum, sAlphaSum_f, sBetaSum, sBetaSum_f, sGammaSum, sGammaSum_f : std_logic_vector(cl_fix_width(cFixFmtInt)-1 downto 0) := (others => '0');
    signal sD, sQ, sDC : std_logic_vector(cl_fix_width(cFixFmt)-1 downto 0) := (others => '0');

    signal sMtxDQA1, sMtxDQA1_f, sMtxDQA2, sMtxDQA2_f, sMtxDQB1, sMtxDQB1_f, sMtxDQB2, sMtxDQB2_f : std_logic_vector(cl_fix_width(cFixFmtInt)-1 downto 0);

    constant cStages : integer := 3; -- processing takes 3 pipeline stages (ready on 4th edge after strobe)
    signal sReady : std_logic_vector(cStages downto 0);

begin

-- two process model (Jiri Gaisler)
p_sequential: process(clk)
begin
    if rising_edge(clk) then
        -- outputs
        oD <= sD;
        oQ <= sQ;
        oDC <= sDC;
        -- signals for pipeline stage 1
        sA <= iA;
        sB <= iB;
        sC <= iC;
        sSin <= iSin;
        sCos <= iCos;
        -- signals for pipeline stage 2
        sAlpha_f <= sAlpha;
        sBeta_f <= sBeta;
        sGamma_f <= sGamma;
        -- signals for pipeline stage 3
        sMtxDQA1_f <= sMtxDQA1;
        sMtxDQA2_f <= sMtxDQA2;
        sMtxDQB1_f <= sMtxDQB1;
        sMtxDQB2_f <= sMtxDQB2;
        sAlphaSum_f <= sAlphaSum;
        sBetaSum_f <= sBetaSum;
        sGammaSum_f <= sGammaSum;
        -- ready signal pipeline
        sReady <= sReady(sReady'left-1 downto 0) & iStrobe;
        -- synchroneous reset
        if reset_n = '0' then
            oD <= (others => '0');
            oQ <= (others => '0');
            oDC <= (others => '0');
            sA <= (others => '0');
            sB <= (others => '0');
            sC <= (others => '0');
            sSin <= (others => '0');
            sCos <= (others => '0');
            sMtxDQA1_f <= (others => '0');
            sMtxDQA2_f <= (others => '0');
            sMtxDQB1_f <= (others => '0');
            sMtxDQB2_f <= (others => '0');
            sAlpha_f <= (others => (others => '0'));
            sBeta_f <= (others => (others => '0'));
            sGamma_f <= (others => (others => '0'));
            sAlphaSum_f <= (others => '0');
            sBetaSum_f <= (others => '0');
            sGammaSum_f <= (others => '0');
            sReady <= (others => '0');
        end if;       
    end if;
end process p_sequential;

p_combinatorial: process(sA, sB, sC, sSin, sCos, sAlpha_f, sBeta_f,
                            sAlphaSum_f, sBetaSum_f, sGammaSum_f, sReady,
                            sMtxDQA1_f, sMtxDQA2_f, sMtxDQB1_f, sMtxDQB2_f)
    variable vAlphaSum, vBetaSum, vGammaSum : std_logic_vector(cl_fix_width(cFixFmtInt)-1 downto 0) := (others => '0');
begin
    -- clarke transform (pipeline stage 1)
    sAlpha(0) <= cl_fix_mult(cMtxCPA1, cFixFmt, sA, cFixFmt, cFixFmtInt);
    sAlpha(1) <= cl_fix_mult(cMtxCPA2, cFixFmt, sB, cFixFmt, cFixFmtInt);
    sAlpha(2) <= cl_fix_mult(cMtxCPA3, cFixFmt, sC, cFixFmt, cFixFmtInt);
    sBeta(0) <= cl_fix_mult(cMtxCPB1, cFixFmt, sA, cFixFmt, cFixFmtInt);
    sBeta(1) <= cl_fix_mult(cMtxCPB2, cFixFmt, sB, cFixFmt, cFixFmtInt);
    sBeta(2) <= cl_fix_mult(cMtxCPB3, cFixFmt, sC, cFixFmt, cFixFmtInt);
    sGamma(0) <= cl_fix_mult(cMtxCPC1, cFixFmt, sA, cFixFmt, cFixFmtInt);
    sGamma(1) <= cl_fix_mult(cMtxCPC2, cFixFmt, sB, cFixFmt, cFixFmtInt);
    sGamma(2) <= cl_fix_mult(cMtxCPC3, cFixFmt, sC, cFixFmt, cFixFmtInt);

    -- simplified park transform (pipeline stage 1)
    sMtxDQA1 <= cl_fix_resize(sCos, cFixFmt, cFixFmtInt);
    sMtxDQA2 <= cl_fix_resize(sSin, cFixFmt, cFixFmtInt);
    sMtxDQB1 <= cl_fix_neg(sSin, cFixFmt, cFixFmtInt);
    sMtxDQB2 <= cl_fix_resize(sCos, cFixFmt, cFixFmtInt);

    -- clarke transform sumup (pipeline stage 2)
    vAlphaSum := cl_fix_add(sAlpha_f(0), cFixFmtInt, sAlpha_f(1), cFixFmtInt, cFixFmtInt);
    sAlphaSum <= cl_fix_add(vAlphaSum, cFixFmtInt, sAlpha_f(2), cFixFmtInt, cFixFmtInt);
    vBetaSum := cl_fix_add(sBeta_f(0), cFixFmtInt, sBeta_f(1), cFixFmtInt, cFixFmtInt);
    sBetaSum <= cl_fix_add(vBetaSum, cFixFmtInt, sBeta_f(2), cFixFmtInt, cFixFmtInt);
    vGammaSum := cl_fix_add(sGamma_f(0), cFixFmtInt, sGamma_f(1), cFixFmtInt, cFixFmtInt);
    sGammaSum <= cl_fix_add(vGammaSum, cFixFmtInt, sGamma_f(2), cFixFmtInt, cFixFmtInt);

    -- calc results (pipeline stage 3)
    sD <= cl_fix_add(
        cl_fix_mult(sMtxDQA1_f, cFixFmtInt, sAlphaSum_f, cFixFmtInt, cFixFmtInt), cFixFmtInt, 
        cl_fix_mult(sMtxDQA2_f, cFixFmtInt, sBetaSum_f, cFixFmtInt, cFixFmtInt), cFixFmtInt, 
        cFixFmt);
    sQ <= cl_fix_add(
        cl_fix_mult(sMtxDQB1_f, cFixFmtInt, sAlphaSum_f, cFixFmtInt, cFixFmtInt), cFixFmtInt, 
        cl_fix_mult(sMtxDQB2_f, cFixFmtInt, sBetaSum_f, cFixFmtInt, cFixFmtInt), cFixFmtInt, 
        cFixFmt);
    sDC <= cl_fix_resize(sGammaSum_f, cFixFmtInt, cFixFmt);

    -- assign Ready output without combinatorial logic after last stage
    oReady <= sReady(sReady'left);
end process p_combinatorial;

end Behavioral;