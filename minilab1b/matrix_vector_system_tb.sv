`timescale 1ns/1ps

module matrix_vector_system_tb;
    // Clock / reset
    logic clk;
    logic [3:0] KEY;

    initial begin
        clk = 1'b0;
        forever #10 clk = ~clk; // 50 MHz
    end

    initial begin
        KEY = 4'b0000;
        #50;
        KEY[0] = 1'b1; // release reset (rst_n)
    end

    // Avalon interconnect signals (loader master <-> mem_wrapper slave)
    logic [31:0] address;
    logic        read;
    logic [63:0] readdata;
    logic        readdatavalid;
    logic        waitrequest;

    // Loader -> compute FIFO fill
    logic [7:0] a_wren_in;
    logic [63:0] a_data_in_flat; // Flattened
    logic       b_wren_in;
    logic [7:0] b_data_in;

    // FIFO full status from compute
    logic [7:0] a_full;
    logic       b_full;

    // Debug / results
    logic        load_done;
    logic [3:0]  l_state;
    logic [3:0]  l_row;
    logic [3:0]  l_byte;

    logic        done;
    logic [191:0] C_matrix_flat; // Flattened
    logic [2:0]  c_state;

    // Arrays for printing
    logic [23:0] C_matrix [8];
    genvar gi;
    generate
        for (gi = 0; gi < 8; gi = gi + 1) begin : gen_out_map
            assign C_matrix[gi] = C_matrix_flat[gi*24 +: 24];
        end
    endgenerate

    // Instantiate provided Avalon-MM slave memory
    mem_wrapper mem (
        .clk(clk),
        .reset_n(KEY[0]),
        .address(address),
        .read(read),
        .readdata(readdata),
        .readdatavalid(readdatavalid),
        .waitrequest(waitrequest)
    );

    // Loader (Avalon-MM master)
    avalon_fifo_loader loader (
        .clk(clk),
        .rst_n(KEY[0]),

        .avm_address(address),
        .avm_read(read),
        .avm_readdata(readdata),
        .avm_readdatavalid(readdatavalid),
        .avm_waitrequest(waitrequest),

        .a_wren(a_wren_in),
        .a_data_out(a_data_in_flat),
        .b_wren(b_wren_in),
        .b_data(b_data_in),

        .a_full(a_full),
        .b_full(b_full),

        .done(load_done),
        .dbg_state(l_state),
        .dbg_row(l_row),
        .dbg_byte(l_byte)
    );

    // Compute engine
    matrix_vector_multi dut (
        .CLOCK_50(clk),
        .KEY(KEY),

        .a_wren_in(a_wren_in),
        .a_data_in(a_data_in_flat),
        .b_wren_in(b_wren_in),
        .b_data_in(b_data_in),

        .done(done),
        .C_matrix_out(C_matrix_flat),
        .dbg_state(c_state),
        .a_full_out(a_full),
        .b_full_out(b_full)
    );

    // Print everything each cycle
    integer i;
    always @(posedge clk) begin
        $display(
            "t=%0t rst_n=%0b | L:state=%0d row=%0d byte=%0d done=%0b",
            $time, KEY[0], l_state, l_row, l_byte, load_done
        );
        $display(
            "AV:addr=%0d read=%0b wait=%0b rvalid=%0b rdata=%h",
            address, read, waitrequest, readdatavalid, readdata
        );
        $display(
            "WREN:a=%b b=%0b | C:state=%0d done=%0b",
            a_wren_in, b_wren_in, c_state, done
        );
        $display(
            "C0=%h C1=%h C2=%h C3=%h C4=%h C5=%h C6=%h C7=%h",
            C_matrix[0], C_matrix[1], C_matrix[2], C_matrix[3],
            C_matrix[4], C_matrix[5], C_matrix[6], C_matrix[7]
        );

        if (done) begin
            $display("DONE: final C = %h %h %h %h %h %h %h %h",
                C_matrix[0], C_matrix[1], C_matrix[2], C_matrix[3],
                C_matrix[4], C_matrix[5], C_matrix[6], C_matrix[7]
            );
            #20;
            $finish;
        end

        // Safety stop
        if ($time > 20000) begin
            $display("TIMEOUT");
            $finish;
        end
    end

endmodule
