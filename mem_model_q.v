module mem_model_q
#(parameter
   DEPTH                       = 4,
   WIDTH                       = 32+12,
   NEARLYFULL                  = (DEPTH/2)
)
(
  input                        clk,
  input                        reset_n,

  input                        clr,

  input                        write,
  input      [WIDTH-1:0]       wdata,

  input                        read,
  output     [WIDTH-1:0]       rdata,

  output reg                   empty,
  output reg                   full,
  output reg                   nearly_full
);

localparam                     LOG2DEPTH = $clog2(DEPTH);

reg  [WIDTH-1:0]               mem [0:DEPTH-1];
reg  [LOG2DEPTH:0]             wptr;
reg  [LOG2DEPTH:0]             rptr;

// The number of words in the FIFO is the write pointer minus the read pointer
wire [LOG2DEPTH:0]             word_count = (wptr - rptr);

assign rdata                   = mem[rptr[LOG2DEPTH-1:0]];

always @(posedge clk or negedge reset_n)
begin
  if (reset_n == 1'b0)
  begin
    wptr                       <= {LOG2DEPTH{1'b0}};
    rptr                       <= {LOG2DEPTH{1'b0}};
    empty                      <= 1'b1;
    full                       <= 1'b0;
    nearly_full                <= 1'b0;
  end
  else
  begin
    // If a write arrives, and not full, write to memory and update write pointer
    if (write && ~full)
    begin
      mem[wptr[LOG2DEPTH-1:0]] <= wdata;
      wptr                     <= wptr + 1;
    end

    // If a read arrives, and not empty, fetch data from memory and update read pointer
    if (read && ~empty)
    begin
      rptr                     <= rptr + 1;
    end

    // If writing, but not reading, update full status when last space being written.
    // The nearly full flag is asserted when about to reach the threshold, or is greater.
    // A write (without read) always clears the empty flag
    if (write & ~(read & ~empty))
    begin
      full                     <= (word_count == DEPTH-1)      ? 1'b1 : 1'b0;
      nearly_full              <= (word_count >= NEARLYFULL-1) ? 1'b1 : 1'b0;
      empty                    <= 1'b0;
    end

    // If reading (but not writing), update empty status when last data is being read.
    // The nearly full flag is deasserted when about to drop below the threshold, or
    // is smaller. A read (without a write), always clears the full status.
    if (read & ~(write & ~full))
    begin
      empty                    <= (word_count == 1)            ? 1'b1 : 1'b0;
      nearly_full              <= (word_count <= NEARLYFULL)   ? 1'b0 : 1'b1;
      full                     <= 1'b0;
    end
  end
end

endmodule