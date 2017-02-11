
module cmd_parser
(
	input clk,
	input rstn,

	output reg  [7:0] tx_data,      // data byte to transmit
	output reg        new_tx_data,  // asserted to indicate that there is a new data byte for transmission
	input             tx_busy,      // signs that transmitter is busy

	input       [7:0] rx_data,      // data byte received
	input             new_rx_data,  // signs that a new byte was received

	output reg  [7:0] leds,         // -- Board leds
	output      [7:0] sseg,         // -- Board 7Segment Display
	output      [3:0] an,           // -- 7Segment Display enable

	// CSoC
	output reg        csoc_clk,
	output reg        csoc_rstn,
	output reg        csoc_test_se,    // Scan Enable
	output reg        csoc_test_tm,    // Test Mode
	input  wire       csoc_uart_write, 
	output reg        csoc_uart_read,  
	input  wire [7:0] csoc_data_i,     
	output reg  [7:0] csoc_data_o      
);


reg [7:0] csoc_data_i_s;
reg csoc_data_write_s;

wire dp;

sevenseg ss0 (
	.clk(clk),
	.digit0(4'h0),
	.digit1(4'h1),
	.digit2(4'h2),
	.digit3(4'h3),
	.decplace(2'b10),
	.seg(sseg),
	.an(an),
	.dp(dp)
);




// RECEIVE DATA FROM CSOC
// parameter BAUDRATE = `B115200;
// wire rcv;        // -- Received character signal
// wire [7:0] csoc_rx_data; // -- Received data
// uart_rx #(.BAUDRATE(BAUDRATE)) rx1 (
// 	.clk(clk),
// 	.rstn(rstn),
// 	.rx(csoc_uart_write),
// 	.rcv(rcv),
// 	.data(csoc_rx_data)
// );

// CSOC INTERFACE
always @(posedge clk) begin
	if (!rstn) begin
		csoc_clk <= 1'b0;
		csoc_rstn <= 1'b0;
		csoc_test_se <= 1'b0;
		csoc_test_tm <= 1'b0;
		csoc_uart_read <= 1'b0;
		csoc_data_o <= 8'b0;

		csoc_data_i_s <= 8'b0;
		csoc_data_write_s <= 1'b0;

		tx_data <= "A";
	end
	else begin
		csoc_clk <= ~csoc_clk;
		csoc_rstn <= 1'b1;
		
		// csoc_data_i_s <= ~csoc_data_i_s;
		// csoc_data_write_s <= ~csoc_data_write_s;

		leds[7] <= 1'b1; // indica que ta funcionando
		// leds[6] <= csoc_rstn;
		// leds[5] <= csoc_test_se;
		// leds[4] <= csoc_test_tm;
		// leds[3] <= csoc_uart_read;
		// leds[2] <= csoc_data_write_s;
		// leds[1] <= &csoc_data_o;
		// leds[0] <= rcv;


		// if (rcv) begin
		// 	new_tx_data <= 1'b1;
		// 	tx_data <= csoc_rx_data;
		// end
		
		tx_data <= tx_data;
		new_tx_data <= 1'b1;
	end
end

endmodule
