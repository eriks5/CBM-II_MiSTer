module cbm2_buslogic (
   input         model,     // 0=Professional, 1=Business
   input         profile,   // 0=Low, 1=High
   input   [1:0] ramSize,   // 0=128k, 1=256k, 2=896k
   input         ipcEn,     // Enable IPC

   input   [3:1] extbankrom,// enable external ROM in bank 2000,4000,6000
   input   [3:0] extbankram,// enable static RAM in bank 1000,2000,4000,6000

   input         clk_sys,
   input         reset,

   input   [1:0] erase_sram,
   input   [5:0] rom_id,
   input  [13:0] rom_addr,
   input         rom_wr,
   input   [7:0] rom_data,

   input         phase,

   input         cpuCycle,
   input  [15:0] cpuAddr,
   input   [7:0] cpuSeg,
   input   [7:0] cpuDo,
   output  [7:0] cpuDi,
   input         cpuWe,

   input         vidCycle,
   input  [15:0] vicAddr,
   input  [10:0] crtcAddr,
   output [11:0] vidDi,

   input         dramon,
   input         vicdotsel,
   input         statvid,

   output [24:0] systemAddr,
   output        systemWe,

   input   [7:0] ramData,

   output        cs_ram,
   output        cs_vic,
   output        cs_crtc,
   output        cs_sid,
   output        cs_ipcia,
   output        cs_cia,
   output        cs_acia,
   output        cs_tpi1,
   output        cs_tpi2,
   output        procvid,

   input   [7:0] vicData,
   input   [7:0] crtcData,
   input   [7:0] sidData,
   input   [7:0] ipciaData,
   input   [7:0] ciaData,
   input   [7:0] aciaData,
   input   [7:0] tpi1Data,
   input   [7:0] tpi2Data
);

reg cs_bank2, cs_bank4, cs_bank6, cs_rom8, cs_romC, cs_romE;
reg cs_sram, cs_vidram, cs_colram;

wire [7:0] bank2Data;
rom_mem #(8,13) bank_2000
(
   .clock_a(clk_sys),
   .address_a(systemAddr),
   .q_a(bank2Data),
   .data_a(cpuDo),
   .wren_a(systemWe & extbankram[1] & cs_bank2),

   .clock_b(clk_sys),
   .address_b(rom_addr),
   .data_b(rom_data),
   .wren_b(rom_wr && (extbankram[1] ? erase_sram[1] : rom_id==3 && !rom_addr[13]))
);

wire [7:0] bank4Data;
rom_mem #(8,13) bank_4000
(
   .clock_a(clk_sys),
   .address_a(systemAddr),
   .q_a(bank4Data),
   .data_a(cpuDo),
   .wren_a(systemWe & extbankram[2] & cs_bank4),

   .clock_b(clk_sys),
   .address_b(rom_addr),
   .data_b(rom_data),
   .wren_b(rom_wr && (extbankram[2] ? erase_sram[1] : ((rom_id==4 && !rom_addr[13]) || (rom_id==3 && rom_addr[13]))))
);

wire [7:0] bank6Data;
rom_mem #(8,13) bank_6000
(
   .clock_a(clk_sys),
   .address_a(systemAddr),
   .q_a(bank6Data),
   .data_a(cpuDo),
   .wren_a(systemWe & extbankram[3] & cs_bank6),

   .clock_b(clk_sys),
   .address_b(rom_addr),
   .data_b(rom_data),
   .wren_b(rom_wr && (extbankram[3] ? erase_sram[1] : ((rom_id==5 && !rom_addr[13]) || (rom_id==4 && rom_addr[13]))))
);

wire [7:0] romLPData;
rom_mem #(8,14,"rtl/roms/basic.901235+6-02.mif") rom_lang_p
(
   .clock_a(clk_sys),
   .address_a(systemAddr),
   .q_a(romLPData),

   .clock_b(clk_sys)
   // .address_b(rom_addr),
   // .data_b(rom_data),
   // .wren_b(rom_wr & rom_id==2)
);

wire [7:0] romLB128Data;
rom_mem #(8,14,"rtl/roms/basic.901242+3-04a.mif") rom_lang_b128
(
   .clock_a(clk_sys),
   .address_a(systemAddr),
   .q_a(romLB128Data),

   .clock_b(clk_sys)
   // .address_b(rom_addr),
   // .data_b(rom_data),
   // .wren_b(rom_wr & rom_id==4)
);

wire [7:0] romLB256Data;
rom_mem #(8,14,"rtl/roms/basic-901240+1-03.mif") rom_lang_b256
(
   .clock_a(clk_sys),
   .address_a(systemAddr),
   .q_a(romLB256Data),

   .clock_b(clk_sys)
   // .address_b(rom_addr),
   // .data_b(rom_data),
   // .wren_b(rom_wr & rom_id==5)
);

wire [7:0] romCPData;
rom_mem #(8,12,"rtl/roms/characters.901225-01.mif") rom_char_p
(
   .clock_a(clk_sys),
   .address_a(systemAddr),
   .q_a(romCPData),

   .clock_b(clk_sys)
   // .address_b(rom_addr),
   // .data_b(rom_data),
   // .wren_b(rom_wr & rom_id==11 & !rom_addr[13:12])
);

wire [7:0] romKPData;
rom_mem #(8,13,"rtl/roms/kernal.901234-02.mif") rom_kernal_p
(
   .clock_a(clk_sys),
   .address_a(systemAddr),
   .q_a(romKPData),

   .clock_b(clk_sys)
   // .address_b(rom_addr),
   // .data_b(rom_data),
   // .wren_b(rom_wr & rom_id==3 & !rom_addr[13])
);

wire [7:0] romKBData;
rom_mem #(8,13,"rtl/roms/kernal.901244-04a.mif") rom_kernal_b
(
   .clock_a(clk_sys),
   .address_a(systemAddr),
   .q_a(romKBData),

   .clock_b(clk_sys)
   // .address_b(rom_addr),
   // .data_b(rom_data),
   // .wren_b(rom_wr & rom_id==6 & !rom_addr[13])
);

wire [7:0] sramData;
sram #(8,13) sram (
   .clock_a(clk_sys),
   .wren_a   (erase_sram ? rom_wr   : systemWe & cs_sram),
   .address_a(erase_sram ? rom_addr : systemAddr),
   .data_a   (erase_sram ? rom_data : cpuDo),
   .q_a(sramData)
);

wire [7:0] vidData;
sram #(8,11) videoram (
   .clock_a(clk_sys),
   .wren_a   (erase_sram ? rom_wr   : systemWe & cs_vidram),
   .address_a(erase_sram ? rom_addr : systemAddr),
   .data_a   (erase_sram ? rom_data : cpuDo),
   .q_a(vidData)
);

wire [3:0] colData;
sram #(4,10) colorram (
   .clock_a(clk_sys),
   .wren_a   (erase_sram ? rom_wr   : systemWe & cs_colram),
   .address_a(erase_sram ? rom_addr : systemAddr),
   .data_a   (erase_sram ? rom_data : cpuDo),
   .q_a(colData)
);

// From KERNAL_CBM2_1983-07-07/declare:

// CURRENT MEMORY MAP:
//   SEGMENT 15- $FFFF-$E000  ROM (KERNAL)
//               $DFFF-$DF00  I/O  6525 TPI2
//               $DEFF-$DE00  I/O  6525 TPI1
//               $DDFF-$DD00  I/O  6551 ACIA
//               $DCFF-$DC00  I/O  6526 CIA
//               $DBFF-$DB00  I/O  UNUSED (Z80,8088,68008) [6526 IPCIA]
//               $DAFF-$DA00  I/O  6581 SID
//               $D9FF-$D900  I/O  UNUSED (DISKS)
//               $D8FF-$D800  I/O  6566 VIC/ 6845 80-COL
//               $D7FF-$D400  COLOR NYBLES/80-COL SCREEN
//               $D3FF-$D000  VIDEO MATRIX/80-COL SCREEN
//               $CFFF-$C000  CHARACTER DOT ROM (P2 ONLY)
//               $BFFF-$8000  ROMS EXTERNAL (LANGUAGE)
//               $7FFF-$4000  ROMS EXTERNAL (EXTENSIONS)
//               $3FFF-$2000  ROM  EXTERNAL
//               $1FFF-$1000  ROM  INTERNAL
//               $0FFF-$0400  UNUSED
//               $03FF-$0002  RAM (KERNAL/BASIC SYSTEM)
//   SEGMENT 14- SEGMENT 8 OPEN (FUTURE EXPANSION)
//   SEGMENT 7 - $FFFF-$0002  RAM EXPANSION (EXTERNAL)
//   SEGMENT 6 - $FFFF-$0002  RAM EXPANSION (EXTERNAL)
//   SEGMENT 5 - $FFFF-$0002  RAM EXPANSION (EXTERNAL)
//   SEGMENT 4 - $FFFF-$0002  RAM B2 EXPANSION (P2 EXTERNAL)
//   SEGMENT 3 - $FFFF-$0002  RAM EXPANSION
//   SEGMENT 2 - $FFFF-$0002  RAM B2 STANDARD (P2 OPTINAL)
//   SEGMENT 1 - $FFFF-$0002  RAM B2 P2 STANDARD
//   SEGMENT 0 - $FFFF-$0002  RAM P2 STANDARD (B2 OPTIONAL)

// Note: The same file later on declares additional RAM in segment 15:
//               $0FFF-$0800  KERNAL INTER-PROCESS COMMUNICATION VARIABLES
//               $07FF-$0400  RAMLOC

always @(*) begin
   // Decode I/O space

   cs_vic <= 0;
   cs_crtc <= 0;
   cs_sid <= 0;
   cs_ipcia <= 0;
   cs_cia <= 0;
   cs_acia <= 0;
   cs_tpi1 <= 0;
   cs_tpi2 <= 0;

   if (cpuSeg == 15 && cpuAddr[15:11] == 5'b11011) // Segment 15, $DFFF-$D000
      case(cpuAddr[10:8])
         3'b000: if (!model) cs_vic    <= 1; // VIC (P2)
                 else        cs_crtc   <= 1; // CRTC (B2)
         3'b010:             cs_sid    <= 1; // SID
         3'b011: if (ipcEn)  cs_ipcia  <= 1; // IPCIA
         3'b100:             cs_cia    <= 1; // CIA
         3'b101:             cs_acia   <= 1; // ACIA
         3'b110:             cs_tpi1   <= 1; // tpi-port 1
         3'b111:             cs_tpi2   <= 1; // tpi-port 2
         default:            ;
      endcase
end

always @(*) begin
   // Decode RAM/ROM

   systemAddr <= 0;
   systemWe <= 0;

   cs_ram <= 0;
   cs_sram <= 0;
   cs_vidram <= 0;
   cs_colram <= 0;
   cs_bank2 <= 0;
   cs_bank4 <= 0;
   cs_bank6 <= 0;
   cs_rom8 <= 0;
   cs_romC <= 0;
   cs_romE <= 0;

   // CPU or CoCPU
   if (cpuCycle) begin
      systemAddr[23:0] <= {cpuSeg, cpuAddr};
      systemWe <= cpuWe & cpuCycle;

      if (cpuSeg == 15) begin
         case(cpuAddr[15:12])
            4'h0      : if (!cpuAddr[11] || ipcEn || extbankram[0]) cs_sram <= 1;
            4'h1      : if (extbankram[0])                  cs_sram <= 1;
            4'h2, 4'h3: if (extbankram[1] || extbankrom[1]) cs_bank2 <= 1;
            4'h4, 4'h5: if (extbankram[2] || extbankrom[2]) cs_bank4 <= 1;
            4'h6, 4'h7: if (extbankram[3] || extbankrom[3]) cs_bank6 <= 1;
            4'h8, 4'h9, 4'hA, 4'hB: cs_rom8 <= 1;
            4'hC      : if (!model) cs_romC <= 1;
            4'hD      : if (!cpuAddr[11]) begin
                           if (!cpuAddr[10] || model) cs_vidram <= 1; else cs_colram <= 1;
                        end
            4'hE, 4'hF: cs_romE <= 1;
            default: ;
         endcase
      end
      else if (dramon)
         case (ramSize)
               0: cs_ram <= !model ? cpuSeg<=1 : cpuSeg>=1 && cpuSeg<=2;  // 128k
               1: cs_ram <= !model ? cpuSeg<=3 : cpuSeg>=1 && cpuSeg<=4;  // 256k
         default: cs_ram <= 1;                                            // Full
         endcase
   end

   // VIC
   if (vidCycle && !model) begin
      if (vicdotsel && !phase) begin
         // Character ROM, Seg 15 $CFFF-$C000
         systemAddr[11:0] <= vicAddr[11:0];
         cs_romC <= 1;
      end
      else if (statvid && phase) begin
         // 4k Static video RAM, Seg 15 $D3FF-$D000
         systemAddr[9:0] <= vicAddr[9:0];
         cs_vidram <= 1;
      end
      else if (dramon) begin
         // Seg 0
         systemAddr[15:0] <= vicAddr;
         cs_ram <= 1;
      end
   end

   // CRTC
   if (vidCycle && model) begin
      // 8k Static video RAM, Seg 15 $D7FF-$D000
      systemAddr[10:0] <= crtcAddr;
      cs_vidram <= 1;
   end
end

always @(*) begin
   procvid <= 0;
   if ((cpuSeg == 15) && (
      (cpuAddr[15:12] == 4'hC && !model)  /* $CFFF-$C000 charrom */
      || (cpuAddr[15:11] == 5'b11010)     /* $D7FF-$D000 videoram/colorram */
   ))
      procvid <= 1;
end

reg [7:0] lastCpuDi;
reg [7:0] lastVidDi;

always @(posedge clk_sys) begin
   if (cpuCycle)
      lastCpuDi <= cpuDi;
   if (vidCycle)
      lastVidDi <= vidDi[7:0];
end

always @(*) begin
   cpuDi <= lastCpuDi;
   if (cpuCycle)
      if (cs_ram)
         cpuDi <= ramData;
      else if (cs_sram)
         cpuDi <= sramData;
      else if (cs_bank2)
         cpuDi <= bank2Data;
      else if (cs_bank4)
         cpuDi <= bank4Data;
      else if (cs_bank6)
         cpuDi <= bank6Data;
      else if (cs_rom8)
         cpuDi <= model ? (ramSize == 0 ? romLB128Data : romLB256Data) : romLPData;
      else if (cs_romC && !model)
         cpuDi <= romCPData;
      else if (cs_romE)
         cpuDi <= model ? romKBData : romKPData;
      else if (cs_vidram)
         cpuDi <= vidData;
      else if (cs_colram)
         cpuDi[3:0] <= colData;
      else if (cs_vic)
         cpuDi <= vicData;
      else if (cs_crtc)
         cpuDi <= crtcData;
      else if (cs_sid)
         cpuDi <= sidData;
      else if (cs_ipcia)
         cpuDi <= ipciaData;
      else if (cs_cia)
         cpuDi <= ciaData;
      else if (cs_acia)
         cpuDi <= aciaData;
      else if (cs_tpi1)
         cpuDi <= tpi1Data;
      else if (cs_tpi2)
         cpuDi <= tpi2Data;

   vidDi <= {colData, lastVidDi};
   if (vidCycle)
      if (cs_ram)
         vidDi[7:0] <= ramData;
      else if (cs_vidram)
         vidDi[7:0] <= vidData;
      else if (cs_romC)
         vidDi[7:0] <= romCPData;
end

endmodule
