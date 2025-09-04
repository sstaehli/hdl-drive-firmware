library vunit_lib;
  context vunit_lib.vunit_context;

library IEEE;
  use IEEE.STD_LOGIC_1164.all;
  use IEEE.MATH_REAL.ALL; 

library olo;
  use olo.en_cl_fix_pkg.all;
  use olo.olo_fix_pkg.all;

library project;
  use project.utility.all;

entity SVPWM_tb is
  generic (runner_cfg : string);
end entity;

architecture tb of SVPWM_tb is

    constant cTestPWMFreqkHz : natural := 8;
    constant cTestDeadTimeNs : natural := 800;

    constant cTestFrequencyTolerance : real := 0.01; -- 1%

    constant cFixFmt : FixFormat_t := (1,0,11);

    signal clk : std_logic := '0';
    signal reset_n : std_logic := '0';

    signal iUq : std_logic_vector(11 downto 0) :=(others => '0');
    signal iUd : std_logic_vector(11 downto 0) := (others => '0');
    signal iSin : std_logic_vector(11 downto 0):= (others => '0');
    signal iCos : std_logic_vector(11 downto 0) := (others => '0');
    signal iEn : std_logic := '0';
    signal iFault_n : std_logic := '0';

    signal oPWM_A_L          :std_logic := '0';
    signal oPWM_A_H          :std_logic := '0';
    signal oPWM_B_L          :std_logic := '0';
    signal oPWM_B_H          :std_logic := '0';
    signal oPWM_C_L          :std_logic := '0';
    signal oPWM_C_H          :std_logic := '0';
    signal oADCTriggerLSOn    :std_logic := '0';
    signal oADCTriggerHSOn    :std_logic := '0';
    signal oEn               :std_logic := '0';
    signal oFault_n          :std_logic := '0';

    signal sMeasureTime : time := 0 ns;
    signal sMeasureF : real := 0.0;

begin

  main : process
    variable vAngle : real := 0.0;
  begin
    test_runner_setup(runner, runner_cfg);
    
    -- test svpwm
    if run("SVPWM_test_out_of_reset") then

      -- Set Coefficients
      iUq <= (others => '0');
      iUd <= (others => '0');
      iSin <= (others => '0');
      iCos <= (others => '0');
      iEn <= '0';
      iFault_n <= '1';

      wait until rising_edge(clk);
      wait for 100 ps;
      -- stimulus here
      wait until reset_n = '1';
      wait until rising_edge(clk);
      wait until rising_edge(clk);
      wait for 100 ps;
      -- check here

    elsif run("SVPWM_test_adc_trigger_and_fpwm") then

      -- Stimulus
      iUq <= X"000";
      iUd <= X"000";
      iSin <= X"000";
      iCos <= X"7FF";

      -- Trigger L
      wait until rising_edge(oADCTriggerHSOn);
      sMeasureTime <= now;
      wait until rising_edge(oADCTriggerHSOn);
      sMeasureTime <= now - sMeasureTime;
      wait for 100 ps;
      -- check frequency
      check_equal(real((1 ms)/sMeasureTime),real(cTestPWMFreqkHz),max_diff => (cTestFrequencyTolerance*real(cTestPWMFreqkHz)));
      
      -- Trigger H
      wait until rising_edge(oADCTriggerLSOn);
      sMeasureTime <= now;
      wait until rising_edge(oADCTriggerLSOn);
      sMeasureTime <= now - sMeasureTime;
      wait for 100 ps;
      -- check frequency
      check_equal(real((1 ms)/sMeasureTime),real(cTestPWMFreqkHz),max_diff => (cTestFrequencyTolerance*real(cTestPWMFreqkHz)));

    elsif run("SVPWM_test_deadtime") then

      -- Stimulus
      iUq <= X"000"; 
      iUd <= X"000";
      iSin <= X"000";
      iCos <= X"7FF";
      iEn <= '1';

      -- PWM A
      wait until falling_edge(oPWM_A_L);
      sMeasureTime <= now;
      wait until rising_edge(oPWM_A_H);
      sMeasureTime <= now - sMeasureTime;
      wait for 100 ps;
      check_equal(real(sMeasureTime/(1 ns)),real(cTestDeadTimeNs),max_diff => (cTestFrequencyTolerance*real(cTestDeadTimeNs)));
      
      wait until falling_edge(oPWM_A_H);
      sMeasureTime <= now;
      wait until rising_edge(oPWM_A_L);
      sMeasureTime <= now - sMeasureTime;
      wait for 100 ps;
      check_equal(real(sMeasureTime/(1 ns)),real(cTestDeadTimeNs),max_diff => (cTestFrequencyTolerance*real(cTestDeadTimeNs)));

      -- PWM B
      wait until falling_edge(oPWM_B_L);
      sMeasureTime <= now;
      wait until rising_edge(oPWM_B_H);
      sMeasureTime <= now - sMeasureTime;
      wait for 100 ps;
      check_equal(real(sMeasureTime/(1 ns)),real(cTestDeadTimeNs),max_diff => (cTestFrequencyTolerance*real(cTestDeadTimeNs)));

      wait until falling_edge(oPWM_B_H);
      sMeasureTime <= now;
      wait until rising_edge(oPWM_B_L);
      sMeasureTime <= now - sMeasureTime;
      wait for 100 ps;
      check_equal(real(sMeasureTime/(1 ns)),real(cTestDeadTimeNs),max_diff => (cTestFrequencyTolerance*real(cTestDeadTimeNs)));
      
      -- PWM C
      wait until falling_edge(oPWM_C_L);
      sMeasureTime <= now;
      wait until rising_edge(oPWM_C_H);
      sMeasureTime <= now - sMeasureTime;
      wait for 100 ps;
      check_equal(real(sMeasureTime/(1 ns)),real(cTestDeadTimeNs),max_diff => (cTestFrequencyTolerance*real(cTestDeadTimeNs)));

      wait until falling_edge(oPWM_C_H);
      sMeasureTime <= now;
      wait until rising_edge(oPWM_C_L);
      sMeasureTime <= now - sMeasureTime;
      wait for 100 ps;
      check_equal(real(sMeasureTime/(1 ns)),real(cTestDeadTimeNs),max_diff => (cTestFrequencyTolerance*real(cTestDeadTimeNs)));


    elsif run("SVPWM_test_values") then

      -- stimulus
      iUq <= X"7FF"; 
      iUd <= X"000";
      iEn <= '1';

      wait until reset_n = '1';
      for i in 0 to 99 loop
        -- simulate angle
        vAngle := 2.0*MATH_PI*real(i)/100.0;
        -- generate sin/cos
        iSin <= cl_fix_from_real(sin(vAngle),cFixFmt);
        iCos <= cl_fix_from_real(cos(vAngle),cFixFmt);
        wait until rising_edge(clk);
        wait for 1 ms;
      end loop;

    end if;

    test_runner_cleanup(runner); -- Simulation ends here
  end process;

  -- generate clock (125 Mhz)
  clk <= not clk after 4 ns;

  -- deassert reset
  reset_n <= '1' after 77 ns;
  
  dut: entity project.SVPWM
  generic map (
      gSysClkMHz => 125,
      gPWMFreqkHz => cTestPWMFreqkHz,
      gDeadTimeNs => cTestDeadTimeNs,
      gDataWidth => 12
  )
  port map (
      clk => clk,
      reset_n => reset_n,
      iUq => iUq,
      iUd => iUd,
      iSin => iSin,
      iCos => iCos,
      iEn => iEn,
      iFault_n => iFault_n,

      oPWM_A_L => oPWM_A_L,
      oPWM_A_H => oPWM_A_H,
      oPWM_B_L => oPWM_B_L,
      oPWM_B_H => oPWM_B_H,
      oPWM_C_L => oPWM_C_L,
      oPWM_C_H => oPWM_C_H,
      oADCTriggerLSOn => oADCTriggerLSOn,
      oADCTriggerHSOn => oADCTriggerHSOn,
      oEn => oEn,
      oFault_n => oFault_n
  );

end architecture;