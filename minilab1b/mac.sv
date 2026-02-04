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
    // Input registers to break the combinational path from FIFO
    // Note: Ain/Bin are already registered at the FIFO output for 200MHz.
    // We only need to delay the control signals to match the FIFO latency.
    logic En_reg, Clr_reg;
    logic [DATA_WIDTH*2-1:0] prod_reg;
    logic en_reg2, clr_reg2;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            En_reg  <= '0;
            Clr_reg <= '0;
            prod_reg <= '0;
            en_reg2  <= '0;
            clr_reg2 <= '0;
        end else begin
            En_reg  <= En;
            Clr_reg <= Clr;

            // Product is captured 1 cycle after inputs are valid (at FIFO output)
            prod_reg <= Ain * Bin;
            en_reg2  <= En_reg;
            clr_reg2 <= Clr_reg;
        end
    end

    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n) begin
            Cout <= '0;
        end
        else if (clr_reg2) begin
            Cout <= '0;
        end
        else if (en_reg2) begin
            Cout <= Cout + prod_reg;
        end
    end
endmodule
