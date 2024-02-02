-- -----------------------------------------------------------------------
--
-- 6509 wrapper for T65
--
-- -----------------------------------------------------------------------

library IEEE;
use ieee.std_logic_1164.ALL;
use ieee.numeric_std.ALL;
use work.T65_Pack.T_t65_dbg;

-- -----------------------------------------------------------------------

entity cpu_6509 is
	port (
		widePO  : in  std_logic; -- 0= 4 bit PO, 1= 8 bit PO

		clk     : in  std_logic;
		enable  : in  std_logic;
		reset   : in  std_logic;
		nmi_n   : in  std_logic;
		nmi_ack : out std_logic;
		irq_n   : in  std_logic;
		rdy     : in  std_logic;

		din     : in  unsigned(7 downto 0);
		dout    : out unsigned(7 downto 0);
		addr    : out unsigned(15 downto 0);
		we      : out std_logic;

		pout    : out unsigned(7 downto 0)
	);
end cpu_6509;

-- -----------------------------------------------------------------------

architecture rtl of cpu_6509 is
	signal localA : std_logic_vector(23 downto 0);
	signal localDi : std_logic_vector(7 downto 0);
	signal localDo : std_logic_vector(7 downto 0);
	signal localWe : std_logic;
	signal sync : std_logic;

	signal localAccess : std_logic;
	signal exeReg : std_logic_vector(7 downto 0);
	signal indReg : std_logic_vector(7 downto 0);

	signal indCount : unsigned(2 downto 0);
	signal lastA0 : std_logic;
begin

	cpu: work.T65
	port map(
		Mode    => "00",
		Res_n   => not reset,
		Enable  => enable,
		Clk     => clk,
		Rdy     => rdy,
		Abort_n => '1',
		IRQ_n   => irq_n,
		NMI_n   => nmi_n,
		SO_n    => '1',
		R_W_n   => localWe,
		A       => localA,
		DI      => localDi,
		DO      => localDo,
		NMI_ack => nmi_ack,
		Sync    => sync
	);

	localAccess <= '1' when localA(15 downto 1) = X"000"&"000" else '0';
	localDi     <= localDo when localWe = '0' else std_logic_vector(din) when localAccess = '0' else exeReg when localA(0) = '0' else indReg;

	process(clk)
	begin
		if rising_edge(clk) then
			if reset = '1' then
				exeReg <= X"0F";
				indReg <= X"0F";
			elsif localAccess = '1' and localWe = '0' and enable = '1' then
				if localA(0) = '0' then
					exeReg <= localDo;
				else
					indReg <= localDo;
				end if;
			end if;

			if widePO = '0' then
				exeReg(7 downto 4) <= (others => '0');
				indReg(7 downto 4) <= (others => '0');
			end if;
		end if;
	end process;

	process(clk)
	begin
		if rising_edge(clk) then
			if reset = '1' then
				indCount <= (others => '0');
			elsif enable = '1' then
				lastA0 <= localA(0);
				if sync = '1' then
					if rdy = '1' and din(7 downto 6) = "10" and din(4 downto 0) = "10001" then
						indCount <= to_unsigned(1, 3);
					else
						indCount <= (others => '0');
					end if;
				elsif (indCount = 1 and (rdy = '0' or localA(0) = lastA0)) then
					indCount <= (others => '0');
				elsif indCount /= 0 then
					indCount <= indCount + 1;
				end if;
			end if;
		end if;
	end process;

	addr <= unsigned(localA(15 downto 0));
	dout <= unsigned(localDo) when localAccess = '0' or widePO = '1' else unsigned("0000" & localDo(3 downto 0));
	pout <= unsigned(indReg) when sync = '0' and indCount >= 4 else unsigned(exeReg);
	we <= not localWe;
end architecture;
