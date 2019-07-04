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
use hdl4fpga.scopeiopkg.all;

entity scopeio is
	generic (
		vlayout_id  : natural;
		max_delay   : natural := 2**14;


		inputs      : natural;
		vt_gains    : natural_vector := (
			 0 => 2**17/(2**(0+0)*5**(0+0)),  1 => 2**17/(2**(1+0)*5**(0+0)),  2 => 2**17/(2**(2+0)*5**(0+0)),  3 => 2**17/(2**(0+0)*5**(1+0)),
			 4 => 2**17/(2**(0+1)*5**(0+1)),  5 => 2**17/(2**(1+1)*5**(0+1)),  6 => 2**17/(2**(2+1)*5**(0+1)),  7 => 2**17/(2**(0+1)*5**(1+1)),
			 8 => 2**17/(2**(0+2)*5**(0+2)),  9 => 2**17/(2**(1+2)*5**(0+2)), 10 => 2**17/(2**(2+2)*5**(0+2)), 11 => 2**17/(2**(0+2)*5**(1+2)),
			12 => 2**17/(2**(0+3)*5**(0+3)), 13 => 2**17/(2**(1+3)*5**(0+3)), 14 => 2**17/(2**(2+3)*5**(0+3)), 15 => 2**17/(2**(0+3)*5**(1+3)));
		vt_factsyms : std_logic_vector := (0 to 0 => '0');
		vt_untsyms  : std_logic_vector := (0 to 0 => '0');

		hz_factors  : natural_vector := (
			 0 => 2**(0+0)*5**(0+0),  1 => 2**(1+0)*5**(0+0),  2 => 2**(2+0)*5**(0+0),  3 => 2**(0+0)*5**(1+0),
			 4 => 2**(0+1)*5**(0+1),  5 => 2**(1+1)*5**(0+1),  6 => 2**(2+1)*5**(0+1),  7 => 2**(0+1)*5**(1+1),
			 8 => 2**(0+2)*5**(0+2),  9 => 2**(1+2)*5**(0+2), 10 => 2**(2+2)*5**(0+2), 11 => 2**(0+2)*5**(1+2),
			12 => 2**(0+3)*5**(0+3), 13 => 2**(1+3)*5**(0+3), 14 => 2**(2+3)*5**(0+3), 15 => 2**(0+3)*5**(1+3));
		
		hz_factsyms : std_logic_vector := (0 to 0 => '0');
		hz_untsyms  : std_logic_vector := (0 to 0 => '0');

		max_pixelsize  : natural := 24;
		default_tracesfg : std_logic_vector := b"1_1_1";
		default_gridfg   : std_logic_vector := b"1_0_0";
		default_gridbg   : std_logic_vector := b"0_0_0";
		default_hzfg     : std_logic_vector := b"1_1_1";
		default_hzbg     : std_logic_vector := b"0_0_1";
		default_vtfg     : std_logic_vector := b"1_1_1";
		default_vtbg     : std_logic_vector := b"0_0_1";
		default_textbg   : std_logic_vector := b"0_0_0";
		default_sgmntbg  : std_logic_vector := b"0_1_1";
		default_bg       : std_logic_vector := b"1_1_1");
	port (
		si_clk      : in  std_logic := '-';
		si_frm      : in  std_logic := '0';
		si_irdy     : in  std_logic := '0';
		si_data     : in  std_logic_vector;
		so_clk      : in  std_logic := '-';
		so_frm      : out std_logic;
		so_irdy     : out std_logic;
		so_trdy     : in  std_logic := '0';
		so_data     : out std_logic_vector;

		input_clk   : in  std_logic;
		input_ena   : in  std_logic := '1';
		input_data  : in  std_logic_vector;
		video_clk   : in  std_logic;
		video_pixel : out std_logic_vector;
		video_hsync : out std_logic;
		video_vsync : out std_logic;
		video_blank : out std_logic;
		video_sync  : out std_logic);

	constant hzoffset_bits : natural := unsigned_num_bits(max_delay-1);
	constant chanid_bits   : natural := unsigned_num_bits(inputs-1);

end;

architecture beh of scopeio is

	constant layout : display_layout := displaylayout_table(video_description(vlayout_id).layout_id);

	subtype storage_word is std_logic_vector(unsigned_num_bits(grid_height(layout))-1 downto 0);
	constant gainid_size : natural := unsigned_num_bits(vt_gains'length-1);

	signal video_hzsync       : std_logic;
	signal video_vtsync       : std_logic;
	signal video_vton         : std_logic;
	signal video_hzon         : std_logic;
	signal video_vld          : std_logic;
	signal video_vtcntr       : std_logic_vector(11-1 downto 0);
	signal video_hzcntr       : std_logic_vector(11-1 downto 0);

	signal video_io           : std_logic_vector(0 to 3-1);
	
	signal rgtr_id            : std_logic_vector(8-1 downto 0);
	signal rgtr_dv            : std_logic;
	signal rgtr_data          : std_logic_vector(32-1 downto 0);

	signal ampsample_ena      : std_logic;
	signal ampsample_data     : std_logic_vector(0 to input_data'length-1);
	signal triggersample_dv   : std_logic;
	signal triggersample_data : std_logic_vector(input_data'range);

	signal resizedsample_dv   : std_logic;
	signal resizedsample_data : std_logic_vector(0 to inputs*storage_word'length-1);
	signal downsample_dv      : std_logic;
	signal downsample_data    : std_logic_vector(resizedsample_data'range);

	constant capture_bits     : natural := unsigned_num_bits(layout.num_of_segments*grid_width(layout)-1);
	signal capture_addr       : std_logic_vector(0 to capture_bits-1);

	signal trigger_shot       : std_logic;
	signal scaler_sync        : std_logic;

	signal capture_rdy        : std_logic;
	signal capture_req        : std_logic;
	signal capture_data       : std_logic_vector(0 to inputs*storage_word'length-1);
	signal scope_color        : std_logic_vector(video_pixel'length-1 downto 0);
	signal video_color        : std_logic_vector(video_pixel'length-1 downto 0);

	signal hz_offset          : std_logic_vector(hzoffset_bits-1 downto 0);
	signal hz_segment         : std_logic_vector(hz_offset'range);

	signal hz_scale           : std_logic_vector(4-1 downto 0);
	signal hz_dv              : std_logic;
	signal vt_dv              : std_logic;
	signal vt_offsets         : std_logic_vector(inputs*(5+8)-1 downto 0);
	signal vt_chanid          : std_logic_vector(chanid_maxsize-1 downto 0);

	signal palette_dv         : std_logic;
	signal palette_id         : std_logic_vector(0 to unsigned_num_bits(max_inputs+9-1)-1);
	signal palette_color      : std_logic_vector(max_pixelsize-1 downto 0);

	signal gain_dv            : std_logic;
	signal gain_ids           : std_logic_vector(0 to inputs*gainid_size-1);

	signal trigger_dv         : std_logic;
	signal trigger_chanid     : std_logic_vector(chanid_bits-1 downto 0);
	signal trigger_edge       : std_logic;
	signal trigger_freeze     : std_logic;
	signal trigger_level      : std_logic_vector(storage_word'range);

	signal pointer_dv         : std_logic;
	signal pointer_x          : std_logic_vector(video_hzcntr'range);
	signal pointer_y          : std_logic_vector(video_vtcntr'range);

	signal wu_frm             : std_logic;
	signal wu_irdy            : std_logic;
	signal wu_trdy            : std_logic;
	signal wu_unit            : std_logic_vector(4-1 downto 0);
	signal wu_neg             : std_logic;
	signal wu_sign            : std_logic;
	signal wu_align           : std_logic;
	signal wu_value           : std_logic_vector(4*4-1 downto 0);
	signal wu_format          : std_logic_vector(8*4-1 downto 0);

begin

	assert inputs < max_inputs
		report "inputs greater than max_inputs"
		severity failure;

	scopeio_sin_e : entity hdl4fpga.scopeio_sin
	port map (
		sin_clk   => si_clk,
		sin_frm   => si_frm,
		sin_irdy  => si_irdy,
		sin_data  => si_data,
		rgtr_dv   => rgtr_dv,
		rgtr_id   => rgtr_id,
		rgtr_data => rgtr_data);

	scopeio_rtgr_e : entity hdl4fpga.scopeio_rgtr
	generic map (
		inputs         => inputs)
	port map (
		clk            => si_clk,
		rgtr_dv        => rgtr_dv,
		rgtr_id        => rgtr_id,
		rgtr_data      => rgtr_data,

		hz_dv          => hz_dv,
		hz_scale       => hz_scale,
		hz_offset      => hz_offset,
		vt_dv          => vt_dv,
		vt_offsets     => vt_offsets,
		vt_chanid      => vt_chanid,
	
		pointer_dv     => pointer_dv,
		pointer_y      => pointer_y,
		pointer_x      => pointer_x,

		palette_dv     => palette_dv,
		palette_id     => palette_id,
		palette_color  => palette_color,

		gain_dv        => gain_dv,
		gain_ids       => gain_ids,

		trigger_dv     => trigger_dv,
		trigger_freeze => trigger_freeze,
		trigger_chanid => trigger_chanid,
		trigger_level  => trigger_level,
		trigger_edge   => trigger_edge);
	
	amp_b : block
		constant sample_size : natural := input_data'length/inputs;
		signal output_ena    : std_logic_vector(0 to inputs-1);
	begin
		amp_g : for i in 0 to inputs-1 generate
			subtype sample_range is natural range i*sample_size to (i+1)*sample_size-1;

			signal input_sample : std_logic_vector(0 to sample_size-1);
			signal gain_id      : std_logic_vector(gainid_size-1 downto 0);
			signal gain_value   : std_logic_vector(18-1 downto 0);
		begin

			gain_id <= word2byte(gain_ids, i, gainid_size);
			input_sample <= word2byte(input_data, i, sample_size);
			amp_e : entity hdl4fpga.scopeio_amp
			generic map (
				gains => vt_gains)
			port map (
				input_clk     => input_clk,
				input_ena     => input_ena,
				input_sample  => input_sample,
				gain_id       => gain_id,
				output_ena    => output_ena(i),
				output_sample => ampsample_data(sample_range));

		end generate;

		ampsample_ena <= output_ena(0);
	end block;

	scopeio_trigger_e : entity hdl4fpga.scopeio_trigger
	generic map (
		inputs => inputs)
	port map (
		input_clk      => input_clk,
		input_ena      => ampsample_ena,
		input_data     => ampsample_data,
		trigger_chanid => trigger_chanid,
		trigger_level  => trigger_level,
		trigger_edge   => trigger_edge,
		trigger_shot   => trigger_shot,
		output_ena     => triggersample_dv,
		output_data    => triggersample_data);

	resize_p : process (triggersample_data)
		variable aux1 : unsigned(storage_word'length*inputs-1 downto 0);
		variable aux2 : unsigned(triggersample_data'length-1  downto 0);
	begin
		aux1 := (others => '-');
		aux2 := unsigned(triggersample_data);
		for i in 0 to inputs-1 loop
			aux1(storage_word'range) := aux2(storage_word'range);
			aux1 := aux1 rol storage_word'length;
			aux2 := aux2 rol triggersample_data'length/inputs;
		end loop;
		resizedsample_data <= std_logic_vector(aux1);
	end process;
	resizedsample_dv  <= triggersample_dv;

	triggers_modes_b : block
	begin
		capture_req <= not capture_rdy or video_vton or not trigger_shot;
		scaler_sync <= not capture_req;
	end block;

	downsampler_e : entity hdl4fpga.scopeio_downsampler
	generic map (
		factors => hz_factors)
	port map (
		factor_id    => hz_scale,
		input_clk    => input_clk,
		scaler_sync  => scaler_sync,
		input_dv     => resizedsample_dv,
		input_data   => resizedsample_data,
		output_dv    => downsample_dv ,
		output_data  => downsample_data);

	scopeio_capture_e : entity hdl4fpga.scopeio_capture
	port map (
		input_clk     => input_clk,
		capture_req   => capture_req,
		capture_rdy   => capture_rdy,
		input_ena     => downsample_dv,
		input_data    => downsample_data,
		input_delay   => hz_offset,

		captured_clk  => video_clk,
		captured_addr => capture_addr,
		captured_data => capture_data,
		captured_vld  => open);

	video_b : block

		constant storageaddr_latency : natural := 1;
		constant storagebram_latency : natural := 2;
		constant input_latency       : natural := storageaddr_latency+storagebram_latency;
		constant mainrgtrin_latency  : natural := 1;
		constant mainrgtrout_latency : natural := 1;
		constant mainrgtrio_latency  : natural := mainrgtrin_latency+mainrgtrout_latency;
		constant sgmntrgtrio_latency : natural := 2;
		constant segmment_latency    : natural := 5;
		constant palette_latency     : natural := 3;
		constant vgaio_latency       : natural := input_latency+mainrgtrio_latency+sgmntrgtrio_latency+segmment_latency+palette_latency;

		constant hztick_bits         : natural := unsigned_num_bits(8*axis_fontsize(layout)-1);

		signal trigger_dot   : std_logic;
		signal traces_dots   : std_logic_vector(0 to inputs-1);
		signal grid_dot      : std_logic;
		signal grid_bgon     : std_logic;
		signal hz_dot        : std_logic;
		signal hz_bgon       : std_logic;
		signal vt_dot        : std_logic;
		signal vt_bgon       : std_logic;
		signal text_bgon     : std_logic;
		signal sgmntbox_on   : std_logic;
		signal sgmntbox_bgon : std_logic;
		signal pointer_dot   : std_logic;
	begin
		formatu_e : entity hdl4fpga.scopeio_formatu
		port map (
			clk    => si_clk,
			frm    => wu_frm,
			irdy   => wu_irdy,
			trdy   => wu_trdy,
			float  => wu_value,
			width  => b"1000",
			sign   => wu_sign,
			neg    => wu_neg,
			unit   => wu_unit,
			align  => wu_align,
			prec   => b"1111",
			format => wu_format);

		video_e : entity hdl4fpga.video_sync
		generic map (
			mode => video_description(vlayout_id).mode_id)
		port map (
			video_clk    => video_clk,
			video_hzsync => video_hzsync,
			video_vtsync => video_vtsync,
			video_hzcntr => video_hzcntr,
			video_vtcntr => video_vtcntr,
			video_hzon   => video_hzon,
			video_vton   => video_vton);

		video_vld <= video_hzon and video_vton;

		vgaio_e : entity hdl4fpga.align
		generic map (
			n => video_io'length,
			d => (video_io'range => vgaio_latency))
		port map (
			clk   => video_clk,
			di(0) => video_hzsync,
			di(1) => video_vtsync,
			di(2) => video_vld,
			do    => video_io);

		layout_b : block

			signal mainbox_xdiv  : std_logic_vector(0 to 2-1);
			signal mainbox_ydiv  : std_logic_vector(0 to 4-1);
			signal mainbox_xedge : std_logic;
			signal mainbox_yedge : std_logic;
			signal mainbox_nexty : std_logic;
			signal mainbox_eox   : std_logic;
			signal mainbox_xon   : std_logic;
			signal mainbox_yon   : std_logic;

			signal sgmnt_decode  : std_logic_vector(0 to layout.num_of_segments-1);
		begin

			mainlayout_e : entity hdl4fpga.videobox_layout
			generic map (
				x_edges => main_xedges(layout),
				y_edges => main_yedges(layout))
			port map (
				video_clk  => video_clk,
				video_x    => video_hzcntr,
				video_y    => video_vtcntr,
				video_xon  => video_hzon,
				video_yon  => video_vton,
				box_xedge  => mainbox_xedge,
				box_yedge  => mainbox_yedge,
				box_eox    => mainbox_eox,
				box_xon    => mainbox_xon,
				box_yon    => mainbox_yon,
				box_xdiv   => mainbox_xdiv,
				box_nexty  => mainbox_nexty,
				box_ydiv   => mainbox_ydiv);

			sgmnt_decode_p: process (video_clk)
			begin
				if rising_edge(video_clk) then
					sgmntbox_on   <= '0';
					sgmnt_decode <= (others => '0');
					for i in 0 to layout.num_of_segments-1 loop
						if main_boxon(box_id => i, x_div => mainbox_xdiv, y_div => mainbox_ydiv, layout => layout)='1' then
							sgmntbox_on     <= mainbox_xon;
							sgmnt_decode(i) <= '1';
						end if;
					end loop;
				end if;
			end process;

			mainbox_b : block

				constant sgmntboxx_bits : natural := unsigned_num_bits(sgmnt_width(layout)-1);
				constant sgmntboxy_bits : natural := unsigned_num_bits(sgmnt_height(layout)-1);

				signal sgmntbox_vyon   : std_logic;
				signal sgmntbox_vxon   : std_logic;
				signal sgmntbox_vx     : std_logic_vector(sgmntboxx_bits-1 downto 0);
				signal sgmntbox_vy     : std_logic_vector(sgmntboxy_bits-1 downto 0);

				signal sgmntbox_x      : std_logic_vector(sgmntboxx_bits-1 downto 0);
				signal sgmntbox_y      : std_logic_vector(sgmntboxy_bits-1 downto 0);
				signal sgmntbox_xedge  : std_logic;
				signal sgmntbox_yedge  : std_logic;
				signal sgmntbox_xdiv   : std_logic_vector(0 to 3-1);
				signal sgmntbox_ydiv   : std_logic_vector(0 to 3-1);
				signal sgmntbox_xon    : std_logic;
				signal sgmntbox_yon    : std_logic;
				signal sgmntbox_eox    : std_logic;

				signal grid_on         : std_logic;
				signal hz_on           : std_logic;
				signal vt_on           : std_logic;
				signal text_on         : std_logic;

			begin

				box_b : block
					signal xon   : std_logic;
					signal yon   : std_logic;
					signal eox   : std_logic;
					signal xedge : std_logic;
					signal yedge : std_logic;
					signal nexty : std_logic;
					signal x     : std_logic_vector(sgmntboxx_bits-1 downto 0);
					signal y     : std_logic_vector(sgmntboxy_bits-1 downto 0);
				begin 

					rgtrin_p : process (video_clk)
					begin
						if rising_edge(video_clk) then
							yon   <= mainbox_yon;
							eox   <= mainbox_eox;
							xedge <= mainbox_xedge;
							yedge <= mainbox_yedge;
							nexty <= mainbox_nexty;
						end if;
					end process;
				
					xon <= sgmntbox_on;
					videobox_e : entity hdl4fpga.videobox
					port map (
						video_clk => video_clk,
						video_xon => xon,
						video_yon => yon,
						video_eox => eox,
						box_xedge => xedge,
						box_yedge => yedge,
						box_x     => x,
						box_y     => y);

					rgtrout_p : process (video_clk)
						variable init_layout : std_logic;
					begin
						if rising_edge(video_clk) then
							sgmntbox_vxon <= xon;
							sgmntbox_vyon <= yon and not init_layout;
							sgmntbox_vx   <= x;
							sgmntbox_vy   <= y;
							init_layout   := nexty;
						end if;
					end process;

				end block;

				sgmntlayout_b : block
				begin

					layout_e : entity hdl4fpga.videobox_layout
					generic map (
						x_edges   => sgmnt_xedges(layout),
						y_edges   => sgmnt_yedges(layout))
					port map (
						video_clk => video_clk,
						video_xon => sgmntbox_vxon,
						video_yon => sgmntbox_vyon,
						video_x   => sgmntbox_vx,
						video_y   => sgmntbox_vy,
						box_xon   => sgmntbox_xon,
						box_yon   => sgmntbox_yon,
						box_eox   => sgmntbox_eox,
						box_xedge => sgmntbox_xedge,
						box_yedge => sgmntbox_yedge,
						box_xdiv  => sgmntbox_xdiv,
						box_ydiv  => sgmntbox_ydiv);
				end block;

				sgmntbox_b : block
					signal xon   : std_logic;
					signal yon   : std_logic;
					signal eox   : std_logic;
					signal xedge : std_logic;
					signal yedge : std_logic;
					signal xdiv  : std_logic_vector(sgmntbox_xdiv'range);
					signal ydiv  : std_logic_vector(sgmntbox_ydiv'range);
					signal x     : std_logic_vector(sgmntbox_x'range);
					signal y     : std_logic_vector(sgmntbox_y'range);
					signal box_on : std_logic;
				begin

					rgtrin_p : process (video_clk)
					begin
						if rising_edge(video_clk) then
							xon   <= sgmntbox_xon;
							yon   <= sgmntbox_yon;
							eox   <= sgmntbox_eox;
							xedge <= sgmntbox_xedge;
							yedge <= sgmntbox_yedge;
							xdiv  <= sgmntbox_xdiv;
							ydiv  <= sgmntbox_ydiv;
						end if;
					end process;

					box_e : entity hdl4fpga.videobox
					port map (
						video_clk => video_clk,
						video_xon => xon,
						video_yon => yon,
						video_eox => eox,
						box_xedge => xedge,
						box_yedge => yedge,
						box_x     => x,
						box_y     => y);

					box_on <= xon and yon;
					rgtrout_p: process (video_clk)
						constant font_bits : natural := unsigned_num_bits(axis_fontsize(layout)-1);
						variable vt_mask : unsigned(x'range);
						variable hz_mask : unsigned(y'range);
					begin
						if rising_edge(video_clk) then
							vt_mask := unsigned(x) srl font_bits;
							if vtaxis_width(layout)=0  then
								if vtaxis_tickrotate(layout)=ccw90 or vtaxis_tickrotate(layout)=ccw270 then
									vt_on <= setif(vt_mask=(vt_mask'range => '0')) and sgmnt_boxon(box_id => grid_boxid, x_div => xdiv, y_div => ydiv, layout => layout) and box_on;
								else
									vt_on <= setif(vt_mask < 6) and sgmnt_boxon(box_id => grid_boxid, x_div => xdiv, y_div => ydiv, layout => layout) and box_on;
								end if;
							else
								vt_on <= sgmnt_boxon(box_id => vtaxis_boxid, x_div => xdiv, y_div => ydiv, layout => layout) and box_on;
							end if;
							hz_mask := unsigned(y) srl 3;
							if hzaxis_height(layout)=0  then
								hz_on <= setif((hz_mask'range => '0')=hz_mask) and sgmnt_boxon(box_id => grid_boxid, x_div => xdiv, y_div => ydiv, layout => layout) and box_on;
							else
								hz_on <= sgmnt_boxon(box_id => hzaxis_boxid, x_div => xdiv, y_div => ydiv, layout => layout) and box_on;
							end if;
							grid_on    <= sgmnt_boxon(box_id => grid_boxid,   x_div => xdiv, y_div => ydiv, layout => layout) and box_on;
							text_on    <= sgmnt_boxon(box_id => text_boxid,   x_div => xdiv, y_div => ydiv, layout => layout) and box_on;
							sgmntbox_x <= x;
							sgmntbox_y <= y;
						end if;
					end process;
				end block;

				capture_addr_p : process (video_clk)
					variable base : unsigned(0 to capture_addr'length-1);
				begin
					if rising_edge(video_clk) then
						base := (others => '0');
						for i in 0 to layout.num_of_segments-1 loop
							if sgmnt_decode(i)='1' then
								base := base or to_unsigned((grid_width(layout)-1)*i, base'length);
							end if;
						end loop;
											   
						capture_addr <= std_logic_vector(base + resize(unsigned(sgmntbox_x), capture_addr'length));
						hz_segment   <= std_logic_vector(base + resize(unsigned(hz_offset(axisx_backscale+hztick_bits-1 downto 0)), hz_segment'length));
															  
					end if;
				end process;

				scopeio_segment_e : entity hdl4fpga.scopeio_segment
				generic map (
					input_latency => input_latency,
					latency       => segmment_latency+input_latency,
					inputs        => inputs,
					layout        => layout)
				port map (
					in_clk        => si_clk,

					wu_frm        => wu_frm ,
					wu_irdy       => wu_irdy,
					wu_trdy       => wu_trdy,
					wu_unit       => wu_unit,
					wu_neg        => wu_neg,
					wu_sign       => wu_sign,
					wu_align      => wu_align,
					wu_value      => wu_value,
					wu_format     => wu_format,

					hz_dv         => hz_dv,
					hz_scale      => hz_scale,
					hz_base       => hz_offset(hz_offset'left downto axisx_backscale+hztick_bits),
					hz_offset     => hz_segment,

					gain_dv       => gain_dv,
					gain_ids      => gain_ids,
					vt_dv         => vt_dv,
					vt_chanid     => vt_chanid,
					vt_offsets    => vt_offsets,

					video_clk     => video_clk,
					x             => sgmntbox_x,
					y             => sgmntbox_y,

					hz_on         => hz_on,
					vt_on         => vt_on,
					grid_on       => grid_on,

					samples       => capture_data,
					trigger_level => trigger_level,
					grid_dot      => grid_dot,
					hz_dot        => hz_dot,
					vt_dot        => vt_dot,
					trigger_dot   => trigger_dot,
					traces_dots   => traces_dots);

				bg_e : entity hdl4fpga.align
				generic map (
					n => 5,
					d => (
						0 to 4-1 => input_latency+segmment_latency,
						4        => input_latency+segmment_latency+mainrgtrout_latency+sgmntrgtrio_latency))
				port map (
					clk => video_clk,
					di(0) => grid_on,
					di(1) => hz_on,
					di(2) => vt_on,
					di(3) => text_on,
					di(4) => sgmntbox_on,
					do(0) => grid_bgon,
					do(1) => hz_bgon,
					do(2) => vt_bgon,
					do(3) => text_bgon,
					do(4) => sgmntbox_bgon);

			end block;

		end block;

		scopeio_palette_e : entity hdl4fpga.scopeio_palette
		generic map (
			default_tracesfg => default_tracesfg,
			default_gridfg   => default_gridfg, 
			default_gridbg   => default_gridbg, 
			default_hzfg     => default_hzfg,
			default_hzbg     => default_hzbg, 
			default_vtfg     => default_vtfg,
			default_vtbg     => default_vtbg, 
			default_textbg   => default_textbg, 
			default_sgmntbg  => default_sgmntbg, 
			default_bg       => default_bg)
		port map (
			wr_clk           => si_clk,
			wr_dv            => palette_dv,
			wr_palette       => palette_id,
			wr_color         => palette_color,
			video_clk        => video_clk,
			traces_dots      => traces_dots, 
			trigger_dot      => trigger_dot,
			trigger_chanid   => trigger_chanid,
			grid_dot         => grid_dot,
			grid_bgon        => grid_bgon,
			hz_dot           => hz_dot,
			hz_bgon          => hz_bgon,
			vt_dot           => vt_dot,
			vt_bgon          => vt_bgon,
			text_bgon        => text_bgon,
			sgmnt_bgon       => sgmntbox_bgon,
			video_color      => scope_color);

		scopeio_pointer_e : entity hdl4fpga.scopeio_pointer
		generic map (
			latency => vgaio_latency)
		port map (
			video_clk    => video_clk,
			pointer_x    => pointer_x,
			pointer_y    => pointer_y,
			video_hzcntr => video_hzcntr,
			video_vtcntr => video_vtcntr,
			video_dot    => pointer_dot);

		video_color <= scope_color or (video_color'range => pointer_dot);
	end block;


	video_pixel <= (video_pixel'range => video_io(2)) and video_color;
	video_blank <= not video_io(2);
	video_hsync <= video_io(0);
	video_vsync <= video_io(1);
	video_sync  <= not video_io(1) and not video_io(0);

end;