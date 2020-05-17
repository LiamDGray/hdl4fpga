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
use hdl4fpga.videopkg.all;

entity graphics is
	generic (
		video_mode   : natural);
	port (
		ctlr_clk     : in  std_logic;
		ctlr_di_dv   : in  std_logic;
		ctlr_di      : in  std_logic_vector;
		video_clk    : in  std_logic;
		dma_req      : buffer std_logic := '0';
		dma_rdy      : in  std_logic;
		dma_len      : out std_logic_vector;
		dma_addr     : buffer std_logic_vector;
		video_hzsync : buffer std_logic;
		video_vtsync : buffer std_logic;
		video_hzon   : buffer std_logic;
		video_vton   : buffer std_logic;
		video_pixel  : out std_logic_vector);
end;

architecture def of graphics is

	constant line_size   : natural := 2**unsigned_num_bits(modeline_data(video_mode)(0)-1);
	constant fifo_size   : natural := 2**unsigned_num_bits(3*modeline_data(video_mode)(0)-1);
	constant byteperword : natural := ctlr_di'length/video_pixel'length;
	constant maxdma_len  : natural := fifo_size/byteperword;
	constant water_mark  : natural := (fifo_size-line_size)/byteperword;

	signal v_hzsync  : std_logic;
	signal v_vtsync  : std_logic;
	signal v_hzon    : std_logic;
	signal v_vton    : std_logic;
	signal v_on      : std_logic;
	signal video_frm : std_logic;
	signal video_on  : std_logic;

	signal video_hzcntr : std_logic_vector(unsigned_num_bits(modeline_data(video_mode)(3)-1)-1 downto 0);
	signal video_vtcntr : std_logic_vector(unsigned_num_bits(modeline_data(video_mode)(7)-1)-1 downto 0);

	signal level     : unsigned(0 to unsigned_num_bits(maxdma_len-1));
	signal vton_dly  : std_logic;
	signal vton_edge : std_logic;
	signal hzon_edge : std_logic;

	signal src_irdy  : std_logic;
	signal src_data  : std_logic_vector(ctlr_di'range);

	signal dma_step  : unsigned(dma_addr'range);

	signal mydma_rdy : std_logic;

begin

	video_e : entity hdl4fpga.video_sync
	generic map (
		mode => video_mode)
	port map (
		video_clk    => video_clk,
		video_hzsync => v_hzsync,
		video_vtsync => v_vtsync,
		video_hzcntr => video_hzcntr,
		video_vtcntr => video_vtcntr,
		video_hzon   => v_hzon,
		video_vton   => v_vton);

	process (video_clk)
	begin
		if rising_edge(video_clk) then
			mydma_rdy <= dma_rdy;
		end if;
	end  process;

	process (video_clk)
	begin
		if rising_edge(video_clk) then
			if vton_dly='0' then
				if vton_edge='1' then
					dma_req <= '1';
				end if;
				level    <= to_unsigned(maxdma_len, level'length);
				dma_len  <= std_logic_vector(to_unsigned(maxdma_len-1, dma_len'length));
				dma_addr <= (dma_addr'range => '0');
				dma_step <= resize(to_unsigned(maxdma_len, level'length), dma_step'length);
			elsif v_vton='1' and hzon_edge='0' and v_hzon='1' then
				level <= level - modeline_data(video_mode)(0);
			elsif level <= water_mark then
				dma_req  <= '1';
				level    <= level + line_size;
				dma_len  <= std_logic_vector(to_unsigned(line_size-1, dma_len'length));
				dma_addr <= std_logic_vector(unsigned(dma_addr) + dma_step);
				dma_step <= resize(to_unsigned(line_size, level'length), dma_step'length);
			elsif mydma_rdy='1' then
				dma_req <= '0';
			end if;

			hzon_edge <= v_hzon;
			vton_edge <= vton_dly;
			vton_dly  <= v_vton;
			video_frm <= not setif(v_vton='0' and vton_dly='1');
		end if;
	end process;

	process (ctlr_clk)
	begin
		if rising_edge(ctlr_clk) then
			src_irdy <= ctlr_di_dv;
			src_data <= ctlr_di;
		end if;
	end process;

	video_output_b : block
		constant inbuffer_size  : natural := 4;
		constant outbuffer_size : natural := 4;

		signal v_on    : std_logic;
		signal v_frm   : std_logic;

		signal v_trdy  : std_logic;
		signal v_pixel : std_logic_vector(video_pixel'range);

	begin

		v_on <= v_hzon and v_vton;

		inbuffer_e : entity hdl4fpga.align
		generic map (
			n => 2,
			d => (0 to 2-1 => inbuffer_size))
		port map (
			clk   => video_clk,
			di(0) => video_frm,
			di(1) => v_on,
			do(0) => v_frm,
			do(1) => video_on);

		vram_e : entity hdl4fpga.fifo
		generic map (
			size           => fifo_size,
			overflow_check => false,
			gray_code      => false)
		port map (
			src_clk  => ctlr_clk,
			src_irdy => src_irdy,
			src_data => src_data,

			dst_clk  => video_clk,
			dst_frm  => v_frm,
			dst_trdy => video_on,
			dst_data => v_pixel);

		outbuffer_e : entity hdl4fpga.align
		generic map (
			n => video_pixel'length,
			d => (0 to video_pixel'length-1 => outbuffer_size-1))
		port map (
			clk => video_clk,
			di  => v_pixel,
			do  => video_pixel);

		sync_e : entity hdl4fpga.align
		generic map (
			n => 4,
			d => (0 to 5-1 => inbuffer_size+outbuffer_size+1))
		port map (
			clk => video_clk,
			di(0) => v_hzon,
			di(1) => v_vton,
			di(2) => v_hzsync,
			di(3) => v_vtsync,
			do(0) => video_hzon,
			do(1) => video_vton,
			do(2) => video_hzsync,
			do(3) => video_vtsync);
	end block;

end;
