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

  constant cFixFmt : FixFormat_t := (1,0,11);
  constant cFixFmtADC : FixFormat_t := (1,0,12);

  constant cCurrentDC : real := 0.2;
  constant cCurrentAC : real := 0.3;
  constant c120Deg : real := (2.0*MATH_PI)/3.0;

  -- for 90 deg (Id) Test
  constant cPhaseShift : real := (2.0*MATH_PI)/4.0;

  -- for asymmetry and limits test 
  constant cCurrentDCLim : real := 0.5; -- AC + ...
  constant cCurrentACLim : real := 0.5; -- ... DC = 1.0 = FS
  constant c110Deg : real := (2.0*MATH_PI*110.0)/360.0;
  
  -- global rough limit 0f 0.5% for calculated values
  constant cTestLimit : real := 0.005;
  -- rough limit of 10% for asymmetryc, saturated calcs
  constant cTestLimitLimit : real := 0.1;

  -- sim signals
  signal clk : std_logic := '0';
  signal reset_n : std_logic := '0';
  signal angle : real := 0.0;

  signal iSin, iCos, iA, iB, iC : std_logic_vector(cl_fix_width(cFixFmt)-1 downto 0) := (others => '0');
  signal oD, oQ, oDC : std_logic_vector(cl_fix_width(cFixFmt)-1 downto 0);
  signal iStrobe, oReady : std_logic;
  signal sRealD, sRealQ, sRealDC : real;

begin

  main : process
  begin
    test_runner_setup(runner, runner_cfg);

    if run("dq_test_values_0deg") then

      wait until reset_n = '1';
      for i in 0 to 99 loop
        wait until rising_edge(clk);
        -- simulate angle
        angle <= 2.0*MATH_PI*real(i)/100.0;
        -- generate sin/cos
        iSin <= cl_fix_from_real(sin(angle),cFixFmt);
        iCos <= cl_fix_from_real(cos(angle),cFixFmt);
        --simulate currents
        iA <= cl_fix_from_real(cCurrentDC+cos(angle)*cCurrentAC,cFixFmt);
        iB <= cl_fix_from_real(cCurrentDC+cos(angle-c120Deg)*cCurrentAC,cFixFmt);
        iC <= cl_fix_from_real(cCurrentDC+cos(angle+c120Deg)*cCurrentAC,cFixFmt);
        iStrobe <= '1';
        wait until rising_edge(clk);
        wait for 100 ps;
        check_equal(oReady, '0');
        iStrobe <= '0';
        --wait for pipeline to settle
        wait until rising_edge(clk);
        wait until rising_edge(clk);
        wait until rising_edge(clk);
        wait for 100 ps;
        -- convert to real for better readability
        sRealD <= cl_fix_to_real(oD,cFixFmt);
        sRealQ <= cl_fix_to_real(oQ,cFixFmt);
        sRealDC <= cl_fix_to_real(oDC,cFixFmt);
        wait for 100 ps;
        check_equal(sRealD, cCurrentAC, max_diff => cTestLimit);
        check_equal(sRealQ, 0.0, max_diff => cTestLimit);
        check_equal(sRealDC, cCurrentDC, max_diff => cTestLimit);
        check_equal(oReady, '1');
      end loop;

    elsif run("dq_test_values_90deg") then

      wait until reset_n = '1';
      for i in 0 to 99 loop
        wait until rising_edge(clk);
        -- simulate angle
        angle <= 2.0*MATH_PI*real(i)/100.0;
        -- generate sin/cos
        iSin <= cl_fix_from_real(sin(angle),cFixFmt);
        iCos <= cl_fix_from_real(cos(angle),cFixFmt);
        --simulate currents
        iA <= cl_fix_from_real(cCurrentDC+cos(angle+cPhaseShift)*cCurrentAC,cFixFmt);
        iB <= cl_fix_from_real(cCurrentDC+cos(angle+cPhaseShift-c120Deg)*cCurrentAC,cFixFmt);
        iC <= cl_fix_from_real(cCurrentDC+cos(angle+cPhaseShift+c120Deg)*cCurrentAC,cFixFmt);
        iStrobe <= '1';
        wait until rising_edge(clk);
        iStrobe <= '0';
        wait for 100 ps;
        check_equal(oReady, '0');
        --wait for pipeline to settle
        wait until rising_edge(clk);
        wait until rising_edge(clk);
        wait until rising_edge(clk);
        wait for 100 ps;
        -- convert to real for better readability
        sRealD <= cl_fix_to_real(oD,cFixFmt);
        sRealQ <= cl_fix_to_real(oQ,cFixFmt);
        sRealDC <= cl_fix_to_real(oDC,cFixFmt);
        wait for 100 ps;
        check_equal(sRealD, 0.0, max_diff => cTestLimit);
        check_equal(sRealQ, cCurrentAC, max_diff => cTestLimit);
        check_equal(sRealDC, cCurrentDC, max_diff => cTestLimit);
        --check_equal(oReady, '1');
      end loop;

    elsif run("dq_test_values_asym_and_limit") then

      wait until reset_n = '1';
      for i in 0 to 99 loop
        wait until rising_edge(clk);
        -- simulate angle
        angle <= 2.0*MATH_PI*real(i)/100.0;
        -- generate sin/cos
        iSin <= cl_fix_from_real(sin(angle),cFixFmt);
        iCos <= cl_fix_from_real(cos(angle),cFixFmt);
        --simulate currents
        iA <= cl_fix_from_real(cCurrentDCLim+cos(angle)*cCurrentACLim,cFixFmt);
        iB <= cl_fix_from_real(cCurrentDCLim+cos(angle-c110Deg)*cCurrentACLim,cFixFmt);
        iC <= cl_fix_from_real(cCurrentDCLim+cos(angle+c110Deg)*cCurrentACLim,cFixFmt);
        iStrobe <= '1';
        wait until rising_edge(clk);
        iStrobe <= '0';
        wait for 100 ps;
        check_equal(oReady, '0');
        --wait for pipeline to settle
        wait until rising_edge(clk);
        wait until rising_edge(clk);
        wait until rising_edge(clk);
        wait for 100 ps;
        -- convert to real for better readability
        sRealD <= cl_fix_to_real(oD,cFixFmt);
        sRealQ <= cl_fix_to_real(oQ,cFixFmt);
        sRealDC <= cl_fix_to_real(oDC,cFixFmt);
        wait for 100 ps;
        check_equal(sRealD, cCurrentACLim, max_diff => cTestLimitLimit);
        check_equal(sRealQ, 0.0, max_diff => cTestLimitLimit);
        check_equal(sRealDC, cCurrentDCLim, max_diff => cTestLimitLimit);
        --check_equal(oReady, '1');
      end loop;

    elsif run("dq_test_stall") then

      wait until reset_n = '1';
      for i in 0 to 99 loop
        wait until rising_edge(clk);
        -- simulate angle
        angle <= 2.0*MATH_PI*real(i)/100.0;
        -- generate sin/cos
        iSin <= cl_fix_from_real(sin(angle),cFixFmt);
        iCos <= cl_fix_from_real(cos(angle),cFixFmt);
        --simulate currents
        iA <= cl_fix_sub(cl_fix_from_real(0.49,cFixFmtADC),cFixFmtADC,cl_fix_from_real(0.50,cFixFmtADC),cFixFmtADC,cFixFmt);
        iB <= cl_fix_sub(cl_fix_from_real(0.50,cFixFmtADC),cFixFmtADC,cl_fix_from_real(0.51,cFixFmtADC),cFixFmtADC,cFixFmt);
        iC <= cl_fix_sub(cl_fix_from_real(0.46,cFixFmtADC),cFixFmtADC,cl_fix_from_real(0.48,cFixFmtADC),cFixFmtADC,cFixFmt);
        iStrobe <= '1';
        wait until rising_edge(clk);
        iStrobe <= '0';
        wait for 100 ps;
        check_equal(oReady, '0');
        --wait for pipeline to settle
        wait until rising_edge(clk);
        wait until rising_edge(clk);
        wait until rising_edge(clk);
        wait for 100 ps;
      end loop;
      
    end if;

    test_runner_cleanup(runner); -- Simulation ends here
  end process;

  -- generate clock
  clk <= not clk after 10 ns;

  -- deassert reset
  reset_n <= '1' after 77 ns;

  dut: entity project.dqTransform
    generic map (
      gDataWidth => 12
    )
    port map (
      clk => clk,
      reset_n => reset_n,
      iSin => iSin,
      iCos => iCos,
      iA => iA,
      iB => iB,
      iC => iC,
      oD => oD,
      oQ => oQ,
      oDC => oDC,
      iStrobe => iStrobe,
      oReady => oReady
    );

end architecture;