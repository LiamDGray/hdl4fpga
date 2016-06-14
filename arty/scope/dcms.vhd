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

library unisim;
use unisim.vcomponents.all;

library hdl4fpga;
use hdl4fpga.std.all;

entity dcms is
	generic (
		ddr_mul : natural;
		ddr_div : natural;
		sys_per : real);
	port (
		sys_rst     : in  std_logic;
		sys_clk     : in  std_logic;
		iodctrl_clk : out  std_logic;
		input_clk   : out std_logic;
		ddr_clk0    : out std_logic;
		ddr_clk90   : out std_logic;
		video_clk   : out std_logic;
		mii_clk     : out std_logic;
		iodctrl_rst : out std_logic;
		input_rst   : out std_logic;
		ddr_rst     : out std_logic;
		mii_rst     : out std_logic;
		video_rst   : out std_logic);
end;

architecture def of dcms is

	constant input   : natural := 0; 
    constant mii     : natural := 1;
    constant video   : natural := 2;
    constant ddr     : natural := 3;
    constant iodctrl : natural := 4;

	signal ddr_clkfb : std_logic;
	signal iodctrl_clkfb : std_logic;
	signal clks : std_logic_vector(0 to 4);
	signal lcks : std_logic_vector(clks'range);
begin

--	videodcm_e : entity hdl4fpga.dfs
--	generic map (
--		dcm_per => sys_per,
--		dfs_mul => 15,
--		dfs_div => 2)
--	port map(
--		dcm_rst => sys_rst,
--		dcm_clk => sys_clk,
--		dfs_clk => clks(video),
--		dcm_lck => lcks(video));

	iodctrl_i :  mmcme2_base
	generic map (
		clkfbout_mult_f => 8.0,
		clkin1_period => sys_per,
		clkout0_divide_f => 4.0,
		bandwidth => "LOW")
	port map (
		pwrdwn   => '0',
		rst      => sys_rst,
		clkin1   => sys_clk,
		clkfbin  => iodctrl_clkfb,
		clkfbout => iodctrl_clkfb,
		clkout0  => clks(iodctrl),
		locked   => lcks(iodctrl));
   
	ddr_i :  mmcme2_base
	generic map (
		divclk_divide => ddr_div,
		clkfbout_mult_f => real(2*ddr_mul),
		clkin1_period => sys_per,
		clkout1_phase => 90.000,
		clkout0_divide_f => 2.0,
		clkout1_divide => 2,
		bandwidth => "HIGH")
	port map (
		pwrdwn   => '0',
		rst      => sys_rst,
		clkin1   => sys_clk,
		clkfbin  => ddr_clkfb,
		clkfbout => ddr_clkfb,
		clkout0  => clks(ddr),
		clkout1  => ddr_clk90,
		locked   => lcks(ddr));
   
	clks(input) <= sys_clk;
	lcks(input) <= not sys_rst;
--	inputdcm_e : entity hdl4fpga.dfs
--	generic map (
--		dcm_per => sys_per,
--		dfs_mul => 3,
--		dfs_div => 2)
--	port map (
--		dcm_rst => sys_rst,
--		dcm_clk => sys_clk,
--		dfs_clk => clks(input),
--		dcm_lck => lcks(input));

--	mii_dfs_e : entity hdl4fpga.dfs
--	generic map (
--		dcm_per => sys_per,
--		dfs_mul => 5,
--		dfs_div => 4)
--	port map (
--		dcm_rst => sys_rst,
--		dcm_clk => sys_clk,
--		dfs_clk => clks(mii),
--		dcm_lck => lcks(mii));

	rsts_b : block
		signal rsts : std_logic_vector(clks'range);
	begin

		input_rst   <= rsts(input);
		mii_rst     <= rsts(mii);
		video_rst   <= rsts(video);
		ddr_rst     <= rsts(ddr);
		iodctrl_rst <= rsts(iodctrl);

		rsts_g: for i in clks'range generate
			signal q : std_logic;
		begin
			process (clks(i), sys_rst)
			begin
				if sys_rst='1' then
					q <= '1';
				elsif rising_edge(clks(i)) then
					q <= not lcks(i);
				end if;
			end process;
			rsts(i) <= q;
		end generate;
	end block;

	input_clk   <= clks(input);
	mii_clk     <= clks(mii);
	video_clk   <= clks(video);
	ddr_clk0    <= clks(ddr);
	iodctrl_clk <= clks(iodctrl);

end;
