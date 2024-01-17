module cbm2_buslogic (
   input         model,     // 0=Professional, 1=Business
   input [1:0]   ramSize,   // 0=128k, 1=256k, 2=1M, 3=16M
   input         ipcRamEn,  // Enable IPC RAM (seg 15 $0FFF-$0800)

   input         clk_sys,
   input         reset,

   input         cpuHasBus,
   input  [15:0] cpuAddr,
   input  [7:0]  cpuSeg,
   output [7:0]  cpuDi,

   input  [15:0] vidAddr,

   input         vicdotsel,
   input         statvid,
   input         vicPhase,

   output [23:0] systemAddr,

   input  [7:0]  ramData,

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

   // input  [7:0]  vidData,
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

reg         cs_rom8, cs_romA, cs_romC, cs_romE;

wire [11:0] rom_addr = 0;
wire [7:0]  rom_data = 0;
wire        rom_wr = 0;

wire [7:0] rom8Data;
rom_mem #(8,13,"rtl/roms/PL/b500-8000.901243-01.mif") rom_basic_lo_p
(
   .clock_a(clk_sys),
   .address_a(rom_addr),
   .data_a(rom_data),
   .wren_a(rom_wr),

   .clock_b(clk_sys),
   .address_b(systemAddr),
   .q_b(rom8Data)
);

wire [7:0] romAData;
rom_mem #(8,13,"rtl/roms/PL/b500-a000.901242-01a.mif") rom_basic_hi_p
(
   .clock_a(clk_sys),
   .address_a(rom_addr),
   .data_a(rom_data),
   .wren_a(rom_wr),

   .clock_b(clk_sys),
   .address_b(systemAddr),
   .q_b(romAData)
);

wire [7:0] romCData;
rom_mem #(8,12,"rtl/roms/PL/characters.901225-01.mif") rom_char_p
(
   .clock_a(clk_sys),
   .address_a(rom_addr),
   .data_a(rom_data),
   .wren_a(rom_wr),

   .clock_b(clk_sys),
   .address_b(systemAddr),
   .q_b(romCData)
);

wire [7:0] romEData;
rom_mem #(8,13,"rtl/roms/PL/kernal.901234-02.mif") rom_kernal_p
(
   .clock_a(clk_sys),
   .address_a(rom_addr),
   .data_a(rom_data),
   .wren_a(rom_wr),

   .clock_b(clk_sys),
   .address_b(systemAddr),
   .q_b(romEData)
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
         4'hB:             cs_ipcia  <= 1; // IPCIA
         4'hC:             cs_cia    <= 1; // CIA
         4'hD:             cs_acia   <= 1; // ACIA
         4'hE:             cs_tpi1   <= 1; // tpi-port 1
         4'hF:             cs_tpi2   <= 1; // tpi-port 2
         default:          ;
      endcase

end

always @(*) begin
   // Decode RAM/ROM

   systemAddr <= 24'h0;

   cs_ram <= 0;
   cs_rom8 <= 0;
   cs_romA <= 0;
   cs_romC <= 0;
   cs_romE <= 0;

   if (cpuHasBus) begin
      systemAddr <= {cpuSeg, cpuAddr};

      if (cpuSeg == 15) // Segment 15
         case(cpuAddr[15:12])
            4'h0: if (~cpuAddr[11] || ipcRamEn) cs_ram    <= 1; // Buffer ram
            4'h8, 4'h9:                         cs_rom8   <= 1; // BASIC ROM lo
            4'hA, 4'hB:                         cs_romA   <= 1; // BASIC ROM hi
            4'hC:                               cs_romC   <= 1; // Character ROM (P2 only)
            4'hD: case(cpuAddr[11:8])
                     4'h0, 4'h1, 4'h2, 4'h3:    cs_ram    <= 1; // Video RAM
                     4'h4, 4'h5, 4'h6, 4'h7:
                                    if (!model) cs_ram    <= 1; // Video RAM (B2)
                     default:                   ;
                  endcase
            4'hE, 4'hF:                         cs_romE   <= 1; // Kernal
            default: ;
         endcase
      else
         case (ramSize)
            0      : cs_ram <= model == 0 ? (cpuSeg<=1) : (cpuSeg>=1 && cpuSeg<=2);   // 128k (Standard)
            1      : cs_ram <= model == 0 ? (cpuSeg<=3) : (cpuSeg>=1 && cpuSeg<=4);   // 256k (Standard+Expansion)
            default: cs_ram <= 1;                                                     // all segments
         endcase
   end
   else if (!model) begin
      if (vicdotsel && !vicPhase) begin
         // Seg 15, $CFFF-$C000 (Character ROM)
         systemAddr <= {12'h0FC, vidAddr[11:0]};
         cs_romC <= 1;
      end
      else if (statvid) begin
         // Seg 15, $D3FF-$D000 (Video RAM)
         systemAddr <= {12'h0FD, 2'b00, vidAddr[9:0]};
         cs_ram <= 1;
      end
      else begin
         // Seg 0
         systemAddr <= {8'h00, vidAddr};
         cs_ram <= 1;
      end
   end
end

reg [7:0] lastCpuDi;

always @(posedge clk_sys) begin
   if (cpuHasBus)
      lastCpuDi <= cpuDi;
end

always @(*) begin
   cpuDi <= lastCpuDi;

   if (cpuHasBus)
      if (cs_ram) begin
         cpuDi <= ramData;
      end
      else if (cs_rom8) begin
         cpuDi <= rom8Data;
      end
      else if (cs_romA) begin
         cpuDi <= romAData;
      end
      else if (cs_romC) begin
         cpuDi <= romCData;
      end
      else if (cs_romE) begin
         cpuDi <= romEData;
      end
      // else if (cs_vidram) begin
      //    cpuDi <= vidData;
      // end
      else if (cs_colram) begin
         cpuDi[3:0] <= colData;
      end
      else if (cs_vic) begin
         cpuDi <= vicData;
      end
      else if (cs_sid) begin
         cpuDi <= sidData;
      end
      else if (cs_ipcia) begin
         cpuDi <= ipciaData;
      end
      else if (cs_cia) begin
         cpuDi <= ciaData;
      end
      else if (cs_acia) begin
         cpuDi <= aciaData;
      end
      else if (cs_tpi1) begin
         cpuDi <= tpi1Data;
      end
      else if (cs_tpi2) begin
         cpuDi <= tpi2Data;
      end
end

endmodule
