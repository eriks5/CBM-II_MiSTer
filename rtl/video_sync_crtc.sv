//============================================================================
//
//  CBM-II BL/BH Video sync
//  Copyright (C) 2025 Erik Scheffers
//
//============================================================================

module video_sync_crtc
(
	input        clk32,
	input        ce_pix,

	input        hsync,
	input        vsync,
	input        hblank,
	input        vblank,

	output       hsync_out,
	output       vsync_out,
	output       hblank_out,
	output       vblank_out
);

localparam HBLANK_DELAY = 3;

assign hsync_out  = hsync;
assign vsync_out  = vsync;
assign hblank_out = hblank_delay[HBLANK_DELAY-1];
assign vblank_out = vblank;

reg [HBLANK_DELAY-1:0] hblank_delay;

always @(posedge clk32) begin
	if (ce_pix) begin
		hblank_delay[HBLANK_DELAY-1:1] <= hblank_delay[HBLANK_DELAY-2:0];
		hblank_delay[0] <= hblank;
	end
end

endmodule
