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

  constant TestLimitTable_c : real := 0.01;
  constant TestLimitInterpol_c : real := 0.05;

  signal Clk : std_logic := '0';
  signal Angle : std_logic_vector(cl_fix_width(cFixFmt)-1 downto 0) := (others => '0');
  signal sine_table, sine_interpol, cosine_table, cosine_interpol : std_logic_vector(cl_fix_width(cFixFmt)-1 downto 0);
  signal sRealSinRef, sRealCosRef, sRealSinTable, sRealCosTable, sRealSinInterpol, sRealCosInterpol : real;

begin

  main : process
  begin
    test_runner_setup(runner, runner_cfg);
    
    if run("modulator_test_values") then

      for i in (-(2**Angle'high)) to (2**Angle'high)-1 loop
        wait until falling_edge(Clk);
        Angle <= cl_fix_from_real(real(i)/real((2**Angle'high)-1),cFixFmt);
        wait until rising_edge(Clk);
        -- wait for pipeline to settle
        wait until rising_edge(Clk);
        wait until rising_edge(Clk);
        sRealSinRef <= sin(2.0*MATH_PI*real(i)/real((2**Angle'high)-1));
        sRealCosRef <= cos(2.0*MATH_PI*real(i)/real((2**Angle'high)-1));
        sRealSinTable <= cl_fix_to_real(sine_table,cFixFmt);
        sRealSinInterpol <= cl_fix_to_real(sine_interpol,cFixFmt);
        sRealCosTable <= cl_fix_to_real(cosine_table,cFixFmt);
        sRealCosInterpol <= cl_fix_to_real(cosine_interpol,cFixFmt);
        wait for 100 ps;
        check_equal(sRealSinTable, sRealSinRef, max_diff => TestLimitTable_c);
        check_equal(sRealSinInterpol, sRealSinRef, max_diff => TestLimitInterpol_c);
        check_equal(sRealCosTable, sRealCosRef, max_diff => TestLimitTable_c);
        check_equal(sRealCosInterpol, sRealCosRef, max_diff => TestLimitInterpol_c);
      end loop;
      
    end if;

    test_runner_cleanup(runner); -- Simulation ends here
  end process;

  -- generate clock
  Clk <= not Clk after 10 ns;


  dut1: entity project.Modulator
    generic map (
      DataWidth_g => 12,
      LUTWidth_g => 12
    )
    port map (
      Clk => Clk,
      Angle => Angle,
      Sine => sine_table,
      Cosine => cosine_table
    );

    dut2: entity project.Modulator
      generic map (
        DataWidth_g => 12,
        LUTWidth_g => 4
      )
      port map (
        Clk => Clk,
        Angle => Angle,
        Sine => sine_interpol,
        Cosine => cosine_interpol
      );

end architecture;