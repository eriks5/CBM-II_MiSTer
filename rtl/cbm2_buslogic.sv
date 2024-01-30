module cbm2_buslogic (
   input         model,     // 0=Professional, 1=Business
   input         profile,   // 0=Low, 1=High
   input   [1:0] ramSize,   // 0=256k, 1=128k, 2=1M
   input         ipcEn,     // Enable IPC
   input   [7:0] extrom,
   input         extram,

   input         clk_sys,
   input         reset,

   input         phase,

   input         cpuCycle,
   input  [15:0] cpuAddr,
   input   [7:0] cpuSeg,
   output  [7:0] cpuDi,
   input         cpuWe,

   input         vidCycle,
   input  [15:0] vicAddr,
   input  [10:0] crtcAddr,
   output  [7:0] vidDi,

   input         vicdotsel,
   input         statvid,

   output [24:0] systemAddr,
   output        systemWe,

   input   [7:0] ramData,

   output        cs_ram,
   output        cs_colram,
   output        cs_vic,
   output        cs_crtc,
   output        cs_sid,
   output        cs_ipcia,
   output        cs_cia,
   output        cs_acia,
   output        cs_tpi1,
   output        cs_tpi2,

   input  [3:0]  colData,
   input  [7:0]  vicData,
   input  [7:0]  crtcData,
   input  [7:0]  sidData,
   input  [7:0]  ipciaData,
   input  [7:0]  ciaData,
   input  [7:0]  aciaData,
   input  [7:0]  tpi1Data,
   input  [7:0]  tpi2Data
);

reg         cs_rom8, cs_romC, cs_romE;

wire [7:0] romLPData;
rom_mem #(8,14,"rtl/roms/basic.901235+6-02.mif") rom_lang_p
(
   .clock(clk_sys),
   .address(systemAddr),
   .q(romLPData)
);

wire [7:0] romLB128Data;
rom_mem #(8,14,"rtl/roms/basic.901242+3-04a.mif") rom_lang_b128
(
   .clock(clk_sys),
   .address(systemAddr),
   .q(romLB128Data)
);

wire [7:0] romLB256Data;
rom_mem #(8,14,"rtl/roms/basic-901240+1-03.mif") rom_lang_b256
(
   .clock(clk_sys),
   .address(systemAddr),
   .q(romLB256Data)
);

wire [7:0] romCPData;
rom_mem #(8,12,"rtl/roms/characters.901225-01.mif") rom_char_p
(
   .clock(clk_sys),
   .address(systemAddr),
   .q(romCPData)
);

wire [7:0] romKPData;
rom_mem #(8,13,"rtl/roms/kernal.901234-02.mif") rom_kernal_p
(
   .clock(clk_sys),
   .address(systemAddr),
   .q(romKPData)
);

wire [7:0] romKBData;
rom_mem #(8,13,"rtl/roms/kernal.901244-04a.mif") rom_kernal_b
(
   .clock(clk_sys),
   .address(systemAddr),
   .q(romKBData)
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

   cs_colram <= 0;
   cs_vic <= 0;
   cs_crtc <= 0;
   cs_sid <= 0;
   cs_ipcia <= 0;
   cs_cia <= 0;
   cs_acia <= 0;
   cs_tpi1 <= 0;
   cs_tpi2 <= 0;

   if (cpuSeg == 15 && cpuAddr[15:12] == 4'hD) // Segment 15, $DFFF-$D000
      case(cpuAddr[11:8])
         4'h4, 4'h5, 4'h6, 4'h7:
               if (!model) cs_colram <= 1; // Color RAM (P2)
         4'h8: if (!model) cs_vic    <= 1; // VIC (P2)
               else        cs_crtc   <= 1; // CRTC (B2)
         4'hA:             cs_sid    <= 1; // SID
         4'hB: if (ipcEn)  cs_ipcia  <= 1; // IPCIA
         4'hC:             cs_cia    <= 1; // CIA
         4'hD:             cs_acia   <= 1; // ACIA
         4'hE:             cs_tpi1   <= 1; // tpi-port 1
         4'hF:             cs_tpi2   <= 1; // tpi-port 2
         default:          ;
      endcase

end

always @(*) begin
   // Decode RAM/ROM

   systemAddr <= 0;
   systemWe <= 0;

   cs_ram <= 0;
   cs_rom8 <= 0;
   cs_romC <= 0;
   cs_romE <= 0;

   // CPU or CoCPU
   if (cpuCycle) begin
      systemAddr[23:0] <= {cpuSeg, cpuAddr};
      systemWe <= cpuWe & cpuCycle;

      if (cpuSeg == 15) begin
         case(cpuAddr[15:12])
            4'h0: if (!cpuAddr[11] || ipcEn || extram) cs_ram <= 1;
            4'h1: if (extrom[0])       begin cs_ram <= 1; systemWe <= 0; end
                  else if (extram)           cs_ram <= 1;
            4'h2, 4'h3: if (extrom[1]) begin cs_ram <= 1; systemWe <= 0; end
                  else if (extram)           cs_ram <= 1;
            4'h4, 4'h5: if (extrom[2]) begin cs_ram <= 1; systemWe <= 0; end
                  else if (extram)           cs_ram <= 1;
            4'h6, 4'h7: if (extrom[3]) begin cs_ram <= 1; systemWe <= 0; end
                  else if (extram)           cs_ram <= 1;
            4'h8, 4'h9: if (extrom[4])       cs_ram <= 1;
                  else                       cs_rom8 <= 1;
            4'hA, 4'hB: if (extrom[5])       cs_ram <= 1;
                  else                       cs_rom8 <= 1;
            4'hC: if (extrom[6])       begin cs_ram <= 1; systemWe <= 0; end
                  else if (!model)           cs_romC <= 1;
                  else if (extram)           cs_ram <= 1;
            4'hD: if (!cpuAddr[11] && (!cpuAddr[10] || model)) cs_ram <= 1;
            4'hE, 4'hF: if (extrom[7])       cs_ram <= 1;
                  else                       cs_romE <= 1;
            default: ;
         endcase
      end
      else
         case (ramSize)
               0: cs_ram <= !model ? cpuSeg<=3 : cpuSeg>=1 && cpuSeg<=4;  // 256k
               1: cs_ram <= !model ? cpuSeg<=1 : cpuSeg>=1 && cpuSeg<=2;  // 128k
         default: cs_ram <= !model || cpuSeg>=1;                          // 1M
         endcase
   end

   // VIC
   if (vidCycle && !model) begin
      if (vicdotsel && !phase) begin
         // Character ROM, Seg 15 $CFFF-$C000
         systemAddr[19:0] <= {8'hFC, vicAddr[11:0]};
         if (extrom[6]) cs_ram <= 1;
         else           cs_romC <= 1;
      end
      else if (statvid && phase) begin
         // 4k Static video RAM, Seg 15 $D3FF-$D000
         systemAddr[19:0] <= {8'hFD, 2'b00, vicAddr[9:0]};
         cs_ram <= 1;
      end
      else begin
         // Seg 0
         systemAddr[15:0] <= vicAddr;
         cs_ram <= 1;
      end
   end

   // CRTC
   if (vidCycle && model) begin
      // 8k Static video RAM, Seg 15 $D7FF-$D000
      systemAddr[19:0] <= {8'hFD, 1'b0, crtcAddr};
      cs_ram <= 1;
   end
end

reg [7:0] lastCpuDi;
reg [7:0] lastVidDi;

always @(posedge clk_sys) begin
   if (cpuCycle)
      lastCpuDi <= cpuDi;
   if (vidCycle)
      lastVidDi <= vidDi;
end

always @(*) begin
   cpuDi <= lastCpuDi;
   vidDi <= lastVidDi;

   if (cpuCycle)
      if (cs_ram)
         cpuDi <= ramData;
      else if (cs_rom8)
         cpuDi <= model ? (ramSize == 1 ? romLB128Data : romLB256Data) : romLPData;
      else if (cs_romC && !model)
         cpuDi <= romCPData;
      else if (cs_romE)
         cpuDi <= model ? romKBData : romKPData;
      else if (cs_colram && !model)
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

   if (vidCycle)
      if (cs_ram)
         vidDi <= ramData;
      else if (cs_romC)
         vidDi <= romCPData;
end

endmodule
