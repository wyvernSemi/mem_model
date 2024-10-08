// ====================================================================
//
// Verilog AHB bus functional model (BFM) wrapper for mem_model.
//
// Copyright (c) 2024 Simon Southwell.
//
// Implements minimal compliant manager interface at 32-bits wide.
// Also has a vectored irq input. Does not (yet) utilise VProc's burst
// capabilities.
//
// This file is part of VProc.
//
// VProc is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// VProc is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with VProc. If not, see <http://www.gnu.org/licenses/>.
//
// ====================================================================

`define AHB_SIZE_WORD         3'b010

`define AHB_BURST_SINGLE      3'b000
`define AHB_BURST_INCR        3'b001

`define AHB_TRANS_IDLE        2'b00
`define AHB_TRANS_BUSY        2'b01
`define AHB_TRANS_NONSEQ      2'b10
`define AHB_TRANS_SEQ         2'b11

module mem_model_ahb
# (parameter
    ADDRWIDTH                 = 32, // For future proofing. Do not change.
    DATAWIDTH                 = 32  // For future proofing. Do not change.0
)
(
    input                     hclk,
    input                     hresetn,

    input                     hsel,
    input  [ADDRWIDTH-1:0]    haddr,
    input  [DATAWIDTH-1:0]    hwdata,
    input                     hwrite,
    input  [2:0]              hburst,
    input  [2:0]              hsize,
    input  [1:0]              htrans,
    input                     hmastlock,
    input  [DATAWIDTH/8-1:0]  hwstrb,

    output [DATAWIDTH-1:0]    hrdata,
    output                    hready,
    output                    hresp

);

wire                          active_access;
wire                          mem_write;
wire                          mem_read;
wire                          mem_readdatavalid;
wire [DATAWIDTH-1:0]          mem_readdata;
wire [ADDRWIDTH-1:0]          mem_addr;
wire [ADDRWIDTH-1:0]          mem_addr_rw;

reg  [ADDRWIDTH-1:0]          mem_addr_phase;
reg                           mem_write_phase;
reg  [DATAWIDTH/8-1:0]        hwstrb_phase;

// ---------------------------------------------------------
// Combinatorial logic
// ---------------------------------------------------------

// Give error if selected, not idle, not a single or an undefined length incrementing burst, and not a 32 bit word transfer
assign hresp                  = hsel & |htrans & (|hburst[2:1] | ((hsize != `AHB_SIZE_WORD) ? 1'b1 : 1'b0));

// Access is active if selected, NONSEQ or SEQ and not an illegal transfer type
assign active_access          =  hsel & htrans[1] & ~hresp;
assign mem_write              =  hwrite & active_access;
assign mem_read               = ~hwrite & active_access & ~(hburst == `AHB_BURST_SINGLE & mem_readdatavalid);
assign mem_addr               = haddr;
assign mem_addr_rw            =  mem_write_phase   ? mem_addr_phase : mem_addr;

// The memory modelwon't stall on any access
assign hready                 = 1'b1;

assign hrdata                 = mem_readdatavalid ? mem_readdata : {DATAWIDTH{1'bx}};

// ---------------------------------------------------------
// Synchronous process
// ---------------------------------------------------------

always @(posedge hclk or negedge hresetn)
begin
  if (hresetn == 1'b0)
  begin
    mem_write_phase           <= 1'b0;
  end
  else
  begin
     mem_write_phase          <= mem_write;
     hwstrb_phase             <= hwstrb;
     mem_addr_phase           <= mem_addr;
  end
end

// ---------------------------------------------------------
// Core memory model
// ---------------------------------------------------------

  mem_model #(.EN_READ_QUEUE(0), .REG_READ_OVERLAP(1)) mem
  (
    .clk                      (hclk),
    .rst_n                    (hresetn),

    .address                  (mem_addr_rw),
    .byteenable               (hwstrb_phase),
    .write                    (mem_write_phase),
    .writedata                (hwdata),
    .read                     (mem_read),
    .readdata                 (mem_readdata),
    .readdatavalid            (mem_readdatavalid),

    .rx_waitrequest           (),
    .rx_burstcount            (12'h000),
    .rx_address               (haddr),
    .rx_read                  (1'b0),
    .rx_readdata              (),
    .rx_readdatavalid         (),

    .tx_waitrequest           (),
    .tx_burstcount            (12'h000),
    .tx_address               ({ADDRWIDTH{1'b0}}),
    .tx_write                 (1'b0),
    .tx_writedata             ({DATAWIDTH{1'b0}}),
    .tx_byteenable            ({DATAWIDTH/8{1'b0}}),

    .wr_port_valid            (1'b0),
    .wr_port_data             ({DATAWIDTH{1'b0}}),
    .wr_port_addr             ({ADDRWIDTH{1'b0}})
  );

endmodule