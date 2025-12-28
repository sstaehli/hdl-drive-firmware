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
    generic (
        runner_cfg : string;
        DataWidth_g : natural := 12;
        LutWidth_g : natural := 4;
        TestLimit_g : real := 0.02
    );
end entity;

architecture tb of modulator_tb is

    constant FixFormat_c : FixFormat_t := (1, 0, DataWidth_g-1);
    constant DiscreteValues_c : natural := 2**cl_fix_width(FixFormat_c);

    signal Clk : std_logic := '0';
    signal Angle : std_logic_vector(cl_fix_width(FixFormat_c)-1 downto 0) := (others => '0');
    signal Sine, Cosine : std_logic_vector(cl_fix_width(FixFormat_c)-1 downto 0);
    signal RealSine, RealCosine : real;
    signal ExpectSine, ExpectCosine : real;

begin
    test_runner_watchdog(runner, 10 sec);

    assert DataWidth_g > LutWidth_g
        report "Data width (" & integer'image(DataWidth_g) & ") must be greater than LUT width (" & integer'image(LutWidth_g) & ")"
        severity error;

    main : process
    begin
        test_runner_setup(runner, runner_cfg);
        
        if run("modulator_test") then

            for i in -DiscreteValues_c/2 to DiscreteValues_c/2-1 loop
                -- inject new angle
                Angle <= cl_fix_from_real(2.0*real(i)/real(DiscreteValues_c),FixFormat_c);
                wait until rising_edge(Clk);
                wait for 100 ps;
                -- wait for pipeline to settle        
                wait until rising_edge(Clk);
                wait until rising_edge(Clk);
                wait for 100 ps;
                -- check values
                check_equal(RealSine, ExpectSine, max_diff => TestLimit_g);
                check_equal(RealCosine, ExpectCosine, max_diff => TestLimit_g);
            end loop;
            
        end if;

        test_runner_cleanup(runner); -- Simulation ends here
    end process;

    -- generate clock
    Clk <= not Clk after 10 ns;

    dut1: entity project.Modulator
        generic map (
            DataWidth_g => DataWidth_g,
            LutWidth_g => LutWidth_g
        )
        port map (
            Clk => Clk,
            Angle => Angle,
            Sine => Sine,
            Cosine => Cosine
        );

        RealSine <= cl_fix_to_real(Sine, FixFormat_c);
        RealCosine <= cl_fix_to_real(Cosine, FixFormat_c);
        
        ExpectSine <= sin(cl_fix_to_real(Angle, FixFormat_c) * 2.0*MATH_PI);
        ExpectCosine <= cos(cl_fix_to_real(Angle, FixFormat_c) * 2.0*MATH_PI);

end architecture;