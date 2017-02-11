
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

// NUM & CHAR         gfedcba
parameter NUM_0  = 7'b1000000;
parameter NUM_1  = 7'b1111001;
parameter NUM_2  = 7'b0100100;
parameter NUM_3  = 7'b0110000;
parameter NUM_4  = 7'b0011001;
parameter NUM_5  = 7'b0010010;
parameter NUM_6  = 7'b0000010;
parameter NUM_7  = 7'b1111000;
parameter NUM_8  = 7'b0000000;
parameter NUM_9  = 7'b0010000;
parameter CHAR_A = 7'b0001000;
parameter CHAR_B = 7'b0000011;
parameter CHAR_C = 7'b1000110;
parameter CHAR_D = 7'b0100001;
parameter CHAR_E = 7'b0000110;
parameter CHAR_F = 7'b0001110;
parameter CHAR_S = 7'b0010010;
parameter char_o = 7'b0100011;

// SCoC
// TEST
// 2017

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
		4'h0:    seg <= CHAR_C;
		4'h1:    seg <= CHAR_S;
		4'h2:    seg <= char_o;
		4'h3:    seg <= CHAR_C;
		4'h4:    seg <= NUM_4;
		4'h5:    seg <= NUM_5;
		4'h6:    seg <= NUM_6;
		4'h7:    seg <= NUM_7;
		4'h8:    seg <= NUM_8;
		4'h9:    seg <= NUM_9;
		4'hA:    seg <= CHAR_A;
		4'hB:    seg <= CHAR_B;
		4'hC:    seg <= CHAR_C;
		4'hD:    seg <= CHAR_D;
		4'hE:    seg <= CHAR_E;
		default: seg <= CHAR_F;
	endcase
end

assign dp = ~((decplace[0] ^ cnt[15]) & (decplace[1] ^ cnt[16]));

always @(posedge clk) begin
	cnt <= cnt + 1;
end

endmodule

