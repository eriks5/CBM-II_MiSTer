//============================================================================
//
//  CBM-II CRTC Video sync adjust
//  Copyright (C) 2025 Erik Scheffers
//
//============================================================================

module video_sync_crtc
(
	input        clk,

	input        hsync,
	input        vsync,
	input        hblank,
	input        vblank,

	output       hsync_out,
	output       vsync_out,
	output       hblank_out,
	output       vblank_out
);

localparam HBLANK_DELAY = 7;

assign hsync_out  = hsync;
assign vsync_out  = vsync;
assign vblank_out = vblank;

always @(posedge clk) begin
	integer hblank_delay;

	if (hblank != hblank_out) begin
		if (!hblank_delay)
			hblank_delay <= HBLANK_DELAY;
		else
			hblank_delay <= hblank_delay - 1;

		if (hblank_delay == 1)
			hblank_out <= hblank;
	end
end

endmodule
