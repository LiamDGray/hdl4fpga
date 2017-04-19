library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library hdl4fpga;
use hdl4fpga.std.all;
use hdl4fpga.cgafont.all;

entity scopeio_channel is
	generic(
		inputs     : natural;
		width      : natural;
		height     : natural);
	port (
		video_clk  : in  std_logic;
		video_nhl  : in  std_logic;
		input_data : in  std_logic_vector;
		input_addr : out std_logic_vector;
		win_frm    : in  std_logic_vector;
		win_on     : in  std_logic_vector;
		video_dot  : out std_logic_vector);
end;

architecture def of scopeio_channel is
	subtype word_s is std_logic_vector(input_data'length/inputs-1 downto 0);
	type words_vector is array (natural range <>) of word_s;

	signal samples : words_vector(inputs-1 downto 0);

	signal x         : std_logic_vector(unsigned_num_bits(width-1)-1  downto 0);
	signal y         : std_logic_vector(unsigned_num_bits(height-1)-1 downto 0);
	signal gon       : std_logic;
	signal plot_on   : std_logic;
	signal plot_dot  : std_logic_vector(win_on'range);
	signal grid_dot  : std_logic;
	signal char_line : std_logic_vector(0 to 8-1);
	signal char_addr : std_logic_vector(8-1 downto 0);
	signal char_dot  : std_logic;
	signal char_code : std_logic_vector(4-1 downto 0);

begin

	win_b : block
		signal phon  : std_logic;
		signal pfrm  : std_logic;
		signal vcntr : std_logic_vector(0 to unsigned_num_bits(height-1)-1);
		signal hcntr : std_logic_vector(0 to unsigned_num_bits(width-1)-1);
		signal cfrm  : std_logic_vector(0 to 3-1);
		signal cdon  : std_logic_vector(0 to 3-1);
		signal wena  : std_logic;
		signal wfrm  : std_logic;
	begin
		phon <= not setif(win_on=(win_on'range => '0'));
		pfrm <= not setif(win_frm=(win_frm'range => '0'));

		parent_e : entity hdl4fpga.win
		port map (
			video_clk => video_clk,
			video_nhl => video_nhl,
			win_frm   => pfrm,
			win_ena   => phon,
			win_x     => hcntr,
			win_y     => vcntr);

		mngr_e : entity hdl4fpga.win_mngr
		generic map (
			tab => (
				4*8+4,         0, width-(4*8+4), height-12,
				4*8+4, height-10, width-(4*8+4), 8,
				    0,         0,       (4*8+3), height-13))
		port map (
			video_clk  => video_clk,
			video_x    => hcntr,
			video_y    => vcntr,
			video_don  => phon,
			video_frm  => pfrm,
			win_don    => cdon,
			win_frm    => cfrm);

		wena <= not setif(cdon=(cdon'range => '0'));
		wfrm <= not setif(cfrm=(cfrm'range => '0'));

		win_e : entity hdl4fpga.win
		port map (
			video_clk => video_clk,
			video_nhl => video_nhl,
			win_frm   => wfrm,
			win_ena   => wena,
			win_x     => x,
			win_y     => y);
		plot_on <= cdon(0);

	end block;

	charrom_e : entity hdl4fpga.fontrom
	generic map (
		bitrom => psf1unitx8x8)
	port map (
		clk  => video_clk,
		code => x(7-1 downto 3),
		row  => y(3-1 downto 0),
		data => char_line);
	char_dot <= word2byte(
		reverse(std_logic_vector(unsigned(char_line) ror 1)), 
		x(2 downto 0))(0) and (cdon(1) or cdon(2)) and setif(x(8-1 downto 5)=(1 to 3 =>'0'))
		and setif(y(5-1 downto 3)=(1 to 2 =>'0'));

	process (input_data)
		variable aux : unsigned(input_data'length-1 downto 0);
	begin
		aux := unsigned(input_data);
		for i in 0 to inputs-1 loop
			samples(i) <= std_logic_vector(aux(word_s'range));
			aux        := aux srl word_s'length;
		end loop;
	end process;

	plot_g : for i in 0 to inputs-1 generate
		signal ena : std_logic;
	begin
		process (video_clk)
		begin
			if rising_edge(video_clk) then
			end if;
		end process;

		draw_vline : entity hdl4fpga.draw_vline
		generic map (
			n => unsigned_num_bits(height-1))
		port map (
			video_clk  => video_clk,
			video_ena  => plot_on,
			video_row1 => y,
			video_row2 => samples(i),
			video_dot  => plot_dot(i));
	end generate;

	grid_b : block
		signal dot : std_logic;
	begin
		grid_e : entity hdl4fpga.grid
		generic map (
			row_div  => "000",
			row_line => "00",
			col_div  => "000",
			col_line => "00")
		port map (
			clk => video_clk,
			don => plot_on,
			row => x,
			col => y,
			dot => dot);

		grid_align_e : entity hdl4fpga.align
		generic map (
			n => 1,
			d => (0 to 0 => -1+unsigned_num_bits(height-1)))
		port map (
			clk   => video_clk,
			di(0) => dot,
			do(0) => grid_dot);
	end block;

	video_dot  <= (grid_dot or char_dot) & plot_dot;
	input_addr <= x;
end;
