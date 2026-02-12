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

entity abzdecoder_tb is
    generic (
        runner_cfg : string;
        DataWidth_g : natural := 12;
        IncrementsPerRevolution_g : natural := 1000;
        FilterLengthClkCycles_g : natural := 16
    );
end entity;

architecture tb of abzdecoder_tb is

    signal Clk : std_logic := '0';
    signal Rst : std_logic := '0';
    signal A : std_logic := '0';
    signal B : std_logic := '0';
    signal Z : std_logic := '0';
    signal Referenced : std_logic;
    signal Position : std_logic_vector(DataWidth_g-1 downto 0);

begin
    test_runner_watchdog(runner, 10 sec);

    main : process
    begin
        test_runner_setup(runner, runner_cfg);
        
        if run("abzdecoder_test") then

            for i in 0 to 2500 loop
                -- inject new angle
                A <= '1';
                wait for 100 ns;
                B <= '1';
                wait for 100 ns;
                A <= '0';
                wait for 100 ns;
                B <= '0';
                wait until rising_edge(Clk);
                wait for 100 ps;
                -- wait for pipeline to settle        
                wait until rising_edge(Clk);
                wait until rising_edge(Clk);
                wait for 100 ps;
                -- check values
                -- TODO
            end loop;
            
        end if;

        test_runner_cleanup(runner); -- Simulation ends here
    end process;

    -- generate clock
    Clk <= not Clk after 10 ns;

    -- deassert Rst
    Rst <= '0' after 77 ns;

    dut1: entity project.ABZDecoder
        generic map (
            DataWidth_g => DataWidth_g,
            IncrementsPerRevolution_g => IncrementsPerRevolution_g,
            FilterLengthClkCycles_g => FilterLengthClkCycles_g
        )
        port map (
            Clk => Clk,
            Rst => Rst,
            A => A,
            B => B,
            Z => Z,
            Referenced => Referenced,
            Position => Position
        );

end architecture;