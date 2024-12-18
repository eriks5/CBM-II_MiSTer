module chargen (
   input         clk_sys,

   input         profile,
   input  [12:0] dotA,
   output  [7:0] dotD,

   input   [5:0] rom_id,
   input  [13:0] rom_addr,
   input         rom_wr,
   input   [7:0] rom_data
);

wire [7:0] charBL;
rom_mem #(8,13,"rtl/roms/characters.901237-01.mif") char_bl
(
   .clock_a(clk_sys),
   .address_a(dotA),
   .q_a(charBL)

   // .clock_b(clk_sys),
   // .address_b(rom_addr),
   // .data_b(rom_data),
   // .wren_b(rom_wr & rom_id==12 & !rom_addr[13])
);

wire [7:0] charBH;
rom_mem #(8,13,"rtl/roms/characters.901232-01.mif") char_bh
(
   .clock_a(clk_sys),
   .address_a(dotA),
   .q_a(charBH)

   // .clock_b(clk_sys),
   // .address_b(rom_addr),
   // .data_b(rom_data),
   // .wren_b(rom_wr & rom_id==13 & !rom_addr[13])
);

assign dotD = profile ? charBH : charBL;

endmodule
