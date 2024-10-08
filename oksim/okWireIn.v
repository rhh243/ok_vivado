//------------------------------------------------------------------------
// okWireIn.v
//
// This module simulates the "Wire In" endpoint.
//
//------------------------------------------------------------------------
// Copyright (c) 2005-2022 Opal Kelly Incorporated
// $Rev$ $Date$
//------------------------------------------------------------------------
`default_nettype none
`timescale 1ns / 1ps

module okWireIn(
	input  wire [112:0] okHE,
	input  wire [7:0]   ep_addr,
	output reg  [31:0]  ep_dataout
	);

`include "parameters.vh" 
`include "mappings.vh"

reg  [31:0] ep_datahold;

always @(posedge ti_clk) begin
	if ((ti_write == 1'b1) && (ti_addr == ep_addr)) ep_datahold = ti_datain;
	if (ti_wireupdate == 1'b1) ep_dataout = #TDOUT_DELAY ep_datahold;
	if (ti_reset == 1'b1) begin
		ep_datahold = #TDOUT_DELAY 0;
		ep_dataout  = 0;
	end
end

initial begin
	if ((ep_addr < 8'h00) || (ep_addr > 8'h1F)) begin
		$error("okWireIn endpoint address outside valid range, must be between 0x00 and 0x1F");
		$finish;
	end
end

endmodule

`default_nettype wire