module mac_tb();

logic clk = 0;
logic rst_n, En, Clr;
logic [7:0] Ain, Bin;
logic [23:0] Cout_expected, Cout_actual;

MAC iDUT (
    .clk(clk),
    .rst_n(rst_n),
    .En(En),
    .Clr(Clr),
    .Ain(Ain),
    .Bin(Bin),
    .Cout(Cout_actual)
);

always #5 clk = ~clk;

// simple test sequence: reset, clear, then several MAC operations
initial begin
    integer fails = 0;
    logic [23:0] product;

    // init
    rst_n = 0;
    En = 0;
    Clr = 0;
    Ain = 0;
    Bin = 0;
    Cout_expected = 0;

    // hold reset for two clocks
    repeat (2) @(posedge clk);
    rst_n = 1;
    @(posedge clk);
    @(negedge clk);

    // Test 0: assert Clr to ensure accumulator clears
    Clr = 1;
    En = 0;
    Ain = 8'hAA; Bin = 8'h55; // arbitrary values while clearing
    Cout_expected = 0;
    @(posedge clk);
    @(negedge clk);
    Clr = 0;
    if (Cout_actual !== Cout_expected) begin
        $display("FAIL: after Clr expected %0h got %0h", Cout_expected, Cout_actual);
        fails++;
    end else $display("PASS: Clr cleared accumulator");

    // Test 1: single MAC operation
    Ain = 8'd3; Bin = 8'd7; // product = 21
    En = 1;
    product = Ain * Bin;
    Cout_expected = Cout_expected + product;
    @(posedge clk);
    @(negedge clk);
    if (Cout_actual !== Cout_expected) begin
        $display("FAIL: step1 expected %0d got %0d", Cout_expected, Cout_actual);
        fails++;
    end else $display("PASS: step1 %0d", Cout_actual);

    // Test 2: another accumulate
    Ain = 8'd10; Bin = 8'd5; // product = 50, total = 71
    product = Ain * Bin;
    Cout_expected = Cout_expected + product;
    @(posedge clk);
    @(negedge clk);
    if (Cout_actual !== Cout_expected) begin
        $display("FAIL: step2 expected %0d got %0d", Cout_expected, Cout_actual);
        fails++;
    end else $display("PASS: step2 %0d", Cout_actual);

    // Test 3: En low -> no accumulate
    En = 0;
    Ain = 8'd255; Bin = 8'd255; // large product but should be ignored
    @(posedge clk);
    @(negedge clk);
    if (Cout_actual !== Cout_expected) begin
        $display("FAIL: En=0 expected %0d got %0d", Cout_expected, Cout_actual);
        fails++;
    end else $display("PASS: En=0 no change");

    // Test 4: clear again mid-stream then accumulate new values
    Clr = 1;
    En = 0;
    @(posedge clk);
    @(negedge clk);
    Clr = 0;
    Cout_expected = 0;
    if (Cout_actual !== Cout_expected) begin
        $display("FAIL: mid Clr expected %0d got %0d", Cout_expected, Cout_actual);
        fails++;
    end else $display("PASS: mid Clr cleared");

    // accumulate multiple cycles
    En = 1;
    // cycle A
    Ain = 8'd2; Bin = 8'd4; product = Ain * Bin; Cout_expected += product;
    @(posedge clk);
    @(negedge clk);
    if (Cout_actual !== Cout_expected) begin $display("FAIL: seq1 expected %0d got %0d", Cout_expected, Cout_actual); fails++; end

    // cycle B
    Ain = 8'd7; Bin = 8'd6; product = Ain * Bin; Cout_expected += product;
    @(posedge clk);
    @(negedge clk);
    if (Cout_actual !== Cout_expected) begin $display("FAIL: seq2 expected %0d got %0d", Cout_expected, Cout_actual); fails++; end

    // final report
    if (fails == 0) $display("ALL TESTS PASSED");
    else $display("TESTS FAILED: %0d failures", fails);

    #10 $finish;
end

endmodule
