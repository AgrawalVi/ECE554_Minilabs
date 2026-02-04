module avalon_fifo_loader (
    input  logic        clk,
    input  logic        rst_n,

    // Avalon-MM master (to mem_wrapper slave)
    output logic [31:0] avm_address,
    output logic        avm_read,
    input  logic [63:0] avm_readdata,
    input  logic        avm_readdatavalid,
    input  logic        avm_waitrequest,

    // FIFO fill interface (to matrix_vector_multi)
    output logic [7:0]  a_wren,
    output logic [63:0] a_data_out, // Flattened: 8 * 8 bits
    output logic        b_wren,
    output logic [7:0]  b_data,

    // FIFO status (from matrix_vector_multi FIFOs)
    input  logic [7:0]  a_full,
    input  logic        b_full,

    output logic        done,
    output logic [3:0]  dbg_state,
    output logic [3:0]  dbg_row,
    output logic [3:0]  dbg_byte
);
    localparam int N = 8;

    // Loader states
    localparam logic [3:0] LIdle      = 4'd0;
    localparam logic [3:0] LIssueRead = 4'd1;
    localparam logic [3:0] LWaitData  = 4'd2;
    localparam logic [3:0] LPushA     = 4'd3;
    localparam logic [3:0] LPushB     = 4'd4;
    localparam logic [3:0] LDone      = 4'd5;

    logic [3:0] state;
    logic [3:0] row_idx;   // 0..8 (8 is B vector)
    logic [3:0] byte_idx;  // 0..7
    logic [63:0] row_buf;

    logic [7:0] a_data [N]; // Internal array

    assign dbg_state = state;
    assign dbg_row   = row_idx;
    assign dbg_byte  = byte_idx;

    // Byte selection: match the .mif order 01 02 03 ... packed MSB->LSB
    function automatic logic [7:0] sel_byte(input logic [63:0] v, input logic [3:0] bi);
        sel_byte = v[8*(7-bi) +: 8];
    endfunction

    integer k;
    always_comb begin
        // Defaults
        avm_address = 32'd0;
        avm_read    = 1'b0;

        for (k = 0; k < N; k = k + 1) begin
            a_wren[k] = 1'b0;
            a_data[k] = 8'h00;
        end
        b_wren = 1'b0;
        b_data = 8'h00;

        done = (state == LDone);
        
        case (state)
            LIssueRead: begin
                avm_address = {28'd0, row_idx[3:0]};
                // For this mem_wrapper implementation, a 1-cycle pulse is enough.
                avm_read    = 1'b1;
            end
            LPushA: begin
                // Only write when FIFO not full
                if (!a_full[row_idx]) begin
                    a_wren[row_idx] = 1'b1;
                    a_data[row_idx] = sel_byte(row_buf, byte_idx);
                end
            end
            LPushB: begin
                if (!b_full) begin
                    b_wren = 1'b1;
                    b_data = sel_byte(row_buf, byte_idx);
                end
            end
            default: begin
            end
        endcase
    end

    // Flatten a_data array to a_data_out output
    genvar gi;
    generate
        for (gi = 0; gi < N; gi = gi + 1) begin : gen_out_map
            assign a_data_out[gi*8 +: 8] = a_data[gi];
        end
    endgenerate

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state    <= LIssueRead;
            row_idx  <= 4'd0;
            byte_idx <= 4'd0;
            row_buf  <= 64'd0;
        end else begin
            case (state)
                LIdle: begin
                    state <= LIssueRead;
                end

                LIssueRead: begin
                    // Move to waiting for data; mem_wrapper will assert waitrequest internally.
                    state <= LWaitData;
                end

                LWaitData: begin
                    if (avm_readdatavalid) begin
                        row_buf  <= avm_readdata;
                        byte_idx <= 4'd0;
                        if (row_idx < 4'd8) begin
                            state <= LPushA;
                        end else begin
                            state <= LPushB;
                        end
                    end
                end

                LPushA: begin
                    // Advance only when the write actually happens (FIFO not full)
                    if (!a_full[row_idx]) begin
                        if (byte_idx == 4'd7) begin
                            byte_idx <= 4'd0;
                            if (row_idx == 4'd7) begin
                                row_idx <= 4'd8; // B vector row
                                state   <= LIssueRead;
                            end else begin
                                row_idx <= row_idx + 1'b1;
                                state   <= LIssueRead;
                            end
                        end else begin
                            byte_idx <= byte_idx + 1'b1;
                        end
                    end
                end

                LPushB: begin
                    if (!b_full) begin
                        if (byte_idx == 4'd7) begin
                            state <= LDone;
                        end else begin
                            byte_idx <= byte_idx + 1'b1;
                        end
                    end
                end

                LDone: begin
                    state <= LDone;
                end

                default: state <= LIssueRead;
            endcase
        end
    end

endmodule
