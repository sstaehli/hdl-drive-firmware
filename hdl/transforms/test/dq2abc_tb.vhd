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

entity dq2abc_tb is
	generic (
	runner_cfg : string;
	D_g : real := 0.2;
	Q_g : real := 0.3;
	TestLimit_g : real := 0.005
	);
end entity;

architecture tb of dq2abc_tb is

	constant FixFormat_c : FixFormat_t := (1,0,11);
	constant DiscreteValues_c : natural := 2**cl_fix_width(FixFormat_c);

	constant A120Deg_c : real := (2.0*MATH_PI)/3.0;
	constant A90Deg_c : real := (2.0*MATH_PI)/4.0;

	-- sim signals
	signal Clk : std_logic := '0';
	signal Rst : std_logic := '1';
	signal Angle : real := 0.0;

	signal Sine, Cosine, D, Q : std_logic_vector(cl_fix_width(FixFormat_c)-1 downto 0) := (others => '0');
	signal A, B, C : std_logic_vector(cl_fix_width(FixFormat_c)-1 downto 0);
	signal Strobe : std_logic := '0';
	signal Valid : std_logic;
	signal RealA, RealB, RealC : real;
	signal ExpectA, ExpectB, ExpectC : real;

begin
	test_runner_watchdog(runner, 10 sec);

	main : process
	begin
	test_runner_setup(runner, runner_cfg);

	if run("dq2abc_test") then
		
		D <= cl_fix_from_real(D_g, FixFormat_c);
		Q <= cl_fix_from_real(Q_g, FixFormat_c);

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
		-- wait for pipeline to settle
		wait until rising_edge(Clk);
		wait for 100 ps;
		-- check values
		check_equal(RealA, ExpectA, max_diff => TestLimit_g);
		check_equal(RealB, ExpectB, max_diff => TestLimit_g);
		check_equal(RealC, ExpectC, max_diff => TestLimit_g);
		check_equal(Valid, '1');
		end loop;
	end if;

	test_runner_cleanup(runner); -- Simulation ends here
	end process;

	-- generate clock
	Clk <= not Clk after 10 ns;

	-- deassert Rst
	Rst <= '0' after 77 ns;

	uut: entity project.dq2abc
	generic map (
		DataWidth_g => 12
	)
	port map (
		Clk => Clk,
		Rst => Rst,
		Sine => Sine,
		Cosine => Cosine,
		D => D,
		Q => Q,
		A => A,
		B => B,
		C => C,
		Strobe => Strobe,
		Valid => Valid
	);
	
	-- generate sin/cos
	Sine <= cl_fix_from_real(sin(Angle), FixFormat_c);
	Cosine <= cl_fix_from_real(cos(Angle), FixFormat_c);
	
	-- Evaluation
	RealA <= cl_fix_to_real(A, FixFormat_c);
	RealB <= cl_fix_to_real(B, FixFormat_c);
	RealC <= cl_fix_to_real(C, FixFormat_c);

	-- Expectation
	ExpectA <= cos(Angle) * cl_fix_to_real(D, FixFormat_c) - sin(Angle) * cl_fix_to_real(Q, FixFormat_c);
	ExpectB <= cos(Angle - A120Deg_c) * cl_fix_to_real(D, FixFormat_c) - sin(Angle - A120Deg_c) * cl_fix_to_real(Q, FixFormat_c);
	ExpectC <= cos(Angle + A120Deg_c) * cl_fix_to_real(D, FixFormat_c) - sin(Angle + A120Deg_c) * cl_fix_to_real(Q, FixFormat_c);

end architecture;