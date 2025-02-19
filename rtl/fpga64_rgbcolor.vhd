-- -----------------------------------------------------------------------
--
--                                 FPGA 64
--
--     A fully functional commodore 64 implementation in a single FPGA
--
-- -----------------------------------------------------------------------
-- Copyright 2005-2008 by Peter Wendrich (pwsoft@syntiac.com)
-- http://www.syntiac.com/fpga64.html
-- -----------------------------------------------------------------------
--
-- C64 palette index to 24 bit RGB color
-- 2025: Extended with early VIC-II palette by Erik Scheffers
-- 
-- -----------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.numeric_std.all;

-- -----------------------------------------------------------------------

entity fpga64_rgbcolor is
	port (
		index: in unsigned(3 downto 0);
		newVic: in std_logic;
		r: out unsigned(7 downto 0);
		g: out unsigned(7 downto 0);
		b: out unsigned(7 downto 0)
	);
end fpga64_rgbcolor;

-- -----------------------------------------------------------------------

architecture Behavioral of fpga64_rgbcolor is
begin
	process(index)
	begin
		if newVic = '0' then
			case index is
			when X"0" => r <= X"00"; g <= X"00"; b <= X"00";
			when X"1" => r <= X"FF"; g <= X"FF"; b <= X"FF";
			when X"2" => r <= X"6D"; g <= X"23"; b <= X"27";
			when X"3" => r <= X"9F"; g <= X"FD"; b <= X"F8";
			when X"4" => r <= X"BA"; g <= X"61"; b <= X"C4";
			when X"5" => r <= X"56"; g <= X"AC"; b <= X"4D";
			when X"6" => r <= X"2D"; g <= X"2C"; b <= X"A0";
			when X"7" => r <= X"ED"; g <= X"F0"; b <= X"71";
			when X"8" => r <= X"BA"; g <= X"77"; b <= X"4D";
			when X"9" => r <= X"55"; g <= X"37"; b <= X"00";
			when X"A" => r <= X"C3"; g <= X"6C"; b <= X"71";
			when X"B" => r <= X"37"; g <= X"37"; b <= X"37";
			when X"C" => r <= X"86"; g <= X"86"; b <= X"86";
			when X"D" => r <= X"AA"; g <= X"FF"; b <= X"A0";
			when X"E" => r <= X"7A"; g <= X"78"; b <= X"F8";
			when X"F" => r <= X"E0"; g <= X"E0"; b <= X"E0";
			end case;
		else
			case index is
			when X"0" => r <= X"00"; g <= X"00"; b <= X"00";
			when X"1" => r <= X"FF"; g <= X"FF"; b <= X"FF";
			when X"2" => r <= X"81"; g <= X"33"; b <= X"38";
			when X"3" => r <= X"75"; g <= X"ce"; b <= X"c8";
			when X"4" => r <= X"8e"; g <= X"3c"; b <= X"97";
			when X"5" => r <= X"56"; g <= X"ac"; b <= X"4d";
			when X"6" => r <= X"2e"; g <= X"2c"; b <= X"9b";
			when X"7" => r <= X"ed"; g <= X"f1"; b <= X"71";
			when X"8" => r <= X"8e"; g <= X"50"; b <= X"29";
			when X"9" => r <= X"55"; g <= X"38"; b <= X"00";
			when X"A" => r <= X"c4"; g <= X"6c"; b <= X"71";
			when X"B" => r <= X"4a"; g <= X"4a"; b <= X"4a";
			when X"C" => r <= X"7b"; g <= X"7b"; b <= X"7b";
			when X"D" => r <= X"a9"; g <= X"ff"; b <= X"9f";
			when X"E" => r <= X"70"; g <= X"6d"; b <= X"eb";
			when X"F" => r <= X"b2"; g <= X"b2"; b <= X"b2";
			end case;
		end if;
	end process;
end Behavioral;
