module Conv (
	input         iCLK,
	input         iRST,
	input  [11:0] iDATA,
	input         iDVAL,
	input         f_select,
	output [11:0] oDATA,
	output        oDVAL
);

	wire signed [11:0] F00, F01, F02, F10, F11, F12, F20, F21, F22;
	assign F00 = f_select ? -1 : -1;
	assign F01 = f_select ? 0 : -2;
	assign F02 = f_select ? 1 : -1;
	assign F10 = f_select ? -2 : 0;
	assign F11 = f_select ? 0 : 0;
	assign F12 = f_select ? 2 : 0;
	assign F20 = f_select ? -1 : 1;
	assign F21 = f_select ? 0 : 2;
	assign F22 = f_select ? 1 : 1;

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
	wire signed [19:0] m00 = $signed(p00_r) * F00, m01 = $signed(p01_r) * F01, m02 = $signed(p02_r) * F02;
	wire signed [19:0] m10 = $signed(p10_r) * F10, m11 = $signed(p11_r) * F11, m12 = $signed(p12_r) * F12;
	wire signed [19:0] m20 = $signed(p20_r) * F20, m21 = $signed(p21_r) * F21, m22 = $signed(p22_r) * F22;
	wire signed [23:0] sum = m00 + m01 + m02 + m10 + m11 + m12 + m20 + m21 + m22;

	// Saturate to [0, 4095] for 12-bit output
	reg [11:0] out_r;
	always @(posedge iCLK or negedge iRST) begin
		if (!iRST)
			out_r <= 0;
		else if (dval_r3) begin
			if (sum < 0)
				out_r <= -1*sum[11:0];
			// if (sum > 4095)
				// out_r <= 12'd4095;
			else
			out_r <= sum[11:0];
		end
	end

	assign oDATA = out_r;
	assign oDVAL = dval_r3;

endmodule
