// --------------------------------------------------------------------
// 3x3 Convolution using Line_Buffer2 (shift register with taps at 640 and 1280).
// Image: 640x480 greyscale, 12-bit pixels, streamed in raster order.
// Interface matches RAW2GREY: iCLK, iRST, iDATA[11:0], iDVAL -> oDATA[11:0], oDVAL.
// --------------------------------------------------------------------

module Conv (
	input         iCLK,
	input         iRST,
	input  [11:0] iDATA,
	input         iDVAL,
	output [11:0] oDATA,
	output        oDVAL
);

	// ----- Hardcoded 3x3 filter (change these to change the kernel) -----
	// Default: simple sharpen-like (center 9, neighbors -1)
	localparam signed [7:0] F00 = -1, F01 = -1, F02 = -1;
	localparam signed [7:0] F10 = -1, F11 =  9, F12 = -1;
	localparam signed [7:0] F20 = -1, F21 = -1, F22 = -1;

	// Line_Buffer2: taps at 640 and 1280 -> row y-1 and y-2
	wire [11:0] shiftout;
	wire [23:0] taps;
	wire [11:0] row_y1;  // pixel at (x, y-1)
	wire [11:0] row_y2;  // pixel at (x, y-2)
	assign row_y1 = taps[11:0];
	assign row_y2 = taps[23:12];

	Line_Buffer2 u_linebuf (
		.clock   (iCLK),
		.clken   (iDVAL),
		.shiftin (iDATA),
		.shiftout(shiftout),
		.taps    (taps)
	);

	// Horizontal delays for 3x3 window (2 pixels per row)
	reg [11:0] d_r0_0, d_r0_1;  // row y-2: [x-2], [x-1]
	reg [11:0] d_r1_0, d_r1_1;  // row y-1: [x-2], [x-1]
	reg [11:0] d_r2_0, d_r2_1;  // row y:   [x-2], [x-1]

	always @(posedge iCLK or negedge iRST) begin
		if (!iRST) begin
			d_r0_0 <= 0; d_r0_1 <= 0;
			d_r1_0 <= 0; d_r1_1 <= 0;
			d_r2_0 <= 0; d_r2_1 <= 0;
		end else begin
			d_r0_0 <= row_y2;    d_r0_1 <= d_r0_0;
			d_r1_0 <= row_y1;    d_r1_1 <= d_r1_0;
			d_r2_0 <= iDATA;     d_r2_1 <= d_r2_0;
		end
	end

	// 3x3 window (p00=top-left, p22=bottom-right)
	wire [11:0] p00 = d_r0_1, p01 = d_r0_0, p02 = row_y2;
	wire [11:0] p10 = d_r1_1, p11 = d_r1_0, p12 = row_y1;
	wire [11:0] p20 = d_r2_1, p21 = d_r2_0, p22 = iDATA;

	// Convolution: sum = sum_ij p_ij * F_ij (signed filter, unsigned pixel -> signed product)
	reg [11:0] p00_r, p01_r, p02_r, p10_r, p11_r, p12_r, p20_r, p21_r, p22_r;
	reg        dval_r1, dval_r2, dval_r3;

	always @(posedge iCLK or negedge iRST) begin
		if (!iRST) begin
			p00_r <= 0; p01_r <= 0; p02_r <= 0;
			p10_r <= 0; p11_r <= 0; p12_r <= 0;
			p20_r <= 0; p21_r <= 0; p22_r <= 0;
			dval_r1 <= 0; dval_r2 <= 0; dval_r3 <= 0;
		end else begin
			p00_r <= p00; p01_r <= p01; p02_r <= p02;
			p10_r <= p10; p11_r <= p11; p12_r <= p12;
			p20_r <= p20; p21_r <= p21; p22_r <= p22;
			dval_r1 <= iDVAL;
			dval_r2 <= dval_r1;
			dval_r3 <= dval_r2;
		end
	end

	// Multiply-accumulate (pixel 12b unsigned, filter 8b signed -> product 20b signed; sum of 9 -> ~24b)
	wire signed [19:0] m00 = p00_r * F00, m01 = p01_r * F01, m02 = p02_r * F02;
	wire signed [19:0] m10 = p10_r * F10, m11 = p11_r * F11, m12 = p12_r * F12;
	wire signed [19:0] m20 = p20_r * F20, m21 = p21_r * F21, m22 = p22_r * F22;
	wire signed [23:0] sum = m00 + m01 + m02 + m10 + m11 + m12 + m20 + m21 + m22;

	// Saturate to [0, 4095] for 12-bit output
	reg [11:0] out_r;
	always @(posedge iCLK or negedge iRST) begin
		if (!iRST)
			out_r <= 0;
		else if (dval_r3) begin
			if (sum < 0)
				out_r <= 12'd0;
			else if (sum > 4095)
				out_r <= 12'd4095;
			else
				out_r <= sum[11:0];
		end
	end

	assign oDATA = out_r;
	assign oDVAL = dval_r3;

endmodule
