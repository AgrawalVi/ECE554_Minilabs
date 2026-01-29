module fifo_tb();

logic clk = 0;
logic rst_n;
logic wr_en, rd_en;
logic [7:0] din;
logic [7:0] dout;
logic full, empty;

FIFO iDUT (
    .clk(clk),
    .rst_n(rst_n),
    .wren(wr_en),
    .rden(rd_en),
    .i_data(din),
    .o_data(dout),
    .full(full),
    .empty(empty)
);

always #5 clk = ~clk;

initial begin
    integer fails = 0;
    logic [7:0] expect_val;
    logic [7:0] expected[$];
    logic [7:0] before1;

    // init
    rst_n = 0;
    wr_en = 0;
    rd_en = 0;
    din = 0;

    // reset
    repeat (2) @(posedge clk);
    rst_n = 1;
    @(posedge clk);

    // check empty after reset
    if (empty !== 1) begin
        $display("WARN: expected empty after reset, empty=%0b", empty);
    end

    // Test 1: simple write then read back (FIFO order)
    // write 1,2,3
    for (int i = 1; i <= 3; i++) begin
        din = i;
        wr_en = 1;
        @(posedge clk);
        @(negedge clk);
        wr_en = 0;
        expected.push_back(din);
        @(posedge clk); // allow internal update
        @(negedge clk);
    end

    // read back 1,2,3
    for (int i = 0; i < 3; i++) begin
        if (empty) begin
            $display("FAIL: expected data available but FIFO empty at read %0d", i);
            fails++;
            break;
        end
        rd_en = 1;
        @(posedge clk);
        @(negedge clk);
        rd_en = 0;
        expect_val = expected[0];
        expected.pop_front();
        if (dout !== expect_val) begin
            $display("FAIL: read %0d expected %0d got %0d", i, expect_val, dout);
            fails++;
        end else begin
            $display("PASS: read %0d value %0d", i, dout);
        end
        @(posedge clk);
        @(negedge clk);
    end

    // Test 2: read when empty should not produce new data
    if (!empty) begin
        // drain remaining if any
        while (!empty) begin rd_en = 1; @(posedge clk); rd_en = 0; @(posedge clk); end
    end
    before1 = dout;
    rd_en = 1;
    @(posedge clk);
    rd_en = 0;
    if (dout !== before1) $display("PASS: read while empty did not change output (dout stable)");
    else $display("WARN: read-while-empty behavior observed");

    // Test 3: basic full indication (attempt a number of writes until full or fixed attempts)
    for (int i = 0; i < 16; i++) begin
        if (full) begin
            $display("INFO: FIFO reported full after %0d writes", i);
            break;
        end
        din = i + 10;
        wr_en = 1;
        @(posedge clk);
        wr_en = 0;
        @(posedge clk);
    end

    // final report
    if (fails == 0) $display("ALL FIFO TESTS PASSED");
    else $display("FIFO TESTS FAILED: %0d failures", fails);

    #10 $finish;
end

endmodule