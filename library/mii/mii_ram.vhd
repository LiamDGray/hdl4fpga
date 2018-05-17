--                                                                            --
-- Author(s):                                                                 --
--   Miguel Angel Sagreras                                                    --
--                                                                            --
-- Copyright (C) 2015                                                         --
--    Miguel Angel Sagreras                                                   --
--                                                                            --
-- This source file may be used and distributed without restriction provided  --
-- that this copyright statement is not removed from the file and that any    --
-- derivative work contains  the original copyright notice and the associated --
-- disclaimer.                                                                --
--                                                                            --
-- This source file is free software; you can redistribute it and/or modify   --
-- it under the terms of the GNU General Public License as published by the   --
-- Free Software Foundation, either version 3 of the License, or (at your     --
-- option) any later version.                                                 --
--                                                                            --
-- This source is distributed in the hope that it will be useful, but WITHOUT --
-- ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or      --
-- FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for   --
-- more details at http://www.gnu.org/licenses/.                              --
--                                                                            --

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library hdl4fpga;
use hdl4fpga.std.all;

entity mii_ram is
	generic (
		size     : natural);
    port (
		mii_rxc  : in  std_logic;
        mii_rxdv : in  std_logic;
        mii_rxd  : in  std_logic_vector;
		mii_treq : in  std_logic;
		mii_trdy : out std_logic;
        mii_txc  : in  std_logic;
		mii_tena : in  std_logic := '1';
        mii_txdv : out std_logic;
        mii_txd  : out std_logic_vector);
end;

architecture def of mii_ram is
	constant addr_size : natural := unsigned_num_bits(size-1);

	signal raddr  : unsigned(0 to addr_size-1);
	signal waddr  : unsigned(0 to addr_size-1);

begin

	process (mii_rxc, mii_rxdv)
		variable edge : std_logic;
		variable cntr : unsigned(waddr'range);
	begin
		if rising_edge(mii_rxc) then
			if mii_rxdv='1' then
				if edge='0' then
					cntr := to_unsigned(1, cntr'length);
				else
					cntr := cntr + 1;
				end if;
			end if;
			edge := mii_rxdv;
		end if;

		waddr <= cntr;
		if mii_rxdv='1' then
			if edge='0' then
				waddr <= (others => '0');
			end if;
		end if;
	end process;

	ram_e : entity hdl4fpga.dpram
	port map (
		wr_clk  => mii_rxc,
		wr_addr => std_logic_vector(waddr),
		wr_data => mii_rxd,
		wr_ena  => mii_rxdv,
		rd_addr => std_logic_vector(raddr),
		rd_data => mii_txd);

	process (mii_txc)
	begin
		if rising_edge(mii_txc) then
			if mii_treq='0' then
				raddr <= (others => '0');
			elsif raddr < waddr then
				if mii_tena='1' then
					raddr <= raddr + 1;
				end if;
			end if;
		end if;
	end process;

	mii_trdy <= mii_treq and setif(waddr=raddr);
	mii_txdv <= mii_treq and not setif(waddr=raddr) and mii_tena;

end;
