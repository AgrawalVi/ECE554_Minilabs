//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    
// Design Name: 
// Module Name:    driver 
// Project Name: 
// Target Devices: 
// Tool versions: 
// Description: 
//   This driver initializes the SPART with a baud rate based on br_cfg
//   and then enters an echoing mode: whatever it receives, it transmits back.
//
// Dependencies: 
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////
module driver(
    input clk,
    input rst,
    input [1:0] br_cfg,
    output reg iocs,
    output reg iorw,
    input rda,
    input tbr,
    output reg [1:0] ioaddr,
    inout [7:0] databus
    );

    // State machine for initialization and echoing
    typedef enum logic [3:0] {
        IDLE,
        INIT_LOW,
        INIT_HIGH,
        WAIT_RX,
        READ_RX,
        WAIT_TX,
        WRITE_TX
    } state_t;

    state_t state, next_state;

    reg [7:0] data_reg;
    reg [15:0] divisor;
    reg [7:0] databus_out;
    reg databus_oe;

    assign databus = databus_oe ? databus_out : 8'hZZ;

    // Divisor lookup based on br_cfg (assuming 50MHz clock)
    // Formula: (50,000,000 / (16 * Baud)) - 1
    // 4800  -> 650  (0x028A)
    // 9600  -> 325  (0x0145)
    // 19200 -> 162  (0x00A2)
    // 38400 -> 80   (0x0050)
    always_comb begin
        case (br_cfg)
            2'b00: divisor = 16'd650; // 4800
            2'b01: divisor = 16'd325; // 9600
            2'b10: divisor = 16'd162; // 19200
            2'b11: divisor = 16'd80;  // 38400
            default: divisor = 16'd325;
        endcase
    end

    // State register
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= INIT_LOW;
            data_reg <= 8'h00;
        end else begin
            state <= next_state;
            if (state == READ_RX && rda) begin
                data_reg <= databus;
            end
        end
    end

    // Next state and output logic
    always_comb begin
        next_state = state;
        iocs = 1'b0;
        iorw = 1'b1;
        ioaddr = 2'b00;
        databus_out = 8'h00;
        databus_oe = 1'b0;

        case (state)
            INIT_LOW: begin
                iocs = 1'b1;
                iorw = 1'b0;
                ioaddr = 2'b10;
                databus_out = divisor[7:0];
                databus_oe = 1'b1;
                next_state = INIT_HIGH;
            end

            INIT_HIGH: begin
                iocs = 1'b1;
                iorw = 1'b0;
                ioaddr = 2'b11;
                databus_out = divisor[15:8];
                databus_oe = 1'b1;
                next_state = WAIT_RX;
            end

            WAIT_RX: begin
                if (rda) begin
                    next_state = READ_RX;
                end
            end

            READ_RX: begin
                iocs = 1'b1;
                iorw = 1'b1;
                ioaddr = 2'b00;
                next_state = WAIT_TX;
            end

            WAIT_TX: begin
                if (tbr) begin
                    next_state = WRITE_TX;
                end
            end

            WRITE_TX: begin
                iocs = 1'b1;
                iorw = 1'b0;
                ioaddr = 2'b00;
                databus_out = data_reg;
                databus_oe = 1'b1;
                next_state = WAIT_RX;
            end

            default: next_state = WAIT_RX;
        endcase
    end

endmodule
