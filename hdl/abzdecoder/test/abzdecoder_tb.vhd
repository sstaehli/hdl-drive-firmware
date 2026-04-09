library vunit_lib;
    context vunit_lib.vunit_context;

library IEEE;
    use IEEE.STD_LOGIC_1164.all;
    use IEEE.MATH_REAL.ALL; 

library olo;
    use olo.en_cl_fix_pkg.all;

library project;
    use project.project_pkg.all;

entity abzdecoder_tb is
    generic (
        runner_cfg : string;
        DataWidth_g : natural := 12;
        IncrementsPerRevolution_g : natural := 1000;
        Increments_g : integer := 0
    );
end entity;

architecture tb of abzdecoder_tb is

    constant ClkCycle_c : time := 20 ns;

    signal Clk : std_logic := '0';
    signal Rst : std_logic := '1';
    signal A : std_logic := '0';
    signal B : std_logic := '0';
    signal Z : std_logic := '0';
    signal Valid : std_logic := '1';
    signal Referenced : std_logic;
    signal Position : std_logic_vector(DataWidth_g-1 downto 0);
    signal Ready : std_logic;

    constant FixFormat_c : FixFormat_t := (0, 0, DataWidth_g);

    procedure incrementEncoder(
        increments : in integer;
        signal A : out std_logic;
        signal B : out std_logic
    ) is
        variable counter : integer := increments;
    begin
        while counter > 0 loop
            wait until rising_edge(Clk);
            A <= '1';
            wait until rising_edge(Clk);
            B <= '1';                
            wait until rising_edge(Clk);
            A <= '0';
            wait until rising_edge(Clk);
            B <= '0';
            counter := counter - 1;
        end loop;
        while counter < 0 loop
            wait until rising_edge(Clk);
            B <= '1';
            wait until rising_edge(Clk);
            A <= '1';
            wait until rising_edge(Clk);
            B <= '0';
            wait until rising_edge(Clk);
            A <= '0';
            counter := counter + 1;
        end loop;
        wait until rising_edge(Clk);
    end procedure incrementEncoder;

begin
    test_runner_watchdog(runner, 10 sec);

    main : process
        variable Increments : integer;
        variable ExpectPosition : std_logic_vector(DataWidth_g-1 downto 0);
        variable ExpectReferenced : std_logic;
    begin
        test_runner_setup(runner, runner_cfg);
        
        if run("abzdecoder_test") then

            ExpectReferenced := '0';
            if Increments_g >= 0 then
                ExpectPosition := cl_fix_from_real(0.0+real(Increments_g)/real(IncrementsPerRevolution_g+1), FixFormat_c);
            else
                ExpectPosition := cl_fix_from_real(1.0+real(Increments_g)/real(IncrementsPerRevolution_g-1), FixFormat_c);
            end if;
            
            wait until Rst = '0';
            wait until rising_edge(Clk);

            incrementEncoder(Increments_g, A, B);

            check_equal(Referenced, ExpectReferenced);
            check_equal(Position, ExpectPosition);
            
        end if;

        test_runner_cleanup(runner); -- Simulation ends here
    end process;

    -- generate clock
    Clk <= not Clk after ClkCycle_c/2;

    -- deassert Rst
    Rst <= '0' after 77 ns;

    uut: entity project.ABZDecoder
        generic map (
            DataWidth_g => DataWidth_g,
            IncrementsPerRevolution_g => IncrementsPerRevolution_g
        )
        port map (
            Clk => Clk,
            Rst => Rst,
            A => A,
            B => B,
            Z => Z,
            Valid => Valid,
            Referenced => Referenced,
            Position => Position,
            Ready => Ready
        );

end architecture;