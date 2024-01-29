module cbm2_main (
   input         model,     // 0=Professional, 1=Business
   input         profile,   // 0=Low, 1=High (Business only)
   input         ntsc,      // 0=PAL, 1=NTSC
   input         turbo,     // 1=2MHz CPU clock (Professional only)
   input  [1:0]  ramSize,   // 0=64k, 1=128k, 2=256k, 3=1M
   input  [1:0]  copro,     // 0=none, 1=8088, 2=Z80

   input  [7:0]  extrom,

   input         pause,
   output        pause_out,

   input  [31:0] CLK,
   input         clk_sys,
   input         reset_n,

   input  [10:0] ps2_key,
   input         kbd_reset,

   output [24:0] ramAddr,
   input  [7:0]  ramData,    // from sdram
   output [7:0]  ramOut,     // to sdram
   output        ramCE,
   output        ramWE,

   output        refresh,
   output        io_cycle,

   output        hsync,
   output        vsync,
   output [7:0]  r,
   output [7:0]  g,
   output [7:0]  b,

   output        sftlk_sense,
   output        soft_reset
);

typedef enum bit[4:0] {
	CYCLE_EXT0, CYCLE_EXT1, CYCLE_EXT2, CYCLE_EXT3,
   CYCLE_CPU0, CYCLE_CPU1, CYCLE_CPU2, CYCLE_CPU3,
   CYCLE_CPU4, CYCLE_CPU5, CYCLE_CPU6, CYCLE_CPU7,
   CYCLE_VID0, CYCLE_VID1, CYCLE_VID2, CYCLE_VID3,
   CYCLE_VID4, CYCLE_VID5
} sysCycle_t;

sysCycle_t PHASE_START = sysCycle_t.first();
wire [4:0] PHASE_END   = model ? sysCycle_t.last() : CYCLE_VID3;

sysCycle_t sysCycle, preCycle;
reg        reset = 0;
reg        sysEnable;

wire       sys2MHz = model | (turbo & ~(cs_vic | cs_sid));
wire       coproEn = model & |copro;

// IOCTL cycle
assign io_cycle   = sysCycle >= CYCLE_EXT0 && sysCycle <= CYCLE_EXT3 && rfsh_cycle != 1 && (phase || !coproEn);

// Video cycle (VIC or CRTC)
wire vid_cycle    = (sysCycle >= CYCLE_VID0 && sysCycle <= CYCLE_VID5);

// CPU cycle
wire cpu_cycle    = (sysCycle >= CYCLE_CPU0 && sysCycle <= CYCLE_CPU3 && (phase || sys2MHz))
                 || (sysCycle >= CYCLE_CPU4 && sysCycle <= CYCLE_CPU7 && coproEn)
                 || (sysCycle >= CYCLE_EXT0 && sysCycle <= CYCLE_EXT3 && coproEn && !phase);

wire enableVic  = sysCycle == CYCLE_VID3;
wire enableCrtc = sysCycle == CYCLE_VID0.prev();
wire enableIO_n = sysCycle == CYCLE_CPU2        && (phase || sys2MHz);
wire enableIO_p = sysCycle == CYCLE_CPU3.next() && (phase || sys2MHz);
wire enableCpu  = sysCycle == CYCLE_CPU3        && (phase || sys2MHz);
wire pulseWr_io = enableCpu && cpuWe;

// assign ramWE = cpuWe && cpu_cycle;
assign ramCE = cs_ram && !sysCycle[4] && !sysCycle[1:0] && (cpu_cycle || vid_cycle);

assign ramAddr = systemAddr;
assign ramOut = cpuDo;

assign sysCycle = sysEnable ? preCycle : CYCLE_EXT0;
assign pause_out = ~sysEnable;

reg [2:0] rfsh_cycle = 0;
reg       phase;

always @(posedge clk_sys) begin
   preCycle <= preCycle.next();
   refresh <= 0;

   if (preCycle == PHASE_END) begin
      preCycle <= PHASE_START;
      phase <= ~phase;
      rfsh_cycle <= rfsh_cycle + 1'b1;

      if (rfsh_cycle == 0) begin
         sysEnable <= ~pause;
         refresh <= 1;
      end

      reset <= ~reset_n;
   end
end

reg [1:0] enablePixel;
always @(posedge clk_sys) begin
   enablePixel <= enablePixel + 1'b1;
   if (reset || !sysEnable || sysCycle == PHASE_END) begin
      enablePixel <= 0;
   end
end

reg [24:0] systemAddr;

reg [15:0] cpuAddr;
reg [7:0]  cpuPO;
reg        cpuWe;
reg [7:0]  cpuDi;
reg [7:0]  cpuDo;

// ============================================================================
// CPU
// ============================================================================

wire irq_n = irq_tpi1 & irq_vic;

cpu_6509 cpu (
   .widePO(0),
   .clk(clk_sys),
   .enable(enableCpu),
   .reset(reset),

   .nmi_n(1),
   // .nmi_ack(nmi_ack),
   .irq_n(irq_n),
   .rdy(1),

   .addr(cpuAddr),
   .din(cpuDi),
   .dout(cpuDo),
   .we(cpuWe),

   .pout(cpuPO)
);

// ============================================================================
// VIC-II
// ============================================================================

reg        baLoc;
reg        aec;
reg        irq_vic;

reg [15:0] vicAddr;
reg  [3:0] colData;

reg  [7:0] vicData;
reg  [3:0] vicColorIndex;

reg        vicHSync;
reg        vicVSync;

reg [7:0]  vicR, vicG, vicB;

spram #(4,10) colorram (
   .clk(clk_sys),
   .we(cs_colram && pulseWr_io),
   .addr(systemAddr[9:0]),
   .data(cpuDo[3:0]),
   .q(colData)
);

video_vicii_656x #(
   .registeredAddress("true"),
   .emulateRefresh("true"),
   .emulateLightpen("true"),
   .emulateGraphics("true")
) vicII (
   .clk(clk_sys),
   .reset(reset | model),
   .enaPixel(&enablePixel & ~model),
   .enaData(enableVic & ~model),
   .phi(phase),

   .baSync(0),
   .ba(baLoc),

   .mode6569(~ntsc),
   .mode6567old(0),
   .mode6567R8(ntsc),
   .mode6572(0),
   .variant(2'b00),

   .turbo_en(0),

   .cs(cs_vic),
   .we(cpuWe),
   .lp_n(0),

   .aRegisters(cpuAddr[5:0]),
   .diRegisters(cpuDo),
   .di(vidDi),
   .diColor(colData),
   .DO(vicData),

   .vicAddr(vicAddr[13:0]),
   .addrValid(aec),
   .irq_n(irq_vic),

   .hsync(vicHSync),
   .vsync(vicVSync),
   .colorIndex(vicColorIndex)
);

fpga64_rgbcolor vic_colors (
   .index(vicColorIndex),
   .r(vicR),
   .g(vicG),
   .b(vicB)
);

// ============================================================================
// CRTC
// ============================================================================

reg  [7:0] crtcData;
reg [13:0] crtcMa;
reg  [4:0] crtcRa;

reg        crtcVsync;
reg        crtcHsync;
reg        crtcDE;
reg        crtcCursor;

mc6845 crtc (
   .CLOCK(clk_sys),
   .CLKEN(enableCrtc),
   .nRESET(~reset & model),

   .ENABLE(enableIO_p),
   .R_nW(~(cs_crtc & cpuWe)),
   .RS(cpuAddr[0]),
   .DI(cpuDo),
   .DO(crtcData),

   .VSYNC(crtcVsync),
   .HSYNC(crtcHsync),
   .DE(crtcDE),
   .LPSTB(0),
   .CURSOR(crtcCursor),

   .MA(crtcMa),
   .RA(crtcRa)
);

reg [7:0] crtcDotD;

chargen chargen (
   .clk_sys(clk_sys),

   .profile(profile),
   .dotA({crtcMa[12], crtcGraphics, vidDi[6:0], crtcRa[3:0]}),
   .dotD(crtcDotD)
);

reg        crtcOut;

always @(posedge clk_sys) begin
   reg [7:0] dot;
   reg       crtcRevid, crtcRevid_r;
   reg       crtcDE_r;
   reg       crtcCursor_r;

   if (enablePixel[0]) begin
      crtcOut      <= crtcCursor_r ^ (crtcDE_r & (crtcRevid_r ^ dot[7]));
      dot          <= {dot[6:0], dot[0] & crtcGraphics};
   end

   if (sysCycle == CYCLE_VID3) begin
      crtcRevid    <= vidDi[7] ^ crtcMa[13];
   end

   if (sysCycle == CYCLE_VID5) begin
      dot          <= crtcDotD;
      crtcRevid_r  <= crtcRevid;
      crtcDE_r     <= crtcDE;
      crtcCursor_r <= crtcCursor;
   end
end

wire  [7:0] crtcR = crtcOut ? 8'h00 : 8'h00;
wire  [7:0] crtcG = crtcOut ? 8'hf8 : 8'h00;
wire  [7:0] crtcB = crtcOut ? 8'h00 : 8'h00;

// ============================================================================
// Video mux
// ============================================================================

assign r     = model ? crtcR     : vicR;
assign g     = model ? crtcG     : vicG;
assign b     = model ? crtcB     : vicB;
assign hsync = model ? crtcHsync : vicHSync;
assign vsync = model ? crtcVsync : vicVSync;

// ============================================================================
// SID
// ============================================================================

reg [7:0]  sidData;

sid_top sid (
   .reset(reset),
   .clk(clk_sys),
   .ce_1m(enableIO_p),
   .we(pulseWr_io),
   .cs(cs_sid),
   .addr(cpuAddr[4:0]),
   .data_in(cpuDo),
   .data_out(sidData)
);

// ============================================================================
// 6526 CIA FOR INTER-PROCESS COMMUNICATION
//
//    PRA  = DATA PORT
//    PRB0 = BUSY1 (1=>6509 OFF DBUS)
//    PRB1 = BUSY2 (1=>8088/Z80 OFF DBUS)
//    PRB2 = SEMAPHORE 8088/Z80
//    PRB3 = SEMAPHORE 6509
//    PRB4 = UNUSED
//    PRB5 = UNUSED
//    PRB6 = IRQ TO 8088/Z80 (LO)
//    PRB7 = UNUSED
// ============================================================================

wire       irq_ipcia;
reg [7:0]  ipciaData;

mos6526 ipcia (
   .mode(0),

   .clk(clk_sys),
   .phi2_p(enableIO_p),
   .phi2_n(enableIO_n),
   .res_n(~reset & coproEn),
   .cs_n(~cs_ipcia),
   .rw(~cpuWe),

   .rs(cpuAddr[3:0]),
   .db_in(cpuDo),
   .db_out(ipciaData),

   .irq_n(irq_ipcia)
);

// ============================================================================
// 6526 CIA  COMPLEX INTERFACE ADAPTER -- GAME / IEEE DATA / USER
//
//   TIMER A: IEEE LOCAL / CASS LOCAL / MUSIC / GAME
//   TIMER B: IEEE DEADM / CASS DEADM / MUSIC / GAME
//
//   PRA0 : IEEE DATA1 / USER / PADDLE GAME 1
//   PRA1 : IEEE DATA2 / USER / PADDLE GAME 2
//   PRA2 : IEEE DATA3 / USER
//   PRA3 : IEEE DATA4 / USER
//   PRA4 : IEEE DATA5 / USER
//   PRA5 : IEEE DATA6 / USER
//   PRA6 : IEEE DATA7 / USER / GAME TRIGGER 14
//   PRA7 : IEEE DATA8 / USER / GAME TRIGGER 24
//
//   PRB0 : USER / GAME 10
//   PRB1 : USER / GAME 11
//   PRB2 : USER / GAME 12
//   PRB3 : USER / GAME 13
//   PRB4 : USER / GAME 20
//   PRB5 : USER / GAME 21
//   PRB6 : USER / GAME 22
//   PRB7 : USER / GAME 23
//
//   FLAG : USER / CASSETTE READ
//   PC   : USER
//   CT   : USER
//   SP   : USER
// ============================================================================

reg todclk;

always @(posedge clk_sys) begin
   integer sum;

   if (reset) begin
      todclk <= 0;
      sum = 0;
   end
   else if (sysEnable) begin
      if (ntsc) begin
         sum = sum + 120;  // todclk is 60 Hz
      end
      else begin
         sum = sum + 100;  // todclk is 50 Hz
      end

      if (sum >= CLK) begin
         sum = sum - CLK;
         todclk <= ~todclk;
      end
   end
end

wire       irq_cia;
reg [7:0]  ciaData;

mos6526 cia (
   .mode(0),

   .clk(clk_sys),
   .phi2_p(enableIO_p),
   .phi2_n(enableIO_n),
   .res_n(~reset),
   .cs_n(~cs_cia),
   .rw(~cpuWe),

   .rs(cpuAddr[3:0]),
   .db_in(cpuDo),
   .db_out(ciaData),

   .tod(todclk),
   .irq_n(irq_cia)
);

// ============================================================================
// ACIA (UART)
// ============================================================================

wire       irq_acia;
reg [7:0]  aciaData;

glb6551 acia (
   .CLK(clk_sys),
   .RESET_N(~reset),
   .PH_2(enableIO_p),
   .DI(cpuDo),
   .DO(aciaData),
   .CS({~cs_acia, 1'b1}),
   .RW_N(~cpuWe),
   .RS(cpuAddr[1:0]),

   .IRQ(irq_acia)
);

// ============================================================================
// 6525 TPI1  TRIPORT INTERFACE DEVICE #1 --  IEEE CONTROL / CASSETTE / NETWORK / VIC / IRQ
//
//   PA0 : IEEE DC CONTROL (TI PARTS)
//   PA1 : IEEE TE CONTROL (TI PARTS) (T/R)
//   PA2 : IEEE REN
//   PA3 : IEEE ATN
//   PA4 : IEEE DAV
//   PA5 : IEEE EOI
//   PA6 : IEEE NDAC
//   PA7 : IEEE NRFD
//
//   PB0 : IEEE IFC
//   PB1 : IEEE SRQ
//   PB2 : NETWORK TRANSMITTER ENABLE
//   PB3 : NETWORK RECEIVER ENABLE
//   PB4 : ARBITRATION LOGIC SWITCH
//   PB5 : CASSETTE WRITE
//   PB6 : CASSETTE MOTOR
//   PB7 : CASSETTE SWITCH
//
//   IRQ0: 50/60 HZ IRQ
//   IRQ1: IEEE SRQ
//   IRQ2: 6526 IRQ
//   IRQ3: (OPT) 6526 INTER-PROCESSOR
//   IRQ4: 6551
//   *IRQ: 6566 (VIC) / USER DEVICES
//   CB  : VIC DOT SELECT (P MODEL)
//   CA  : VIC MATRIX SELECT (P MODEL) / GRAPHICS (B MODEL)
// ============================================================================

reg  [7:0] tpi1Data;
wire [7:0] tpi1_pao;
wire [7:0] tpi1_pbo;
wire [7:0] tpi1_pco;

wire       ifc_i = 1'b1;
wire       ifc_o = tpi1_pbo[0];
wire       srq_i = 1'b1;
wire       srq_o = tpi1_pbo[1];
wire       ren_i = 1'b1;
wire       ren_o = tpi1_pao[2];
wire       atn_i = 1'b1;
wire       atn_o = tpi1_pao[3];
wire       dav_i = 1'b1;
wire       dav_o = tpi1_pao[4];
wire       eoi_i = 1'b1;
wire       eoi_o = tpi1_pao[5];
wire       ndac_i = 1'b1;
wire       ndac_o = tpi1_pao[6];
wire       nrfd_i = 1'b1;
wire       nrfd_o = tpi1_pao[7];

wire       dirctl = tpi1_pao[0];
wire       talken = tpi1_pao[1];

wire       irq_tpi1 = tpi1_pco[5];
wire       statvid = tpi1_pco[6];
wire       crtcGraphics = tpi1_pco[6];
wire       vicdotsel = tpi1_pco[7];

mos_tpi tpi1 (
   .mode(1),

   .clk(clk_sys),
   .res_n(~reset),
   .cs_n(~(cs_tpi1 & enableIO_p)),
   .rw(~cpuWe),

   .rs(cpuAddr[2:0]),
   .db_in(cpuDo),
   .db_out(tpi1Data),

   .pa_in({nrfd_i, ndac_i, eoi_i, dav_i, atn_i, ren_i, tpi1_pao[1:0]}),
   .pa_out(tpi1_pao),

   .pb_in({tpi1_pbo[7:2], srq_i, ifc_i}),
   .pb_out(tpi1_pbo),

   .pc_in({tpi1_pco[7:5], irq_acia, irq_ipcia, irq_cia, srq_i & srq_o, todclk}),
   .pc_out(tpi1_pco)
);

// ============================================================================
// 6525 TPI2 TIRPORT INTERFACE DEVICE #2 -- KEYBOARD / VIC 16K CONTROL
//
//   PA0 : KYBD OUT 8
//   PA1 : KYBD OUT 9
//   PA2 : KYBD OUT 10
//   PA3 : KYBD OUT 11
//   PA4 : KYBD OUT 12
//   PA5 : KYBD OUT 13
//   PA6 : KYBD OUT 14
//   PA7 : KYBD OUT 15
//
//   PB0 : KYBD OUT 0
//   PB1 : KYBD OUT 1
//   PB2 : KYBD OUT 2
//   PB3 : KYBD OUT 3
//   PB4 : KYBD OUT 4
//   PB5 : KYBD OUT 5
//   PB6 : KYBD OUT 6
//   PB7 : KYBD OUT 7
//
//   PC0 : KYBD IN 0
//   PC1 : KYBD IN 1
//   PC2 : KYBD IN 2
//   PC3 : KYBD IN 3
//   PC4 : KYBD IN 4
//   PC5 : KYBD IN 5
//   PC6 : VIC 16K BANK SELECT LOW OUT (P MODEL) / 50/60 Select IN (B MODEL)
//   PC7 : VIC 16K BANK SELECT HI  OUT (P MODEL) / Low/High Profile Select IN (B MODEL)
// ============================================================================

reg  [7:0] tpi2Data;

wire [5:0] tpi2_pci;
wire [7:0] tpi2_pao;
wire [7:0] tpi2_pbo;
wire [7:0] tpi2_pco;

assign vicAddr[15:14] = tpi2_pco[7:6];

mos_tpi tpi2 (
   .mode(1),

   .clk(clk_sys),
   .res_n(~reset),
   .cs_n(~(cs_tpi2 & enableIO_p)),
   .rw(~cpuWe),

   .rs(cpuAddr[2:0]),
   .db_in(cpuDo),
   .db_out(tpi2Data),

   .pa_in(tpi2_pao),
   .pa_out(tpi2_pao),

   .pb_in(tpi2_pbo),
   .pb_out(tpi2_pbo),

   .pc_in({(~model | profile) & tpi2_pco[7], (~model | ntsc) & tpi2_pco[6], tpi2_pci}),
   .pc_out(tpi2_pco)
);

// ============================================================================
// Keyboard
// ============================================================================

cbm2_keyboard keyboard (
   .clk(clk_sys),
   .reset(kbd_reset),
   .ps2_key(ps2_key),

   .pai(tpi2_pao),
   .pbi(tpi2_pbo),
   .pci(tpi2_pco[5:0]),
   .pco(tpi2_pci[5:0]),

   .soft_reset(soft_reset),
   .sftlk_sense(sftlk_sense)
);

// ============================================================================
// PLA, ROM and glue logic
// ============================================================================

reg [7:0] vidDi;

reg       cs_ram;
reg       cs_colram;
reg       cs_vic;
reg       cs_crtc;
reg       cs_sid;
reg       cs_ipcia;
reg       cs_cia;
reg       cs_acia;
reg       cs_tpi1;
reg       cs_tpi2;

cbm2_buslogic buslogic (
   .model(model),
   .profile(profile),
   .ramSize(ramSize),
   .ipcEn(coproEn),
   .extrom(extrom),

   .clk_sys(clk_sys),
   .reset(reset),

   .phase(phase),

   .cpuCycle(cpu_cycle),
   .cpuAddr(cpuAddr),
   .cpuSeg(cpuPO),
   .cpuDi(cpuDi),
   .cpuWe(cpuWe),

   .vidCycle(vid_cycle),
   .vicAddr(vicAddr),
   .crtcAddr(crtcMa),
   .vidDi(vidDi),

   .vicdotsel(vicdotsel),
   .statvid(statvid),

   .systemAddr(systemAddr),
   .systemWe(ramWE),

   .ramData(ramData),

   .cs_ram(cs_ram),
   .cs_colram(cs_colram),
   .cs_vic(cs_vic),
   .cs_crtc(cs_crtc),
   .cs_sid(cs_sid),
   .cs_ipcia(cs_ipcia),
   .cs_cia(cs_cia),
   .cs_acia(cs_acia),
   .cs_tpi1(cs_tpi1),
   .cs_tpi2(cs_tpi2),

   .colData(colData),
   .vicData(vicData),
   .crtcData(crtcData),
   .sidData(sidData),
   .ipciaData(ipciaData),
   .ciaData(ciaData),
   .aciaData(aciaData),
   .tpi1Data(tpi1Data),
   .tpi2Data(tpi2Data)
);

endmodule
