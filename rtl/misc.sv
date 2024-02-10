module rom_mem #(
	parameter DATAWIDTH,
	parameter ADDRWIDTH,
	parameter INITFILE="UNUSED"
)(
	input	                     clock_a,
	input	     [ADDRWIDTH-1:0] address_a,
	input	     [DATAWIDTH-1:0] data_a,
	input	                     wren_a,
	output reg [DATAWIDTH-1:0] q_a,

	input	                     clock_b,
	input	     [ADDRWIDTH-1:0] address_b,
	input	     [DATAWIDTH-1:0] data_b,
	input	                     wren_b,
	output reg [DATAWIDTH-1:0] q_b
);

altsyncram altsyncram_component (
	.clock0 (clock_a),
	.address_a (address_a),
	.addressstall_a (1'b0),
	.byteena_a (1'b1),
	.data_a (data_a),
	.rden_a (1'b1),
	.wren_a (wren_a),
	.q_a (q_a),

	.clock1 (clock_b),
	.address_b (address_b),
	.addressstall_b (1'b0),
	.byteena_b (1'b1),
	.data_b (data_b),
	.rden_b (1'b1),
	.wren_b (wren_b),
	.q_b (q_b)
);

defparam
	altsyncram_component.byte_size = DATAWIDTH,
	altsyncram_component.intended_device_family = "Cyclone V",
	altsyncram_component.lpm_hint = "ENABLE_RUNTIME_MOD=NO",
	altsyncram_component.lpm_type = "altsyncram",
	altsyncram_component.init_file = INITFILE,

	altsyncram_component.operation_mode = "BIDIR_DUAL_PORT",
	altsyncram_component.power_up_uninitialized = "FALSE",

	altsyncram_component.clock_enable_input_a = "BYPASS",
	altsyncram_component.clock_enable_output_a = "BYPASS",
	altsyncram_component.outdata_reg_a = "CLOCK0",
	altsyncram_component.outdata_aclr_a = "NONE",
	altsyncram_component.read_during_write_mode_port_a = "NEW_DATA_NO_NBE_READ",
	altsyncram_component.widthad_a = ADDRWIDTH,
	altsyncram_component.width_a = DATAWIDTH,

	altsyncram_component.clock_enable_input_b = "BYPASS",
	altsyncram_component.clock_enable_output_b = "BYPASS",
	altsyncram_component.outdata_reg_b = "CLOCK1",
	altsyncram_component.outdata_aclr_b = "NONE",
	altsyncram_component.read_during_write_mode_port_b = "NEW_DATA_NO_NBE_READ",
	altsyncram_component.widthad_b = ADDRWIDTH,
	altsyncram_component.width_b = DATAWIDTH;

endmodule

module sram #(
	parameter DATAWIDTH,
	parameter ADDRWIDTH
)(
	input	                     clock_a,
	input	     [ADDRWIDTH-1:0] address_a,
	input	     [DATAWIDTH-1:0] data_a,
	input	                     wren_a,
	output reg [DATAWIDTH-1:0] q_a
);

altsyncram altsyncram_component (
	.clock0 (clock_a),
	.address_a (address_a),
	.addressstall_a (1'b0),
	.byteena_a (1'b1),
	.data_a (data_a),
	.rden_a (1'b1),
	.wren_a (wren_a),
	.q_a (q_a)
);

defparam
	altsyncram_component.byte_size = DATAWIDTH,
	altsyncram_component.intended_device_family = "Cyclone V",
	altsyncram_component.lpm_hint = "ENABLE_RUNTIME_MOD=NO",
	altsyncram_component.lpm_type = "altsyncram",

	altsyncram_component.operation_mode = "SINGLE_PORT",
	altsyncram_component.power_up_uninitialized = "FALSE",

	altsyncram_component.clock_enable_input_a = "BYPASS",
	altsyncram_component.clock_enable_output_a = "BYPASS",
	altsyncram_component.outdata_reg_a = "CLOCK0",
	altsyncram_component.outdata_aclr_a = "NONE",
	altsyncram_component.read_during_write_mode_port_a = "NEW_DATA_NO_NBE_READ",
	altsyncram_component.widthad_a = ADDRWIDTH,
	altsyncram_component.width_a = DATAWIDTH;

endmodule
