// ----------------------------------------------------------------------------
// -- capeta_test.v: CSoC scan chain control and cadence ATPG
// -- All the received characters are echoed
// ----------------------------------------------------------------------------
// -- (C) BQ. Fev 2017. Written by Leandro Heck (leoheck@gmail.com)
// -- GPL license
// ----------------------------------------------------------------------------

`default_nettype none

module part_tester #(
	parameter SHOW_INIT_MSG = 1,
	parameter BAUDRATE = `B9600,
	parameter NPIS = 14,
	parameter NPOS = 11
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

	// PART UNDER TEST
	output wire [1:14] part_pis_o, // primary input
	input  wire [1:11] part_pos_i // primary outputs
);

reg [1:0] master_rst_n;  // -- Master, active low, asynchonous reset, synchronous release

wire rx_rcv;        // -- Received character signal
wire [7:0] rx_data; // -- Received data

wire [7:0] tx_data; // -- Received data
wire tx_start;      // --
wire tx_ready;      // -- Transmitter ready signal

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

uart_tx #(.BAUDRATE(BAUDRATE)) tx0 (
	.clk(clk),
	.rstn(master_rst_n[0]),
	.start(tx_start),
	.data(tx_data),
	.ready(tx_ready),
	.tx(tx)
);

uart_rx #(.BAUDRATE(BAUDRATE)) rx0 (
	.clk(clk),
	.rstn(master_rst_n[0]),
	.rx(rx),
	.rcv(rx_rcv),
	.data(rx_data)
);

cmd_parser #(
	.SHOW_INIT_MSG(SHOW_INIT_MSG),
	.NPIS(NPIS),
	.NPOS(NPOS)
)
cp0 (
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
	.part_pis_o(part_pis_o),
	.part_pos_i(part_pos_i)
);

endmodule
