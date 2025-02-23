/*
 * CBM-II Bus logic
 * 
 * Copyright (C) 2024, Erik Scheffers (https://github.com/eriks5)
 *
 * This file is part of CBM-II_MiSTer.
 *
 * This program is free software: you can redistribute it and/or modify it
 * under the terms of the GNU General Public License as published by
 * the Free Software Foundation, version 2.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program. If not, see <https://www.gnu.org/licenses/>.
 */

module cbm2_buslogic (
   input         model,     // 0=Professional, 1=Business
   input         profile,   // 0=Low, 1=High
   input   [1:0] ramSize,   // 0=128k, 1=256k, 2=896k
   input         ipcEn,     // Enable IPC

   input   [3:1] extbankrom,// enable external ROM in bank 2000,4000,6000
   input   [3:0] extbankram,// enable static RAM in bank 1000,2000,4000,6000

   input         clk_sys,
   input         reset,

   input         erase_colram,
   input   [9:0] erase_colram_addr,

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

wire [8:0] modelRomBank = {7'b1_0000_00, ~model, model & profile};

reg        cs_colram;
wire [3:0] colData;
sram #(4,10) colorram (
   .clock_a(clk_sys),
   .wren_a   (erase_colram | (systemWe & cs_colram)),
   .address_a(erase_colram ? erase_colram_addr : systemAddr),
   .data_a   (erase_colram ? {4{erase_colram_addr[6]}} : cpuDo),
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

   if (cpuSeg == 15 && cpuAddr[15:11] == 5'b11011) // Segment 15, $DFFF-$D800
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
   cs_colram <= 0;

   // CPU or CoCPU
   if (cpuCycle) begin
      systemAddr <= {1'b0, cpuSeg, cpuAddr};
      systemWe <= cpuWe & cpuCycle;

      if (cpuSeg == 15) begin
         case(cpuAddr[15:12])
            4'h0      : if (!cpuAddr[11] || ipcEn || extbankram[0])
                           cs_ram <= 1;
            4'h1      : if (extbankram[0])
                           cs_ram <= 1;
            4'h2, 4'h3,
            4'h4, 4'h5,
            4'h6, 4'h7: if (extbankram[cpuAddr[14:13]])
                           cs_ram <= 1;
                        else if (extbankrom[cpuAddr[14:13]]) begin
                           systemAddr[24:16] <= 9'h103;
                           systemWe <= 0;
                           cs_ram <= 1;
                        end
            4'h8, 4'h9, 
            4'hA, 4'hB: begin
                           systemAddr[24:14] <= {modelRomBank, 1'b0, |ramSize};
                           systemWe <= 0;
                           cs_ram <= 1;
                        end
            4'hC      : if (!model) begin
                           systemAddr[24:13] <= {modelRomBank, 3'b101};
                           systemWe <= 0;
                           cs_ram <= 1;
                        end
            4'hD      : if (!cpuAddr[11]) begin
                           if (!cpuAddr[10] || model) 
                              cs_ram <= 1; 
                           else 
                              cs_colram <= 1;
                        end
            4'hE, 4'hF: begin
                           systemAddr[24:13] <= {modelRomBank, 3'b100};
                           systemWe <= 0;
                           cs_ram <= 1;
                        end
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
         // Character ROM
         systemAddr <= {modelRomBank, 4'hA, vicAddr[11:0]};
         cs_ram <= 1;
      end
      else if (statvid && phase) begin
         // 4k Static video RAM, Seg 15 $D3FF-$D000
         systemAddr <= {13'h00FD, 2'b00, vicAddr[9:0]};
         cs_ram <= 1;
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
      systemAddr <= {13'h00FD, 1'b0, crtcAddr};
      cs_ram <= 1;
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
   if (vidCycle && cs_ram)
      vidDi[7:0] <= ramData;
end

endmodule
