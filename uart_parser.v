
module cmd_parser
(
	input clk,
	input rstn,

	output [7:0] tx_data,      // data byte to transmit
	output       new_tx_data,  // asserted to indicate that there is a new data byte for transmission
	input        tx_busy,      // signs that transmitter is busy

	input [7:0] rx_data,     // data byte received
	input       new_rx_data, // signs that a new byte was received

	output reg [7:0] leds,  // -- Board leds
	output [7:0] sseg,  // -- Board 7Segment Display
	output [3:0] an,    // -- 7Segment Display enable

	// CSoC
	output reg       csoc_clk,
	output reg       csoc_rstn,
	output reg       csoc_test_se,
	output reg       csoc_test_tm,

	input  wire       csoc_uart_write,
	output            csoc_uart_read,
	input  wire [7:0] csoc_data_i,
	output      [7:0] csoc_data_o
);

assign csoc_data_o = csoc_data_i;
assign csoc_uart_read = csoc_uart_write;

always @(posedge clk) begin
	leds[7:4] = ~leds[3:0];
	leds[3:0] =  rx_data[3:0];
end

reg  [27:0]  sevenseg;
reg  [3:0]   sec0;
reg  [3:0]   sec1;
reg  [3:0]   min0;
reg  [3:0]   min1;
reg          counting;
wire          dp;


reg  [3:0]   data0;
reg  [3:0]   data1;
reg  [3:0]   data2;
reg  [3:0]   data3;


sevenseg ss0 (
	.clk(clk),
	.digit0(data0),
	.digit1(data1),
	.digit2(data2),
	.digit3(data3),
	.decplace(2'b00),
	.seg(sseg),
	.an(an),
	.dp(dp)
);

always @(posedge clk) begin
	counting <= ~counting;
end

always @(posedge clk) begin
	if (counting == 1'b1) begin
		sevenseg <= sevenseg + 1;
		if (sevenseg == 50000000) begin
			sevenseg <= 1;
			sec0 <= sec0 + 1;
			data0 <= 4'hc;
			data1 <= 4'ha;
			data2 <= 4'hf;
			data3 <= 4'he;
		end

		if (sec0 == 4'hA) begin
			data0 <= data1;
			data1 <= data2;
			data2 <= data3;
			data3 <= data0;
		end

		// if (sec0 == 4'hA) begin
		// 	sec1 <= sec1 + 1;
		// 	sec0 <= 0;
		// end

		// if (sec1 == 4'h6) begin
		// 	min0 <= min0 + 1;
		// 	sec1 <= 0;
		// end

		// if (min0 == 4'hA) begin
		// 	min1 <= min1 + 1;
		// 	min0 <= 0;
		// end

		// if (min1 == 4'h6) min1 <= 0;
	end
end

// always @(posedge clk) begin
// 	if (!rstn) begin
// 		data0 <= 4'hc;
// 		data1 <= 4'ha;
// 		data2 <= 4'hf;
// 		data3 <= 4'he;
// 	end
// 	else if (clk) begin
// 		data0 <= data1;
// 		data1 <= data2;
// 		data2 <= data3;
// 		data3 <= data0;
// 	end
// end

endmodule
