library IEEE;
  use IEEE.std_logic_1164.all;
  use IEEE.NUMERIC_STD.all;
  use IEEE.MATH_REAL.all;

library olo;
  use olo.en_cl_fix_pkg.all;
  use olo.olo_fix_pkg.all;

entity SVPWM is
  generic (
    SysClkMHz_g   : natural;
    PWMFreqkHz_g  : natural;
    DeadTimeNs_g  : natural;
    DataWidth_g   : natural
  );
  port (
    Clk           : in    std_logic;
    Rst           : in    std_logic;
    Uq            : in    std_logic_vector(DataWidth_g-1 downto 0);
    iUd           : in    std_logic_vector(DataWidth_g-1 downto 0);
    Sine          : in    std_logic_vector(DataWidth_g-1 downto 0);
    Cosine        : in    std_logic_vector(DataWidth_g-1 downto 0);
    EnableIn      : in    std_logic;
    FaultIn_N     : in    std_logic;
    
    PWM_A_L : out std_logic;
    PWM_A_H : out std_logic;
    PWM_B_L : out std_logic;
    PWM_B_H : out std_logic;
    PWM_C_L : out std_logic;
    PWM_C_H : out std_logic;
    ADCTriggerLSOn : out std_logic;
    ADCTriggerHSOn : out std_logic;
    oEn : out std_logic;
    oFault_n : out std_logic
  );
end entity SVPWM;

architecture Behavioral of SVPWM is

  constant TimerMax_c   : natural := (1000*SysClkMHz_g)/(2*PWMFreqkHz_g);
  constant TimerWidth_c : natural := natural(ceil(log2(real(TimerMax_c))));
  constant DeadTime_c   : natural := (SysClkMHz_g * DeadTimeNs_g)/1000;
  constant MaxDC_c      : real := 0.5 - real(4 * DeadTimeNs_g * PWMFreqkHz_g)/1.0e6;

  constant FixFmt_c     : FixFormat_t := (1,0,DataWidth_g-1);
  constant FixFmtInt_c  : FixFormat_t := (1,1,DataWidth_g-1);
  constant FixFmtOut_c  : FixFormat_t := (0,TimerWidth_c,0);

  constant PwmDc_c : std_logic_vector(cl_fix_width(FixFmt_c)-1 downto 0) := cl_fix_from_real(0.5              ,FixFmt_c); -- = 1/2

  signal sTimerCounter : integer range 0 to TimerMax_c := 0;
  signal sCountDirection : std_logic := '0';
  signal sCompA, sCompB, sCompC : integer range 0 to TimerMax_c := 0;  

  signal sUaPWM0, sUbPWM0, sUcPWM0, sUaPWM1, sUbPWM1, sUcPWM1 : std_logic_vector(cl_fix_width(FixFmt_c)-1 downto 0) := (others => '0');
  signal sUaPWM2, sUbPWM2, sUcPWM2 : std_logic_vector(TimerWidth_c-1 downto 0) := (others => '0');
  signal sUq, sUd, sSin, sCos : std_logic_vector(cl_fix_width(FixFmt_c)-1 downto 0) := (others => '0');
  signal sAlpha0, sBeta0, sAlpha1, sBeta1 : std_logic_vector(cl_fix_width(FixFmtInt_c)-1 downto 0) := (others => '0');
  signal sUa0, sUb0, sUc0, sUa1, sUb1, sUc1 : std_logic_vector(cl_fix_width(FixFmtInt_c)-1 downto 0) := (others => '0');
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
      IF sTimerCounter =  TimerMax_c-1 THEN
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
    ELSIF sTimerCounter <= (sCompA - DeadTime_c) and sCountDirection = '1' THEN
      sPWM_A_H <= '1';
    ELSE
      sPWM_A_H <= '0';
    END IF;    
    
    IF sTimerCounter > (sCompA + DeadTime_c) and sCountDirection = '0' THEN
      sPWM_A_L <= '1';
    ELSIF sTimerCounter > sCompA and sCountDirection = '1' THEN
      sPWM_A_L <= '1';
    ELSE
      sPWM_A_L <= '0';
    END IF;             

    IF sTimerCounter <= sCompB and sCountDirection = '0' THEN
      sPWM_B_H <= '1';
    ELSIF sTimerCounter <= (sCompB - DeadTime_c) and sCountDirection = '1' THEN
      sPWM_B_H <= '1';
    ELSE
      sPWM_B_H <= '0';
    END IF;    
    
    IF sTimerCounter > (sCompB + DeadTime_c) and sCountDirection = '0' THEN
      sPWM_B_L <= '1';
    ELSIF sTimerCounter > sCompB and sCountDirection = '1' THEN
      sPWM_B_L <= '1';
    ELSE
      sPWM_B_L <= '0';
    END IF;  
    
    IF sTimerCounter <= sCompC and sCountDirection = '0' THEN
      sPWM_C_H <= '1';
    ELSIF sTimerCounter <= (sCompC - DeadTime_c) and sCountDirection = '1' THEN
      sPWM_C_H <= '1';
    ELSE
      sPWM_C_H <= '0';
    END IF;    
    
    IF sTimerCounter > (sCompC + DeadTime_c) and sCountDirection = '0' THEN
      sPWM_C_L <= '1';
    ELSIF sTimerCounter > sCompC and sCountDirection = '1' THEN
      sPWM_C_L <= '1';
    ELSE
      sPWM_C_L <= '0';
    END IF; 
    
    IF sTimerCounter = (TimerMax_c-1) and sCountDirection = '0' THEN
      ADCTriggerLSOn <= '1';
    ELSE
      ADCTriggerLSOn <= '0';
    END IF;  
    
    IF sTimerCounter = 1 and sCountDirection = '1' THEN
      ADCTriggerHSOn <= '1';
    ELSE
      ADCTriggerHSOn <= '0';
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
      ADCTriggerLSOn <=  '0';
      ADCTriggerHSOn <=  '0';
    END IF;

  END IF;
end process p_sequential;   
  
p_combinatorial: process(sSin, sCos, sUq, sUd, sAlpha1, sBeta1, sUa1, sUb1, sUc1,
                          sUaPWM1, sUbPWM1, sUcPWM1,
                          sPWM_A_L, sPWM_A_H, sPWM_B_L, sPWM_B_H, sPWM_C_L, sPWM_C_H,
                          iEn)
    variable negSin, posCos, posSin : std_logic_vector(cl_fix_width(FixFmtInt_c)-1 downto 0);  
begin  

  -- Pipeline stage 1: inv Park Transformation
  negSin := cl_fix_neg(sSin,FixFmt_c,FixFmtInt_c);   
  posCos := cl_fix_resize(sCos,FixFmt_c,FixFmtInt_c);
  posSin := cl_fix_resize(sSin,FixFmt_c,FixFmtInt_c);

 
      
  -- Pipeline stage 3: duty cycle calculation
  -- Duty cycle = 0.5 + Ux * (max. Duty Cycle - 0.5), e. g. 0.5 + Ux * 0.48 if max. DC is 98%
  sUaPWM0 <= cl_fix_add(
    cl_fix_mult(sUa1,FixFmtInt_c,cl_fix_from_real(MaxDC_c,FixFmtInt_c),FixFmtInt_c,FixFmt_c), FixFmt_c,
    cl_fix_from_real(0.5,FixFmt_c), FixFmt_c, FixFmt_c);

  sUbPWM0 <= cl_fix_add(
    cl_fix_mult(sUb1,FixFmtInt_c,cl_fix_from_real(MaxDC_c,FixFmtInt_c),FixFmtInt_c,FixFmt_c), FixFmt_c,
    cl_fix_from_real(0.5,FixFmt_c), FixFmt_c, FixFmt_c);
                
  sUcPWM0 <= cl_fix_add(
    cl_fix_mult(sUc1,FixFmtInt_c,cl_fix_from_real(MaxDC_c,FixFmtInt_c),FixFmtInt_c,FixFmt_c), FixFmt_c,
    cl_fix_from_real(0.5,FixFmt_c), FixFmt_c, FixFmt_c);

  -- Pipeline stage 4: scale to counter
  sUaPWM2 <= cl_fix_mult(sUaPWM1,FixFmt_c,cl_fix_from_integer(TimerMax_c,FixFmtOut_c),FixFmtOut_c, FixFmtOut_c);
  sUbPWM2 <= cl_fix_mult(sUbPWM1,FixFmt_c,cl_fix_from_integer(TimerMax_c,FixFmtOut_c),FixFmtOut_c, FixFmtOut_c);
  sUcPWM2 <= cl_fix_mult(sUcPWM1,FixFmt_c,cl_fix_from_integer(TimerMax_c,FixFmtOut_c),FixFmtOut_c, FixFmtOut_c);

  -- output signal assignement  
  PWM_A_L <= sPWM_A_L;
  PWM_A_H <= sPWM_A_H; 
  PWM_B_L <= sPWM_B_L;
  PWM_B_H <= sPWM_B_H;
  PWM_C_L <= sPWM_C_L;
  PWM_C_H <= sPWM_C_H;
                
  -- Fault signal passtrough
  oFault_n <= iFault_n;

end process p_combinatorial;
  
end Behavioral;