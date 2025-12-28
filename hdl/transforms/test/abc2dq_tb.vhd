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

    entity abc2dq_tb is
    generic (
        runner_cfg   : string;
        AC_D_g       : real := 0.2;
        AC_Q_g       : real := 0.3; 
        DC_g         : real := 0.4;
        TestLimit_g  : real := 0.005
    );
    end entity;

architecture tb of abc2dq_tb is

    constant FixFormat_c : FixFormat_t := (1,0,11);
    constant DiscreteValues_c : natural := 2**cl_fix_width(FixFormat_c);

    constant A120Deg_c : real := (2.0*MATH_PI)/3.0;
    constant A90Deg_c : real := (2.0*MATH_PI)/4.0;


    -- for asymmetry and limits test 
    constant Angle110Deg_c : real := (2.0*MATH_PI*110.0)/360.0;

    -- sim signals
    signal Clk : std_logic := '0';
    signal Rst : std_logic := '1';
    signal Angle : real := 0.0;

    signal Sine, Cosine, A, B, C : std_logic_vector(cl_fix_width(FixFormat_c)-1 downto 0) := (others => '0');
    signal D, Q, DC : std_logic_vector(cl_fix_width(FixFormat_c)-1 downto 0);
    signal Strobe : std_logic := '0';
    signal Valid : std_logic;
    signal RealD, RealQ, RealDC : real;

begin
    test_runner_watchdog(runner, 10 sec);

    main : process
    begin
        test_runner_setup(runner, runner_cfg);

        if run("abc2dq_test") then
            
            wait until Rst = '0';

            for i in 0 to DiscreteValues_c-1 loop
                -- inject new angle
                Angle <= 2.0*MATH_PI*real(i)/real(DiscreteValues_c);
                -- inject strobe
                Strobe <= '1';
                wait until rising_edge(Clk);
                wait for 100 ps;
                Strobe <= '0';
                check_equal(Valid, '0');
                --wait for pipeline to settle
                wait until rising_edge(Clk);
                wait until rising_edge(Clk);
                wait for 100 ps;
                -- check values
                check_equal(RealD, AC_D_g, max_diff => TestLimit_g);
                check_equal(RealQ, AC_Q_g, max_diff => TestLimit_g);
                check_equal(RealDC, DC_g, max_diff => TestLimit_g);
                check_equal(Valid, '1');
            end loop;

        end if;

        test_runner_cleanup(runner); -- Simulation ends here
    end process;

    -- generate clock
    Clk <= not Clk after 10 ns;

    -- deassert Rst
    Rst <= '0' after 77 ns;

    uut: entity project.abc2dq
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
    
    -- generate sin/cos
    Sine <= cl_fix_from_real(sin(Angle), FixFormat_c);
    Cosine <= cl_fix_from_real(cos(Angle), FixFormat_c);

    --simulate currents
    A <= cl_fix_from_real(
        DC_g
        + cos(Angle) * AC_D_g
        - sin(Angle) * AC_Q_g,
        FixFormat_c
    );
    B <= cl_fix_from_real(
        DC_g
        + cos(Angle - A120Deg_c) * AC_D_g
        - sin(Angle - A120Deg_c) * AC_Q_g
        , FixFormat_c
    );
    C <= cl_fix_from_real(
        DC_g
        + cos(Angle + A120Deg_c) * AC_D_g
        - sin(Angle + A120Deg_c) * AC_Q_g,
        FixFormat_c
    );
    
    -- Evaluation
    RealD <= cl_fix_to_real(D, FixFormat_c);
    RealQ <= cl_fix_to_real(Q, FixFormat_c);
    RealDC <= cl_fix_to_real(DC, FixFormat_c);

end architecture;