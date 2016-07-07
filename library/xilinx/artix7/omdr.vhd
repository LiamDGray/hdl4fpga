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

entity omdr is
	generic (
		SIZE : natural;
		GEAR : natural);
	port (
		rst : in  std_logic;
		clk : in  std_logic_vector;
		t   : in  std_logic_vector(0 to GEAR*SIZE-1) := (others => '0');
		tq  : out std_logic_vector(0 to SIZE-1);
		d   : in  std_logic_vector(0 to GEAR*SIZE-1);
		q   : out std_logic_vector(0 to SIZE-1));
end;

library unisim;
use unisim.vcomponents.all;

architecture beh of omdr is

begin

	reg_g : for i in q'range generate
		signal pi  : std_logic_vector(0 to 8-1);
		signal pit : std_logic_vector(0 to 8-1);
	begin

		process (d)
			variable aux : std_logic_vector(0 to d'length-1);
		begin
			aux := d;
			pi <= (others => '-');
			for j in pi'range loop
				pi(j) <= aux(gear*i+j);
			end loop;
		end process;

		process (t)
			variable aux : std_logic_vector(0 to t'length-1);
		begin
			aux := d;
			pit <= (others => '-');
			for j in pit'range loop
				pit(j) <= aux(gear*i+j);
			end loop;
		end process;

		ser_i : oserdese2
		port map (
			rst      => rst,
			clk      => clk(0),
			clkdiv   => clk(1),
			d1       => pi(0),
			d2       => pi(1),
			d3       => pi(2),
			d4       => pi(3),
			d5       => pi(4),
			d6       => pi(5),
			d7       => pi(6),
			d8       => pi(7),
			oq       => q(i),

			t1       => pit(0),
			t2       => pit(1),
			t3       => pit(2),
			t4       => pit(3),
			tq       => tq(i),
			oce      => '1',
			shiftin1 => '0',
			shiftin2 => '0',
			tce      => '1',
			tbytein  => '0');

	end generate;

end;
