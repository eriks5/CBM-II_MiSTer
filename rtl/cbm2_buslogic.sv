module cbm2_buslogic (
   input         model,     // 0=Professional, 1=Business
   input [1:0]   ramSize,   // 0=128k, 1=256k, 2=1M, 3=16M
   
   input         clk_sys,
   input         reset,

   input  [15:0] cpuAddr,
   input  [7:0]  cpuPO,
   input         cpuWe,
   output [7:0]  cpuDi,

   output [24:0] ramAddr,
   input  [7:0]  ramData,
   output        ramWE,

   output        cs_ram,
   output        cs_romcrt,
   // output        cs_vidram,
   output        cs_colram,
   output        cs_vic,
   output        cs_crtc,
   output        cs_disk,
   output        cs_sid,
   output        cs_cop,
   output        cs_cia,
   output        cs_acia,
   output        cs_tpi1,
   output        cs_tpi2,

   // input  [7:0]  vidData,
   input  [3:0]  colData,
   input  [7:0]  vicData,
   input  [7:0]  crtcData,
   input  [7:0]  diskData,
   input  [7:0]  sidData,
   input  [7:0]  copData,
   input  [7:0]  ciaData,
   input  [7:0]  aciaData,
   input  [7:0]  tpi1Data,
   input  [7:0]  tpi2Data
);

reg         cs_rom1, cs_rom8, cs_romA, cs_romC, cs_romE;

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
   .address_b(cpuAddr),
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
   .address_b(cpuAddr),
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
   .address_b(cpuAddr),
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
   .address_b(cpuAddr),
   .q_b(romEData)
);

always @(*) begin
   cs_ram <= 0;
   cs_rom1 <= 0;
   cs_rom8 <= 0;
   cs_romA <= 0;
   cs_romC <= 0;
   cs_romE <= 0;
   cs_romcrt <= 0;
   // cs_vidram <= 0;
   cs_colram <= 0;
   cs_vic <= 0;
   cs_crtc <= 0;
   cs_disk <= 0;
   cs_sid <= 0;
   cs_cop <= 0;
   cs_cia <= 0;
   cs_acia <= 0;
   cs_tpi1 <= 0;
   cs_tpi2 <= 0;

   ramAddr[15:0] <= cpuAddr;
   ramAddr[23:16] <= cpuPO;
   ramAddr[24] <= 0;

   ramWE <= 0;

   if (cpuPO == 15) begin  // Bank 15
      case(cpuAddr[15:12])
         4'h0: begin // buffer RAM
                  ramWE  <= cpuWe;   
                  cs_ram <= 1;
               end
         4'h1: begin // Disk ROM
                  cs_rom1 <= 1;
               end
         4'h2, 4'h3, 4'h4, 4'h5, 4'h6, 4'h7:  // Cartpidge port ROM
               begin
                  cs_romcrt <= 1;
               end
         4'h8, 4'h9: begin // BASIC ROM lo
                  cs_rom8 <= 1;
               end
         4'hA, 4'hB: begin // BASIC ROM hi
                  cs_romA <= 1;
               end
         4'hC: if (model == 0) begin // Character ROM (P model only)
                  cs_romC <= 1;
               end
         4'hD: case(cpuAddr[11:8]) // I/O
                  4'h0, 4'h1, 4'h2, 4'h3: // Video RAM
                        cs_ram <= 1;
                  4'h4, 4'h5, 4'h6, 4'h7:
                        if (model == 0) cs_colram <= 1;
                        else            cs_ram    <= 1;
                  4'h8: if (model == 0) cs_vic    <= 1;
                        else            cs_crtc   <= 1;
                  4'h9: cs_disk <= 1;  // Disk
                  4'hA: cs_sid <= 1;   // SID
                  4'hB: cs_cop <= 1;   // Coprocessor
                  4'hC: cs_cia <= 1;   // CIA
                  4'hD: cs_acia <= 1;  // ACIA
                  4'hE: cs_tpi1 <= 1;  // tpi-port 1
                  4'hF: cs_tpi2 <= 1;  // tpi-port 2
               endcase
         4'hE, 4'hF: begin // Kernal ROM
                  cs_romE <= 1;
               end
         default: ;
      endcase
   end 
   else begin  // Other banks
      ramWE <= cpuWe;
      
      case (ramSize)
         0      : cs_ram <= model == 0 ? (cpuPO<=1) : (cpuPO>=1 && cpuPO<=2);   // 128k
         1      : cs_ram <= model == 0 ? (cpuPO<=3) : (cpuPO>=1 && cpuPO<=4);   // 256k
         default: cs_ram <= ~model || ~|cpuPO;                                  // all banks
      endcase
   end
end

always @(*) begin
   cpuDi <= 0;
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
   else if (cs_disk) begin
      cpuDi <= diskData;
   end
   else if (cs_sid) begin
      cpuDi <= sidData;
   end
   else if (cs_cop) begin
      cpuDi <= copData;
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
