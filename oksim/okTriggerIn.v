//------------------------------------------------------------------------
// okTriggerIn.v
//
// This module simulates the "Trigger In" endpoint.
//
//------------------------------------------------------------------------
// Copyright (c) 2005-2022 Opal Kelly Incorporated
// $Rev$ $Date$
//------------------------------------------------------------------------
`default_nettype none
`timescale 1ns / 1ps

module okTriggerIn(
	input  wire [112:0] okHE,
	input  wire [7:0]   ep_addr,
	input  wire         ep_clk,
	output reg  [31:0]  ep_trigger
	);

`include "parameters.vh" 
`include "mappings.vh"

reg  [31:0] eptrig;


always @(posedge ep_clk or posedge ti_reset) begin
	#TTRIG_DELAY;
	if (ti_reset == 1) begin
		ep_trigger = 0;
	end else begin   
		ep_trigger = eptrig;
		eptrig = 0;
	end
end

always @(posedge ti_clk) begin
	if (ti_reset == 1)
		eptrig = 0;
	else if ((ti_write == 1) && (ti_addr == ep_addr))
		eptrig = eptrig ^ ti_datain;
end

initial begin
	if ((ep_addr < 8'h40) || (ep_addr > 8'h5F)) begin
		$error("okTriggerIn endpoint address outside valid range, must be between 0x40 and 0x5F");
		$finish;
	end
end

endmodule

`default_nettype wire