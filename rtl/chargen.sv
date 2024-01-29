module chargen (
   input         clk_sys,

   input         profile,   // 0=Low, 1=High (Business only)
   input  [12:0] dotA,
   output  [7:0] dotD
);

wire [7:0] charBL;
rom_mem #(8,13,"rtl/roms/characters.901237-01.mif") char_bl
(
   .clock(clk_sys),
   .address(dotA),
   .q(charBL)
);

wire [7:0] charBH;
rom_mem #(8,13,"rtl/roms/characters.901232-01.mif") char_bh
(
   .clock(clk_sys),
   .address(dotA),
   .q(charBH)
);

assign dotD = profile ? charBH : charBL;

endmodule
