module rom_mem #(parameter DATAWIDTH, ADDRWIDTH, INITFILE=" ")
(
	input	                     clock,
	input	     [ADDRWIDTH-1:0] address,
	input	     [DATAWIDTH-1:0] data,
	input	                     wren,
	output reg [DATAWIDTH-1:0] q
);

(* ram_init_file = INITFILE *) reg [DATAWIDTH-1:0] ram[1<<ADDRWIDTH];

reg                 wren_d;
reg [ADDRWIDTH-1:0] address_d;
always @(posedge clock) begin
	wren_d    <= wren;
	address_d <= address;
end

always @(posedge clock) begin
	if(wren_d) begin
		ram[address_d] <= data;
		q <= data;
	end else begin
		q <= ram[address_d];
	end
end

endmodule
