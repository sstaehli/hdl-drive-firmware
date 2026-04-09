library vunit_lib;
    context vunit_lib.vunit_context;

library IEEE;
    use IEEE.STD_LOGIC_1164.all;
    use IEEE.MATH_REAL.ALL; 

library olo;
    use olo.olo_base_pkg_math.all;
    use olo.en_cl_fix_pkg.all;

library project;
    use project.project_pkg.all;

entity bitfilter_tb is
    generic (
        runner_cfg : string;
        FilterLengthSamples_g : natural := 16;
        FilterThreshold_g : natural := 0
    );
end entity;

architecture tb of bitfilter_tb is

    constant ClkCycle_c : time := 10 ns;

    constant LatencyClkCycles_c : natural := log2ceil(FilterLengthSamples_g) + 2; -- +2 for the register stage
    constant FilterLatencyLevel_c : time := (
        real(
            FilterLengthSamples_g -- time for the filter to fill up with the new bit value
            - 2*FilterThreshold_g -- due to the toggling bit, the counter increases only every 2nd clock cycle, so the latency is reduced by 2*FilterThreshold_g clock cycles
            + LatencyClkCycles_c  -- inherent pipelining latency of the design
        ) + 0.6) * ClkCycle_c; -- Worst case latency for a bit change at the input to be reflected at the output
    constant FilterLatencyEdge_c : time := (
        real(
            FilterLengthSamples_g/2 -- time for the filter to detect the edge (half of the filter length)
            + LatencyClkCycles_c -- inherent pipelining latency of the design
        ) + 0.6) * ClkCycle_c; 
    
    signal FilterLatency : time := 1 sec;

    signal Clk              : std_logic := '0';
    signal Rst              : std_logic := '1';
    signal BitInValue       : std_logic := 'W';
    signal BitIn            : std_logic := '0';
    signal BitCheckValue    : std_logic := 'U';
    signal BitOutExpected   : std_logic := 'U';
    signal BitOut           : std_logic;
    signal ReadyExpected    : std_logic := '0';
    signal Ready            : std_logic;

begin
    test_runner_watchdog(runner, 10 sec);

    main : process
    begin
        test_runner_setup(runner, runner_cfg);
            
        wait until Rst = '0';
        wait until falling_edge(Clk);
        wait for 2*(FilterLengthSamples_g + LatencyClkCycles_c) * ClkCycle_c;

        if run("bitfilter_test_level") then
            FilterLatency <= FilterLatencyLevel_c;
            wait until rising_edge(BitIn);
            wait until falling_edge(Clk);
            BitInValue <= '1';
            BitCheckValue <= '1';
            wait for (2*FilterLengthSamples_g) * ClkCycle_c;
            BitInValue <= 'W';
            wait for (2*FilterLengthSamples_g + LatencyClkCycles_c) * ClkCycle_c;
            wait for ClkCycle_c;
            wait until falling_edge(BitIn);
            wait until falling_edge(Clk);
            BitInValue <= '0';
            BitCheckValue <= '0';
            wait for (2*FilterLengthSamples_g) * ClkCycle_c;
            BitInValue <= 'W';
            wait for (2*FilterLengthSamples_g + LatencyClkCycles_c) * ClkCycle_c;
        end if;

        if run("bitfilter_test_edge") then
            FilterLatency <= FilterLatencyEdge_c;
            -- rising edge
            wait until falling_edge(BitIn);
            wait until falling_edge(Clk);
            BitInValue <= '0';
            wait for (FilterLengthSamples_g/2 - 2*(FilterThreshold_g/2)) * ClkCycle_c;
            BitInValue <= '1';
            BitCheckValue <= '1';
            wait for (FilterLengthSamples_g/2 - 2*(FilterThreshold_g/2)) * ClkCycle_c;
            BitInValue <= 'W';
            wait for (2*FilterLengthSamples_g + LatencyClkCycles_c) * ClkCycle_c;
            -- falling edge
            wait until rising_edge(BitIn);
            wait until falling_edge(Clk);
            BitInValue <= '0';
            wait for (FilterLengthSamples_g/2 - 2*(FilterThreshold_g/2)) * ClkCycle_c;
            BitInValue <= '1';
            BitCheckValue <= '1';
            wait for (FilterLengthSamples_g/2 - 2*(FilterThreshold_g/2)) * ClkCycle_c;
            BitInValue <= 'W';
            wait for (2*FilterLengthSamples_g + LatencyClkCycles_c) * ClkCycle_c;
        end if;

        test_runner_cleanup(runner); -- Simulation ends here
    end process;

    -- generate clock
    Clk <= not Clk after ClkCycle_c/2;
    
    -- deassert Rst
    Rst <= '0' after 77 ns;

    -- Bit in generation
    bitGen: process
    begin
        wait until falling_edge(Clk);
        if BitInValue = '1' and BitIn = '1' then
            BitIn <= '1';
        elsif BitInValue = '0' and BitIn = '0' then
            BitIn <= '0';
        else
            BitIn <= not BitIn;
        end if;
    end process;

    -- Bit out expectetd
    BitOutExpected <= transport BitCheckValue after FilterLatency;
    ReadyExpected <= not Rst after (FilterLengthSamples_g + LatencyClkCycles_c - 1) * ClkCycle_C;

    -- Bit out check
    check: process
    begin
        wait until rising_edge(Clk);
        if Rst = '0' then
            check_equal(Ready, ReadyExpected, "Ready check failed");
            if ReadyExpected = '1' then
                check_equal(BitOut, BitOutExpected, "BitOut check failed");
            end if;
        end if;
    end process;
    
    uut: entity project.BitFilter
        generic map (
            FilterLengthSamples_g => FilterLengthSamples_g,
            FilterThreshold_g => FilterThreshold_g
        )
        port map (
            Clk => Clk,
            Rst => Rst,
            BitIn => BitIn, -- Combine BitIn with Burst for testing
            BitOut => BitOut,
            Ready => Ready
        );

end architecture;