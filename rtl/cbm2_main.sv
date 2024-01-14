module cbm2_main (
   input         model,     // 0=Professional, 1=Business
   input [1:0]   ramSize,   // 0=128k, 2=256k, 2=1M, 3=16M
   input         ntsc,      // 0=PAL, 1=NTSC

   input         clk_sys,
   input         reset_n,

   output [24:0] ramAddr,
   input  [7:0]  ramData,    // from sdram
   output [7:0]  ramOut,     // to sdram
   output        ramCE,
   output        ramWE,

   output        refresh,
   output        io_cycle
);

typedef enum {
	CYCLE_EXT[12],
	CYCLE_VID[4],
   CYCLE_CPU[16]
} sysCycle_t;

sysCycle_t sysCycle, preCycle;
reg [1:0]  rfsh_cycle = 0;
reg        reset = 0;

assign ramCE = cs_ram && cpu_cycle;

assign io_cycle = (sysCycle >= CYCLE_EXT0 && sysCycle <= CYCLE_EXT3)
               || (sysCycle >= CYCLE_EXT4 && sysCycle <= CYCLE_EXT7 && rfsh_cycle != 0)
               || (sysCycle >= CYCLE_EXT8 && sysCycle <= CYCLE_EXT11);

wire vic_cycle = (sysCycle >= CYCLE_VID0 && sysCycle <= CYCLE_VID3)
              || (sysCycle >= CYCLE_CPU12 && sysCycle <= CYCLE_CPU15);

wire cpu_cycle = sysCycle >= CYCLE_CPU0 && sysCycle <= CYCLE_CPU15;

always @(posedge clk_sys) begin
   sysCycle <= sysCycle.next();

   if (sysCycle == sysCycle.last()) begin
      rfsh_cycle <= rfsh_cycle + 1'b1;
      reset <= ~reset_n;
   end

   refresh <= 0;
   if (sysCycle == CYCLE_EXT4.prev() && rfsh_cycle == 0) begin
      refresh <= 1;
   end
end

wire enableCpu  = sysCycle == CYCLE_CPU2;
wire enableVic  = sysCycle == CYCLE_VID3 || sysCycle == CYCLE_CPU15;
wire enableIO_p = sysCycle == CYCLE_CPU13;
wire enableIO_n = sysCycle == CYCLE_CPU15.next();

reg pulseWr_io;
always @(posedge clk_sys) begin
   pulseWr_io <= 0;
   if (cpuWe && sysCycle == CYCLE_CPU12) begin
      pulseWr_io <= 1;
   end
end


reg [15:0] cpuAddr;
reg [7:0]  cpuPO;
reg        cpuWe;
reg [7:0]  cpuDi;
reg [7:0]  cpuDo;

reg        cs_ram;
// reg        cs_vidram;
reg        cs_colram;
reg        cs_vic;
reg        cs_crtc;
reg        cs_disk;
reg        cs_sid;
reg        cs_cop;
reg        cs_cia;
reg        cs_acia;
reg        cs_tpi1;
reg        cs_tpi2;

// reg [7:0]  vidData;
reg [3:0]  colData;
reg [7:0]  vicData;
reg [7:0]  crtcData;
reg [7:0]  diskData;
reg [7:0]  sidData;
reg [7:0]  copData;
reg [7:0]  ciaData;
reg [7:0]  aciaData;
reg [7:0]  tpi1Data;
reg [7:0]  tpi2Data;

always @(*)
   ramOut <= cpuDo;

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

spram #(4,10) colorram (
   .clk(clk_sys),
   .we(cs_colram && pulseWr_io),
   .addr(cpuAddr[9:0]),
   .data(cpuDo[3:0]),
   .q(colData)
);

// spram #(8,11) videoram (
//    .clk(clk_sys),
//    .we(cs_vidram && pulseWr_io),
//    .addr(cpuAddr[10:0]),
//    .data(cpuDo),
//    .q(vidData)
// );

sid_top sid (
   .reset(reset),
   .clk(clk_sys),
   .ce_1m(enableIO_n),
   .we(pulseWr_io),
   .cs(cs_sid),
   .addr(cpuAddr[4:0]),
   .data_in(cpuDo),
   .data_out(sidData)
);

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
      
      if (model) begin
         // clk_sys is 32000000 Hz
         if (sum >= 32000000) begin
            sum = sum - 32000000;
            todclk <= ~todclk;
         end
      end
      else if (ntsc) begin
         // clk_sys is 32727266 Hz
         if (sum >= 32727266) begin
            sum = sum - 32727266;
            todclk <= ~todclk;
         end
      end
      else begin
         // clk_sys is 31527954 Hz
         if (sum >= 31527954) begin
            sum = sum - 31527954;
            todclk <= ~todclk;
         end
      end
   end
end

wire irq_cia;

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

wire irq_acia;

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
// TPI 1 -- Interupt handling and IEEE-488 control signals
// ============================================================================

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

wire       irq_n   = tpi1_pco[5];
wire       tpi1_ca = tpi1_pco[6];
wire       tpi1_cb = tpi1_pco[7];

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

mos_tpi tpi2 (
   .mode(1),

   .clk(clk_sys),
   .res_n(~reset),
   .cs_n(~(cs_tpi2 & enableIO_p)),
   .rw(~cpuWe),

   .rs(cpuAddr[2:0]),
   .db_in(cpuDo),
   .db_out(tpi2Data)
);

cbm2_buslogic buslogic (
   .model(model),
   .ramSize(ramSize),

   .clk_sys(clk_sys),
   .reset(reset),

   .cpuAddr(cpuAddr),
   .cpuDi(cpuDi),
   .cpuPO(cpuPO),
   .cpuWe(cpuWe),

   .ramAddr(ramAddr),
   .ramData(ramData),
   .ramWE(ramWE),

   .cs_ram(cs_ram),
   .cs_colram(cs_colram),
   .cs_vic(cs_vic),
   .cs_crtc(cs_crtc),
   .cs_disk(cs_disk),
   .cs_sid(cs_sid),
   .cs_cop(cs_cop),
   .cs_cia(cs_cia),
   .cs_acia(cs_acia),
   .cs_tpi1(cs_tpi1),
   .cs_tpi2(cs_tpi2),

   .colData(colData),
   .vicData(vicData),
   .crtcData(crtcData),
   .diskData(diskData),
   .sidData(sidData),
   .copData(copData),
   .ciaData(ciaData),
   .aciaData(aciaData),
   .tpi1Data(tpi1Data),
   .tpi2Data(tpi2Data)
);

endmodule
