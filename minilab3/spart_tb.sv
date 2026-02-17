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

    // DUT Instantiation (SPART + Driver)
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

    // TB SPART Instantiation (spart0)
    spart spart_tb_inst (
        .clk(clk),
        .rst(rst),
        .iocs(iocs_tb),
        .iorw(iorw_tb),
        .rda(rda_tb),
        .tbr(tbr_tb),
        .ioaddr(ioaddr_tb),
        .databus(databus_tb),
        .txd(rxd_dut),  // TB Tx connects to DUT Rx
        .rxd(txd_dut)   // TB Rx connects to DUT Tx
    );

    // Tasks for TB SPART interaction
    task write_reg(input [1:0] addr, input [7:0] data);
    begin
        @(posedge clk);
        iocs_tb = 1;
        iorw_tb = 0;
        ioaddr_tb = addr;
        tb_data_out = data;
        tb_bus_oe = 1;
        @(posedge clk);
        iocs_tb = 0;
        tb_bus_oe = 0;
    end
    endtask

    task read_reg(input [1:0] addr, output [7:0] data);
    begin
        @(posedge clk);
        iocs_tb = 1;
        iorw_tb = 1;
        ioaddr_tb = addr;
        @(posedge clk);
        data = databus_tb;
        iocs_tb = 0;
    end
    endtask

    // Monitoring process (Printing echoed characters)
    reg [7:0] rx_char;
    initial begin
        forever begin
            @(posedge clk);
            if (rda_tb) begin
                read_reg(2'b00, rx_char);
                $display("[TB RECEIVE] Character echoed back: %c (0x%h)", rx_char, rx_char);
            end
        end
    end

    // Test sequence
    initial begin
        // Initialize signals
        rst = 1;
        br_cfg = 2'b01; // 9600 Baud
        iocs_tb = 0;
        iorw_tb = 1;
        ioaddr_tb = 2'b00;
        tb_bus_oe = 0;
        tb_data_out = 8'h00;

        // Reset pulse
        repeat (5) @(posedge clk);
        rst = 0;
        repeat (10) @(posedge clk);

        // 1. Initialize TB SPART baud rate to 9600 (divisor 325 = 0x0145)
        $display("[TB] Initializing SPART0 baud rate to 9600...");
        write_reg(2'b10, 8'h45); // Low byte
        write_reg(2'b11, 8'h01); // High byte
        
        // Wait for driver to finish its initialization (takes a few cycles)
        repeat (20) @(posedge clk);

        // 2. Send characters to DUT
        send_char("H");
        send_char("e");
        send_char("l");
        send_char("l");
        send_char("o");
        send_char(",");
        send_char(" ");
        send_char("W");
        send_char("o");
        send_char("r");
        send_char("l");
        send_char("d");
        send_char("!");

        // Wait for all echoes to complete
        #1000000; // Wait 1ms (serial is slow)
        
        $display("[TB] Simulation complete.");
        $stop;
    end

    task send_char(input [7:0] c);
    begin
        $display("[TB SEND] Sending character: %c (0x%h)", c, c);
        // Wait for TB SPART to be ready to transmit
        while (!tbr_tb) @(posedge clk);
        write_reg(2'b00, c);
    end
    endtask

endmodule
