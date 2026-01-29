module FIFO
#(
  parameter DEPTH=8,
  parameter DATA_WIDTH=8
)
(
  input  clk,
  input  rst_n,
  input  rden,
  input  wren,
  input  [DATA_WIDTH-1:0] i_data,
  output logic [DATA_WIDTH-1:0] o_data,
  output logic full,
  output logic empty
);

logic [DATA_WIDTH-1:0] queue [DEPTH];
logic [$clog2(DEPTH)+1:0] head, tail, size;

always_ff @(posedge clk, negedge rst_n) begin
  if (!rst_n) begin
    head = '0;
    tail = '0;
    size = '0;
  end
  else if (rden) begin
    o_data = queue[head];
    head = (head + 1) % DEPTH;
    size -= 1;
  end
  else if (wren) begin
    queue[tail] = i_data;
    tail = (tail + 1) % DEPTH;
    size += 1;
  end
  full = size == DEPTH;
  empty = size == 0;
end

endmodule