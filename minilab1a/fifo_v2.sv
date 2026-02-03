module FIFO_v2
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

  fifo_ip fifo (
    .aclr(~rst_n),
    .rdclk(clk),
    .wrclk(clk),
    .data(i_data),
    .rdreq(rden),
    .wrreq(wren),
    .rdempty(empty),
    .wrfull(full),
    .q(o_data)
  );

endmodule
