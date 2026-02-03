`timescale 1ns/1ps

module Minilab0_tb();

  // Inputs
  logic CLOCK_50;
  logic [3:0] KEY;
  logic [9:0] SW;

  // Outputs
  logic [6:0] HEX0;
  logic [6:0] HEX1;
  logic [6:0] HEX2;
  logic [6:0] HEX3;
  logic [6:0] HEX4;
  logic [6:0] HEX5;
  logic [9:0] LEDR;

  // Instantiate the Unit Under Test (UUT)
  Minilab0 uut (
    .CLOCK_50(CLOCK_50),
    .CLOCK2_50(1'b0),
    .CLOCK3_50(1'b0),
    .CLOCK4_50(1'b0),
    .HEX0(HEX0),
    .HEX1(HEX1),
    .HEX2(HEX2),
    .HEX3(HEX3),
    .HEX4(HEX4),
    .HEX5(HEX5),
    .LEDR(LEDR),
    .KEY(KEY),
    .SW(SW)
  );

  // Clock generation
  initial begin
    CLOCK_50 = 0;
    forever #10 CLOCK_50 = ~CLOCK_50; // 50MHz clock
  end

  // Test procedure
  initial begin
    // Initialize Inputs
    KEY = 4'hF; // Active low reset, so set high
    SW = 10'h001; // Set SW[0] high to see HEX output

    // Reset the system
    $display("Applying Reset...");
    #25;
    KEY[0] = 0; // Assert reset
    #40;
    KEY[0] = 1; // Deassert reset
    $display("Reset Deasserted. State: %b", LEDR[1:0]);

    // Wait for the state to reach DONE (state 2)
    wait(LEDR[1:0] == 2'd2);
    $display("State reached DONE.");

    // Give it a few more cycles to settle
    repeat(5) @(posedge CLOCK_50);

    // Verify macout value via internal signal access if possible, 
    // or check HEX displays.
    // macout should be 1B58 (hex)
    $display("Checking Results...");
    $display("macout (internal): %h", uut.macout);
    
    if (uut.macout == 24'h001B58) begin
      $display("SUCCESS: macout is 1B58");
    end else begin
      $display("FAILURE: macout is %h, expected 001B58", uut.macout);
    end

    // End simulation
    #100;
    $display("Simulation Finished.");
    $stop;
  end

endmodule
