module cbm2_main (
   input         model,     // 0=Professional, 1=Business
   input         ntsc,      // 0=PAL, 1=NTSC
   input         turbo,     // 1=2MHz CPU clock (Professional only)
   input  [1:0]  ramSize,   // 0=128k, 2=256k, 2=1M, 3=16M

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
   output        ext_cycle,

   output        hsync,
   output        vsync,
   output [7:0]  r,
   output [7:0]  g,
   output [7:0]  b
);

typedef enum bit[4:0] {
	CYCLE_EXT0, CYCLE_EXT1, CYCLE_EXT2, CYCLE_EXT3,
   CYCLE_EXT4, CYCLE_EXT5, CYCLE_EXT6, CYCLE_EXT7,
   CYCLE_CPU0, CYCLE_CPU1, CYCLE_CPU2, CYCLE_CPU3,
   CYCLE_VID0, CYCLE_VID1, CYCLE_VID2, CYCLE_VID3,
   CYCLE_EXT8, CYCLE_EXT9, CYCLE_EXTA, CYCLE_EXTB,
   CYCLE_EXTC, CYCLE_EXTD, CYCLE_EXTE, CYCLE_EXTF,
   CYCLE_CPU4, CYCLE_CPU5, CYCLE_CPU6, CYCLE_CPU7,
   CYCLE_VID4, CYCLE_VID5, CYCLE_VID6, CYCLE_VID7
} sysCycle_t;

sysCycle_t sysCycle, preCycle;
reg [1:0]  rfsh_cycle = 0;
reg        reset = 0;
reg        sysEnable;

wire       sys2MHz = model | (turbo & ~(cs_vic | cs_sid));

// External cycle
assign ext_cycle = (sysCycle >= CYCLE_EXT0 && sysCycle <= CYCLE_EXT3)
                || (sysCycle >= CYCLE_EXT4 && sysCycle <= CYCLE_EXT7 && rfsh_cycle != 0)
                || (sysCycle >= CYCLE_EXT8 && sysCycle <= CYCLE_EXTB)
                || (sysCycle >= CYCLE_EXTC && sysCycle <= CYCLE_EXTF);

// Video cycle (VIC or CRTC)
wire vid_cycle = (sysCycle >= CYCLE_VID0 && sysCycle <= CYCLE_VID3)
              || (sysCycle >= CYCLE_VID4 && sysCycle <= CYCLE_VID7);

// CPU cycle
wire cpu_cycle = (sysCycle >= CYCLE_CPU0 && sysCycle <= CYCLE_CPU3 && sys2MHz)
              || (sysCycle >= CYCLE_CPU4 && sysCycle <= CYCLE_CPU7);

// wire enableVid  = vid_cycle && sysCycle[1:0] == 3;
// wire enableIO_n = cpu_cycle && sysCycle[1:0] == 2;
// wire enableCpu  = cpu_cycle && sysCycle[1:0] == 3;
// wire pulseWr_io = cpu_cycle && sysCycle[1:0] == 3 && cpuWe;
// wire enableIO_p = ext_cycle && sysCycle[1:0] == 0 && (!sysCycle[4] || sys2MHz);

wire enableVid  = sysCycle == CYCLE_VID7        ||  sysCycle == CYCLE_VID3;
wire enableIO_n = sysCycle == CYCLE_CPU6        || (sysCycle == CYCLE_CPU2 && sys2MHz);
wire enableCpu  = sysCycle == CYCLE_CPU7        || (sysCycle == CYCLE_CPU3 && sys2MHz);
wire pulseWr_io = enableCpu && cpuWe;
wire enableIO_p = sysCycle == CYCLE_CPU7.next() || (sysCycle == CYCLE_CPU3.next() && sys2MHz);

wire crtcPixel  = sysCycle[0];
wire vicPixel   = &sysCycle[1:0];
wire phase      = sysCycle[4];

assign ramWE = cpuWe && cpu_cycle;
assign ramCE = cs_ram && ((sysCycle == CYCLE_CPU0 && sys2MHz)
                         || sysCycle == CYCLE_VID0
                         || sysCycle == CYCLE_CPU4
                         || sysCycle == CYCLE_VID4
                         );

assign ramAddr = {1'b0, systemAddr};
assign ramOut = cpuDo;

assign sysCycle = sysEnable ? preCycle : CYCLE_EXT4;
assign pause_out = ~sysEnable;

always @(posedge clk_sys) begin
   preCycle <=preCycle.next();
   if (preCycle == sysCycle_t.last()) begin
      // preCycle <= sysCycle_t.first();
      if (sysEnable)
         rfsh_cycle <= rfsh_cycle + 1'b1;

      reset <= ~reset_n;
   end

   refresh <= 0;
   if (preCycle == CYCLE_EXT4.prev() && rfsh_cycle == 0) begin
      sysEnable <= ~pause;
      refresh <= 1;
   end
end

reg [23:0] systemAddr;

reg [15:0] cpuAddr;
reg [7:0]  cpuPO;
reg        cpuWe;
reg [7:0]  cpuDi;
reg [7:0]  cpuDo;

wire [7:0]  crtcData = 0;
wire [7:0]  ipciaData = 0;

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

reg [7:0]  vicBus;
reg [7:0]  vicData;
reg [3:0]  colData;
reg [15:0] vicAddr;
reg [3:0]  vicColorIndex;

assign vicAddr[15:14] = ~tpi2_pbo[7:6];

always @(posedge clk_sys) begin
   if (phase) begin
      vicBus <= (cpuWe && cs_vic) ? cpuDo : 8'hFF;
   end
end

wire [7:0] vicDiAec = aec ? cpuDi : vicBus;
wire [3:0] colorDataAec = aec ? colData : cpuDi[3:0];

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
   .enaPixel(vicPixel & ~model),
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
   .di(vicDiAec),
   .diColor(colorDataAec),
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
// CIA
// ============================================================================

reg todclk;

always @(posedge clk_sys) begin
   integer sum;

   if (reset) begin
      todclk <= 0;
      sum = 0;
   end
   else begin
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
// TPI 1 -- IRQ control and IEEE-488 control signals
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

   .pc_in({3'b111, irq_acia, 1'b1, irq_cia, srq_i & srq_o, todclk}),
   .pc_out(tpi1_pco)
);

// ============================================================================
// TPI 2 -- Keyboard
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

   .clk_sys(clk_sys),
   .reset(reset),

   .cpuHasBus(),
   .cpuAddr(cpuAddr),
   .cpuSeg(cpuPO),
   .cpuDi(cpuDi),

   .vidAddr(vicAddr),

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
   .crtcData(crtcData),
   .sidData(sidData),
   .ipciaData(ipciaData),
   .ciaData(ciaData),
   .aciaData(aciaData),
   .tpi1Data(tpi1Data),
   .tpi2Data(tpi2Data)
);

endmodule
