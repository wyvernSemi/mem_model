// ====================================================================
//
// Verilog APB bus functional model (BFM) wrapper for mem_model.
//
// Copyright (c) 2024 Simon Southwell.
//
// Implements minimal compliant completer interface at 32-bits wide.
// Also has a vectored irq input.
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


module mem_model_apb
# (parameter
    ADDRWIDTH                 = 32, // For future proofing. Do not change.
    DATAWIDTH                 = 32  // For future proofing. Do not change.0
)
(
    input                     pclk,
    input                     presetn,

    input                     psel,

    input     [ADDRWIDTH-1:0] paddr,
    input     [DATAWIDTH-1:0] pwdata,
    input                     pwrite,
    input                     penable,

    input   [DATAWIDTH/8-1:0] pstrb,
    input               [2:0] pprot,

    output    [DATAWIDTH-1:0] prdata,
    output                    pready,
    output                    pslverr

);

wire                          mem_write;
wire                          mem_read;
wire                          mem_readdatavalid;
wire [DATAWIDTH-1:0]          mem_readdata;
wire [DATAWIDTH-1:0]          mem_writedata;
wire [ADDRWIDTH-1:0]          mem_addr;
wire [DATAWIDTH/8-1:0]        mem_be;

wire                          addr_phase;
wire                          data_phase;

// ---------------------------------------------------------
// Combinatorial logic
// ---------------------------------------------------------

// Pass address, write data and write strobes straight through to memory
assign mem_addr               = paddr;
assign mem_writedata          = pwdata;
assign mem_be                 = pstrb;

// In address phase when selected and PENABLE low and data phase when PENABLE high
assign addr_phase             = psel & ~penable;
assign data_phase             = psel &  penable;

// Write to memory in the address phase
assign mem_write              = pwrite & addr_phase;

// Read from memory in the address phase
assign mem_read               = ~pwrite & addr_phase;

// Signal pready immediately in data phase of write or, when reading, in the data phase and read data valid from memory
assign pready                 = (pwrite & data_phase) | (~pwrite & data_phase & mem_readdatavalid);

// Export memory read data directly from memory
assign prdata                 = mem_readdata;

// No possible error conditions
assign pslverr                = 1'b0;

// ---------------------------------------------------------
// Core memory model
// ---------------------------------------------------------

  mem_model #(.EN_READ_QUEUE(0), .REG_READ_OVERLAP(1)) mem
  (
    .clk                      (pclk),
    .rst_n                    (presetn),

    .address                  (mem_addr),
    .byteenable               (mem_be),
    .write                    (mem_write),
    .writedata                (mem_writedata),
    .read                     (mem_read),
    .readdata                 (mem_readdata),
    .readdatavalid            (mem_readdatavalid),

    .rx_waitrequest           (),
    .rx_burstcount            (12'h000),
    .rx_address               ({ADDRWIDTH{1'b0}}),
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