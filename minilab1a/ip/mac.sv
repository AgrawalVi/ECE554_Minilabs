module MAC #
(
parameter DATA_WIDTH = 8
)
(
input clk,
input rst_n,
input En,
input Clr,
input [DATA_WIDTH-1:0] Ain,
input [DATA_WIDTH-1:0] Bin,
output logic [DATA_WIDTH*3-1:0] Cout
);

logic [DATA_WIDTH*3-1:0] product, next_cout;

lpm_mult_ip mult(
    .dataa(Ain),
    .datab(Bin),
    .result(product)
);

lpm_add_sub_ip add(
    .dataa(Cout),
    .datab(product),
    .result(next_cout)
);

always_ff @(posedge clk, negedge rst_n) begin
    if (!rst_n) begin
        Cout <= '0;
    end
    else if (Clr) begin
        Cout <= '0;
    end
    else if (En) begin
        Cout <= next_cout;
    end
end
endmodule
