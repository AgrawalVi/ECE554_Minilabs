module matrix_vector_multi (
    input  logic        CLOCK_50,
    input  logic [3:0]  KEY,
    // FIFO fill interface (from Avalon loader)
    input  logic [7:0]  a_wren_in,
    input  logic [7:0]  a_data_in [8],
    input  logic        b_wren_in,
    input  logic [7:0]  b_data_in,

    output logic        done,
    output logic [23:0] C_matrix [8],
    output logic [2:0]  dbg_state,
    output logic [7:0]  a_full_out,
    output logic        b_full_out
);
    localparam int DataWidth = 8;
    localparam int Depth     = 8;
    localparam int N         = 8;

    // Compute FSM
    localparam logic [2:0] SWaitFull = 3'd0;
    localparam logic [2:0] SClr      = 3'd1;
    localparam logic [2:0] SExec     = 3'd2;
    localparam logic [2:0] SDone     = 3'd3;

    logic rst_n;
    assign rst_n = KEY[0];

    // ----------------------------
    // FIFOs: 8 for A rows, 1 for B
    // ----------------------------
    logic [N-1:0] a_wren, a_rden, a_full, a_empty;
    logic [DataWidth-1:0] a_in   [N];
    logic [DataWidth-1:0] a_out  [N];

    logic b_wren, b_rden, b_full, b_empty;
    logic [DataWidth-1:0] b_in, b_out;

    assign a_full_out = a_full;
    assign b_full_out = b_full;

    // External fill drives FIFO writes
    genvar gi;
    generate
        for (gi = 0; gi < N; gi = gi + 1) begin : gen_fill_map
            always_comb begin
                a_wren[gi] = a_wren_in[gi];
                a_in[gi]   = a_data_in[gi];
            end
        end
    endgenerate
    always_comb begin
        b_wren = b_wren_in;
        b_in   = b_data_in;
    end

    generate
        for (gi = 0; gi < N; gi = gi + 1) begin : gen_a_fifos
            FIFO #(
                .DEPTH(Depth),
                .DATA_WIDTH(DataWidth)
            ) a_fifo (
                .clk(CLOCK_50),
                .rst_n(rst_n),
                .rden(a_rden[gi]),
                .wren(a_wren[gi]),
                .i_data(a_in[gi]),
                .o_data(a_out[gi]),
                .full(a_full[gi]),
                .empty(a_empty[gi])
            );
        end
    endgenerate

    FIFO #(
        .DEPTH(Depth),
        .DATA_WIDTH(DataWidth)
    ) b_fifo (
        .clk(CLOCK_50),
        .rst_n(rst_n),
        .rden(b_rden),
        .wren(b_wren),
        .i_data(b_in),
        .o_data(b_out),
        .full(b_full),
        .empty(b_empty)
    );

    // ----------------------------
    // 8 MACs (one per output row)
    // En and B propagate left->right, 1 cycle per MAC.
    // ----------------------------
    logic [N-1:0] mac_en;
    logic [N-1:0] mac_clr;
    logic [DataWidth-1:0] b_pipe [N];
    logic [23:0] mac_cout [N];

    // Stage 0 uses the FIFO output directly
    assign b_pipe[0] = b_out;
    logic [DataWidth-1:0] b_d [1:N-1];

    // Stages 1..7 use the registered B pipeline values
    generate
        for (gi = 1; gi < N; gi = gi + 1) begin : gen_b_pipe
            assign b_pipe[gi] = b_d[gi];
        end
    endgenerate

    generate
        for (gi = 0; gi < N; gi = gi + 1) begin : gen_macs
            MAC #(
                .DATA_WIDTH(DataWidth)
            ) mac_i (
                .clk(CLOCK_50),
                .rst_n(rst_n),
                .En(mac_en[gi]),
                .Clr(mac_clr[gi]),
                .Ain(a_out[gi]),
                .Bin(b_pipe[gi]),
                .Cout(mac_cout[gi])
            );
        end
    endgenerate

    // Export results
    generate
        for (gi = 0; gi < N; gi = gi + 1) begin : gen_out
            assign C_matrix[gi] = mac_cout[gi];
        end
    endgenerate

    // ----------------------------
    // Control FSM
    // ----------------------------
    logic [2:0] state;
    logic [3:0] launch_count; // number of B elements launched (0..8)

    assign dbg_state = state;

    // Propagation registers for stages 1..7 (stage 0 is combinational)
    logic [N-1:1] en_d;
    logic [N-1:1] clr_d;

    // Default comb assigns
    integer k;
    always_comb begin
        for (k = 0; k < N; k = k + 1) begin
            a_rden[k] = 1'b0;
        end
        b_rden = 1'b0;

        // MAC stage enables/clears
        mac_en   = '0;
        mac_clr  = '0;

        done = (state == SDone);

        // EXEC stage 0 drive (stages 1..7 come from regs)
        if (state == SExec) begin
            mac_en[0]  = (launch_count < N) && !b_empty;
            mac_clr[0] = 1'b0;
        end
        if (state == SClr) begin
            mac_en[0]  = 1'b0;
            mac_clr[0] = 1'b1;
        end

        // Map registered stage signals (1..7)
        for (k = 1; k < N; k = k + 1) begin
            mac_en[k]  = en_d[k];
            mac_clr[k] = clr_d[k];
        end

        // FIFO reads align with MAC enables
        for (k = 0; k < N; k = k + 1) begin
            a_rden[k] = mac_en[k];
        end
        b_rden = mac_en[0];
    end

    // Sequential state / counters / pipelines
    always_ff @(posedge CLOCK_50 or negedge rst_n) begin
        if (!rst_n) begin
            state        <= SWaitFull;
            launch_count <= 4'd0;

            en_d  <= '0;
            clr_d <= '0;
            for (int bi = 1; bi < N; bi++) begin
                b_d[bi] <= '0;
            end
        end else begin
            // Shift En/Clr/B pipelines for stages 1..7
            // Stage 1 receives stage-0 signals; stage i receives stage (i-1) delayed.
            en_d[1]  <= mac_en[0];
            clr_d[1] <= mac_clr[0];
            if (mac_en[0]) begin
                b_d[1] <= b_out;
            end
            for (int si = 2; si < N; si++) begin
                en_d[si]  <= en_d[si-1];
                clr_d[si] <= clr_d[si-1];
                if (en_d[si-1]) begin
                    b_d[si] <= b_d[si-1];
                end
            end
            case (state)
                SWaitFull: begin
                    launch_count <= 4'd0;
                    if ((&a_full) && b_full) begin
                        state <= SClr;
                    end
                end
                SClr: begin
                    // Single cycle: Clr propagates; next cycle start executing
                    state        <= SExec;
                    launch_count <= 4'd0;
                end
                SExec: begin
                    if (mac_en[0]) begin
                        launch_count <= launch_count + 1'b1;
                    end
                    // Done when all 8 B elements launched and the pipeline is drained
                    if ((launch_count >= N) && (en_d == '0)) begin
                        state <= SDone;
                    end
                end
                SDone: begin
                    state <= SDone;
                end
                default: state <= SWaitFull;
            endcase
        end
    end

endmodule
