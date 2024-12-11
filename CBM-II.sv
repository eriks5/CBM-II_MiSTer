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

assign ADC_BUS = 'Z;
assign {USER_OUT[6], USER_OUT[1:0]} = '1;
assign {UART_RTS, UART_TXD, UART_DTR} = 0;
assign {DDRAM_CLK, DDRAM_BURSTCNT, DDRAM_ADDR, DDRAM_DIN, DDRAM_BE, DDRAM_RD, DDRAM_WE} = '0;
assign {SD_SCK, SD_MOSI, SD_CS} = 'Z;

assign LED_DISK = 0;
assign LED_POWER = 0;
assign LED_USER = |drive_led | ioctl_download;
assign BUTTONS = 0;
assign VGA_DISABLE = 0;
assign VGA_SCALER = 0;

//////////////////////////////////////////////////////////////////

localparam NDRIVES=2;

// Status Bit Map:
//              Upper                          Lower
// 0         1         2         3          4         5         6
// 01234567890123456789012345678901 23456789012345678901234567890123
// 0123456789ABCDEFGHIJKLMNOPQRSTUV 0123456789ABCDEFGHIJKLMNOPQRSTUV
// XXXXXXXXXXXXXXXXXXXXXXXXX XXXXXX XXXXXXXXXXXXXXXXXXXX

`include "build_id.v"
localparam CONF_STR = {
	"CBM-II;;",
	"HAO[50],Drive #8 Type,8250,4040;",
	"HAHCS0,D80D82, Mount #8.0;",
	"HAHCS1,D80D82, Mount #8.1;",
	"HAhCS0,D64, Mount #8.0;",
	"HAhCS1,D64, Mount #8.1;",
	"HA-;",
	"HBO[51],Drive #9 Type,8250,4040;",
	"HBHDS2,D80D82, Mount #9.0;",
	"HBHDS3,D80D82, Mount #9.1;",
	"HBhDS2,D64, Mount #9.0;",
	"HBhDS3,D64, Mount #9.1;",
	"HB-;",
	"FE,PRG;",
	"-;",

	"P1,Hardware;",
	"P1O[4:2],System,730,720,710,630,620,610,500,Custom;",
	"h0P1-;",
	"h0P1O[6:5],Model,High Profile,Low Profile,Professional;",
//	"h0P1O[8:7],Co-processor,None,8088;",
	"h0P1O[10:9],RAM,256K,128K,1M;",
	"H0H1P1-;",
	"H1P1O[11],CPU Clock,1 MHz,2 MHz;",
	"h0h1P1-;H1h6P1-;",
	"h0h1P1O[37],Enable Joysticks,No,Yes;",
	"h6P1O[36],Swap Joysticks,No,Yes;",
	"H1P1O[33:32],Pot 1/2,Joy 1 Fire 2/3,Mouse,Paddles 1/2;",
	"H1P1O[35:34],Pot 3/4,Joy 2 Fire 2/3,Mouse,Paddles 3/4;",
	"P1-;",
	"P1O[47:46],Enable Drive #8,If Mounted,Always,Never;",
	"P1O[49:48],Enable Drive #9,If Mounted,Always,Never;",
	"P1O[45],Enable External IEC,No,Yes;",
	"P1R[44],Reset Drives;",
	"P1-;",
	"P1O[13],Release Keys on Reset,Yes,No;",
	"P1O[14],Clear All RAM on Reset,Yes,No;",
	"P1O[15],Pause When OSD is Open,No,Yes;",

   "P2,Audio & Video;",
	"H2P2O[12],TV System,PAL,NTSC;",
	"H2P2-;",
	"P2O[17:16],Aspect Ratio,Original,Full Screen,[ARC1],[ARC2];",
	"P2O[20:18],Scandoubler Fx,None,HQ2x-320,HQ2x-160,CRT 25%,CRT 50%,CRT 75%;",
	"d3P2O[21],Vertical Crop,No,Yes;",
	"P2O[23:22],Scale,Normal,V-Integer,Narrower HV-Integer,Wider HV-Integer;",
	"P2-;",
	"P2O[28:26],SID Filter,Default,Custom 1,Custom 2,Custom 3,Adjustable;",
	"D5P2O[31:29],Fc Offset,0,1,2,3,4,5;",
	"P2FCF,FLT,Load Custom Filters;",

	"P3,Loadable ROMs;",
	"P3-,Model 500 ROMs;",
	"P3FC2,ROMBIN, Load Basic                 ;",
	"P3FC3,ROMBIN, Load Kernal                ;",
	"P3FCB,ROMBIN, Load Charset               ;",
	"P3-;",
	"P3-,Model 6x0/7x0 ROMs;",
	"P3FC4,ROMBIN, Load Basic 128             ;",
	"P3FC5,ROMBIN, Load Basic 256             ;",
	"P3FC6,ROMBIN, Load Kernal                ;",
// "P3FC7,ROMBIN, Load Coprocessor Bios      ;",
	"P3FCC,ROMBIN, Load Model 600 Charset     ;",
	"P3FCD,ROMBIN, Load Model 700 Charset     ;",
	"P3-;",
	"P3-,External ROM/RAM;",
   "P3O[24], Bank $1000,Disabled,RAM;",
   "P3O[39:38], Bank $2000,Disabled,ROM,RAM;",
	"h7P3FC8,ROMBIN,  Load Rom Bank $2000       ;",
   "P3O[41:40], Bank $4000,Disabled,ROM,RAM;",
	"h8P3FC9,ROMBIN,  Load Rom Bank $4000       ;",
   "P3O[43:42], Bank $6000,Disabled,ROM,RAM;",
	"h9P3FCA,ROMBIN,  Load Rom Bank $6000       ;",

	"-;",
 	"R[0],Hard reset;",
	"R[1],Soft reset;",
	"J,Fire 1,Fire 2,Fire 3,Paddle Btn;",
	"jn,A,B,Y,X|P;",
	"jp,A,B,Y,X|P;",
	"v,0;",
	"V,v",`BUILD_DATE
};

wire pll_locked;
wire clk_sys;
wire clk_dbl;
wire clk48;

pll pll
(
	.refclk(CLK_50M),
	.outclk_0(clk48),
	.outclk_1(clk_dbl),
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
	reg [3:0] state = 0;
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
					cfg_data <= model_r ? 'h40404 : 'h60504;
					cfg_write <= 1;
				end
			5: begin
					cfg_address <= 5;
					cfg_data <= model_r ? 'h80808 : 'h80909;
					cfg_write <= 1;
				end
			7: begin
					cfg_address <= 7;
					cfg_data <= model_r ? 2233382994 : (ntsc_r ? 3357876127 : 1503512573);
					cfg_write <= 1;
				end
			9: begin
					cfg_address <= 2;
					cfg_data <= 0;
					cfg_write <= 1;
				end
		endcase
	end
end

reg reset_n;
reg sys_reset_n;
reg reset_wait = 0;
always @(posedge clk_sys) begin
	integer   reset_counter;
	reg [8:0] cfg_r;
	reg       ntsc_r;
	reg       do_erase = 1;
	reg [1:0] do_erase_sram = 2; // 0 - no, 1 - seg 15 bank0+ vidram, 2 - all sram

	cfg_r <= status[10:2];
	ntsc_r <= ntsc;

	reset_n <= !reset_counter;
	sys_reset_n <= !(reset_counter && do_erase_sram);

	if (RESET || (cfg_r != status[10:2]) || status[0] || !pll_locked) begin
		do_erase <= do_erase | status[14] | RESET;

		if (RESET)
			do_erase_sram <= 2'd2;
		else if (do_erase < 2)
			do_erase_sram <= status[14] ? 2'd1 : 2'd2;

		reset_counter <= 100000;
	end
	else if (ntsc_r != ntsc || status[1] || buttons[1])
		reset_counter <= 255;
	else if (ioctl_download && load_rom) begin
		do_erase <= status[14];
		do_erase_sram <= status[14] ? 2'd1 : 2'd2;
		reset_counter <= 255;
	end
	else if (erasing) force_erase <= 0;
	else if (erasing_sram) force_erase_sram <= 0;
	else if (!reset_counter) begin
		do_erase <= 0;
		do_erase_sram <= 0;
	end
	else if (reset_counter) begin
		reset_counter <= reset_counter - 1;
		if (reset_counter == 100) begin
			force_erase <= do_erase;
			force_erase_sram <= do_erase_sram;
		end
	end
end

localparam NDU = NDRIVES*2;

wire   [127:0] status;

wire           forced_scandoubler;

wire           ioctl_wr;
wire    [24:0] ioctl_addr;
wire     [7:0] ioctl_data;
wire     [7:0] ioctl_index;
wire           ioctl_download;

wire    [31:0] sd_lba[NDU];
wire     [5:0] sd_blk_cnt[NDU];
wire [NDU-1:0] sd_rd;
wire [NDU-1:0] sd_wr;
wire [NDU-1:0] sd_ack;
wire    [12:0] sd_buff_addr;
wire     [7:0] sd_buff_dout;
wire     [7:0] sd_buff_din[NDU];
wire           sd_buff_wr;
wire [NDU-1:0] img_mounted;
wire    [31:0] img_size;
wire           img_readonly;

wire    [24:0] ps2_mouse;
wire    [10:0] ps2_key;
wire     [2:0] ps2_kbd_led_status = {2'b00, sftlk_sense};
wire     [2:0] ps2_kbd_led_use = 3'b001;

wire     [1:0] buttons;
wire           sftlk_sense;

wire    [21:0] gamma_bus;

wire           joy_en = ~model | (cfgcust & status[37]);
wire    [15:0] joyA, joyB, joyC, joyD;
wire     [7:0] pd1, pd2,pd3, pd4;

hps_io #(.CONF_STR(CONF_STR), .VDNUM(NDU), .BLKSZ(1)) hps_io
(
	.clk_sys(clk_sys),
	.HPS_BUS(HPS_BUS),
	.EXT_BUS(),

	.status(status),
	.status_menumask({
		/* D */ status[51], // drive #9 type
		/* C */ status[50], // drive #8 type
		/* B */ status[49], // drive #9 enabled
		/* A */ status[47], // drive #8 enabled
		/* 9 */ status[42],
		/* 8 */ status[40],
		/* 7 */ status[38],
		/* 6 */ joy_en,
		/* 5 */ ~status[28],
		/* 4 */ 1'b0,
		/* 3 */ |vcrop,
		/* 2 */ model7x0,
		/* 1 */ model,
		/* 0 */ cfgcust
	}),
	.buttons(buttons),
	.forced_scandoubler(forced_scandoubler),
	.gamma_bus(gamma_bus),

	.sd_lba(sd_lba),
	.sd_blk_cnt(sd_blk_cnt),
	.sd_rd(sd_rd),
	.sd_wr(sd_wr),
	.sd_ack(sd_ack),

	.sd_buff_addr(sd_buff_addr),
	.sd_buff_dout(sd_buff_dout),
	.sd_buff_din(sd_buff_din),
	.sd_buff_wr(sd_buff_wr),
	.img_mounted(img_mounted),
	.img_size(img_size),
	.img_readonly(img_readonly),

   .ps2_key(ps2_key),
	.ps2_mouse(ps2_mouse),
   .ps2_kbd_led_status(ps2_kbd_led_status),
   .ps2_kbd_led_use(ps2_kbd_led_use),

	.joystick_0(joyA),
	.joystick_1(joyB),
	.joystick_2(joyC),
	.joystick_3(joyD),

	.paddle_0(pd1),
	.paddle_1(pd2),
	.paddle_2(pd3),
	.paddle_3(pd4),

	.ioctl_download(ioctl_download),
	.ioctl_index(ioctl_index),
	.ioctl_wr(ioctl_wr),
	.ioctl_addr(ioctl_addr),
	.ioctl_dout(ioctl_data),
	.ioctl_wait(ioctl_req_wr|reset_wait)
);

wire load_rom = ioctl_index[5:0] >= 2 && ioctl_index[5:0] < 11;
wire load_chr = ioctl_index[5:0] >= 11 && ioctl_index[5:0] < 14;
wire load_prg = ioctl_index[5:0] == 14;
wire load_flt = ioctl_index[5:0] == 15;

wire       model500 = status[4:2] == 6;
wire       model6x0 = status[4:2] == 3 || status[4:2] == 4 || status[4:2] == 5;
wire       model7x0 = status[4:2] == 0 || status[4:2] == 1 || status[4:2] == 2;
wire       modelx10 = status[4:2] == 2 || status[4:2] == 5;
// wire    modelx20 = status[4:2] == 1 || status[4:2] == 4;
wire       modelx30 = status[4:2] == 0 || status[4:2] == 3;
wire       cfgcust  = status[4:2] == 7;

// System configuration
wire       model   = cfgcust ? ~status[6]    : model6x0|model7x0;         // 0=P, 1=B
wire       profile = cfgcust ? ~|status[6:5] : model7x0;                  // 0=P/L, 1=H
wire [1:0] copro   = cfgcust ? status[8:7]   : {1'b0, modelx30};          // 0=None, 1=8088, 2/3=reserved
wire [1:0] ramsize = cfgcust ? status[10:9]  : {1'b0, model500|modelx10}; // 0=256k, 1=128k, 2=1M
wire       ntsc    = status[12] | model7x0;                               // 0=PAL/50, 1=NTSC/60

// ========================================================================
// I/O
// ========================================================================

reg        erasing, force_erase;

reg [24:0] ioctl_load_addr;
reg        ioctl_req_wr;

reg        inj_meminit = 0;

wire       io_cycle;
reg        io_cycle_ce;
reg        io_cycle_we;
reg [24:0] io_cycle_addr;
reg  [7:0] io_cycle_data;

always @(posedge clk_sys) begin
	reg  [4:0] erase_to;
	reg        old_download;
	reg        io_cycleD;
	reg [15:0] inj_start, inj_end;
	reg  [7:0] inj_meminit_data;

	old_download <= ioctl_download;
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
				io_cycle_data <= {8{ioctl_load_addr[14]^ioctl_load_addr[3]^ioctl_load_addr[2]}};
			else if (inj_meminit)
				io_cycle_data <= inj_meminit_data;
			else
				io_cycle_data <= ioctl_data;
		end
	end

	if (io_cycle & ~io_cycleD) io_cycle_ce <= 0;

	if (ioctl_wr) begin
		if (load_prg) begin
			if (ioctl_addr == 0) begin
				ioctl_load_addr[24:16] <= model ? 9'd1 : 9'd0;
				ioctl_load_addr[7:0] <= ioctl_data;
				inj_start[7:0] <= ioctl_data;
				inj_end[7:0] <= ioctl_data;
			end
			else if (ioctl_addr == 1) begin
				ioctl_load_addr[15:8] <= ioctl_data;
				inj_start[15:8] <= ioctl_data;
				inj_end[15:8] <= ioctl_data;
			end
			else begin
				ioctl_req_wr <= 1;
				inj_end <= inj_end + 1'b1;
			end
		end
	end

	// meminit for RAM injection
	if (old_download != ioctl_download && load_prg && !inj_meminit) begin
		inj_meminit <= 1;
		ioctl_load_addr <= 25'h00F_0000;
	end

	if (inj_meminit && !ioctl_req_wr) begin
		if (ioctl_load_addr[8]) begin
			inj_meminit <= 0;
			// start_strk <= 1;
		end
		else begin
			ioctl_req_wr <= 1;

			// Initialize BASIC pointers to simulate the BASIC LOAD command
			case(ioctl_load_addr[7:0])
				// TXTTAB (2D-2E)
				'h2D: inj_meminit_data <= inj_start[7:0];
				'h2E: inj_meminit_data <= inj_start[15:8];

				// TXTEND (2F-30)
				'h2F: inj_meminit_data <= inj_end[7:0];
				'h30: inj_meminit_data <= inj_end[15:8];

				default: begin
					ioctl_req_wr <= 0;
					ioctl_load_addr <= ioctl_load_addr + 1'b1;
				end
			endcase
		end
	end

	if (!erasing && force_erase) begin
		erasing <= force_erase;
		ioctl_load_addr <= model ? 25'h01_0000 : 25'h00_0000;
	end

	if (erasing && !ioctl_req_wr) begin
		erase_to <= erase_to + 1'b1;
		if (&erase_to) begin
			if ((ramsize == 1 && model == 0 && ioctl_load_addr == 'h01_FFFF) // 128k P
		     ||(ramsize == 1 && model == 1 && ioctl_load_addr == 'h02_FFFF) // 128k B
			  ||(ramsize == 0 && model == 0 && ioctl_load_addr == 'h03_FFFF) // 256k P
			  ||(ramsize == 0 && model == 1 && ioctl_load_addr == 'h04_FFFF) // 256k B
			  ||(ioctl_load_addr == 'h0E_FFFF)                               // 1M
			)
				erasing <= 0;
			else
				ioctl_req_wr <= 1;
		end
	end
end

reg [11:0] sid_ld_addr = 0;
reg [15:0] sid_ld_data = 0;
reg        sid_ld_wr   = 0;
always @(posedge clk_sys) begin
	sid_ld_wr <= 0;
	if(ioctl_wr && load_flt && ioctl_addr < 6144) begin
		if(ioctl_addr[0]) begin
			sid_ld_data[15:8] <= ioctl_data;
			sid_ld_addr <= ioctl_addr[12:1];
			sid_ld_wr <= 1;
		end
		else begin
			sid_ld_data[7:0] <= ioctl_data;
		end
	end
end

// ========================================================================
// Static RAM
// ========================================================================

reg  [1:0] erasing_sram, force_erase_sram;
reg [12:0] erase_sram_addr;

always @(posedge clk_sys) begin
	reg [4:0] erase_to;

	if (force_erase_sram) begin
		erasing_sram <= force_erase_sram;
		erase_sram_addr <= 0;
		erase_to <= 0;
	end

	if (erasing_sram) begin
		erase_to <= erase_to + 1'b1;
		if (&erase_to) begin
			if (erase_sram_addr == {erasing_sram[1],12'hFFF})
				erasing_sram <= 0;
			else
				erase_sram_addr <= erase_sram_addr + 1'b1;
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

	.clk(clk_dbl),
	.init(~pll_locked),
	.refresh(refresh),
	.addr(io_cycle ? io_cycle_addr : cpu_addr),
	.ce  (io_cycle ? io_cycle_ce   : cpu_ce),
	.we  (io_cycle ? io_cycle_we   : cpu_we),
	.din (io_cycle ? io_cycle_data : cpu_out),
	.dout(sdram_data)
);

// ========================================================================
// Joystick/paddles/mouse
// ========================================================================

wire [7:0] mouse_x;
wire [7:0] mouse_y;
wire [1:0] mouse_btn;

c1351 mouse
(
	.clk_sys(clk_sys),
	.reset(~reset_n),

	.ps2_mouse(ps2_mouse),

	.potX(mouse_x),
	.potY(mouse_y),
	.button(mouse_btn)
);

wire  [1:0] pd12_mode = status[33:32];
wire  [1:0] pd34_mode = status[35:34];

wire  [6:0] joyA_int = {joyA[6:4], joyA[0], joyA[1], joyA[2], joyA[3]};
wire  [6:0] joyB_int = {joyB[6:4], joyB[0], joyB[1], joyB[2], joyB[3]};
wire  [6:0] joyA_cbm = status[36] ? joyB_int : joyA_int;
wire  [6:0] joyB_cbm = status[36] ? joyA_int : joyB_int;

wire  [7:0] paddle_1 = status[36] ? pd3 : pd1;
wire  [7:0] paddle_2 = status[36] ? pd4 : pd2;
wire  [7:0] paddle_3 = status[36] ? pd1 : pd3;
wire  [7:0] paddle_4 = status[36] ? pd2 : pd4;

wire        paddle_1_btn = status[36] ? joyC[7] : joyA[7];
wire        paddle_2_btn = status[36] ? joyD[7] : joyB[7];
wire        paddle_3_btn = status[36] ? joyA[7] : joyC[7];
wire        paddle_4_btn = status[36] ? joyB[7] : joyD[7];

// ========================================================================
// CBM-II Main
// ========================================================================

wire [24:0] cpu_addr;
wire        cpu_ce;
wire  [7:0] cpu_out;
wire        cpu_we;

wire        pause;

wire        refresh;
wire  [7:0] r, g, b;
wire        hsync, vsync;

wire [17:0] audio;

st_ieee_bus ieee_bus_te;
st_ieee_bus ieee_bus_dc;

cbm2_main main (
	.CLK(CLK),

	.model(model),
	.profile(profile),
	.ntsc(ntsc),
	.turbo(status[11]),
	.ramSize(ramsize),
	.copro(copro),
	.extbankrom({status[42], status[40], status[38]}),
	.extbankram({status[43], status[41], status[39], status[24]}),

	.pause(freeze),
	.pause_out(pause),

	.clk_sys(clk_sys),
	.reset_n(reset_n),

	.kbd_reset(~sys_reset_n & ~status[13]),
	.ps2_key(ps2_key),

	.joy_en(joy_en),
	.joya({joyA_cbm[4:0] | {1'b0, pd12_mode[1] & paddle_2_btn, pd12_mode[1] & paddle_1_btn, 2'b00} | {pd12_mode[0] & mouse_btn[0], 3'b000, pd12_mode[0] & mouse_btn[1]}}),
	.joyb({joyB_cbm[4:0] | {1'b0, pd34_mode[1] & paddle_4_btn, pd34_mode[1] & paddle_3_btn, 2'b00} | {pd34_mode[0] & mouse_btn[0], 3'b000, pd34_mode[0] & mouse_btn[1]}}),

	.pot1(pd12_mode[1] ? paddle_1 : pd12_mode[0] ? mouse_x : {8{joyA_cbm[5]}}),
	.pot2(pd12_mode[1] ? paddle_2 : pd12_mode[0] ? mouse_y : {8{joyA_cbm[6]}}),
	.pot3(pd34_mode[1] ? paddle_3 : pd34_mode[0] ? mouse_x : {8{joyB_cbm[5]}}),
	.pot4(pd34_mode[1] ? paddle_4 : pd34_mode[0] ? mouse_y : {8{joyB_cbm[6]}}),

	.sid_ld_clk(clk_sys),
	.sid_ld_addr(sid_ld_addr),
	.sid_ld_data(sid_ld_data),
	.sid_ld_wr(sid_ld_wr),
	.sid_cfg(status[27:26]),
	.sid_fc_off(status[28] ? (13'h600 - {status[31:29],7'd0}) : 13'd0),

	.ieee_i(ieee_bus_te),
	.ieee_o(ieee_bus_dc),

	.iec_atn_o(cbm_iec_atn),
	.iec_clk_o(cbm_iec_clk),
	.iec_clk_i(ext_iec_clk),
	.iec_data_o(cbm_iec_data),
	.iec_data_i(ext_iec_data),

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

	.audio(audio),

	.sftlk_sense(sftlk_sense),

   .erase_sram(erasing_sram),
	.rom_id  (!erasing_sram ? ioctl_index[5:0] : 0),
	.rom_addr(!erasing_sram ? ioctl_addr : erase_sram_addr),
	.rom_wr  (!erasing_sram ? ((load_rom || load_chr) && !ioctl_addr[24:14] && ioctl_download && ioctl_wr) : 1'b1),
	.rom_data(!erasing_sram ? ioctl_data : {8{erase_sram_addr[6]}})
);

// ========================================================================
// IEEE
// ========================================================================

wire drive_reset = ~sys_reset_n | status[44];
wire [1:0] drive_led;

reg [3:0] drive_mounted = 0;
always @(posedge clk_sys) begin 
	if(img_mounted[0]) drive_mounted[0] <= |img_size;
	if(img_mounted[1]) drive_mounted[1] <= |img_size;
	if(img_mounted[2]) drive_mounted[2] <= |img_size;
	if(img_mounted[3]) drive_mounted[3] <= |img_size;
end

ieee_drive #(.DRIVES(NDRIVES)) ieee_drive
(
	.CLK(CLK),

	.clk_sys(clk_sys),
	.reset({drive_reset | ((!status[49:48]) ? !drive_mounted[3:2] : status[49]),
		     drive_reset | ((!status[47:46]) ? !drive_mounted[1:0] : status[47])}),

	.pause(pause),

	.led(drive_led),

	.bus_i(ieee_bus_dc),
	.bus_o(ieee_bus_te),

	.sd_lba(sd_lba),
	.sd_blk_cnt(sd_blk_cnt),
	.sd_rd(sd_rd),
	.sd_wr(sd_wr),
	.sd_ack(sd_ack),
	.sd_buff_addr(sd_buff_addr),
	.sd_buff_dout(sd_buff_dout),
	.sd_buff_din(sd_buff_din),
	.sd_buff_wr(sd_buff_wr),

	.drv_type({status[51], status[50]}),

	.img_mounted(img_mounted),
	.img_readonly(img_readonly),
	.img_size(img_size)

	// .rom_addr(load_rom ? (ioctl_addr[15:0] - 16'h4000) : {1'b1,ioctl_addr[14:0]}),
	// .rom_data(ioctl_data),
	// .rom_wr(((load_rom && ioctl_addr[16:14]) || load_c1581) && ioctl_download && ioctl_wr),
	// .rom_std(status[14])
);

// ========================================================================
// External IEC
// ========================================================================

wire cbm_iec_atn;
wire cbm_iec_clk;
wire cbm_iec_data;

wire ext_iec_en   = status[45];
wire ext_iec_clk  = USER_IN[2] | ~ext_iec_en;
wire ext_iec_data = USER_IN[4] | ~ext_iec_en;

assign USER_OUT[2] = cbm_iec_clk | ~ext_iec_en;
assign USER_OUT[3] = (reset_n & ~status[44]) | ~ext_iec_en;
assign USER_OUT[4] = cbm_iec_data | ~ext_iec_en;
assign USER_OUT[5] = cbm_iec_atn | ~ext_iec_en;

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
	.video_out(~model),
	.bypass(0),
	.pause(pause),
	.wide(wide),

	.hsync(hsync),
	.vsync(vsync),

	.hsync_out(hsync_out),
	.vsync_out(vsync_out),
	.hblank(hblank),
	.vblank(vblank)
);

reg hq2x160;
reg hq2x320;
always @(posedge clk_sys) begin
   reg old_vsync;

   old_vsync <= vsync_out;
   if (!old_vsync && vsync_out) begin
      hq2x320 <= (status[20:8] == 1);
      hq2x160 <= (status[20:8] == 2);
   end
end

reg ce_pix;
always @(posedge CLK_VIDEO) begin
   reg       model_r;
   reg [1:0] div;
   reg [1:0] lores;

   model_r <= model;
   if (model != model_r) begin
      div <= 0;
      lores <= 0;
      ce_pix <= 0;
   end
   else if (model) begin
      div <= div + 1'd1;
      ce_pix <= !div[0];
   end
   else begin
      div <= div + 1'd1;
      if (&div) lores <= lores + 1'd1;
      ce_pix <= (~|lores | ~hq2x160) && (~lores[0] | ~hq2x320) && !div;
   end
end

wire scandoubler = status[20:18] || forced_scandoubler;

assign CLK_VIDEO = clk_dbl;
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

// ========================================================================
// Audio
// ========================================================================

assign AUDIO_S = 1;
assign AUDIO_L = audio[17:2];
assign AUDIO_R = audio[17:2];
assign AUDIO_MIX = 0;

endmodule
