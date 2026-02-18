`timescale 1ns / 1ps

module spart_tb();

    reg clk;
    reg rst;
    reg [1:0] br_cfg;

    // DUT signals (spart1 + driver)
    wire txd_dut, rxd_dut;
    wire iocs_dut, iorw_dut;
    wire rda_dut, tbr_dut;
    wire [1:0] ioaddr_dut;
    wire [7:0] databus_dut;

    // TB SPART signals (spart0)
    reg iocs_tb, iorw_tb;
    reg [1:0] ioaddr_tb;
    wire rda_tb, tbr_tb;
    wire [7:0] databus_tb;
    reg [7:0] tb_data_out;
    reg tb_bus_oe;

    assign databus_tb = tb_bus_oe ? tb_data_out : 8'hZZ;

    // Clock generation (50MHz -> 20ns period)
    initial clk = 0;
    always #10 clk = ~clk;

    // DUT: SPART + Driver
    spart spart_dut (
        .clk(clk),
        .rst(rst),
        .iocs(iocs_dut),
        .iorw(iorw_dut),
        .rda(rda_dut),
        .tbr(tbr_dut),
        .ioaddr(ioaddr_dut),
        .databus(databus_dut),
        .txd(txd_dut),
        .rxd(rxd_dut)
    );

    driver driver_dut (
        .clk(clk),
        .rst(rst),
        .br_cfg(br_cfg),
        .iocs(iocs_dut),
        .iorw(iorw_dut),
        .rda(rda_dut),
        .tbr(tbr_dut),
        .ioaddr(ioaddr_dut),
        .databus(databus_dut)
    );

    // TB SPART (spart0) - acts as the terminal
    spart spart_tb_inst (
        .clk(clk),
        .rst(rst),
        .iocs(iocs_tb),
        .iorw(iorw_tb),
        .rda(rda_tb),
        .tbr(tbr_tb),
        .ioaddr(ioaddr_tb),
        .databus(databus_tb),
        .txd(rxd_dut),   // TB Tx -> DUT Rx
        .rxd(txd_dut)    // DUT Tx -> TB Rx
    );

    // Write a register on the TB SPART
    task write_reg(input [1:0] addr, input [7:0] data);
    begin
        @(posedge clk);
        iocs_tb   <= 1'b1;
        iorw_tb   <= 1'b0;
        ioaddr_tb <= addr;
        tb_data_out <= data;
        tb_bus_oe <= 1'b1;
        @(posedge clk);
        iocs_tb   <= 1'b0;
        tb_bus_oe <= 1'b0;
    end
    endtask

    // Read a register on the TB SPART
    task read_reg(input [1:0] addr, output [7:0] data);
    begin
        @(posedge clk);
        iocs_tb   <= 1'b1;
        iorw_tb   <= 1'b1;
        ioaddr_tb <= addr;
        tb_bus_oe <= 1'b0;
        @(posedge clk);
        data = databus_tb;
        iocs_tb <= 1'b0;
    end
    endtask

    // Send one character and wait for the echo, then print it
    task send_and_receive(input [7:0] tx_char);
        reg [7:0] rx_char;
        integer timeout;
    begin
        // Wait for TB SPART transmitter to be ready
        while (!tbr_tb) @(posedge clk);

        $display("[TB SEND]    time=%0t  Sending: %c (0x%02h)", $time, tx_char, tx_char);
        write_reg(2'b00, tx_char);

        // Wait for TBR to drop (transmission started)
        repeat (5) @(posedge clk);

        // Wait for TBR to return (transmission finished)
        while (!tbr_tb) @(posedge clk);

        // Now wait for echoed character to arrive (RDA goes high)
        timeout = 0;
        while (!rda_tb && timeout < 500000) begin
            @(posedge clk);
            timeout = timeout + 1;
        end

        if (rda_tb) begin
            read_reg(2'b00, rx_char);
            $display("[TB RECEIVE] time=%0t  Echoed:  %c (0x%02h)", $time, rx_char, rx_char);
            if (rx_char !== tx_char)
                $display("[TB ERROR]   Mismatch! Expected 0x%02h, Got 0x%02h", tx_char, rx_char);
        end else begin
            $display("[TB ERROR]   time=%0t  Timeout waiting for echo of %c", $time, tx_char);
        end
    end
    endtask

    // Main test
    initial begin
        // Initialize
        rst = 1;
        br_cfg = 2'b01;  // 9600 baud
        iocs_tb = 0;
        iorw_tb = 1;
        ioaddr_tb = 2'b00;
        tb_bus_oe = 0;
        tb_data_out = 8'h00;

        // Reset pulse
        repeat (10) @(posedge clk);
        rst = 0;
        repeat (10) @(posedge clk);

        // Initialize TB SPART baud rate (divisor 325 = 0x0145 for 9600 @ 50MHz)
        $display("[TB] Initializing baud rate to 9600...");
        write_reg(2'b10, 8'h45);  // Low byte
        write_reg(2'b11, 8'h01);  // High byte

        // Let driver finish its init
        repeat (20) @(posedge clk);

        // Send characters one at a time and wait for echo
        $display("[TB] Starting echo test...");
        send_and_receive("H");
        send_and_receive("e");
        send_and_receive("l");
        send_and_receive("l");
        send_and_receive("o");
        send_and_receive("!");

        $display("[TB] All characters sent and echoed. Test complete.");
        #1000;
        $finish;
    end

    // Safety timeout
    initial begin
        #100_000_000;
        $display("[TB] TIMEOUT - simulation exceeded 100ms");
        $finish;
    end

endmodule
