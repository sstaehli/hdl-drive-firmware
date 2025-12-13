library IEEE;
  use IEEE.STD_LOGIC_1164.ALL;
  use IEEE.NUMERIC_STD.ALL;
  use IEEE.MATH_REAL.ALL; 

library olo;
  use olo.en_cl_fix_pkg.all;
  use olo.olo_fix_pkg.all;

entity Modulator is
    generic (
           gDataWidth : natural;
           gLUTWidth : natural);
    port ( clk : in std_logic;
           reset_n : in std_logic;
           iAngle : in std_logic_vector(gDataWidth-1 downto 0); -- fix_fmt(1,0,datawidth-1) / signed
           oSin : out std_logic_vector(gDataWidth-1 downto 0); -- fix_fmt(1,0,datawidth-1) / signed
           oCos : out std_logic_vector(gDataWidth-1 downto 0)); -- fix_fmt(1,0,datawidth-1) / signed
end Modulator;

architecture Behavioral of Modulator is
    
    -- since the fix format we use is signed, the table is half the size of the value range
    -- sin(-a) = sin(360-a)
    constant cFixFmt : FixFormat_t := (1, 0, gDataWidth-1);
    constant cSinTableWidth : integer := minimum(gLUTWidth, gDataWidth-1);
    constant cSinTableSize : natural := 2**(cSinTableWidth);
    constant c90Deg : natural := (2**(gDataWidth-1)-1)/4;
    constant cRemainderFmt : FixFormat_t := (0,0,gDataWidth-1-cSinTableWidth);

    -- define discrete sSine values of one whole period (= table size)
	type tSinLut is array (0 to cSinTableSize-1) of std_logic_vector(cl_fix_width(cFixFmt)-1 downto 0);
	signal sSinTable : tSinLut;
    
    -- intermediate signals
    signal sAngle, sAngle_f : std_logic_vector(cl_fix_width(cFixFmt)-1 downto 0) := (others => '0');
    signal sSine, sCosine : std_logic_vector(cl_fix_width(cFixFmt)-1 downto 0) := (others => '0');
    signal sSineLUT, sSineLUT_f, sSineDelta, sSineDelta_f : unsigned(cl_fix_width(cFixFmt)-1 downto 0) := (others => '0');
    signal sCOsineLUT, sCOsineLUT_f, sCosineDelta, sCosineDelta_f : unsigned(cl_fix_width(cFixFmt)-1 downto 0) := (others => '0');

begin
  	
-- create array with sSine values for sin
-- cos will be determined with sin(a) --> cos(a) = sin(90-a)
table : for i in 0 to cSinTableSize-1 generate
    sSinTable(i) <= cl_fix_from_real(sin(2.0*MATH_PI*real(i)/real(cSinTableSize)),cFixFmt);
end generate table;

-- two process model (Jiri Gaisler)
p_sequential: process(clk)
begin
    if rising_edge(clk) then
        sAngle <= iAngle;
        oSin <= sSine;
        oCos <= sCosine;
        -- pipeline stage 1
        sAngle_f <= sAngle;
        sSineLUT_f <= sSineLUT;
        sCosineLUT_f <= sCosineLUT;
        sSineDelta_f <= sSineDelta;
        sCosineDelta_f <= sCosineDelta;
        -- synchroneous reset
        if reset_n = '0' then
            sAngle <= (others => '0');
            oSin <= (others => '0');
            oCos <= (others => '0');
            sAngle_f <= (others => '0');
            sSineLUT_f <= (others => '0');
            sCosineLUT_f <= (others => '0');
            sSineDelta_f <= (others => '0');
            sCosineDelta_f <= (others => '0');
        end if;       
    end if;
end process p_sequential;

p_combinatorial: process(all)
    
    -- lut table indizes, make use of the wrapping with vector size
    variable vSinFullIndex, vCosFullIndex : unsigned(gDataWidth-2 downto 0);
    alias aSinTableIndex : unsigned(cSinTableWidth-1 downto 0)
        is vSinFullIndex(gDataWidth-2 downto gDataWidth-1-cSinTableWidth);
    alias aCosTableIndex : unsigned(cSinTableWidth-1 downto 0)
        is vCosFullIndex(gDataWidth-2 downto gDataWidth-1-cSinTableWidth);
    
    -- interpolation
    alias aRemainder : std_logic_vector(gDataWidth-2-cSinTableWidth downto 0)
        is sAngle_f(gDataWidth-2-cSinTableWidth downto 0);

    variable vSinDelta, vCosDelta : unsigned(cl_fix_width(cFixFmt)-1 downto 0) := (others => '0');

begin

    -- pipeline stage 1: LUT
    -- sin index is directly coupled to the angle
    vSinFullIndex := unsigned(sAngle(vSinFullIndex'range));
    
    -- cos index is 90-angle
    vCosFullIndex := to_unsigned(c90Deg,vCosFullIndex'length) - unsigned(sAngle(vCosFullIndex'range));

    -- lookup sin/cos in table
    sSineLUT <= unsigned(sSinTable(to_integer(aSinTableIndex)));
    sCosineLUT <= unsigned(sSinTable(to_integer(aCosTableIndex+1)));

    -- delta is always 0 if table is same width as angle input
    sSineDelta <= (others => '0');
    sCosineDelta <= (others => '0');
    vSinDelta := (others => '0');
    vCosDelta := (others => '0');

    -- otherwise calc remainder for sin/cos interpolation        
    if ((gDataWidth-1) > cSinTableWidth) then
    
        -- pipeline stage 1: calculate delta
        -- take next index, subract current index and interpolate
        sSineDelta <= unsigned(sSinTable(to_integer(aSinTableIndex+1))) - unsigned(sSinTable(to_integer(aSinTableIndex)));
        -- cos table pointer rotataes opposite to sSine (90° -> - <- alpha)
        sCosineDelta <= unsigned(sSinTable(to_integer(aCosTableIndex))) - unsigned(sSinTable(to_integer(aCosTableIndex+1)));
    
        -- pipeline stage 2: multiply
        -- multiply with remainder
        vSinDelta := unsigned(cl_fix_mult(std_logic_vector(sSineDelta_f),cFixFmt,aRemainder,cRemainderFmt,cFixFmt));
        vCosDelta := unsigned(cl_fix_mult(std_logic_vector(sCosineDelta_f),cFixFmt,aRemainder,cRemainderFmt,cFixFmt));

    end if;
    
    -- pipeline stage 2: Add LUT and Interpolation
    sSine <= std_logic_vector(sSineLUT_f + vSinDelta);
    sCosine <= std_logic_vector(sCosineLUT_f + vCosDelta);

end process p_combinatorial;

end Behavioral;