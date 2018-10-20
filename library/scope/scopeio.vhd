library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library hdl4fpga;
use hdl4fpga.std.all;

entity scopeio is
	generic (
		inputs      : natural := 1;
		vlayout_id  : natural := 0;

		vt_gain     : natural_vector := (0 => 2**17, 1 => 2**16);
		vt_factsyms : std_logic_vector := (0 to 0 => '0');
		vt_untsyms  : std_logic_vector := (0 to 0 => '0');

		hz_gain     : natural_vector := (0 to 0 => 2**18);
		hz_factsyms : std_logic_vector := (0 to 0 => '0');
		hz_untsyms  : std_logic_vector := (0 to 0 => '0'));
	port (
		si_clk      : in  std_logic := '-';
		si_dv       : in  std_logic := '0';
		si_data     : in  std_logic_vector;
		so_clk      : in  std_logic := '-';
		so_dv       : out std_logic := '0';
		so_data     : out std_logic_vector;
		ipcfg_req   : in  std_logic;
		input_clk   : in  std_logic;
		input_ena   : in  std_logic := '1';
		input_data  : in  std_logic_vector;
		video_clk   : in  std_logic;
		video_pixel : out std_logic_vector;
		video_hsync : out std_logic;
		video_vsync : out std_logic;
		video_blank : out std_logic;
		video_sync  : out std_logic);
end;

architecture beh of scopeio is

	subtype sample_word  is std_logic_vector(input_data'length/inputs-1 downto 0);
	subtype chanid_range is natural range unsigned_num_bits(inputs-1)-1 downto 0;

	type square is record
		x      : natural;
		y      : natural;
		width  : natural;
		height : natural;
	end record;

	type video_layout is record 
		mode        : natural;
		scr_width   : natural;
		num_of_seg  : natural;
		sgmnt       : square;
	end record;

	type vlayout_vector is array (natural range <>) of video_layout;

	constant vlayout_tab : vlayout_vector(0 to 1) := (
		0 => (mode => 7, scr_width => 1920, num_of_seg => 4, sgmnt => (x => 320, y => 270, width => 50*32, height => 256)),
		1 => (mode => 1, scr_width =>  800, num_of_seg => 2, sgmnt => (x => 320, y => 300, width => 15*32, height => 256)));

	signal video_hs         : std_logic;
	signal video_vs         : std_logic;
	signal video_frm        : std_logic;
	signal video_hon        : std_logic;
	signal video_hzl        : std_logic;
	signal video_vld        : std_logic;
	signal video_vcntr      : std_logic_vector(11-1 downto 0);
	signal video_hcntr      : std_logic_vector(11-1 downto 0);

	signal video_io         : std_logic_vector(0 to 3-1);
	
	signal udpso_clk  : std_logic;
	signal udpso_dv   : std_logic;
	signal udpso_data : std_logic_vector(si_data'range);

	signal rgtr_id            : std_logic_vector(8-1 downto 0);
	signal rgtr_dv            : std_logic;
	signal rgtr_data          : std_logic_vector(32-1 downto 0);

	signal downsample_ena     : std_logic;
	signal downsample_data    : std_logic_vector(input_data'range);
	signal ampsample_ena      : std_logic;
	signal ampsample_data     : std_logic_vector(input_data'range);

	constant storage_size : natural := unsigned_num_bits(
		vlayout_tab(vlayout_id).num_of_seg*vlayout_tab(vlayout_id).sgmnt.width-1);
	signal storage_addr : std_logic_vector(0 to storage_size-1);
	signal storage_base : std_logic_vector(storage_addr'range);

	subtype storage_word is std_logic_vector(0 to 9-1);

	signal trigger_chanid : std_logic_vector(chanid_range);
	signal trigger_edge   : std_logic;
	signal trigger_ena    : std_logic;
	signal trigger_shot   : std_logic;
	signal trigger_addr   : std_logic_vector(storage_addr'range);
	signal trigger_level  : std_logic_vector(sample_word'range);

	signal storage_data   : std_logic_vector(0 to inputs*storage_word'length-1);
	signal storage_bsel   : std_logic_vector(0 to vlayout_tab(vlayout_id).num_of_seg-1);
	signal video_color    : std_logic_vector(video_pixel'length-1 downto 0);

	signal axis_dv        : std_logic;
	signal axis_scale     : std_logic_vector(4-1 downto 0);
	signal axis_base      : std_logic_vector(5-1 downto 0);
	signal axis_sel       : std_logic;
	signal hz_segment     : std_logic_vector(13-1 downto 0);
	signal hz_offset      : std_logic_vector(9-1 downto 0);
	signal vt_offset      : std_logic_vector(8-1 downto 0);

	signal palette_dv     : std_logic;
	signal palette_id     : std_logic_vector(0 to 3-1);
	signal palette_color  : std_logic_vector(video_pixel'range);

	signal gain_dv        : std_logic;
	signal gain_id        : std_logic_vector(4-1 downto 0);
	signal gain_chanid    : std_logic_vector(chanid_range);



begin

	miiip_e : entity hdl4fpga.scopeio_miiudp
	port map (
		mii_rxc  => si_clk,
		mii_rxdv => si_dv,
		mii_rxd  => si_data,

		mii_req  => ipcfg_req,
		mii_txc  => so_clk,
		mii_txdv => so_dv,
		mii_txd  => so_data,

		so_clk   => udpso_clk,
		so_dv    => udpso_dv,
		so_data  => udpso_data);

	scopeio_sin_e : entity hdl4fpga.scopeio_sin
	port map (
		sin_clk   => udpso_clk,
		sin_dv    => udpso_dv,
		sin_data  => udpso_data,
		rgtr_dv   => rgtr_dv,
		rgtr_id   => rgtr_id,
		rgtr_data => rgtr_data);


	scopeio_rtgr_e : entity hdl4fpga.scopeio_rgtr
	port map (
		clk           => si_clk,
		rgtr_dv       => rgtr_dv,
		rgtr_id       => rgtr_id,
		rgtr_data     => rgtr_data,

		axis_dv       => axis_dv,
		axis_scale    => axis_scale,
		axis_base     => axis_base,
		axis_sel      => axis_sel,
		hz_offset     => hz_offset,
		vt_offset     => vt_offset,
	
		palette_dv    => palette_dv,
		palette_id    => palette_id,
		palette_color => palette_color,

		gain_dv      =>  gain_dv,
		gain_id      =>  gain_id,
		gain_chanid  =>  gain_chanid,

		trigger_ena    => trigger_ena,
		trigger_chanid => trigger_chanid,
		trigger_level  => trigger_level,
		trigger_edge   => trigger_edge);

	amp_b : block
		constant sample_length : natural := input_data'length/inputs;
		signal output_ena : std_logic_vector(0 to inputs-1);
	begin
		amp_g : for i in 0 to inputs-1 generate
			subtype sample_range is natural range i*sample_length to (i+1)*sample_length-1;

			function to_bitrom (
				value : natural_vector;
				size  : natural)
				return std_logic_vector is
				variable retval : unsigned(0 to value'length*size-1);
			begin
				for i in value'range loop
					retval(0 to size-1) := to_unsigned(value(i), size);
					retval := retval rol size;
				end loop;
				return std_logic_vector(retval);
			end;

			signal gain_addr  : std_logic_vector(unsigned_num_bits(vt_gain'length-1)-1 downto 0);
			signal gain_value : std_logic_vector(18-1 downto 0);
		begin

			process (si_clk)
			begin
				if rising_edge(si_clk) then
					if gain_dv='1' then
						if to_integer(unsigned(gain_id(gain_addr'range)))=i then
							gain_addr <= gain_id(gain_addr'range);
						end if;
					end if;
				end if;
			end process;

			mult_e : entity hdl4fpga.rom 
			generic map (
				bitrom => to_bitrom(vt_gain,18))
			port map (
				clk  => input_clk,
				addr => gain_addr,
				data => gain_value);

			amp_e : entity hdl4fpga.scopeio_amp
			port map (
				input_clk     => input_clk,
				input_ena     => input_ena,
				input_sample  => input_data,
				gain_value    => gain_value,
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
		trigger_ena    => trigger_ena,
		trigger_chanid => trigger_chanid,
		trigger_level  => trigger_level,
		trigger_edge   => trigger_edge,
		trigger_shot   => trigger_shot);

--	downsampler_e : entity hdl4fpga.scopeio_downsampler
--	port map (
--		input_clk   => input_clk,
--		input_ena   => downsample_ena,
--		input_data  => downsample_data(sample_range),
--		factor_data => rgtr_data(hzscale_rgtr),
--		output_ena  => downsample_ena,
--		output_data => downsample_data);

	downsample_data <= ampsample_data;
	downsample_ena  <= ampsample_ena;

	storage_b : block

		signal wr_clk   : std_logic;
		signal wr_ena   : std_logic;
		signal wr_addr  : std_logic_vector(storage_addr'range);
		signal wr_cntr  : unsigned(0 to wr_addr'length+1);
		signal wr_data  : std_logic_vector(0 to storage_word'length*inputs-1);
		signal rd_clk   : std_logic;
		signal rd_addr  : std_logic_vector(wr_addr'range);
		signal rd_data  : std_logic_vector(wr_data'range);

	begin

		resize_p : process (downsample_data)
			variable aux1 : unsigned(0 to wr_data'length-1);
			variable aux2 : unsigned(0 to downsample_data'length-1);
		begin
			aux1 := (others => '-');
			aux2 := unsigned(downsample_data);
			for i in 0 to inputs-1 loop
				aux1(storage_word'range) := aux2(storage_word'range);
				aux1 := aux1 rol storage_word'length;
				aux2 := aux2 rol downsample_data'length/inputs;
			end loop;
--			wr_data <= std_logic_vector(aux1);
		end process;

		wr_clk  <= input_clk;
		wr_ena  <= not wr_cntr(0);
		wr_data <= downsample_data;

		rd_clk  <= video_clk;
		gen_addr_p : process (wr_clk)
		begin
			if rising_edge(wr_clk) then

--              ----------------
--				-- CALIBRATON --
--              ----------------
--
--				wr_data <= ('0','0', '0', '0', others => '1');
--				if wr_addr=std_logic_vector(to_unsigned(0,wr_addr'length)) then
--					wr_data <= ('0', '0', '1', others => '0');
--				elsif wr_addr=std_logic_vector(to_unsigned(1,wr_addr'length)) then
--					wr_data <= ('0', '0', '1', others => '0');
--				elsif wr_addr=std_logic_vector(to_unsigned(1600,wr_addr'length)) then
--					wr_data <= ('0', '0', '1', others => '0');
--				elsif wr_addr=std_logic_vector(to_unsigned(1601,wr_addr'length)) then
--					wr_data <= ('0', '0', '1', others => '0');
--				end if;
--				wr_data  <= std_logic_vector(resize(unsigned(wr_addr),wr_data'length));

				if trigger_shot='1' then
					trigger_addr <= std_logic_vector(unsigned(wr_addr) + unsigned(hz_offset));
				end if;

				if trigger_shot='1' then
					wr_cntr <= unsigned(hz_offset)+(2**wr_addr'length-1);
				else
					wr_cntr <= wr_cntr - 1;
				end if;
				wr_addr  <= std_logic_vector(unsigned(wr_addr) + 1);
			end if;
		end process;

		rd_addr_e : entity hdl4fpga.align
		generic map (
			n => rd_addr'length,
			d => (rd_addr'range => 1))
		port map (
			clk => rd_clk,
			di  => storage_addr,
			do  => rd_addr);

		mem_e : entity hdl4fpga.dpram 
		port map (
			wr_clk  => wr_clk,
			wr_ena  => wr_ena,
			wr_addr => wr_addr,
			wr_data => wr_data,
			rd_addr => rd_addr,
			rd_data => rd_data);

		rd_data_e : entity hdl4fpga.align
		generic map (
			n => rd_data'length,
			d => (rd_data'range => 1))
		port map (
			clk => rd_clk,
			di  => rd_data,
			do  => storage_data);

	end block;

	 video_b : block

		constant vgaio_latency : natural := storage_data'length+4+4+2;

		signal trigger_dot : std_logic;
		signal traces_dots : std_logic_vector(0 to inputs-1);
		signal grid_dot    : std_logic;
		signal grid_bgon   : std_logic;
		signal hz_dot      : std_logic;
		signal hz_bgon     : std_logic;
		signal vt_dot      : std_logic;
		signal vt_bgon     : std_logic;
	begin
		video_e : entity hdl4fpga.video_vga
		generic map (
			mode => vlayout_tab(vlayout_id).mode,
			n    => 11)
		port map (
			clk   => video_clk,
			hsync => video_hs,
			vsync => video_vs,
			hcntr => video_hcntr,
			vcntr => video_vcntr,
			don   => video_hon,
			frm   => video_frm,
			nhl   => video_hzl);

		video_vld <= video_hon and video_frm;

		vgaio_e : entity hdl4fpga.align
		generic map (
			n => video_io'length,
			d => (video_io'range => vgaio_latency))
		port map (
			clk   => video_clk,
			di(0) => video_hs,
			di(1) => video_vs,
			di(2) => video_vld,
			do    => video_io);

		graphics_b : block

			function to_naturalvector (
				constant vlayout : video_layout;
				constant param   : natural range 0 to 3)
				return natural_vector is
				variable rval : natural_vector(0 to vlayout.num_of_seg-1);
			begin
				for i in 0 to vlayout.num_of_seg-1 loop
					case param is
					when 0 =>
						rval(i) := 0;
					when 1 => 
						rval(i) := vlayout.sgmnt.y*i;
					when 2 => 
						rval(i) := vlayout.scr_width;
					when 3 => 
						rval(i) := vlayout.sgmnt.y-1;
					end case;
				end loop;
				return rval;
			end;

			signal win_don : std_logic_vector(0 to vlayout_tab(vlayout_id).num_of_seg-1);
			signal win_frm : std_logic_vector(0 to vlayout_tab(vlayout_id).num_of_seg-1);
			signal phon   : std_logic;
			signal pfrm   : std_logic;

		begin

			win_mngr_e : entity hdl4fpga.win_mngr
			generic map (
				x     => to_naturalvector(vlayout_tab(vlayout_id), 0),
				y     => to_naturalvector(vlayout_tab(vlayout_id), 1),
				width => to_naturalvector(vlayout_tab(vlayout_id), 2),
				height=> to_naturalvector(vlayout_tab(vlayout_id), 3))
			port map (
				video_clk  => video_clk,
				video_x    => video_hcntr,
				video_y    => video_vcntr,
				video_don  => video_hon,
				video_frm  => video_frm,
				win_don    => win_don,
				win_frm    => win_frm);

			phon <= not setif(win_don=(win_don'range => '0'));
			pfrm <= not setif(win_frm=(win_frm'range => '0'));

			sgmnt_b : block
				constant sgmnt : square := vlayout_tab(vlayout_id).sgmnt;

				signal pwin_y  : std_logic_vector(unsigned_num_bits(sgmnt.y-1)-1 downto 0);
				signal pwin_x  : std_logic_vector(unsigned_num_bits(vlayout_tab(vlayout_id).scr_width-1)-1 downto 0);
				signal p_hzl   : std_logic;

				signal win_x   : std_logic_vector(unsigned_num_bits(vlayout_tab(vlayout_id).sgmnt.width-1)-1  downto 0);
				signal win_y   : std_logic_vector(unsigned_num_bits(vlayout_tab(vlayout_id).sgmnt.height-1)-1  downto 0);
				signal x       : std_logic_vector(win_x'range);
				signal y       : std_logic_vector(win_y'range);
				signal cfrm    : std_logic_vector(0 to 3-1);
				signal cdon    : std_logic_vector(cfrm'range);
				signal wena    : std_logic;
				signal wfrm    : std_logic;
				signal w_hzl   : std_logic;
				signal grid_on : std_logic;
				signal hz_on   : std_logic;
				signal vt_on   : std_logic;
			begin

				latency_phzl_e : entity hdl4fpga.align
				generic map (
					n => 1,
					d => (0 => 2))
				port map (
					clk   => video_clk,
					di(0) => video_hzl,
					do(0) => p_hzl);

				parent_e : entity hdl4fpga.win
				port map (
					video_clk => video_clk,
					video_hzl => p_hzl,
					win_frm   => pfrm,
					win_ena   => phon,
					win_x     => pwin_x,
					win_y     => pwin_y);

				mngr_e : entity hdl4fpga.win_mngr
				generic map (
					x      => natural_vector'(0 => sgmnt.x-1,      1 => sgmnt.x-8*8-2, 2 => sgmnt.x-1),
					y      => natural_vector'(0 => 0,              1 => 0,             2 => sgmnt.height+2),
					width  => natural_vector'(0 => sgmnt.width+1,  1 => 8*8,           2 => sgmnt.width),
					height => natural_vector'(0 => sgmnt.height+1, 1 => sgmnt.height,  2 => 8))
				port map (
					video_clk  => video_clk,
					video_x    => pwin_x,
					video_y    => pwin_y,
					video_don  => phon,
					video_frm  => pfrm,
					win_don    => cdon,
					win_frm    => cfrm);

				wena <= not setif(cdon=(cdon'range => '0'));
				wfrm <= not setif(cfrm=(cfrm'range => '0'));

				latency_whzl_e : entity hdl4fpga.align
				generic map (
					n => 1,
					d => (0 => 2))
				port map (
					clk   => video_clk,
					di(0) => p_hzl,
					do(0) => w_hzl);

				win_e : entity hdl4fpga.win
				port map (
					video_clk => video_clk,
					video_hzl => w_hzl,
					win_frm   => wfrm,
					win_ena   => wena,
					win_x     => win_x,
					win_y     => win_y);

				winfrm_lat_e : entity hdl4fpga.align
				generic map (
					n => win_frm'length,
					d => (win_frm'range => 2))
				port map (
					clk => video_clk,
					di  => win_frm,
					do  => storage_bsel);

				storage_addr_p : process (storage_bsel)
					variable base : unsigned(storage_base'range);
				begin
					base := (base'range => '0');
					for i in storage_bsel'range loop
						if storage_bsel(i)='1' then
							base := to_unsigned(vlayout_tab(vlayout_id).sgmnt.width*i, base'length);
						end if;
					end loop;
					storage_base <= std_logic_vector(base);
				end process;
				storage_addr <= std_logic_vector(unsigned(win_x) + unsigned(storage_base) + unsigned(trigger_addr));

				latency_b : block
				begin
					latency_on_e : entity hdl4fpga.align
					generic map (
						n => cdon'length,
						d => (cdon'range => 2))
					port map (
						clk   => video_clk,
						di    => cdon,
						do(0) => grid_on,
						do(1) => vt_on,
						do(2) => hz_on);

					latency_x_e : entity hdl4fpga.align
					generic map (
						n => win_x'length,
						d => (win_x'range => 2))
					port map (
						clk => video_clk,
						di  => win_x,
						do  => x);

					latency_y_e : entity hdl4fpga.align
					generic map (
						n => win_y'length,
						d => (win_y'range => 1))
					port map (
						clk => video_clk,
						di  => win_y,
						do  => y);

				end block;

				process (video_clk)
				begin
					if rising_edge(video_clk) then
						hz_segment <= std_logic_vector(
							unsigned(
								std_logic_vector'(wirebus(b"000_0000" & b"001_1001" & b"011_0010" & b"100_1011", win_frm) & b"000000")) +
							unsigned(hz_offset));
					end if;
				end process;

				scopeio_segment_e : entity hdl4fpga.scopeio_segment
				generic map (
					latency       => storage_data'length+4,
					inputs        => inputs)
				port map (
					in_clk        => si_clk,

					axis_dv      => axis_dv,
					axis_sel      => axis_sel,
					axis_base     => axis_base,
					axis_scale    => axis_scale,

					video_clk     => video_clk,
					x             => x,
					y             => y,

					hz_on         => hz_on,
					hz_offset     => hz_segment,

					vt_on         => vt_on,
					vt_offset     => vt_offset,

					grid_on       => grid_on,

					samples       => storage_data,
					trigger_level => trigger_level,
					grid_dot      => grid_dot,
					hz_dot        => hz_dot,
					vt_dot        => vt_dot,
					trigger_dot   => trigger_dot,
					traces_dots   => traces_dots);

				bg_e : entity hdl4fpga.align
				generic map (
					n => 3,
					d => (0 to 3-1 => storage_data'length+2))
				port map (
					clk => video_clk,
					di(0) => grid_on,
					di(1) => hz_on,
					di(2) => vt_on,
					do(0) => grid_bgon,
					do(1) => hz_bgon,
					do(2) => vt_bgon);

			end block;

		end block;

		scopeio_palette_e : entity hdl4fpga.scopeio_palette
		generic map (
			traces_fg   => std_logic_vector'("010"),
			grid_fg     => std_logic_vector'("100"), 
			grid_bg     => std_logic_vector'("000"), 
			hz_fg       => std_logic_vector'("111"),
			hz_bg       => std_logic_vector'("000"), 
			vt_fg       => std_logic_vector'("111"),
			vt_bg       => std_logic_vector'("000"), 
			bk_gd       => std_logic_vector'("000"))
		port map (
			wr_clk      => si_clk,
			wr_req      => palette_dv,
			wr_palette  => palette_id,
			wr_color    => palette_color,
			video_clk   => video_clk,
			traces_dots => traces_dots, 
			grid_dot    => grid_dot,
			grid_bgon   => grid_bgon,
			hz_dot      => hz_dot,
			hz_bgon     => hz_bgon,
			vt_dot      => vt_dot,
			vt_bgon     => vt_bgon,
			video_color => video_color);
	end block;

	video_pixel <= (video_pixel'range => video_io(2)) and video_color;
	video_blank <= video_io(2);
	video_hsync <= video_io(0);
	video_vsync <= video_io(1);
	video_sync  <= not video_io(1) and not video_io(0);

end;
