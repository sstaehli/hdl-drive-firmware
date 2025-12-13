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

entity modulator_tb is
  generic (runner_cfg : string);
end entity;

architecture tb of modulator_tb is

  constant cFixFmt : FixFormat_t := (1,0,11);

  constant cTestLimitTable : real := 0.01;
  constant cTestLimitInterpol : real := 0.05;

  signal clk : std_logic := '0';
  signal reset_n : std_logic := '0';
  signal angle : std_logic_vector(cl_fix_width(cFixFmt)-1 downto 0) := (others => '0');
  signal sine_table, sine_interpol, cosine_table, cosine_interpol : std_logic_vector(cl_fix_width(cFixFmt)-1 downto 0);
  signal sRealSinRef, sRealCosRef, sRealSinTable, sRealCosTable, sRealSinInterpol, sRealCosInterpol : real;

begin

  main : process
  begin
    test_runner_setup(runner, runner_cfg);
    
    -- test comparator
    if run("modulator_test_out_of_reset") then

      angle <= cl_fix_from_real(0.0,cFixFmt);
      wait until rising_edge(clk);
      wait for 100 ps;
      check_equal(sine_table, cl_fix_from_real(0.0,cFixFmt), result("zero"));
      check_equal(cosine_table, cl_fix_from_real(0.0,cFixFmt), result("zero"));
      check_equal(sine_interpol, cl_fix_from_real(0.0,cFixFmt), result("zero"));
      check_equal(cosine_interpol, cl_fix_from_real(0.0,cFixFmt), result("zero"));
      wait until reset_n = '1';
      wait until rising_edge(clk);
      wait until rising_edge(clk);
      wait for 100 ps;
      check_equal(sine_table, cl_fix_from_real(0.0,cFixFmt), result("still zero"));
      check_equal(cosine_table, cl_fix_from_real(1.0,cFixFmt), result("one"));
      check_equal(sine_interpol, cl_fix_from_real(0.0,cFixFmt), result("still zero"));
      check_equal(cosine_interpol, cl_fix_from_real(1.0,cFixFmt), result("one"));

    elsif run("modulator_test_values") then

      wait until reset_n = '1';
      for i in (-(2**angle'high)) to (2**angle'high)-1 loop
        wait until falling_edge(clk);
        angle <= cl_fix_from_real(real(i)/real((2**angle'high)-1),cFixFmt);
        wait until rising_edge(clk);
        -- wait for pipeline to settle
        wait until rising_edge(clk);
        wait until rising_edge(clk);
        sRealSinRef <= sin(2.0*MATH_PI*real(i)/real((2**angle'high)-1));
        sRealCosRef <= cos(2.0*MATH_PI*real(i)/real((2**angle'high)-1));
        sRealSinTable <= cl_fix_to_real(sine_table,cFixFmt);
        sRealSinInterpol <= cl_fix_to_real(sine_interpol,cFixFmt);
        sRealCosTable <= cl_fix_to_real(cosine_table,cFixFmt);
        sRealCosInterpol <= cl_fix_to_real(cosine_interpol,cFixFmt);
        wait for 100 ps;
        check_equal(sRealSinTable, sRealSinRef, max_diff => cTestLimitTable);
        check_equal(sRealSinInterpol, sRealSinRef, max_diff => cTestLimitInterpol);
        check_equal(sRealCosTable, sRealCosRef, max_diff => cTestLimitTable);
        check_equal(sRealCosInterpol, sRealCosRef, max_diff => cTestLimitInterpol);
      end loop;
      
    end if;

    test_runner_cleanup(runner); -- Simulation ends here
  end process;

  -- generate clock
  clk <= not clk after 10 ns;

  -- deassert reset
  reset_n <= '1' after 77 ns;

  dut1: entity project.Modulator
    generic map (
      gDataWidth => 12,
      gLUTWidth => 12
    )
    port map (
      clk => clk,
      reset_n => reset_n,
      iAngle => angle,
      oSin => sine_table,
      oCos => cosine_table
    );

    dut2: entity project.Modulator
      generic map (
        gDataWidth => 12,
        gLUTWidth => 4
      )
      port map (
        clk => clk,
        reset_n => reset_n,
        iAngle => angle,
        oSin => sine_interpol,
        oCos => cosine_interpol
      );

end architecture;