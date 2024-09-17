// -----------------------------------------------------------------------------
//  Title      : Verilog memory model AXI subordinate
//  Project    : UNKNOWN
// -----------------------------------------------------------------------------
//  File       : mem_model_axi.vhd
//  Author     : Simon Southwell
//  Created    : 2024-09-17
//  Standard   : Verilog 2001
// -----------------------------------------------------------------------------
//  Description:
//  A Verilog AXI subordinate wrapper around mem_model
// -----------------------------------------------------------------------------
//  Copyright (c) 2024 Simon Southwell
// -----------------------------------------------------------------------------
//
//  This is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation(), either version 3 of the License(), or
//  (at your option) any later version.
//
//  It is distributed in the hope that it will be useful(),
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this code. If not, see <http://www.gnu.org/licenses/>.
//
// -----------------------------------------------------------------------------

module mem_model_axi
# (parameter
    ADDRWIDTH                 = 32,
    DATAWIDTH                 = 32,
    ID_W_WIDTH                = 4,
    ID_R_WIDTH                = 4,
    CMDQ_DEPTH                = 8,
    DATAQ_DEPTH               = 64
)
(
    input                     clk,
    input                     nreset,

    // Write address channel
    input  [ADDRWIDTH-1:0]    awaddr,
    input                     awvalid,
    output                    awready,

      // Unused at the moment
    input  [1:0]              awburst,
    input  [2:0]              awsize,
    input  [7:0]              awlen,
    input  [ID_W_WIDTH-1:0]   awid,

    // Write Data channel
    input  [DATAWIDTH-1:0]    wdata,
    input                     wvalid,
    output                    wready,
    input  [DATAWIDTH/8-1:0]  wstrb,

    // Write response channel
    output reg                bvalid,
    input                     bready,
    output [ID_W_WIDTH-1:0]   bid,

    // Read address channel
    input  [ADDRWIDTH-1:0]    araddr,
    input                     arvalid,
    output                    arready,

    // Unused at the moment
    input  [1:0]              arburst,
    input  [2:0]              arsize,
    input  [7:0]              arlen,
    input  [ID_R_WIDTH-1:0]   arid,

    // Read data/response channel
    output [DATAWIDTH-1:0]    rdata,
    output                    rvalid,
    input                     rready,
    output                    rlast,
    output [ID_R_WIDTH-1:0]   rid
);

wire [31:0]                           av_address;
wire [3:0]                            av_byteenable;
wire                                  av_write;
wire [31:0]                           av_writedata;
wire                                  av_read;
wire [31:0]                           av_readdata;
wire                                  av_readdatavalid;

wire                                  aw_q_full;
wire                                  aw_q_empty;
wire [ADDRWIDTH+2+3+8+ID_W_WIDTH-1:0] aw_q_wdata;
wire [ADDRWIDTH+2+3+8+ID_W_WIDTH-1:0] aw_q_rdata;

wire                                  ar_q_full;
wire                                  ar_q_empty;
wire [ADDRWIDTH+2+3+8+ID_R_WIDTH-1:0] ar_q_wdata;
wire [ADDRWIDTH+2+3+8+ID_R_WIDTH-1:0] ar_q_rdata;

wire                                  w_q_write;
wire                                  w_q_full;
wire                                  w_q_empty;
wire [DATAWIDTH+DATAWIDTH/8-1:0]      w_q_wdata;
wire [DATAWIDTH+DATAWIDTH/8-1:0]      w_q_rdata;

wire                                  rnw_arb;

reg                                   last_rnw;
reg                                   hold_rvalid;
reg  [DATAWIDTH-1:0]                  hold_rdata;


initial
begin
  bvalid                      <= 1'b0;
  last_rnw                    <= 1'b0;
end

// ---------------------------------------------------------
// Combinatorial logic
// ---------------------------------------------------------

// WRITE ADDRESS PORT LOGIC
assign awready                = ~aw_q_full;
assign aw_q_wdata             = {awid, awlen, awsize, awburst, awaddr};

// WRITE DATA PORT LOGIC
assign wready                 = ~w_q_full;
assign w_q_wdata              = {wstrb, wdata};

// READ ADDRESS PORT LOGIC
assign arready                = ~ar_q_full;
assign ar_q_wdata             = {arid, arlen, arsize, arburst, araddr};

// READ DATA PORT LOGIC

// Output held memory read if read response stalled, else return memory output if valid, else make X
assign rdata                  = (hold_rvalid == 1'b1)      ? hold_rdata  :
                                (av_readdatavalid == 1'b1) ? av_readdata :
                                                             {DATAWIDTH{1'bx}};

// Read valid when data memory read valid, or read response stalled
assign rvalid                 = av_readdatavalid | hold_rvalid;
assign rlast                  = rvalid;

// MEMORY ACCESS LOGIC

// Select a read if a read command ready and not a write command ready
// and read was the last access type.
assign rnw_arb                = ~ar_q_empty & ~(~aw_q_empty & ~w_q_empty & last_rnw);

assign av_address             = (rnw_arb == 1'b0) ? aw_q_rdata[ADDRWIDTH-1:0] : ar_q_rdata[ADDRWIDTH-1:0];
assign av_byteenable          = (rnw_arb == 1'b0) ?  w_q_rdata[DATAWIDTH+DATAWIDTH/8-1:DATAWIDTH] : {DATAWIDTH/8{1'b1}} ;

assign av_writedata           = w_q_rdata[DATAWIDTH-1:0];

// Write if arbitration selecting writes, and write address/data ready and not stalled on write response
assign av_write               = ~rnw_arb & ~aw_q_empty & ~w_q_empty & ~(bvalid & ~bready);

// Read if arbitration selecting reads, and a read ready to go and not stalled on read response
assign av_read                = rnw_arb & ~ar_q_empty & ~(rvalid & ~rready);

// ---------------------------------------------------------
// Synchronous process
// ---------------------------------------------------------

always @(posedge clk)
begin
  // Set bvalid when written to memory, and hold until bready asserted
  bvalid                      <= (av_write | (bvalid & ~bready)) & nreset;

  // Last access read-not-write status set on read to memory and held, cleared on a write
  last_rnw                    <= (last_rnw | av_read) & ~av_write & nreset;

  // Held rvalid if read response port stalled
  hold_rvalid                 <= rvalid & ~rready & nreset;

  // Hold the memory read data
  hold_rdata                  <= (av_readdatavalid == 1'b1) ? av_readdata : hold_rdata;

end

// ---------------------------------------------------------
// Write address queue
// ---------------------------------------------------------

  mem_model_q
  #(
    .DEPTH                    (CMDQ_DEPTH),
    .WIDTH                    (ADDRWIDTH+2+3+8+ID_W_WIDTH)
  ) aw_q
  (
    .clk                      (clk),
    .reset_n                  (nreset),

    .write                    (awvalid),
    .wdata                    (aw_q_wdata),
    .full                     (aw_q_full),

    .read                     (av_write),
    .rdata                    (aw_q_rdata),
    .empty                    (aw_q_empty),

    .clr                      (1'b0),
    .nearly_full              ()
  );

// ---------------------------------------------------------
// Write data queue
// ---------------------------------------------------------

  mem_model_q
  #(
    .DEPTH                    (DATAQ_DEPTH),
    .WIDTH                    (DATAWIDTH+DATAWIDTH/8)
  ) w_q
  (
    .clk                      (clk),
    .reset_n                  (nreset),

    .write                    (wvalid),
    .wdata                    (w_q_wdata),
    .full                     (w_q_full),

    .read                     (wvalid),
    .rdata                    (w_q_rdata),
    .empty                    (w_q_empty),

    .clr                      (1'b0),
    .nearly_full              ()
  );

// ---------------------------------------------------------
// Read address queue
// ---------------------------------------------------------

  mem_model_q
  #(
    .DEPTH                    (CMDQ_DEPTH),
    .WIDTH                    (ADDRWIDTH+2+3+8+ID_W_WIDTH)
  ) ar_q
  (
    .clk                      (clk),
    .reset_n                  (nreset),

    .write                    (arvalid),
    .wdata                    (ar_q_wdata),
    .full                     (ar_q_full),

    .read                     (av_read),
    .rdata                    (ar_q_rdata),
    .empty                    (ar_q_empty),

    .clr                      (1'b0),
    .nearly_full              ()
  );

// ---------------------------------------------------------
// Core memory model
// ---------------------------------------------------------

  mem_model mem
  (
    .clk                      (clk),
    .rst_n                    (nreset),

    .address                  (av_address),
    .byteenable               (av_byteenable),
    .write                    (av_write),
    .writedata                (av_writedata),
    .read                     (av_read),
    .readdata                 (av_readdata),
    .readdatavalid            (av_readdatavalid),

    .rx_waitrequest           (open),
    .rx_burstcount            (12'h0),
    .rx_address               ({ADDRWIDTH{1'b0}}),
    .rx_read                  (1'b0),
    .rx_readdata              (),
    .rx_readdatavalid         (),

    .tx_waitrequest           (),
    .tx_burstcount            (12'h0),
    .tx_address               ({ADDRWIDTH{1'b0}}),
    .tx_write                 (1'b0),
    .tx_writedata             ({DATAWIDTH{1'b0}}),

    .wr_port_valid            (),
    .wr_port_data             ({DATAWIDTH{1'b0}}),
    .wr_port_addr             ({ADDRWIDTH{1'b0}})
  );

endmodule