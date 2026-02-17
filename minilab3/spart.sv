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

    reg [15:0] div_buff;
    reg [15:0] receive_buffer;
    reg [15:0] transmit_buffer;

    reg [7:0] databus_out;
    reg databus_oe;
    assign databus = databus_oe ? databus_out : 8'hZZ;

    always_comb begin
        databus_out = 8'h00;
        databus_oe  = 1'b0;

        if (iocs && iorw) begin
            databus_oe = 1'b1;
            case (ioaddr)
                2'b00:   databus_out = receive_buffer[7:0];
                2'b01:   databus_out = {6'd0, tbr, rda};
                2'b10:   databus_out = div_buff[7:0];
                2'b11:   databus_out = div_buff[15:8];
                default: databus_out = 8'h00;
            endcase
        end
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            div_buff <= 16'd0;
            receive_buffer <= 16'd0;
            transmit_buffer <= 16'd0;
        end else begin
            if (iocs && !iorw) begin
                case (ioaddr)
                    2'b00:   transmit_buffer <= {8'h00, databus};
                    2'b10:   div_buff[7:0] <= databus;
                    2'b11:   div_buff[15:8] <= databus;
                    default: ;
                endcase
            end
        end
    end







endmodule
