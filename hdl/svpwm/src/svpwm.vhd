library IEEE;
  use IEEE.STD_LOGIC_1164.all;
  use IEEE.NUMERIC_STD.all;
  use IEEE.MATH_REAL.all;

library olo;
  use olo.en_cl_fix_pkg.all;
  use olo.olo_fix_pkg.all;

entity SVPWM is
  generic (
    gSysClkMHz : natural := 125;
    gPWMFreqkHz : natural := 8;
    gDeadTimeNs : natural := 800;
    gDataWidth : natural := 12);
  port (
    reset_n : in STD_LOGIC;
    clk : in STD_LOGIC;
    iUq : in STD_LOGIC_VECTOR(gDataWidth-1 downto 0);
    iUd : in STD_LOGIC_VECTOR(gDataWidth-1 downto 0);
    iSin : in STD_LOGIC_VECTOR(gDataWidth-1 downto 0);
    iCos : in STD_LOGIC_VECTOR(gDataWidth-1 downto 0);
    iEn : in STD_LOGIC;
    iFault_n : in STD_LOGIC;
    
    oPWM_A_L : out STD_LOGIC;
    oPWM_A_H : out STD_LOGIC;
    oPWM_B_L : out STD_LOGIC;
    oPWM_B_H : out STD_LOGIC;
    oPWM_C_L : out STD_LOGIC;
    oPWM_C_H : out STD_LOGIC;
    oADCTriggerLSOn : out STD_LOGIC;
    oADCTriggerHSOn : out STD_LOGIC;
    oEn : out STD_LOGIC;
    oFault_n : out STD_LOGIC

  );
end entity SVPWM;

architecture Behavioral of SVPWM is

  constant cTimerMax : natural := (1000*gSysClkMHz)/(2*gPWMFreqkHz);
  constant cTimerWidth : natural := natural(ceil(log2(real(cTimerMax))));
  constant cDeadTime : natural := (gSysClkMHz * gDeadTimeNs)/1000;
  constant cMaxDC : real := 0.5 - real(4 * gDeadTimeNs * gPWMFreqkHz)/1.0e6;

  constant cFixFmt : FixFormat_t := (1,0,gDataWidth-1);
  constant cFixFmtInt : FixFormat_t := (1,1,gDataWidth-1);
  constant cFixFmtOut : FixFormat_t := (0,cTimerWidth,0);

  constant cMtx11 : std_logic_vector(cl_fix_width(cFixFmt)-1 downto 0) := cl_fix_from_real(1.0              ,cFixFmt); -- = 1
  constant cMtx12 : std_logic_vector(cl_fix_width(cFixFmt)-1 downto 0) := cl_fix_from_real(0.0              ,cFixFmt); -- = 0
  constant cMtx21 : std_logic_vector(cl_fix_width(cFixFmt)-1 downto 0) := cl_fix_from_real(-0.5             ,cFixFmt); -- = 1/2
  constant cMtx22 : std_logic_vector(cl_fix_width(cFixFmt)-1 downto 0) := cl_fix_from_real(sqrt(3.0)/2.0    ,cFixFmt); -- = sqrt(3)/2
  constant cMtx31 : std_logic_vector(cl_fix_width(cFixFmt)-1 downto 0) := cl_fix_from_real(-0.5             ,cFixFmt); -- = 1/2
  constant cMtx32 : std_logic_vector(cl_fix_width(cFixFmt)-1 downto 0) := cl_fix_from_real(-sqrt(3.0)/2.0   ,cFixFmt); -- = -sqrt(3)/2
  constant cPwmDC : std_logic_vector(cl_fix_width(cFixFmt)-1 downto 0) := cl_fix_from_real(0.5              ,cFixFmt); -- = 1/2

  signal sTimerCounter : integer range 0 to cTimerMax := 0;
  signal sCountDirection : std_logic := '0';
  signal sCompA, sCompB, sCompC : integer range 0 to cTimerMax := 0;  

  signal sUaPWM0, sUbPWM0, sUcPWM0, sUaPWM1, sUbPWM1, sUcPWM1 : std_logic_vector(cl_fix_width(cFixFmt)-1 downto 0) := (others => '0');
  signal sUaPWM2, sUbPWM2, sUcPWM2 : std_logic_vector(cTimerWidth-1 downto 0) := (others => '0');
  signal sUq, sUd, sSin, sCos : std_logic_vector(cl_fix_width(cFixFmt)-1 downto 0) := (others => '0');
  signal sAlpha0, sBeta0, sAlpha1, sBeta1 : std_logic_vector(cl_fix_width(cFixFmtInt)-1 downto 0) := (others => '0');
  signal sUa0, sUb0, sUc0, sUa1, sUb1, sUc1 : std_logic_vector(cl_fix_width(cFixFmtInt)-1 downto 0) := (others => '0');
  signal sEnReady : std_logic := '0';  
    
  signal sPWM_A_L, sPWM_A_H, sPWM_B_L, sPWM_B_H, sPWM_C_L, sPWM_C_H : std_logic := '0';

begin 

p_sequential : process (clk)
begin
  IF rising_edge(clk) THEN  
        -- outputs
      IF sTimerCounter = 0 THEN
          sCompA <= to_integer(unsigned(sUaPWM2));
          sCompB <= to_integer(unsigned(sUbPWM2));
          sCompC <= to_integer(unsigned(sUcPWM2));
      END IF;
      -- pipeline       
      sUq <= iUq;
      sUd <= iUd;
      sSin <= iSin;
      sCos <= iCos;
      -- pipeline stage 1
      sAlpha1 <= sAlpha0;
      sBeta1 <= sBeta0;
      -- pipeline stage 2
      sUa1 <= sUa0;
      sUb1 <= sUb0;
      sUc1 <= sUc0;
      -- pipeline stage 3
      sUaPWM1 <= sUaPWM0;
      sUbPWM1 <= sUbPWM0;
      sUcPWM1 <= sUcPWM0;

    --Enable Fault Control
    IF iFault_n ='0' then
      sEnReady <= '0';
    ELSIF iEn = '0' THEN
      sEnReady <= '1';
    END IF; 

    -- set enable signal
    IF sEnReady = '1' and iEn = '1' THEN
      oEn <= '1';
    ELSE
      oEn <= '0';  
    END IF;  
    
    --Timer     
    IF sCountDirection = '0' THEN
      --hochzaehlen
      sTimerCounter <= sTimerCounter +1; 
      IF sTimerCounter =  cTimerMax-1 THEN
        sCountDirection <= '1';
      END IF;      
    ELSE
      --runterzaehlen
      sTimerCounter <= sTimerCounter - 1;
      IF sTimerCounter = 1 THEN
        sCountDirection <= '0';
      END IF;
    END IF;

    --Compare
    IF sTimerCounter <= sCompA and sCountDirection = '0' THEN
      sPWM_A_H <= '1';
    ELSIF sTimerCounter <= (sCompA - cDeadTime) and sCountDirection = '1' THEN
      sPWM_A_H <= '1';
    ELSE
      sPWM_A_H <= '0';
    END IF;    
    
    IF sTimerCounter > (sCompA + cDeadTime) and sCountDirection = '0' THEN
      sPWM_A_L <= '1';
    ELSIF sTimerCounter > sCompA and sCountDirection = '1' THEN
      sPWM_A_L <= '1';
    ELSE
      sPWM_A_L <= '0';
    END IF;             

    IF sTimerCounter <= sCompB and sCountDirection = '0' THEN
      sPWM_B_H <= '1';
    ELSIF sTimerCounter <= (sCompB - cDeadTime) and sCountDirection = '1' THEN
      sPWM_B_H <= '1';
    ELSE
      sPWM_B_H <= '0';
    END IF;    
    
    IF sTimerCounter > (sCompB + cDeadTime) and sCountDirection = '0' THEN
      sPWM_B_L <= '1';
    ELSIF sTimerCounter > sCompB and sCountDirection = '1' THEN
      sPWM_B_L <= '1';
    ELSE
      sPWM_B_L <= '0';
    END IF;  
    
    IF sTimerCounter <= sCompC and sCountDirection = '0' THEN
      sPWM_C_H <= '1';
    ELSIF sTimerCounter <= (sCompC - cDeadTime) and sCountDirection = '1' THEN
      sPWM_C_H <= '1';
    ELSE
      sPWM_C_H <= '0';
    END IF;    
    
    IF sTimerCounter > (sCompC + cDeadTime) and sCountDirection = '0' THEN
      sPWM_C_L <= '1';
    ELSIF sTimerCounter > sCompC and sCountDirection = '1' THEN
      sPWM_C_L <= '1';
    ELSE
      sPWM_C_L <= '0';
    END IF; 
    
    IF sTimerCounter = (cTimerMax-1) and sCountDirection = '0' THEN
      oADCTriggerLSOn <= '1';
    ELSE
      oADCTriggerLSOn <= '0';
    END IF;  
    
    IF sTimerCounter = 1 and sCountDirection = '1' THEN
      oADCTriggerHSOn <= '1';
    ELSE
      oADCTriggerHSOn <= '0';
    END IF;

    --Reset      
    IF reset_n = '0' THEN
      sTimerCounter <= 0;
      sPWM_A_L  <=  '0';
      sPWM_A_H  <=  '0';
      sPWM_B_L  <=  '0';
      sPWM_B_H  <=  '0';
      sPWM_C_L  <=  '0';
      sPWM_C_H  <=  '0';
      oADCTriggerLSOn <=  '0';
      oADCTriggerHSOn <=  '0';
    END IF;

  END IF;
end process p_sequential;   
  
p_combinatorial: process(sSin, sCos, sUq, sUd, sAlpha1, sBeta1, sUa1, sUb1, sUc1,
                          sUaPWM1, sUbPWM1, sUcPWM1,
                          sPWM_A_L, sPWM_A_H, sPWM_B_L, sPWM_B_H, sPWM_C_L, sPWM_C_H,
                          iEn)
    variable negSin, posCos, posSin : std_logic_vector(cl_fix_width(cFixFmtInt)-1 downto 0);  
begin  

  -- Pipeline stage 1: inv Park Transformation
  negSin := cl_fix_neg(sSin,cFixFmt,cFixFmtInt);   
  posCos := cl_fix_resize(sCos,cFixFmt,cFixFmtInt);
  posSin := cl_fix_resize(sSin,cFixFmt,cFixFmtInt);

  -- calc results
  sAlpha0 <= cl_fix_add(
              cl_fix_mult(posCos,cFixFmtInt,sUd,cFixFmt,cFixFmtInt),cFixFmtInt,
              cl_fix_mult(negSin,cFixFmtInt,sUq,cFixFmt,cFixFmtInt),cFixFmtInt,
              cFixFmtInt);
  sBeta0 <= cl_fix_add(
              cl_fix_mult(posSin,cFixFmtInt,sUd,cFixFmt,cFixFmtInt),cFixFmtInt,
              cl_fix_mult(posCos,cFixFmtInt,sUq,cFixFmt,cFixFmtInt),cFixFmtInt,
              cFixFmtInt);

  --Pipeline stage 2: inv Clarke Transformation
  sUa0 <= cl_fix_add(
      cl_fix_mult(cMtx11,cFixFmt,sAlpha1,cFixFmtInt,cFixFmtInt),cFixFmtInt,
      cl_fix_mult(cMtx12,cFixFmt,sBeta1,cFixFmtInt,cFixFmtInt),cFixFmtInt,
      cFixFmtInt);
  
  sUb0 <= cl_fix_add(
      cl_fix_mult(cMtx21,cFixFmt,sAlpha1,cFixFmtInt,cFixFmtInt),cFixFmtInt,
      cl_fix_mult(cMtx22,cFixFmt,sBeta1,cFixFmtInt,cFixFmtInt),cFixFmtInt,
      cFixFmtInt);

  sUc0 <= cl_fix_add(
      cl_fix_mult(cMtx31,cFixFmt,sAlpha1,cFixFmtInt,cFixFmtInt),cFixFmtInt,
      cl_fix_mult(cMtx32,cFixFmt,sBeta1,cFixFmtInt,cFixFmtInt),cFixFmtInt,
      cFixFmtInt);
      
  -- Pipeline stage 3: duty cycle calculation
  -- Duty cycle = 0.5 + Ux * (max. Duty Cycle - 0.5), e. g. 0.5 + Ux * 0.48 if max. DC is 98%
  sUaPWM0 <= cl_fix_add(
    cl_fix_mult(sUa1,cFixFmtInt,cl_fix_from_real(cMaxDC,cFixFmtInt),cFixFmtInt,cFixFmt), cFixFmt,
    cl_fix_from_real(0.5,cFixFmt), cFixFmt, cFixFmt);

  sUbPWM0 <= cl_fix_add(
    cl_fix_mult(sUb1,cFixFmtInt,cl_fix_from_real(cMaxDC,cFixFmtInt),cFixFmtInt,cFixFmt), cFixFmt,
    cl_fix_from_real(0.5,cFixFmt), cFixFmt, cFixFmt);
                
  sUcPWM0 <= cl_fix_add(
    cl_fix_mult(sUc1,cFixFmtInt,cl_fix_from_real(cMaxDC,cFixFmtInt),cFixFmtInt,cFixFmt), cFixFmt,
    cl_fix_from_real(0.5,cFixFmt), cFixFmt, cFixFmt);

  -- Pipeline stage 4: scale to counter
  sUaPWM2 <= cl_fix_mult(sUaPWM1,cFixFmt,cl_fix_from_integer(cTimerMax,cFixFmtOut),cFixFmtOut, cFixFmtOut);
  sUbPWM2 <= cl_fix_mult(sUbPWM1,cFixFmt,cl_fix_from_integer(cTimerMax,cFixFmtOut),cFixFmtOut, cFixFmtOut);
  sUcPWM2 <= cl_fix_mult(sUcPWM1,cFixFmt,cl_fix_from_integer(cTimerMax,cFixFmtOut),cFixFmtOut, cFixFmtOut);

  -- output signal assignement  
  oPWM_A_L <= sPWM_A_L;
  oPWM_A_H <= sPWM_A_H; 
  oPWM_B_L <= sPWM_B_L;
  oPWM_B_H <= sPWM_B_H;
  oPWM_C_L <= sPWM_C_L;
  oPWM_C_H <= sPWM_C_H;
                
  -- Fault signal passtrough
  oFault_n <= iFault_n;

end process p_combinatorial;
  
end Behavioral;