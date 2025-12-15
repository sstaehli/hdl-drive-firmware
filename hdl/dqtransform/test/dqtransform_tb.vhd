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

entity dq_transform_tb is
  generic (runner_cfg : string);
end entity;

architecture tb of dq_transform_tb is

  constant FixFmt_c : FixFormat_t := (1,0,11);

  constant CurrentDC_c : real := 0.2;
  constant CurrentAC_c : real := 0.3;
  constant A120Deg_c : real := (2.0*MATH_PI)/3.0;

  -- for 90 deg (Id) Test
  constant PhaseShift_c : real := (2.0*MATH_PI)/4.0;

  -- for asymmetry and limits test 
  constant CurrentLimiDC_c : real := 0.5; -- AC + ...
  constant CurrentLimAC_c : real := 0.5; -- ... DC = 1.0 = FS
  constant c110Deg : real := (2.0*MATH_PI*110.0)/360.0;
  
  -- global rough limit 0f 0.5% for calculated values
  constant cTestLimit : real := 0.005;
  -- rough limit of 10% for asymmetryc, saturated calcs
  constant cTestLimitLimit : real := 0.1;

  -- sim signals
  signal Clk : std_logic := '0';
  signal Rst : std_logic := '1';
  signal Angle : real := 0.0;

  signal Sine, Cosine, A, B, C : std_logic_vector(cl_fix_width(FixFmt_c)-1 downto 0) := (others => '0');
  signal D, Q, DC : std_logic_vector(cl_fix_width(FixFmt_c)-1 downto 0);
  signal Strobe, Valid : std_logic;
  signal RealD, RealQ, RealDC : real;

begin

  main : process
  begin
    test_runner_setup(runner, runner_cfg);

    if run("dq_test_values_0deg") then

      wait until Rst = '0';
      for i in 0 to 99 loop
        wait until rising_edge(Clk);
        -- simulate Angle
        Angle <= 2.0*MATH_PI*real(i)/100.0;
        -- generate sin/cos
        Sine <= cl_fix_from_real(sin(Angle),FixFmt_c);
        Cosine <= cl_fix_from_real(cos(Angle),FixFmt_c);
        --simulate currents
        A <= cl_fix_from_real(CurrentDC_c+cos(Angle)*CurrentAC_c,FixFmt_c);
        B <= cl_fix_from_real(CurrentDC_c+cos(Angle-A120Deg_c)*CurrentAC_c,FixFmt_c);
        C <= cl_fix_from_real(CurrentDC_c+cos(Angle+A120Deg_c)*CurrentAC_c,FixFmt_c);
        Strobe <= '1';
        wait until rising_edge(Clk);
        wait for 100 ps;
        check_equal(Valid, '0');
        Strobe <= '0';
        --wait for pipeline to settle
        wait until rising_edge(Clk);
        wait until rising_edge(Clk);
        wait for 100 ps;
        -- convert to real for better readability
        RealD <= cl_fix_to_real(D,FixFmt_c);
        RealQ <= cl_fix_to_real(Q,FixFmt_c);
        RealDC <= cl_fix_to_real(DC,FixFmt_c);
        wait for 100 ps;
        check_equal(RealD, CurrentAC_c, max_diff => cTestLimit);
        check_equal(RealQ, 0.0, max_diff => cTestLimit);
        check_equal(RealDC, CurrentDC_c, max_diff => cTestLimit);
        check_equal(Valid, '1');
      end loop;

    elsif run("dq_test_values_90deg") then

      wait until Rst = '0';
      for i in 0 to 99 loop
        wait until rising_edge(Clk);
        -- simulate Angle
        Angle <= 2.0*MATH_PI*real(i)/100.0;
        -- generate sin/cos
        Sine <= cl_fix_from_real(sin(Angle),FixFmt_c);
        Cosine <= cl_fix_from_real(cos(Angle),FixFmt_c);
        --simulate currents
        A <= cl_fix_from_real(CurrentDC_c+cos(Angle+PhaseShift_c)*CurrentAC_c,FixFmt_c);
        B <= cl_fix_from_real(CurrentDC_c+cos(Angle+PhaseShift_c-A120Deg_c)*CurrentAC_c,FixFmt_c);
        C <= cl_fix_from_real(CurrentDC_c+cos(Angle+PhaseShift_c+A120Deg_c)*CurrentAC_c,FixFmt_c);
        Strobe <= '1';
        wait until rising_edge(Clk);
        Strobe <= '0';
        wait for 100 ps;
        check_equal(Valid, '0');
        --wait for pipeline to settle
        wait until rising_edge(Clk);
        wait until rising_edge(Clk);
        wait for 100 ps;
        -- convert to real for better readability
        RealD <= cl_fix_to_real(D,FixFmt_c);
        RealQ <= cl_fix_to_real(Q,FixFmt_c);
        RealDC <= cl_fix_to_real(DC,FixFmt_c);
        wait for 100 ps;
        check_equal(RealD, 0.0, max_diff => cTestLimit);
        check_equal(RealQ, CurrentAC_c, max_diff => cTestLimit);
        check_equal(RealDC, CurrentDC_c, max_diff => cTestLimit);
        check_equal(Valid, '1');
      end loop;

    elsif run("dq_test_values_asym_and_limit") then

      wait until Rst = '0';
      for i in 0 to 99 loop
        wait until rising_edge(Clk);
        -- simulate Angle
        Angle <= 2.0*MATH_PI*real(i)/100.0;
        -- generate sin/cos
        Sine <= cl_fix_from_real(sin(Angle),FixFmt_c);
        Cosine <= cl_fix_from_real(cos(Angle),FixFmt_c);
        --simulate currents
        A <= cl_fix_from_real(CurrentLimiDC_c+cos(Angle)*CurrentLimAC_c,FixFmt_c);
        B <= cl_fix_from_real(CurrentLimiDC_c+cos(Angle-c110Deg)*CurrentLimAC_c,FixFmt_c);
        C <= cl_fix_from_real(CurrentLimiDC_c+cos(Angle+c110Deg)*CurrentLimAC_c,FixFmt_c);
        Strobe <= '1';
        wait until rising_edge(Clk);
        Strobe <= '0';
        wait for 100 ps;
        check_equal(Valid, '0');
        --wait for pipeline to settle
        wait until rising_edge(Clk);
        wait until rising_edge(Clk);
        wait for 100 ps;
        -- convert to real for better readability
        RealD <= cl_fix_to_real(D,FixFmt_c);
        RealQ <= cl_fix_to_real(Q,FixFmt_c);
        RealDC <= cl_fix_to_real(DC,FixFmt_c);
        wait for 100 ps;
        check_equal(RealD, CurrentLimAC_c, max_diff => cTestLimitLimit);
        check_equal(RealQ, 0.0, max_diff => cTestLimitLimit);
        check_equal(RealDC, CurrentLimiDC_c, max_diff => cTestLimitLimit);
        check_equal(Valid, '1');
      end loop;

    end if;

    test_runner_cleanup(runner); -- Simulation ends here
  end process;

  -- generate clock
  Clk <= not Clk after 10 ns;

  -- deassert Rst
  Rst <= '0' after 77 ns;

  dut: entity project.dqTransform
    generic map (
      DataWidth_g => 12
    )
    port map (
      Clk => Clk,
      Rst => Rst,
      Sine => Sine,
      Cosine => Cosine,
      A => A,
      B => B,
      C => C,
      D => D,
      Q => Q,
      DC => DC,
      Strobe => Strobe,
      Valid => Valid
    );

end architecture;