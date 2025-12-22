library vunit_lib;
  context vunit_lib.vunit_context;

library IEEE;
  use IEEE.STD_LOGIC_1164.all;
  use IEEE.MATH_REAL.ALL; 

library olo;
  use olo.en_cl_fix_pkg.all;
  use olo.olo_fix_pkg.all;

library project;
  use project.project_pkg.all;

entity SVPWM_tb is
  generic (runner_cfg : string);
end entity;

architecture tb of SVPWM_tb is

    constant TestPWMFreqkHz_c : natural := 8;
    constant TestDeadTimeNs_c : natural := 800;

    constant TestFrequencyTolerance_c : real := 0.01; -- 1%

    constant FixFmt_c : FixFormat_t := (1,0,11);

    signal Clk              : std_logic := '0';
    signal Rst              : std_logic := '0';

    signal Uq               : std_logic_vector(11 downto 0) :=(others => '0');
    signal Ud               : std_logic_vector(11 downto 0) := (others => '0');
    signal Sine             : std_logic_vector(11 downto 0):= (others => '0');
    signal Cosine           : std_logic_vector(11 downto 0) := (others => '0');
    signal EnableIn         : std_logic := '0';
    signal FaultIn_N        : std_logic := '0';

    signal PWM_A_L          :std_logic := '0';
    signal PWM_A_H          :std_logic := '0';
    signal PWM_B_L          :std_logic := '0';
    signal PWM_B_H          :std_logic := '0';
    signal PWM_C_L          :std_logic := '0';
    signal PWM_C_H          :std_logic := '0';
    signal ADCTriggerLSOn   :std_logic := '0';
    signal ADCTriggerHSOn   :std_logic := '0';
    signal EnableOut        :std_logic := '0';
    signal FaultOut_N       :std_logic := '0';

    signal MeasureTime : time := 0 ns;
    signal MeasureF : real := 0.0;

begin

  main : process
    variable vAngle : real := 0.0;
  begin
    test_runner_setup(runner, runner_cfg);
    
    -- test svpwm
    if run("SVPWM_test_out_of_reset") then

      -- Set Coefficients
      Uq <= (others => '0');
      Ud <= (others => '0');
      Sine <= (others => '0');
      Cosine <= (others => '0');
      EnableIn <= '0';
      FaultIn_N <= '1';

      wait until rising_edge(Clk);
      wait for 100 ps;
      -- stimulus here
      wait until Rst = '1';
      wait until rising_edge(Clk);
      wait until rising_edge(Clk);
      wait for 100 ps;
      -- check here

    elsif run("SVPWM_test_adc_trigger_and_fpwm") then

      -- Stimulus
      Uq <= X"000";
      Ud <= X"000";
      Sine <= X"000";
      Cosine <= X"7FF";

      -- Trigger L
      wait until rising_edge(ADCTriggerHSOn);
      MeasureTime <= now;
      wait until rising_edge(ADCTriggerHSOn);
      MeasureTime <= now - MeasureTime;
      wait for 100 ps;
      -- check frequency
      check_equal(real((1 ms)/MeasureTime),real(TestPWMFreqkHz_c),max_diff => (TestFrequencyTolerance_c*real(TestPWMFreqkHz_c)));
      
      -- Trigger H
      wait until rising_edge(ADCTriggerLSOn);
      MeasureTime <= now;
      wait until rising_edge(ADCTriggerLSOn);
      MeasureTime <= now - MeasureTime;
      wait for 100 ps;
      -- check frequency
      check_equal(real((1 ms)/MeasureTime),real(TestPWMFreqkHz_c),max_diff => (TestFrequencyTolerance_c*real(TestPWMFreqkHz_c)));

    elsif run("SVPWM_test_deadtime") then

      -- Stimulus
      Uq <= X"000"; 
      Ud <= X"000";
      Sine <= X"000";
      Cosine <= X"7FF";
      EnableIn <= '1';

      -- PWM A
      wait until falling_edge(PWM_A_L);
      MeasureTime <= now;
      wait until rising_edge(PWM_A_H);
      MeasureTime <= now - MeasureTime;
      wait for 100 ps;
      check_equal(real(MeasureTime/(1 ns)),real(TestDeadTimeNs_c),max_diff => (TestFrequencyTolerance_c*real(TestDeadTimeNs_c)));
      
      wait until falling_edge(PWM_A_H);
      MeasureTime <= now;
      wait until rising_edge(PWM_A_L);
      MeasureTime <= now - MeasureTime;
      wait for 100 ps;
      check_equal(real(MeasureTime/(1 ns)),real(TestDeadTimeNs_c),max_diff => (TestFrequencyTolerance_c*real(TestDeadTimeNs_c)));

      -- PWM B
      wait until falling_edge(PWM_B_L);
      MeasureTime <= now;
      wait until rising_edge(PWM_B_H);
      MeasureTime <= now - MeasureTime;
      wait for 100 ps;
      check_equal(real(MeasureTime/(1 ns)),real(TestDeadTimeNs_c),max_diff => (TestFrequencyTolerance_c*real(TestDeadTimeNs_c)));

      wait until falling_edge(PWM_B_H);
      MeasureTime <= now;
      wait until rising_edge(PWM_B_L);
      MeasureTime <= now - MeasureTime;
      wait for 100 ps;
      check_equal(real(MeasureTime/(1 ns)),real(TestDeadTimeNs_c),max_diff => (TestFrequencyTolerance_c*real(TestDeadTimeNs_c)));
      
      -- PWM C
      wait until falling_edge(PWM_C_L);
      MeasureTime <= now;
      wait until rising_edge(PWM_C_H);
      MeasureTime <= now - MeasureTime;
      wait for 100 ps;
      check_equal(real(MeasureTime/(1 ns)),real(TestDeadTimeNs_c),max_diff => (TestFrequencyTolerance_c*real(TestDeadTimeNs_c)));

      wait until falling_edge(PWM_C_H);
      MeasureTime <= now;
      wait until rising_edge(PWM_C_L);
      MeasureTime <= now - MeasureTime;
      wait for 100 ps;
      check_equal(real(MeasureTime/(1 ns)),real(TestDeadTimeNs_c),max_diff => (TestFrequencyTolerance_c*real(TestDeadTimeNs_c)));


    elsif run("SVPWM_test_values") then

      -- stimulus
      Uq <= X"7FF"; 
      Ud <= X"000";
      EnableIn <= '1';

      wait until Rst = '1';
      for i in 0 to 99 loop
        -- simulate angle
        vAngle := 2.0*MATH_PI*real(i)/100.0;
        -- generate sin/cos
        Sine <= cl_fix_from_real(sin(vAngle),FixFmt_c);
        Cosine <= cl_fix_from_real(cos(vAngle),FixFmt_c);
        wait until rising_edge(Clk);
        wait for 1 ms;
      end loop;

    end if;

    test_runner_cleanup(runner); -- Simulation ends here
  end process;

  -- generate clock (125 Mhz)
  Clk <= not Clk after 4 ns;

  -- deassert reset
  Rst <= '1' after 77 ns;
  
  dut: entity project.SVPWM
  generic map (
      gSysClkMHz => 125,
      gPWMFreqkHz => TestPWMFreqkHz_c,
      gDeadTimeNs => TestDeadTimeNs_c,
      gDataWidth => 12
  )
  port map (
      Clk => Clk,
      Rst => Rst,
      Uq => Uq,
      Ud => Ud,
      Sine => Sine,
      Cosine => Cosine,
      Enable => Enable,
      Fault_N => Fault_N,

      PWM_A_L => PWM_A_L,
      PWM_A_H => PWM_A_H,
      PWM_B_L => PWM_B_L,
      PWM_B_H => PWM_B_H,
      PWM_C_L => PWM_C_L,
      PWM_C_H => PWM_C_H,
      ADCTriggerLSOn => ADCTriggerLSOn,
      ADCTriggerHSOn => ADCTriggerHSOn,
      oEn => oEn,
      oFault_n => oFault_n
  );

end architecture;