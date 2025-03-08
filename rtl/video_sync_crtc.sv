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

always @(posedge clk) begin
	integer hblank_delay;

	hsync_out <= hsync;
	vsync_out <= vsync;
	vblank_out <= vblank;

	if (hblank != hblank_out) begin
		hblank_delay <= hblank_delay - 1;
		if (hblank_delay == 1)
			hblank_out <= hblank;
	end
	else
		hblank_delay <= HBLANK_DELAY;
end

endmodule
