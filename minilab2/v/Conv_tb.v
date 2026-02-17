`timescale 1ns/1ps

// -----------------------------------------------------------------------
// SIMPLIFIED TESTBENCH FOR REPORT
// We use a small "fake" image width (4 pixels) so you can see the 
// vertical convolution happen in just a few lines of output.
// -----------------------------------------------------------------------

module Conv_tb;

    reg clk, rst, dval;
    reg [11:0] data;
    wire [11:0] out;
    wire out_val;

    // Instantiate DUT
    Conv uut (
        .iCLK(clk), .iRST(rst),
        .iDATA(data), .iDVAL(dval),
        .oDATA(out), .oDVAL(out_val)
    );

    // 50MHz Clock
    always #10 clk = ~clk;

    integer i;

    initial begin
        // Setup
        clk = 0; rst = 0; dval = 0; data = 0;
        #50 rst = 1; #20;

        $display("-------------------------------------------------------------");
        $display("Time | Line | Pix | Input | Output | Note");
        $display("-------------------------------------------------------------");

        // ------------------------------------------------------------
        // STRATEGY: 
        // Feed a "Horizontal Edge" image to trigger the vertical filter.
        // The filter is: Bottom_Row - Top_Row.
        // We assume image width is 4 (set in the mock buffer below).
        // Sequence:
        // Line 0: All 0s
        // Line 1: All 0s
        // Line 2: All 10s  <-- Edge starts here
        // Line 3: All 10s
        // ------------------------------------------------------------

        // Line 0 (Input 0)
        for(i=0; i<4; i=i+1) begin
            feed_pixel(0);
            print_status(0, i, 0);
        end

        // Line 1 (Input 0)
        for(i=0; i<4; i=i+1) begin
            feed_pixel(0);
            print_status(1, i, 0);
        end

        // Line 2 (Input 10) -> This becomes the "Bottom" row (Positive weights)
        // Top row is Line 0 (0s). Result should be positive.
        for(i=0; i<4; i=i+1) begin
            feed_pixel(10);
            print_status(2, i, 10);
        end

        // Line 3 (Input 10) -> This becomes "Bottom" row.
        // Top row is Line 1 (0s). Result should still be positive.
        for(i=0; i<4; i=i+1) begin
            feed_pixel(10);
            print_status(3, i, 10);
        end

         // Line 4 (Input 0) -> "Bottom" is 0.
        // Top row is Line 2 (10s). Result should be Negative (clipped to abs/0).
        for(i=0; i<4; i=i+1) begin
            feed_pixel(0);
            print_status(4, i, 0);
        end

        $display("-------------------------------------------------------------");
        $finish;
    end

    task feed_pixel(input [11:0] val);
    begin
        @(posedge clk);
        dval = 1;
        data = val;
    end
    endtask

    task print_status(input integer line, input integer pix, input [11:0] val);
    begin
        // Sample output just after the edge
        #1; 
        if (out_val)
            $display("%4t | %4d | %3d |  %3d  |  %3d   | Valid Output", $time, line, pix, val, out);
        else
            $display("%4t | %4d | %3d |  %3d  |   x    | Filling Buffer...", $time, line, pix, val);
    end
    endtask

endmodule
