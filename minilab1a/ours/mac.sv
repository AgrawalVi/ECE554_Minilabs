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
    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n) begin
            Cout <= '0;
        end
        else if (Clr) begin
            Cout <= '0;
        end
        else if (En) begin
            Cout <= Cout + Ain * Bin;
        end
    end
endmodule
