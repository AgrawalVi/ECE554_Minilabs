//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer:
//
// Create Date:
// Design Name:
// Module Name:    spart
// Project Name:
// Target Devices:
// Tool versions:
// Description:
//
// Dependencies:
//
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
//
//////////////////////////////////////////////////////////////////////////////////
module spart (
    input clk,
    input rst,

    //------------communicate to CPU-------------------------------
    input iocs,  //I/O Chip Select

    input iorw,  //Determines the direction of data transfer between the
                 //Processor and SPART. For a Read (IOR/W=1), data is transferred
                 //from the SPART to the Processor and for a Write (IOR/W=0),
                 //data is transferred from the processor to the SPART.

    output rda,  //Receive Data Available - Indicates that a byte of data has been received and is
                 //ready to be read from the SPART to the Processor

    output tbr,  //Transmit Buffer Ready - Indicates that the transmit buffer in the SPART is ready
                 //to accept a byte for transmission.

    input [1:0] ioaddr,  //A 2-bit address bus used to select the particular register that
                         //interacts with the DATABUS during an I/O operation
                         // -------------------------------------------------------------
                         // SPART Register Address Mapping
                         // -------------------------------------------------------------
                         // IOADDR  | SPART Register
                         // --------|-----------------------------------------------------
                         //   2'b00 | Transmit Buffer (IOR/W = 0)
                         //         | Receive Buffer  (IOR/W = 1)
                         //
                         //   2'b01 | Status Register (IOR/W = 1)
                         //
                         //   2'b10 | DB (Low)  Division Buffer
                         //
                         //   2'b11 | DB (High) Division Buffer
                         // -------------------------------------------------------------


    inout [7:0] databus,  // An 8-bit, 3-state bidirectional bus used to transfer data and
                          // control information between the Processor and the SPART.
    //---------------------------------------------------------

    //-------------communicate to other spark------------------
    output txd,  //transmit
    input  rxd   //receive
    //---------------------------------------------------------
);

    // Baud Rate Generator
    reg [15:0] div_buff;
    reg [15:0] brg_count;
    wire brg_en;

    // Internal signals
    reg [7:0] tx_data_reg;
    reg trmt;
    reg clr_rdy;
    wire [7:0] rx_data;
    wire tx_done;
    wire rx_rdy;

    // Status signals
    assign rda = rx_rdy;
    assign tbr = tx_done;

    // BRG logic
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            div_buff <= 16'd325; // Default for 50MHz, 9600 baud
            brg_count <= 16'd325;
        end else begin
            // Division Buffer loading
            if (iocs && !iorw) begin
                if (ioaddr == 2'b10)
                    div_buff[7:0] <= databus;
                else if (ioaddr == 2'b11)
                    div_buff[15:8] <= databus;
            end

            // Counter logic
            if (brg_count == 16'd0)
                brg_count <= div_buff;
            else
                brg_count <= brg_count - 16'd1;
        end
    end

    assign brg_en = (brg_count == 16'd0);

    // Bus Interface logic
    reg [7:0] databus_out;
    assign databus = (iocs && iorw) ? databus_out : 8'hZZ;

    always_comb begin
        databus_out = 8'h00;
        clr_rdy = 1'b0;
        if (iocs && iorw) begin
            case (ioaddr)
                2'b00: begin
                    databus_out = rx_data;
                    clr_rdy = 1'b1;
                end
                2'b01: begin
                    databus_out = {6'd0, tbr, rda};
                end
                2'b10: begin
                    databus_out = div_buff[7:0];
                end
                2'b11: begin
                    databus_out = div_buff[15:8];
                end
                default: databus_out = 8'h00;
            endcase
        end
    end

    // Transmit logic
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            tx_data_reg <= 8'd0;
            trmt <= 1'b0;
        end else begin
            trmt <= 1'b0; // Default pulse
            if (iocs && !iorw && ioaddr == 2'b00) begin
                tx_data_reg <= databus;
                trmt <= 1'b1;
            end
        end
    end

    // Instantiate UART components
    UART_tx iTX (
        .clk(clk),
        .rst_n(!rst),
        .trmt(trmt),
        .tx_data(tx_data_reg),
        .brg_en(brg_en),
        .tx_done(tx_done),
        .TX(txd)
    );

    UART_rx iRX (
        .clk(clk),
        .rst_n(!rst),
        .RX(rxd),
        .clr_rdy(clr_rdy),
        .brg_en(brg_en),
        .rdy(rx_rdy),
        .rx_data(rx_data)
    );

endmodule
