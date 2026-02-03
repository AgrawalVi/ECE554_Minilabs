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

fifo_ip fifo(
  .aclr(~rst_n),
  .data(i_data),
  .rdclk(clk),
  .rdreq(rden),
  .wrclk(clk),
  .wrreq(wren),
  .q(o_data),
  .rdempty(empty),
  .wrfull(full)
);

endmodule
