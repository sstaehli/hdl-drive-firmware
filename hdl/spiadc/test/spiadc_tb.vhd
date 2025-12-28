library vunit_lib;
context vunit_lib.vunit_context;

library IEEE;
    use IEEE.STD_LOGIC_1164.all;
    use IEEE.NUMERIC_STD.ALL;
    use IEEE.MATH_REAL.ALL;

library project;
    use project.project_pkg.all;

entity spiadc_tb is
    generic (
        runner_cfg      : string;
        DataWidth_g     : natural := 12;
        TestDataU_g     : natural := 16#AFF#;
        TestDataV_g     : natural := 16#AFE#;
        TestDataW_g     : natural := 16#AFD#;
        TestDataVBus_g  : natural := 16#AFC#
    );
end entity;

architecture tb of spiadc_tb is

    constant TestDataUSlv_c     : std_logic_vector(0 to DataWidth_g-1) := std_logic_vector(to_unsigned(TestDataU_g, DataWidth_g));
    constant TestDataVSlv_c     : std_logic_vector(0 to DataWidth_g-1) := std_logic_vector(to_unsigned(TestDataV_g, DataWidth_g));
    constant TestDataWSlv_c     : std_logic_vector(0 to DataWidth_g-1) := std_logic_vector(to_unsigned(TestDataW_g, DataWidth_g));
    constant TestDataVBusSlv_c  : std_logic_vector(0 to DataWidth_g-1) := std_logic_vector(to_unsigned(TestDataVBus_g, DataWidth_g));

    constant ExpectAvg_c    : integer := (TestDataU_g + TestDataV_g + TestDataW_g) / 3;
    constant ExpectU_c      : std_logic_vector(DataWidth_g-1 downto 0) := std_logic_vector(to_signed(TestDataU_g - ExpectAvg_c, DataWidth_g));
    constant ExpectV_c      : std_logic_vector(DataWidth_g-1 downto 0) := std_logic_vector(to_signed(TestDataV_g - ExpectAvg_c, DataWidth_g));
    constant ExpectW_c      : std_logic_vector(DataWidth_g-1 downto 0) := std_logic_vector(to_signed(TestDataW_g - ExpectAvg_c, DataWidth_g));
    constant ExpectVBus     : std_logic_vector(DataWidth_g-1 downto 0) := std_logic_vector(to_unsigned(TestDataVBus_g, DataWidth_g));

    -- sim signals
    signal Clk : std_logic := '0';
    signal Rst : std_logic := '1';
    signal Trigger : std_logic := '0';
    signal CS_N : std_logic;
    signal SCLK : std_logic;
    signal MISO : std_logic_vector(3 downto 0) := (others => '0');
    signal Valid : std_logic;
    signal U : std_logic_vector(DataWidth_g-1 downto 0);
    signal V : std_logic_vector(DataWidth_g-1 downto 0);
    signal W : std_logic_vector(DataWidth_g-1 downto 0);
    signal VBus : std_logic_vector(DataWidth_g-1 downto 0);

begin
    test_runner_watchdog(runner, 10 sec);

    main : process
    begin
        test_runner_setup(runner, runner_cfg);

        if run("spiadc_test") then
            
            wait until Rst = '0';
            check_equal(CS_N, '0', "CS_N should be low in IDLE state");

            wait until rising_edge(Clk);
            Trigger <= '1';
            wait for 100 ps;
            wait until rising_edge(Clk);
            Trigger <= '0';
            wait for 100 ps;
            wait until rising_edge(Clk);
            check_equal(CS_N, '1', "CS_N should go high after trigger");
            wait for 1200 ns; -- wait for conversion time
            check_equal(CS_N, '1', "CS_N should stay high during conversion");
            wait until falling_edge(Clk);
            check_equal(CS_N, '0', "CS_N should go low to start reading data");
            check_equal(SCLK, '0', "SCLK should start low");

            for i in 0 to DataWidth_g-1 loop
                MISO <= TestDataVBusSlv_c(i) & TestDataWSlv_c(i) & TestDataVSlv_c(i) & TestDataUSlv_c(i);
                wait for 100 ps;
                wait until rising_edge(Clk);
                check_equal(SCLK, '0');
                wait until rising_edge(Clk);
                check_equal(SCLK, '1');
                wait until falling_edge(Clk);
            end loop;
            
            wait until rising_edge(Clk);
            wait until rising_edge(Clk);
            wait for 100 ps;

            check_equal(Valid, '1');
            check_equal(U, ExpectU_c);
            check_equal(V, ExpectV_c);
            check_equal(W, ExpectW_c);
            check_equal(VBus, ExpectVBus);

            wait until rising_edge(Clk);
            wait for 100 ps;

            check_equal(Valid, '0');

        end if; 

        test_runner_cleanup(runner); -- Simulation ends here
    end process;

    -- generate clock
    Clk <= not Clk after 5 ns;

    -- deassert Rst
    Rst <= '0' after 77 ns;

    uut: entity project.spiadc
    generic map (
        DataWidth_g => DataWidth_g,
        ClockFrequenceyMHz_g => 100
    )
    port map (
        Clk => Clk,
        Rst => Rst,
        Trigger => Trigger,
        CS_N => CS_N,
        SCLK => SCLK,
        MISO => MISO,
        Valid => Valid,
        U => U,
        V => V,
        W => W,
        VBus => VBus
    );

end architecture;