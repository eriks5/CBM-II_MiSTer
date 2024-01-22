-- CBM-II keyboard Based on fpga64_keyboard.vhd

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

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.std_logic_unsigned.ALL;
use IEEE.numeric_std.ALL;

entity cbm2_keyboard is
	port (
		clk         : in std_logic;
		reset       : in std_logic;
		ps2_key     : in std_logic_vector(10 downto 0);
		pai         : in unsigned(7 downto 0);
		pbi         : in unsigned(7 downto 0);
		pci			: in unsigned(5 downto 0);
		pco			: out unsigned(5 downto 0);

		tape_play   : out std_logic;
		nmi         : out std_logic
	);
end cbm2_keyboard;

-- Matrix:
--
--     | PB0 PB1 PB2 PB3 PB4 PB5 PB6 PB7 PA0 PA1 PA2 PA3 PA4 PA5 PA6 PA7
-- ----+-----------------------------------------------------------------
-- PC0 | F1  F2  F3  F4  F5  F6  F7  F8  F9  F10 CuD CuU HOM RVS GRA RUN
-- PC1 | ESC  1   2   3   4   5   7   8   9   0   =  CuL n?  nCE n*  n/
-- PC2 | TAB  Q   W   E   R   6   U   I   O   -  <-  CuR n7  n8  n9  n-
-- PC3 |      A   S   D   T   Y   J   K   L   P   ]  DEL n4  n5  n6  n+
-- PC4 | SHI  Z   X   F   G   H   M   ,   ;   [  RET C=  n1  n2  n3  ENT
-- PC5 | CTR      C   V   B   N  SPA  .   /   '  PI      n0  n.  n00
--
-- CuU/CuD/CuL/CuR: Cursor up/down/left/right
-- nX: Num pad key X
--
-- PAx, PBx: outputs; PCx: inputs
-- Other way around not possible because of diodes in the PAx/PBx lines

architecture rtl of cbm2_keyboard is
	signal pressed: std_logic := '0';

	signal key_0: std_logic := '0';
	signal key_1: std_logic := '0';
	signal key_2: std_logic := '0';
	signal key_3: std_logic := '0';
	signal key_4: std_logic := '0';
	signal key_5: std_logic := '0';
	signal key_6: std_logic := '0';
	signal key_7: std_logic := '0';
	signal key_8: std_logic := '0';
	signal key_9: std_logic := '0';
	signal key_A: std_logic := '0';
	signal key_B: std_logic := '0';
	signal key_C: std_logic := '0';
	signal key_D: std_logic := '0';
	signal key_E: std_logic := '0';
	signal key_F: std_logic := '0';
	signal key_G: std_logic := '0';
	signal key_H: std_logic := '0';
	signal key_I: std_logic := '0';
	signal key_J: std_logic := '0';
	signal key_K: std_logic := '0';
	signal key_L: std_logic := '0';
	signal key_M: std_logic := '0';
	signal key_N: std_logic := '0';
	signal key_O: std_logic := '0';
	signal key_P: std_logic := '0';
	signal key_Q: std_logic := '0';
	signal key_R: std_logic := '0';
	signal key_S: std_logic := '0';
	signal key_T: std_logic := '0';
	signal key_U: std_logic := '0';
	signal key_V: std_logic := '0';
	signal key_W: std_logic := '0';
	signal key_X: std_logic := '0';
	signal key_Y: std_logic := '0';
	signal key_Z: std_logic := '0';
	signal key_F1: std_logic := '0';
	signal key_F2: std_logic := '0';
	signal key_F3: std_logic := '0';
	signal key_F4: std_logic := '0';
	signal key_F5: std_logic := '0';
	signal key_F6: std_logic := '0';
	signal key_F7: std_logic := '0';
	signal key_F8: std_logic := '0';
	signal key_F9: std_logic := '0';
	signal key_F10: std_logic := '0';
	signal key_F11: std_logic := '0';
	signal key_arrowleft: std_logic := '0';
	signal key_capslock: std_logic := '0';
	signal key_ce: std_logic := '0';
	signal key_comma: std_logic := '0';
	signal key_commodore: std_logic := '0';
	signal key_ctrl: std_logic := '0';
	signal key_del: std_logic := '0';
	signal key_dot: std_logic := '0';
	signal key_down: std_logic := '0';
	signal key_enter: std_logic := '0';
	signal key_equal: std_logic := '0';
	signal key_esc: std_logic := '0';
	signal key_home: std_logic := '0';
	signal key_ins: std_logic := '0';
	signal key_lalt: std_logic := '0';
	signal key_lbrack: std_logic := '0';
	signal key_left: std_logic := '0';
	signal key_minus: std_logic := '0';
	signal key_graph: std_logic := '0';
	signal key_num0: std_logic := '0';
	signal key_num1: std_logic := '0';
	signal key_num2: std_logic := '0';
	signal key_num3: std_logic := '0';
	signal key_num4: std_logic := '0';
	signal key_num5: std_logic := '0';
	signal key_num6: std_logic := '0';
	signal key_num7: std_logic := '0';
	signal key_num8: std_logic := '0';
	signal key_num9: std_logic := '0';
	signal key_numdot: std_logic := '0';
	signal key_numminus: std_logic := '0';
	signal key_numplus: std_logic := '0';
	signal key_numslash: std_logic := '0';
	signal key_numstar: std_logic := '0';
	signal key_rvs: std_logic := '0';
	signal key_pi: std_logic := '0';
	signal key_quote: std_logic := '0';
	signal key_ralt: std_logic := '0';
	signal key_rbrack: std_logic := '0';
	signal key_return: std_logic := '0';
	signal key_right: std_logic := '0';
	signal key_runstop: std_logic := '0';
	signal key_semicolon: std_logic := '0';
	signal key_shiftl: std_logic := '0';
	signal key_shiftr: std_logic := '0';
	signal key_slash: std_logic := '0';
	signal key_space: std_logic := '0';
	signal key_tab: std_logic := '0';
	signal key_up: std_logic := '0';

	-- for joystick emulation on PS2
	signal old_state : std_logic;

	signal ps2_stb   : std_logic;

	signal key_shift : std_logic;
	signal key_alt   : std_logic;

begin
	key_shift <= key_shiftl or key_shiftr or key_capslock;
	key_alt <= key_lalt or key_ralt;

	tape_play <= key_F11 and (not key_alt);
	nmi <= key_F11 and key_alt;

	pressed <= ps2_key(9);
	matrix: process(clk)
	begin
		if rising_edge(clk) then
			ps2_stb <= ps2_key(10);

			pco(0) <= pci(0) and
							(pbi(0) or not key_F1) and
							(pbi(1) or not key_F2) and
							(pbi(2) or not key_F3) and
							(pbi(3) or not key_F4) and
							(pbi(4) or not key_F5) and
							(pbi(5) or not key_F6) and
							(pbi(6) or not key_F7) and
							(pbi(7) or not key_F8) and
							(pai(0) or not key_F9) and
							(pai(1) or not key_F10) and
							(pai(2) or not key_down) and
							(pai(3) or not key_up) and
							(pai(4) or not key_home) and
							(pai(5) or not key_rvs) and
							(pai(6) or not key_graph) and
							(pai(7) or not key_runstop);

			pco(1) <= pci(1) and
							(pbi(0) or not key_esc) and
							(pbi(1) or not key_1) and
							(pbi(2) or not key_2) and
							(pbi(3) or not key_3) and
							(pbi(4) or not key_4) and
							(pbi(5) or not key_5) and
							(pbi(6) or not key_7) and
							(pbi(7) or not key_8) and
							(pai(0) or not key_9) and
							(pai(1) or not key_0) and
							(pai(2) or not key_equal) and
							(pai(3) or not key_left) and
							(pai(4) or not (key_alt and key_numslash)) and
							(pai(5) or not key_ce) and
							(pai(6) or not key_numstar) and
							(pai(7) or not ((not key_alt) and key_numslash));

			pco(2) <= pci(2) and
							(pbi(0) or not key_tab) and
							(pbi(1) or not key_Q) and
							(pbi(2) or not key_W) and
							(pbi(3) or not key_E) and
							(pbi(4) or not key_R) and
							(pbi(5) or not key_6) and
							(pbi(6) or not key_U) and
							(pbi(7) or not key_I) and
							(pai(0) or not key_O) and
							(pai(1) or not key_minus) and
							(pai(2) or not key_arrowleft) and
							(pai(3) or not key_right) and
							(pai(4) or not key_num7) and
							(pai(5) or not key_num8) and
							(pai(6) or not key_num9) and
							(pai(7) or not key_numminus);

			pco(3) <= pci(3) and
							(pbi(1) or not key_A) and
							(pbi(2) or not key_S) and
							(pbi(3) or not key_D) and
							(pbi(4) or not key_T) and
							(pbi(5) or not key_Y) and
							(pbi(6) or not key_J) and
							(pbi(7) or not key_K) and
							(pai(0) or not key_L) and
							(pai(1) or not key_P) and
							(pai(2) or not key_rbrack) and
							(pai(3) or not (key_del or key_ins)) and
							(pai(4) or not key_num4) and
							(pai(5) or not key_num5) and
							(pai(6) or not key_num6) and
							(pai(7) or not key_numplus);

			pco(4) <= pci(4) and
							(pbi(0) or not (key_shift or key_ins)) and
							(pbi(1) or not key_Z) and
							(pbi(2) or not key_X) and
							(pbi(3) or not key_F) and
							(pbi(4) or not key_G) and
							(pbi(5) or not key_H) and
							(pbi(6) or not key_M) and
							(pbi(7) or not key_comma) and
							(pai(0) or not key_semicolon) and
							(pai(1) or not key_lbrack) and
							(pai(2) or not key_return) and
							(pai(3) or not key_commodore) and
							(pai(4) or not key_num1) and
							(pai(5) or not key_num2) and
							(pai(6) or not key_num3) and
							(pai(7) or not key_enter);

			pco(5) <= pci(5) and
							(pbi(0) or not key_ctrl) and
							(pbi(2) or not key_C) and
							(pbi(3) or not key_V) and
							(pbi(4) or not key_B) and
							(pbi(5) or not key_N) and
							(pbi(6) or not key_space) and
							(pbi(7) or not key_dot) and
							(pai(0) or not key_slash) and
							(pai(1) or not key_quote) and
							(pai(2) or not key_pi) and
							(pai(4) or not ((not key_alt) and key_num0)) and
							(pai(5) or not key_numdot) and
							(pai(6) or not (key_alt and key_num0));

			if ps2_key(10) /= ps2_stb then
				case ps2_key(8 downto 0) is
					when "0" & X"01" => key_F9 <= pressed;
					when "0" & X"03" => key_F5 <= pressed;
					when "0" & X"04" => key_F3 <= pressed;
					when "0" & X"05" => key_F1 <= pressed;
					when "0" & X"06" => key_F2 <= pressed;
					when "0" & X"09" => key_F10 <= pressed;
					when "0" & X"0A" => key_F8 <= pressed;
					when "0" & X"0B" => key_F6 <= pressed;
					when "0" & X"0C" => key_F4 <= pressed;
					when "0" & X"0D" => key_tab <= pressed;
					when "0" & X"0E" => key_arrowleft <= pressed;
					when "0" & X"11" => key_lalt <= pressed;
					when "0" & X"12" => key_shiftl <= pressed;
					when "0" & X"14" => key_ctrl <= pressed; -- Ctrl (left)
					when "0" & X"15" => key_Q <= pressed;
					when "0" & X"16" => key_1 <= pressed;
					when "0" & X"1A" => key_Z <= pressed;
					when "0" & X"1B" => key_S <= pressed;
					when "0" & X"1C" => key_A <= pressed;
					when "0" & X"1D" => key_W <= pressed;
					when "0" & X"1E" => key_2 <= pressed;
					when "0" & X"21" => key_C <= pressed;
					when "0" & X"22" => key_X <= pressed;
					when "0" & X"23" => key_D <= pressed;
					when "0" & X"24" => key_E <= pressed;
					when "0" & X"25" => key_4 <= pressed;
					when "0" & X"26" => key_3 <= pressed;
					when "0" & X"29" => key_space <= pressed;
					when "0" & X"2A" => key_V <= pressed;
					when "0" & X"2B" => key_F <= pressed;
					when "0" & X"2C" => key_T <= pressed;
					when "0" & X"2D" => key_R <= pressed;
					when "0" & X"2E" => key_5 <= pressed;
					when "0" & X"31" => key_N <= pressed;
					when "0" & X"32" => key_B <= pressed;
					when "0" & X"33" => key_H <= pressed;
					when "0" & X"34" => key_G <= pressed;
					when "0" & X"35" => key_Y <= pressed;
					when "0" & X"36" => key_6 <= pressed;
					when "0" & X"3A" => key_M <= pressed;
					when "0" & X"3B" => key_J <= pressed;
					when "0" & X"3C" => key_U <= pressed;
					when "0" & X"3D" => key_7 <= pressed;
					when "0" & X"3E" => key_8 <= pressed;
					when "0" & X"41" => key_comma <= pressed;
					when "0" & X"42" => key_K <= pressed;
					when "0" & X"43" => key_I <= pressed;
					when "0" & X"44" => key_O <= pressed;
					when "0" & X"45" => key_0 <= pressed;
					when "0" & X"46" => key_9 <= pressed;
					when "0" & X"49" => key_dot <= pressed;
					when "0" & X"4A" => key_slash <= pressed;
					when "0" & X"4B" => key_L <= pressed;
					when "0" & X"4C" => key_semicolon <= pressed;
					when "0" & X"4D" => key_P <= pressed;
					when "0" & X"4E" => key_minus <= pressed;
					when "0" & X"52" => key_quote <= pressed;
					when "0" & X"54" => key_lbrack <= pressed;
					when "0" & X"55" => key_equal <= pressed;
					when "0" & X"58" => key_capslock <= pressed;
					when "0" & X"59" => key_shiftr <= pressed;
					when "0" & X"5A" => key_return <= pressed;
					when "0" & X"5B" => key_rbrack <= pressed;
					when "0" & X"5D" => key_pi <= pressed;
					when "0" & X"66" => key_del <= pressed;
					when "0" & X"69" => key_num1 <= pressed;
					when "0" & X"6B" => key_num4 <= pressed;
					when "0" & X"6C" => key_num7 <= pressed;
					when "0" & X"70" => key_num0 <= pressed;
					when "0" & X"71" => key_numdot <= pressed;
					when "0" & X"72" => key_num2 <= pressed;
					when "0" & X"73" => key_num5 <= pressed;
					when "0" & X"74" => key_num6 <= pressed;
					when "0" & X"75" => key_num8 <= pressed;
					when "0" & X"76" => key_esc <= pressed;
					when "0" & X"78" => key_F11 <= pressed;
					when "0" & X"79" => key_numplus <= pressed;
					when "0" & X"7A" => key_num3 <= pressed;
					when "0" & X"7B" => key_numminus <= pressed;
					when "0" & X"7C" => key_numstar <= pressed;
					when "0" & X"7D" => key_num9 <= pressed;
					when "0" & X"83" => key_F7 <= pressed;

					when "1" & X"11" => key_ralt <= pressed;
					when "1" & X"14" => key_commodore <= pressed; -- Ctrl (right)
					when "1" & X"4A" => key_numslash <= pressed;
					when "1" & X"5A" => key_enter <= pressed;
					when "1" & X"69" => key_runstop <= pressed;
					when "1" & X"6B" => key_left <= pressed;
					when "1" & X"6C" => key_home <= pressed;
					when "1" & X"70" => key_ins <= pressed;
					when "1" & X"71" => key_ce <= pressed;  -- Del
					when "1" & X"72" => key_down <= pressed;
					when "1" & X"74" => key_right <= pressed;
					when "1" & X"75" => key_up <= pressed;
					when "1" & X"7A" => key_graph <= pressed;  -- PageDn
					when "1" & X"7D" => key_rvs <= pressed;  -- PageUp
					when others => null;
				end case;
			end if;

			if reset = '1' then
				key_0 <= '0';
				key_1 <= '0';
				key_2 <= '0';
				key_3 <= '0';
				key_4 <= '0';
				key_5 <= '0';
				key_6 <= '0';
				key_7 <= '0';
				key_8 <= '0';
				key_9 <= '0';
				key_A <= '0';
				key_B <= '0';
				key_C <= '0';
				key_D <= '0';
				key_E <= '0';
				key_F <= '0';
				key_G <= '0';
				key_H <= '0';
				key_I <= '0';
				key_J <= '0';
				key_K <= '0';
				key_L <= '0';
				key_M <= '0';
				key_N <= '0';
				key_O <= '0';
				key_P <= '0';
				key_Q <= '0';
				key_R <= '0';
				key_S <= '0';
				key_T <= '0';
				key_U <= '0';
				key_V <= '0';
				key_W <= '0';
				key_X <= '0';
				key_Y <= '0';
				key_Z <= '0';
				key_F1 <= '0';
				key_F2 <= '0';
				key_F3 <= '0';
				key_F4 <= '0';
				key_F5 <= '0';
				key_F6 <= '0';
				key_F7 <= '0';
				key_F8 <= '0';
				key_F9 <= '0';
				key_F10 <= '0';
				key_F11 <= '0';
				key_arrowleft <= '0';
				key_capslock <= '0';
				key_ce <= '0';
				key_comma <= '0';
				key_commodore <= '0';
				key_ctrl <= '0';
				key_del <= '0';
				key_dot <= '0';
				key_down <= '0';
				key_enter <= '0';
				key_esc <= '0';
				key_equal <= '0';
				key_home <= '0';
				key_ins <= '0';
				key_lalt <= '0';
				key_lbrack <= '0';
				key_left <= '0';
				key_minus <= '0';
				key_graph <= '0';
				key_num0 <= '0';
				key_num1 <= '0';
				key_num2 <= '0';
				key_num3 <= '0';
				key_num4 <= '0';
				key_num5 <= '0';
				key_num6 <= '0';
				key_num7 <= '0';
				key_num8 <= '0';
				key_num9 <= '0';
				key_numdot <= '0';
				key_numminus <= '0';
				key_numplus <= '0';
				key_numslash <= '0';
				key_numstar <= '0';
				key_rvs <= '0';
				key_pi <= '0';
				key_quote <= '0';
				key_ralt <= '0';
				key_rbrack <= '0';
				key_return <= '0';
				key_right <= '0';
				key_runstop <= '0';
				key_semicolon <= '0';
				key_shiftl <= '0';
				key_shiftr <= '0';
				key_slash <= '0';
				key_space <= '0';
				key_tab <= '0';
				key_up <= '0';
			end if;
		end if;
	end process;
end architecture;
