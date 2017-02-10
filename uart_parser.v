
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
	output reg        csoc_clk,
	output reg        csoc_rstn,
	output reg        csoc_test_se,
	output reg        csoc_test_tm,
	input  wire       csoc_uart_write,
	output reg        csoc_uart_read,
	input  wire [7:0] csoc_data_i,
	output reg  [7:0] csoc_data_o
);


reg [7:0] csoc_data_i_s;
reg csoc_data_write_s;

// always @(posedge clk) begin
// 	// leds[7:4] = ~leds[3:0];
// 	leds[3:0] =  rx_data[3:0];
// end

reg          counting;
reg  [27:0]  sevenseg;

reg  [3:0]   sec0;
reg  [3:0]   sec1;
reg  [3:0]   min0;
reg  [3:0]   min1;
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

// clk = 50 MHz, 20ns
// contador = 50000000
// tempo = 50000000 * 20 ns = 1000000000 ns = 1 s
// parameter TIMEOUT = 50000000;

always @(posedge clk or negedge rstn) begin
	if (!rstn) begin
		data0 <= 4'h0;
		data1 <= 4'h1;
		data2 <= 4'h2;
		data3 <= 4'h3;
	end else begin
		sevenseg <= sevenseg + 1;
		if (sevenseg == 50000000) begin
			sevenseg <= 1;
			data0 <= data1;
			data1 <= data2;
			data2 <= data3;
			data3 <= data0;
		end
	end
end


// # CSOC INTERFACE

always @(posedge clk or negedge rstn) begin
	if (!rstn) begin
		csoc_clk <= 1'b0;
		csoc_rstn <= 1'b0;
		csoc_test_se <= 1'b0;
		csoc_test_tm <= 1'b0;
		csoc_uart_read <= 1'b0;
		csoc_data_o <= 8'b0;

		csoc_data_i_s <= 8'b0;
		csoc_data_write_s <= 1'b0;
	end
	else begin
		csoc_clk <= ~csoc_clk;
		csoc_data_i_s <= ~csoc_data_i_s;
		csoc_data_write_s <= ~csoc_data_write_s;
		leds[7] <= csoc_clk;
		leds[6] <= csoc_rstn;
		leds[5] <= csoc_test_se;
		leds[4] <= csoc_test_tm;
		leds[3] <= csoc_uart_read;
		leds[2] <= csoc_data_write_s;
		leds[1] <= &csoc_data_o;
		leds[0] <= &csoc_data_i_s;
	end
end

endmodule
