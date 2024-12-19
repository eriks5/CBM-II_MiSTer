/*
 * CBM-II 80-column character generator
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
