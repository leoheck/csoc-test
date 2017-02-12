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

wire rcv;        // -- Received character signal
wire [7:0] data; // -- Received data
reg rstn = 0;    // -- Reset signal
wire ready;      // -- Transmitter ready signal


always @(posedge clk) begin
	rstn <= 1;
end

uart_rx #(.BAUDRATE(BAUDRATE)) rx0 (
	.clk(clk),
	.rstn(rstn),
	.rx(rx),
	.rcv(rcv),
	.data(data)
);

wire [7:0] tx_data; // -- Received data
wire tx_start;      // -- 
wire tx_ready;      // -- Transmitter ready signal

uart_tx #(.BAUDRATE(BAUDRATE)) tx0 (
	.clk(clk),
	.rstn(rstn),
	.start(tx_start),
	.data(tx_data),
	.ready(tx_ready),
	.tx(tx)
);

cmd_parser cp0 (
	.clk(clk),
	.rstn(rstn),
	// 
	.tx_start_o(tx_start),
	.tx_data_o(tx_data),
	.tx_ready_i(tx_ready),
	// 
	.rx_data(data),
	.new_rx_data(rcv),
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
