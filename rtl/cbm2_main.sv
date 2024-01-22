module cbm2_main (
   input         model,     // 0=Professional, 1=Business
   input         ntsc,      // 0=PAL, 1=NTSC
   input         turbo,     // 1=2MHz CPU clock (Professional only)
   input  [1:0]  ramSize,   // 0=128k, 2=256k, 2=1M, 3=16M
   input  [1:0]  copro,     // 0=none, 1=Z80, 2=8088 (Business only)

   input         pause,
   output        pause_out,

   input  [31:0] CLK,
   input         clk_sys,
   input         reset_n,

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
   output [7:0]  b
);

typedef enum bit[4:0] {
	CYCLE_EXT0, CYCLE_EXT1, CYCLE_EXT2, CYCLE_EXT3,
   CYCLE_CPU0, CYCLE_CPU1, CYCLE_CPU2, CYCLE_CPU3,
   CYCLE_COP0, CYCLE_COP1, CYCLE_COP2, CYCLE_COP3,
   CYCLE_VID0, CYCLE_VID1, CYCLE_VID2, CYCLE_VID3,
   CYCLE_NOP0, CYCLE_NOP1
} sysCycle_t;

sysCycle_t PHASE_START = sysCycle_t.first();
wire [5:0] PHASE_END   = model ? sysCycle_t.last() : CYCLE_VID3;

sysCycle_t sysCycle, preCycle;
reg        reset = 0;
reg        sysEnable;

wire       sys2MHz = model | (turbo & ~(cs_vic | cs_sid));
wire       ipcEn = model & ~|copro;

// External cycle
assign io_cycle = sysCycle >= CYCLE_EXT0 && sysCycle <= CYCLE_EXT3 && rfsh_cycle != 1;

// Video cycle (VIC or CRTC)
wire vid_cycle  = sysCycle >= CYCLE_VID0 && sysCycle <= CYCLE_VID3;

// CPU cycle
wire cpu_cycle  = sysCycle >= CYCLE_CPU0 && sysCycle <= CYCLE_CPU3 && (phase || sys2MHz);

// CoCPU cycle
wire cop_cycle  = sysCycle >= CYCLE_COP0 && sysCycle <= CYCLE_COP3 && (phase || sys2MHz);

wire enableVid  = sysCycle == CYCLE_VID3;
wire enableIO_n = sysCycle == CYCLE_CPU2        && (phase || sys2MHz);
wire enableIO_p = sysCycle == CYCLE_CPU3.next() && (phase || sys2MHz);
wire enableCpu  = sysCycle == CYCLE_CPU3        && (phase || sys2MHz);
wire enableCop  = sysCycle == CYCLE_COP3        && ipcEn;
wire pulseWr_io = enableCpu && cpuWe;

assign ramWE = cpuWe && cpu_cycle;
assign ramCE = cs_ram && ( (sysCycle == CYCLE_CPU0 && (phase || sys2MHz))
                        || (sysCycle == CYCLE_COP0 && ipcEn)
                        ||  sysCycle == CYCLE_VID0
                        );

assign ramAddr = {1'b0, systemAddr};
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

reg [23:0] systemAddr;

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
   .widePO(&ramSize),
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
// VIC-II (P model)
// ============================================================================

reg        baLoc;
reg        aec;
reg        irq_vic;

// reg [7:0]  vicBus;
reg [15:0] vicAddr;
reg [3:0]  colData;
reg [7:0]  vicDi;

reg [7:0]  vicData;
reg [3:0]  vicColorIndex;

assign vicAddr[15:14] = ~tpi2_pbo[7:6];

// always @(posedge clk_sys) begin
//    if (phase) begin
//       vicBus <= (cpuWe && cs_vic) ? cpuDo : 8'hFF;
//    end
// end

// wire [7:0] vicDiAec = aec ? vidDi : vicBus;
// wire [3:0] colorDataAec = aec ? colData : vidDi[3:0];

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
   .enaData(enableVid & ~model),
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
   .di(vicDi),
   .diColor(colData),
   .DO(vicData),

   .vicAddr(vicAddr[13:0]),
   .addrValid(aec),
   .irq_n(irq_vic),

   .hsync(hsync),
   .vsync(vsync),
   .colorIndex(vicColorIndex)
);

fpga64_rgbcolor vic_colors (
   .index(vicColorIndex),
   .r(r),
   .g(g),
   .b(b)
);

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
   .res_n(~reset & ipcEn),
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
//   CB  : VIC DOT SELECT
//   CA  : VIC MATRIX SELECT
// ============================================================================

reg [7:0]  tpi1Data;
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

wire       irq_tpi1  = tpi1_pco[5];
wire       statvid   = tpi1_pco[6];
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

   .pa_in({nrfd_i, ndac_i, eoi_i, dav_i, atn_i, ren_i, 2'b11}),
   .pa_out(tpi1_pao),

   .pb_in({6'b111111, srq_i, ifc_i}),
   .pb_out(tpi1_pbo),

   .pc_in({3'b111, irq_acia, irq_ipcia, irq_cia, srq_i & srq_o, todclk}),
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
//   PC6 : VIC 16K BANK SELECT LOW
//   PC7 : VIC 16K BANK SELECT HI
// ============================================================================

reg [7:0]  tpi2Data;

wire [7:0] tpi2_pao;
wire [7:0] tpi2_pbo;
wire [7:0] tpi2_pco;

mos_tpi tpi2 (
   .mode(1),

   .clk(clk_sys),
   .res_n(~reset),
   .cs_n(~(cs_tpi2 & enableIO_p)),
   .rw(~cpuWe),

   .rs(cpuAddr[2:0]),
   .db_in(cpuDo),
   .db_out(tpi2Data),

   .pa_in(8'b11111111),
   .pa_out(tpi2_pao),

   .pb_in(8'b11111111),
   .pb_out(tpi2_pbo),

   .pc_in(8'b11111111),
   .pc_out(tpi2_pco)
);

// ============================================================================
// PLA, ROM and glue logic
// ============================================================================

reg        cs_ram;
reg        cs_colram;
reg        cs_vic;
reg        cs_crtc;
reg        cs_sid;
reg        cs_ipcia;
reg        cs_cia;
reg        cs_acia;
reg        cs_tpi1;
reg        cs_tpi2;

cbm2_buslogic buslogic (
   .model(model),
   .ramSize(ramSize),
   .ipcEn(ipcEn),

   .clk_sys(clk_sys),
   .reset(reset),

   .cpuCycle(cpu_cycle || cop_cycle),
   .cpuAddr(cpuAddr),
   .cpuSeg(cpuPO),
   .cpuDi(cpuDi),

   .vidCycle(vid_cycle),
   .vidAddr(vicAddr),
   .vidDi(vicDi),

   .vicdotsel(vicdotsel),
   .statvid(statvid),
   .vicPhase(phase),

   .systemAddr(systemAddr),

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
   // .crtcData(crtcData),
   .sidData(sidData),
   .ipciaData(ipciaData),
   .ciaData(ciaData),
   .aciaData(aciaData),
   .tpi1Data(tpi1Data),
   .tpi2Data(tpi2Data)
);

endmodule
