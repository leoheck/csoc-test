// ----------------------------------------------------------------------------
// -- capeta_test.v: CSoC scan chain control and cadence ATPG
// -- All the received characters are echoed
// ----------------------------------------------------------------------------
// -- (C) BQ. Fev 2017. Written by Leandro Heck (leoheck@gmail.com)
// -- GPL license
// ----------------------------------------------------------------------------

`default_nettype none
`include "baudgen.vh"

module csoc_test #(
	parameter BAUDRATE = `B9600
)(
	input  wire clk, // -- System clock
	input  wire rst, // -- Reset active high (@BTN0)

	// UART
	input  wire rx,  // -- Serial input
	output wire tx,  // -- Serial output

	// DEBUG
	output wire [7:0] leds, // -- Board leds
	output wire [7:0] sseg, // -- Board 7Segment Display
	output wire [3:0] an,   // -- 7Segment Display enable

	// CSoC
	output wire  csoc_clk,
	output wire  csoc_rstn,
	output wire  csoc_test_se,
	output wire  csoc_test_tm,

	input  wire  csoc_uart_write,
	output wire  csoc_uart_read,
	input  [7:0] csoc_data_i,
	output [7:0] csoc_data_o
);

wire rx_rcv;        // -- Received character signal
wire [7:0] rx_data; // -- Received data

wire [7:0] tx_data; // -- Received data
wire tx_start;      // --
wire tx_ready;      // -- Transmitter ready signal


reg [1:0] master_rst_n;  // -- Master, active low, asynchonous reset, synchronous release

// Async reset synchronization
always @(posedge clk or posedge rst) begin
	if (rst) begin
		master_rst_n <= 0;
	end
	else begin
		master_rst_n[1] <= 1;
		master_rst_n[0] <= master_rst_n[1];
	end
end


uart_rx #(.BAUDRATE(BAUDRATE)) rx0 (
	.clk(clk),
	.rstn(master_rst_n[0]),
	.rcv(rx_rcv),
	.data(rx_data),
	.rx(rx)
);

uart_tx #(.BAUDRATE(BAUDRATE)) tx0 (
	.clk(clk),
	.rstn(master_rst_n[0]),
	.start(tx_start),
	.data(tx_data),
	.ready(tx_ready),
	.tx(tx)
);

cmd_parser cp0 (
	.clk(clk),
	.rstn(master_rst_n[0]),
	//
	.tx_start_o(tx_start),
	.tx_data_o(tx_data),
	.tx_ready_i(tx_ready),
	//
	.rx_data(rx_data),
	.new_rx_data(rx_rcv),
	//
	.leds(leds),
	.sseg(sseg),
	.an(an),
	//
	.csoc_clk(csoc_clk),
	.csoc_rstn(csoc_rstn),
	.csoc_test_se(csoc_test_se),
	.csoc_test_tm(csoc_test_tm),
	.csoc_uart_write(csoc_uart_write),
	.csoc_uart_read(csoc_uart_read),
	.csoc_data_i(csoc_data_i),
	.csoc_data_o(csoc_data_o)
);

endmodule
