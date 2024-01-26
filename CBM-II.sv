//============================================================================
//
//  This program is free software; you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the Free
//  Software Foundation; either version 2 of the License, or (at your option)
//  any later version.
//
//  This program is distributed in the hope that it will be useful, but WITHOUT
//  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
//  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
//  more details.
//
//  You should have received a copy of the GNU General Public License along
//  with this program; if not, write to the Free Software Foundation, Inc.,
//  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
//
//============================================================================

module emu
(
	//Master input clock
	input         CLK_50M,

	//Async reset from top-level module.
	//Can be used as initial reset.
	input         RESET,

	//Must be passed to hps_io module
	inout  [48:0] HPS_BUS,

	//Base video clock. Usually equals to CLK_SYS.
	output        CLK_VIDEO,

	//Multiple resolutions are supported using different CE_PIXEL rates.
	//Must be based on CLK_VIDEO
	output        CE_PIXEL,

	//Video aspect ratio for HDMI. Most retro systems have ratio 4:3.
	//if VIDEO_ARX[12] or VIDEO_ARY[12] is set then [11:0] contains scaled size instead of aspect ratio.
	output [12:0] VIDEO_ARX,
	output [12:0] VIDEO_ARY,

	output  [7:0] VGA_R,
	output  [7:0] VGA_G,
	output  [7:0] VGA_B,
	output        VGA_HS,
	output        VGA_VS,
	output        VGA_DE,    // = ~(VBlank | HBlank)
	output        VGA_F1,
	output [1:0]  VGA_SL,
	output        VGA_SCALER, // Force VGA scaler
	output        VGA_DISABLE, // analog out is off

	input  [11:0] HDMI_WIDTH,
	input  [11:0] HDMI_HEIGHT,
	output        HDMI_FREEZE,

`ifdef MISTER_FB
	// Use framebuffer in DDRAM
	// FB_FORMAT:
	//    [2:0] : 011=8bpp(palette) 100=16bpp 101=24bpp 110=32bpp
	//    [3]   : 0=16bits 565 1=16bits 1555
	//    [4]   : 0=RGB  1=BGR (for 16/24/32 modes)
	//
	// FB_STRIDE either 0 (rounded to 256 bytes) or multiple of pixel size (in bytes)
	output        FB_EN,
	output  [4:0] FB_FORMAT,
	output [11:0] FB_WIDTH,
	output [11:0] FB_HEIGHT,
	output [31:0] FB_BASE,
	output [13:0] FB_STRIDE,
	input         FB_VBL,
	input         FB_LL,
	output        FB_FORCE_BLANK,

`ifdef MISTER_FB_PALETTE
	// Palette control for 8bit modes.
	// Ignored for other video modes.
	output        FB_PAL_CLK,
	output  [7:0] FB_PAL_ADDR,
	output [23:0] FB_PAL_DOUT,
	input  [23:0] FB_PAL_DIN,
	output        FB_PAL_WR,
`endif
`endif

	output        LED_USER,  // 1 - ON, 0 - OFF.

	// b[1]: 0 - LED status is system status OR'd with b[0]
	//       1 - LED status is controled solely by b[0]
	// hint: supply 2'b00 to let the system control the LED.
	output  [1:0] LED_POWER,
	output  [1:0] LED_DISK,

	// I/O board button press simulation (active high)
	// b[1]: user button
	// b[0]: osd button
	output  [1:0] BUTTONS,

	input         CLK_AUDIO, // 24.576 MHz
	output [15:0] AUDIO_L,
	output [15:0] AUDIO_R,
	output        AUDIO_S,   // 1 - signed audio samples, 0 - unsigned
	output  [1:0] AUDIO_MIX, // 0 - no mix, 1 - 25%, 2 - 50%, 3 - 100% (mono)

	//ADC
	inout   [3:0] ADC_BUS,

	//SD-SPI
	output        SD_SCK,
	output        SD_MOSI,
	input         SD_MISO,
	output        SD_CS,
	input         SD_CD,

	//High latency DDR3 RAM interface
	//Use for non-critical time purposes
	output        DDRAM_CLK,
	input         DDRAM_BUSY,
	output  [7:0] DDRAM_BURSTCNT,
	output [28:0] DDRAM_ADDR,
	input  [63:0] DDRAM_DOUT,
	input         DDRAM_DOUT_READY,
	output        DDRAM_RD,
	output [63:0] DDRAM_DIN,
	output  [7:0] DDRAM_BE,
	output        DDRAM_WE,

	//SDRAM interface with lower latency
	output        SDRAM_CLK,
	output        SDRAM_CKE,
	output [12:0] SDRAM_A,
	output  [1:0] SDRAM_BA,
	inout  [15:0] SDRAM_DQ,
	output        SDRAM_DQML,
	output        SDRAM_DQMH,
	output        SDRAM_nCS,
	output        SDRAM_nCAS,
	output        SDRAM_nRAS,
	output        SDRAM_nWE,

`ifdef MISTER_DUAL_SDRAM
	//Secondary SDRAM
	//Set all output SDRAM_* signals to Z ASAP if SDRAM2_EN is 0
	input         SDRAM2_EN,
	output        SDRAM2_CLK,
	output [12:0] SDRAM2_A,
	output  [1:0] SDRAM2_BA,
	inout  [15:0] SDRAM2_DQ,
	output        SDRAM2_nCS,
	output        SDRAM2_nCAS,
	output        SDRAM2_nRAS,
	output        SDRAM2_nWE,
`endif

	input         UART_CTS,
	output        UART_RTS,
	input         UART_RXD,
	output        UART_TXD,
	output        UART_DTR,
	input         UART_DSR,

	// Open-drain User port.
	// 0 - D+/RX
	// 1 - D-/TX
	// 2..6 - USR2..USR6
	// Set USER_OUT to 1 to read from USER_IN.
	input   [6:0] USER_IN,
	output  [6:0] USER_OUT,

	input         OSD_STATUS
);

assign ADC_BUS  = 'Z;
assign USER_OUT = '1;
assign {UART_RTS, UART_TXD, UART_DTR} = 0;
assign {DDRAM_CLK, DDRAM_BURSTCNT, DDRAM_ADDR, DDRAM_DIN, DDRAM_BE, DDRAM_RD, DDRAM_WE} = '0;
assign {SD_SCK, SD_MOSI, SD_CS} = 'Z;

assign AUDIO_S = 0;
assign AUDIO_L = 0;
assign AUDIO_R = 0;
assign AUDIO_MIX = 0;

assign LED_DISK = 0;
assign LED_POWER = 0;
assign LED_USER = 0;
assign BUTTONS = 0;
assign VGA_DISABLE = 0;
assign VGA_SCALER = 0;

//////////////////////////////////////////////////////////////////

// Status Bit Map:
//              Upper                          Lower
// 0         1         2         3          4         5         6
// 01234567890123456789012345678901 23456789012345678901234567890123
// 0123456789ABCDEFGHIJKLMNOPQRSTUV 0123456789ABCDEFGHIJKLMNOPQRSTUV
// XXXXXXXXXXXXXXXXXXXXXXXX

`include "build_id.v"
localparam CONF_STR = {
	"CBM-II;;",
	"P1,Hardware;",
	"P1O[4:2],System,500,610,620,630,710,720,730,Custom;",
	"h0P1-;H0H1P1-;",
	"h0P1O[6:5],Model,Professional,Low Profile,High Profile;",
	"h0P1O[8:7],Co-processor,None,8088,Z80;",
	"h0P1O[10:9],RAM,256K,128K,64K,1M;",
	"H1P1O[11],CPU Clock,1 MHz,2 MHz;",
	"P1-;",
	"P1FC8,ROMBIN,Load Rom $1000              ;",
  	"P1FC7,ROMBIN,Load Rom $2000              ;",
  	"P1FC6,ROMBIN,Load Rom $4000              ;",
  	"P1FC5,ROMBIN,Load Rom $6000              ;",
  	"P1FC4,ROMBIN,Load Rom $8000 (Basic)      ;",
   "H1P1FC3,ROMBIN,Load Rom $C000 (VIC Char)   ;",
   "h1P1FC3,ROMBIN,Load Rom $C000              ;",
   "P1FC2,ROMBIN,Load Rom $E000 (Kernal)     ;",
   "h1P1FC9,ROMBIN,Load CRTC Char ROM          ;",
	"P1-;",
	"P1O[13],Release Keys on Reset,Yes,No;",
	"P1O[14],Clear All RAM on Reset,Yes,No;",
	"P1O[15],Pause When OSD is Open,No,Yes;",
   "P2,Audio & Video;",
	"H2P2O[12],TV System,PAL,NTSC;",
	"H2P2-;",
	"P2O[17:16],Aspect Ratio,Original,Full Screen,[ARC1],[ARC2];",
	"P2O[20:18],Scandoubler Fx,None,HQ2x-320,HQ2x-160,CRT 25%,CRT 50%,CRT 75%;",
	"P2d3O[21],Vertical Crop,No,Yes;",
	"P2O[23:22],Scale,Normal,V-Integer,Narrower HV-Integer,Wider HV-Integer;",
	"-;",
 	"R[0],Hard reset;",
	"R[1],Soft reset;",
	"v,0;",
	"V,v",`BUILD_DATE
};

wire pll_locked;
wire clk_sys;
wire clk64;
wire clk48;

pll pll
(
	.refclk(CLK_50M),
	.outclk_0(clk48),
	.outclk_1(clk64),
	.outclk_2(clk_sys),
	.reconfig_to_pll(reconfig_to_pll),
	.reconfig_from_pll(reconfig_from_pll),
	.locked(pll_locked)
);

wire [63:0] reconfig_to_pll;
wire [63:0] reconfig_from_pll;
wire        cfg_waitrequest;
reg         cfg_write;
reg   [5:0] cfg_address;
reg  [31:0] cfg_data;

pll_cfg pll_cfg
(
	.mgmt_clk(CLK_50M),
	.mgmt_reset(0),
	.mgmt_waitrequest(cfg_waitrequest),
	.mgmt_read(0),
	.mgmt_readdata(),
	.mgmt_write(cfg_write),
	.mgmt_address(cfg_address),
	.mgmt_writedata(cfg_data),
	.reconfig_to_pll(reconfig_to_pll),
	.reconfig_from_pll(reconfig_from_pll)
);

wire [31:0] CLK = model ? 36_000_000
                : ntsc  ? 32_727_266
                :         31_527_954;

always @(posedge CLK_50M) begin
	reg ntscd = 0, ntscd2 = 0;
	reg modeld = 0, modeld2 = 0;
	reg [2:0] state = 0;
	reg ntsc_r, model_r;

	ntscd <= ntsc;
	ntscd2 <= ntscd;
	if(ntscd2 == ntscd && ntscd2 != ntsc_r) begin
		if (!model_r) state <= 1;
		ntsc_r <= ntscd2;
	end

	modeld <= model;
	modeld2 <= modeld;
	if(modeld2 == modeld && modeld2 != model_r) begin
		state <= 1;
		model_r <= modeld2;
	end

	cfg_write <= 0;
	if(!cfg_waitrequest) begin
		if(state) state<=state+1'd1;
		case(state)
			1: begin
					cfg_address <= 0;
					cfg_data <= 0;
					cfg_write <= 1;
				end
			3: begin
					cfg_address <= 5;
					cfg_data <= model_r ? 'h80808 : 'h80909;
					cfg_write <= 1;
				end
			5: begin
					cfg_address <= 7;
					cfg_data <= model_r ? 2233382994 : (ntsc_r ? 3357876127 : 1503512573);
					cfg_write <= 1;
				end
			7: begin
					cfg_address <= 2;
					cfg_data <= 0;
					cfg_write <= 1;
				end
		endcase
	end
end

reg reset_n;
reg reset_wait = 0;
always @(posedge clk_sys) begin
	integer   reset_counter;
	reg [8:0] cfg_r;
	reg [1:0] do_erase = 2'd2;  // 0 - no erase, 1 - erase segment 15 only, 2 - erase all segments

	cfg_r <= status[10:2];

	reset_n <= !reset_counter;

	if (RESET || (cfg_r != status[10:2]) || status[0] || status[1] || buttons[1] || soft_reset || !pll_locked) begin
		if (RESET)
			do_erase <= 2'd2;
		else if ((status[0] || (cfg_r != status[10:2])) && do_erase < 2)
			do_erase <= status[14] ? 2'd1 : 2'd2;

		reset_counter <= 100000;
	end
	else if (ioctl_download && (load_rom1 || load_rom2 || load_rom4 || load_rom6 || load_rom8 || (load_romC && model) || load_romE)) begin
		do_erase <= status[14] ? 2'd1 : 2'd2;
		reset_counter <= 255;
	end
	else if (erasing) force_erase <= 0;
	else if (!reset_counter) do_erase <= 0;
	else if (reset_counter) begin
		reset_counter <= reset_counter - 1;
		if (reset_counter == 100) force_erase <= do_erase;
	end
end

wire [127:0] status;

wire         forced_scandoubler;

wire         ioctl_wr;
wire  [24:0] ioctl_addr;
wire   [7:0] ioctl_data;
wire   [7:0] ioctl_index;
wire         ioctl_download;

wire  [10:0] ps2_key;
wire   [2:0] ps2_kbd_led_status = {2'b00, sftlk_sense};
wire   [2:0] ps2_kbd_led_use = 3'b001;

wire   [1:0] buttons;
wire         sftlk_sense;

wire  [21:0] gamma_bus;

hps_io #(.CONF_STR(CONF_STR)) hps_io
(
	.clk_sys(clk_sys),
	.HPS_BUS(HPS_BUS),
	.EXT_BUS(),

	.status(status),
	.status_menumask({
		/* 3 */ |vcrop,
		/* 2 */ cfg7x0,
		/* 1 */ model,
		/* 0 */ cfgcust
	}),
	.buttons(buttons),
	.forced_scandoubler(forced_scandoubler),
	.gamma_bus(gamma_bus),

   .ps2_key(ps2_key),
   .ps2_kbd_led_status(ps2_kbd_led_status),
   .ps2_kbd_led_use(ps2_kbd_led_use),

	.ioctl_download(ioctl_download),
	.ioctl_index(ioctl_index),
	.ioctl_wr(ioctl_wr),
	.ioctl_addr(ioctl_addr),
	.ioctl_dout(ioctl_data),
	.ioctl_wait(ioctl_req_wr|reset_wait)
);

wire load_char  = ioctl_index[5:0] == 9;
wire load_rom1  = ioctl_index[5:0] == 8;
wire load_rom2  = ioctl_index[5:0] == 7;
wire load_rom4  = ioctl_index[5:0] == 6;
wire load_rom6  = ioctl_index[5:0] == 5;
wire load_rom8  = ioctl_index[5:0] == 4;
wire load_romC  = ioctl_index[5:0] == 3;
wire load_romE  = ioctl_index[5:0] == 2;

wire       cfg500  = status[4:2] == 0;
// wire    cfg6x0  = status[4:2] == 1 || status[4:2] == 2 || status[4:2] == 3;
wire       cfg7x0  = status[4:2] == 4 || status[4:2] == 5 || status[4:2] == 6;
wire       cfgx10  = status[4:2] == 1 || status[4:2] == 4;
// wire    cfgx20  = status[4:2] == 2 || status[4:2] == 5;
wire       cfgx30  = status[4:2] == 3 || status[4:2] == 6;
wire       cfgcust = status[4:2] == 7;

// System configuration
wire       model   = cfgcust ? |status[6:5] : |status[4:2];            // 0=B, 1=P
wire       profile = cfgcust ? status[6]    : status[4];               // 0=B/L, 1=H
wire [1:0] copro   = cfgcust ? status[8:7]  : {1'b0, cfgx30};          // 0=None, 1=8088, 2=Z80
wire [1:0] ramsize = cfgcust ? status[10:9] : {1'b0, cfg500|cfgx10};   // 0=256k, 1=128k, 2=64k, 3=1M
wire       ntsc    = status[12] | cfg7x0;                              // 0=PAL/50, 1=NTSC/60

// ========================================================================
// I/O
// ========================================================================

reg [1:0]  force_erase;  // 1 - erase segment 15, 2 - erase all segments
reg        erasing;

reg [24:0] ioctl_load_addr;
reg        ioctl_req_wr;

wire       io_cycle;
reg        io_cycle_ce;
reg        io_cycle_we;
reg [24:0] io_cycle_addr;
reg  [7:0] io_cycle_data;

reg  [8:0] rom_loaded = 0;

always @(posedge clk_sys) begin
	reg  [4:0] erase_to;
	reg        io_cycleD;

	io_cycleD <= io_cycle;

	if (~io_cycle & io_cycleD) begin
		io_cycle_ce <= 1;
		io_cycle_we <= 0;
		if (ioctl_req_wr) begin
			ioctl_req_wr <= 0;
			io_cycle_we <= 1;
			io_cycle_addr <= ioctl_load_addr;
			ioctl_load_addr <= ioctl_load_addr + 1'b1;

			if (erasing)
				io_cycle_data <= &ioctl_load_addr[19:16] ? {8{ioctl_load_addr[6]}} : {8{ioctl_load_addr[14]^ioctl_load_addr[3]^ioctl_load_addr[2]}};
			else begin
				io_cycle_data <= ioctl_data;

				if (|ioctl_data && ~&ioctl_data)
					if (ioctl_load_addr[24:16] == 'h00F)
						rom_loaded[ioctl_load_addr[15:13]] <= 1;
					else if (ioctl_load_addr[24:16] == 'h010)
						rom_loaded[8] <= 1;
			end
		end
	end

	if (io_cycle & ~io_cycleD) io_cycle_ce <= 0;

	if (ioctl_wr) begin
		if (ioctl_addr == 0) begin
			if (load_rom1) ioctl_load_addr <= 25'h00F_1000;
			if (load_rom2) ioctl_load_addr <= 25'h00F_2000;
			if (load_rom4) ioctl_load_addr <= 25'h00F_4000;
			if (load_rom6) ioctl_load_addr <= 25'h00F_6000;
			if (load_rom8) ioctl_load_addr <= 25'h00F_8000;
			if (load_romC) ioctl_load_addr <= 25'h00F_C000;
			if (load_romE) ioctl_load_addr <= 25'h00F_E000;
			if (load_char) ioctl_load_addr <= 25'h010_0000;

			if (load_rom1 || load_rom2 || load_rom4 || load_rom6 || load_rom8 || load_romC || load_romE || load_char)
				ioctl_req_wr <= 1;
		end
		else if (load_char) begin
			if (ioctl_load_addr[24:12] == 'h010_0)
				ioctl_req_wr <= 1;
		end
		else if (load_rom1 || load_rom2 || load_rom4 || load_rom6 || load_rom8 || load_romC || load_romE) begin
			if (ioctl_load_addr[24:16] == 'h00F && ioctl_load_addr[15:12] != 'hD)
				ioctl_req_wr <= 1;
		end
	end

	if (!erasing && force_erase) begin
		erasing <= 1;
		ioctl_load_addr <= force_erase == 1 ? 25'h0F_0000 : model && ramsize < 3 ? 25'h01_0000 : 25'h00_0000;
	end

	if (erasing && !ioctl_req_wr) begin
		erase_to <= erase_to + 1'b1;
		if (&erase_to) begin
			if (  (ramsize == 2 && model == 0 && ioctl_load_addr == 'h00_FFFF) // 64k P
			   || (ramsize == 2 && model == 1 && ioctl_load_addr == 'h01_FFFF) // 64k B
			   || (ramsize == 1 && model == 0 && ioctl_load_addr == 'h01_FFFF) // 128k P
			   || (ramsize == 1 && model == 1 && ioctl_load_addr == 'h02_FFFF) // 128k B
			   || (ramsize == 0 && model == 0 && ioctl_load_addr == 'h03_FFFF) // 256k P
				|| (ramsize == 0 && model == 1 && ioctl_load_addr == 'h04_FFFF) // 256k B
			) begin
				ioctl_load_addr <= 25'h0F_0000;
			end
			else if (ioctl_load_addr == 'h0F_0FFF) begin
				ioctl_load_addr <= 25'h0F_D000;
			end

			if (ioctl_load_addr < 'h0F_DFFF)
				ioctl_req_wr <= 1;
			else
				erasing <= 0;
		end
	end
end

// ========================================================================
// SDRAM
// ========================================================================

assign SDRAM_CKE  = 1;

wire [7:0]  sdram_data;

sdram sdram
(
	.sd_addr(SDRAM_A),
	.sd_data(SDRAM_DQ),
	.sd_ba(SDRAM_BA),
	.sd_cs(SDRAM_nCS),
	.sd_we(SDRAM_nWE),
	.sd_ras(SDRAM_nRAS),
	.sd_cas(SDRAM_nCAS),
	.sd_clk(SDRAM_CLK),
	.sd_dqm({SDRAM_DQMH,SDRAM_DQML}),

	.clk(clk64),
	.init(~pll_locked),
	.refresh(refresh),
	.addr(io_cycle ? io_cycle_addr : cpu_addr),
	.ce  (io_cycle ? io_cycle_ce   : cpu_ce),
	.we  (io_cycle ? io_cycle_we   : cpu_we),
	.din (io_cycle ? io_cycle_data : cpu_out),
	.dout(sdram_data)
);

// ========================================================================
// CBM-II Main
// ========================================================================

wire [24:0] cpu_addr;
wire        cpu_ce;
wire        cpu_we;
wire [7:0]  cpu_out;

wire        pause;

wire        refresh;
wire [7:0]  r, g, b;
wire        hsync, vsync;

wire        soft_reset;

cbm2_main main (
	.CLK(CLK),

	.model(model),
	.profile(profile),
	.ntsc(ntsc),
	.turbo(status[11]),
	.ramSize(ramsize),
	.copro(copro),

	.extrom(rom_loaded),

	.pause(freeze),
	.pause_out(pause),

	.clk_sys(clk_sys),
	.reset_n(reset_n),

	.kbd_reset(~reset_n & ~status[13]),
	.ps2_key(ps2_key),

	.ramAddr(cpu_addr),
	.ramData(sdram_data),
	.ramOut(cpu_out),
	.ramCE(cpu_ce),
	.ramWE(cpu_we),
	.refresh(refresh),

	.io_cycle(io_cycle),

	.hsync(hsync),
	.vsync(vsync),
	.r(r),
	.g(g),
	.b(b),

	.sftlk_sense(sftlk_sense),
	.soft_reset(soft_reset)
);

// ========================================================================
// Video
// ========================================================================

wire hblank;
wire vblank;
wire hsync_out;
wire vsync_out;

video_sync sync
(
	.clk32(clk_sys),
	.pause(pause),
	.hsync(hsync),
	.vsync(vsync),
	.ntsc(ntsc),
	.wide(wide),
	.hsync_out(hsync_out),
	.vsync_out(vsync_out),
	.hblank(hblank),
	.vblank(vblank)
);

reg hq2x160;
always @(posedge clk_sys) begin
	reg old_vsync;

	old_vsync <= vsync_out;
	if (!old_vsync && vsync_out) begin
		hq2x160 <= (status[20:18] == 2);
	end
end

reg ce_pix;
always @(posedge CLK_VIDEO) begin
	reg [2:0] div;
	reg       lores;

	div <= div + 1'b1;
	if(&div) lores <= ~lores;
	ce_pix <= (~lores | ~hq2x160) && !div;
end

wire scandoubler = status[20:18] || forced_scandoubler;

assign CLK_VIDEO = clk64;
assign VGA_SL    = (status[20:18] > 2) ? status[19:18] - 2'd2 : 2'd0;
assign VGA_F1    = 0;

reg [9:0] vcrop;
reg wide;
always @(posedge CLK_VIDEO) begin
	vcrop <= 0;
	wide <= 0;
	if(HDMI_WIDTH >= (HDMI_HEIGHT + HDMI_HEIGHT[11:1]) && !scandoubler) begin
		if(HDMI_HEIGHT == 480)  vcrop <= 240;
		if(HDMI_HEIGHT == 600)  begin vcrop <= 200; wide <= vcrop_en; end
		if(HDMI_HEIGHT == 720)  vcrop <= 240;
		if(HDMI_HEIGHT == 768)  vcrop <= 256; // NTSC mode has 250 visible lines only!
		if(HDMI_HEIGHT == 800)  begin vcrop <= 200; wide <= vcrop_en; end
		if(HDMI_HEIGHT == 1080) vcrop <= 10'd216;
		if(HDMI_HEIGHT == 1200) vcrop <= 240;
	end
	else if(HDMI_WIDTH >= 1440 && !scandoubler) begin
		// 1920x1440 and 2048x1536 are 4:3 resolutions and won't fit in the previous if statement ( width > height * 1.5 )
		if(HDMI_HEIGHT == 1440) vcrop <= 240;
		if(HDMI_HEIGHT == 1536) vcrop <= 256;
	end
end

wire [1:0] ar = status[17:16];
wire vcrop_en = status[21];
wire vga_de;
video_freak video_freak
(
	.*,
	.VGA_DE_IN(vga_de),
	.ARX((!ar) ? (wide ? 12'd340 : 12'd400) : (ar - 1'd1)),
	.ARY((!ar) ? 12'd300 : 12'd0),
	.CROP_SIZE(vcrop_en ? vcrop : 10'd0),
	.CROP_OFF(0),
	.SCALE(status[23:22])
);

wire freeze_sync;
reg freeze;
always @(posedge clk_sys) begin
	reg old_sync;

	old_sync <= freeze_sync;
	if(old_sync ^ freeze_sync) freeze <= OSD_STATUS & status[15];
end

assign HDMI_FREEZE = freeze;

video_mixer #(.GAMMA(1)) video_mixer
(
	.CLK_VIDEO(CLK_VIDEO),

	.hq2x(~status[20] & (status[19] ^ status[18])),
	.scandoubler(scandoubler),
	.gamma_bus(gamma_bus),

	.ce_pix(ce_pix),
	.R(r),
	.G(g),
	.B(b),
	.HSync(hsync_out),
	.VSync(vsync_out),
	.HBlank(hblank),
	.VBlank(vblank),

	.HDMI_FREEZE(HDMI_FREEZE),
	.freeze_sync(freeze_sync),

	.CE_PIXEL(CE_PIXEL),
	.VGA_R(VGA_R),
	.VGA_G(VGA_G),
	.VGA_B(VGA_B),
	.VGA_VS(VGA_VS),
	.VGA_HS(VGA_HS),
	.VGA_DE(vga_de)
);

endmodule
