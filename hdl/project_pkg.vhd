library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;

-- for assertion / bus width calcs
use ieee.math_real.log2;
use ieee.math_real.ceil;

package project_pkg is

    -----------------------------------
    ------ external input signal ------
    -----------------------------------
    
    -- external Encoder Signal
    subtype tEncoder is std_logic;

    -----------------------------------------
    ------ from Position Decoder Block ------
    -----------------------------------------

    -- Width declaration of the angle signal generated in the position block
    constant cAngleWidth : positive := 12;
    -- Angle integer value is (2 ^ (cAngleWidth -1)) -1 / If cAngleWidth is 12bit, Integer is 11bit -1 = 2047
    constant cAngleInteger  : positive := integer((2**(cAngleWidth-1))-1);
    -- Width declaration of the position counter signal
    constant cPositionWidth : natural := 32;
    -- Width declaration of the position counter signal
    constant cSpeedWidth : natural := 16;
    -- Angle signal declaration from position decoder block
    subtype tAngle is std_logic_vector(CAngleWidth-1 downto 0);
    -- Angle Invalid signal declaration. High active = 1 = invalid angle signal
    subtype tAngleInvalid is std_logic;
    -- Angle calculation value declaration from position decoder block
    subtype tAngleCalc is integer range 0 to cAngleInteger;

    -----------------------
    ------ FUNCTIONS ------
    -----------------------

    function invert (arg: std_logic) return std_logic;

end project_pkg;

package body project_pkg is

    function invert (arg: std_logic)
        return std_logic is
        variable var : std_logic := '0';
    begin
        var := arg;
        return not var;
    end invert;
    
end package body project_pkg;