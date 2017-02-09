
module sevenseg
(
	input             clk,
	input       [3:0] digit0,
	input       [3:0] digit1,
	input       [3:0] digit2,
	input       [3:0] digit3,
	input       [1:0] decplace,
	output reg  [6:0] seg,
	output reg  [3:0] an,
	output            dp
);

reg  [16:0] cnt;
reg  [3:0]  digit;

// Anode
always @(cnt[16:15]) begin
	case (cnt[16:15])
		2'b11:   an <= 4'b1110;
		2'b10:   an <= 4'b1101;
		2'b01:   an <= 4'b1011;
		default: an <= 4'b0111;
	endcase
end

// Cathode
always @(cnt[16:15] or digit0 or digit1 or digit2 or digit3) begin
	case (cnt[16:15])
		2'b00:   digit <= digit0;
		2'b01:   digit <= digit1;
		2'b10:   digit <= digit2;
		default: digit <= digit3;
	endcase

	case (digit)
		4'h0:    seg <= 7'b1000000;
		4'h1:    seg <= 7'b1111001;
		4'h2:    seg <= 7'b0100100;
		4'h3:    seg <= 7'b0110000;
		4'h4:    seg <= 7'b0011001;
		4'h5:    seg <= 7'b0010010;
		4'h6:    seg <= 7'b0000010;
		4'h7:    seg <= 7'b1111000;
		4'h8:    seg <= 7'b0000000;
		4'h9:    seg <= 7'b0010000;
		4'hA:    seg <= 7'b0001000;
		4'hB:    seg <= 7'b0000011;
		4'hC:    seg <= 7'b1000110;
		4'hD:    seg <= 7'b0100001;
		4'hE:    seg <= 7'b0000110;
		default: seg <= 7'b0001110;
	endcase
end

assign dp = ~((decplace[0] ^ cnt[15]) & (decplace[1] ^ cnt[16]));

always @(posedge clk) begin
	cnt <= cnt + 1;
end

endmodule