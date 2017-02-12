
module cmd_parser
(
	input clk,
	input rstn,

	output reg  [7:0] tx_data,      // data byte to transmit
	output reg        new_tx_data,  // asserted to indicate that there is a new data byte for transmission
	output reg        tx_start,     // signs that transmitter is busy

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
reg        counting;
reg [27:0] sevenseg;
integer i;
reg  [4:0] banner [0:19]; // "SCoC TEST GAPH 2017 "




//-- Connecting wires
wire ready;

//-- Characters counter
//-- It only counts when the cena control signal is enabled
reg [2:0] char_count;
reg cena; //-- Counter enable

//-- fsm state
reg [1:0] state;
reg [1:0] next_state;




// Banner ROM initialization
initial begin
	$readmemh("banner.txt", banner);
	// $readmemh("banner.txt", banner);
end

sevenseg ss0 (
	.clk(clk),
	.digit0(banner[0]),
	.digit1(banner[1]),
	.digit2(banner[2]),
	.digit3(banner[3]),
	.decplace(2'b10),
	.seg(sseg),
	.an(an),
	.dp(dp)
);

parameter TIMEOUT = 10000000;
always @(posedge clk) begin
	sevenseg <= sevenseg + 1;
	if (sevenseg == TIMEOUT) begin
		sevenseg <= 1;
		banner[19] <= banner[0];
		for(i=0; i<19; i=i+1) begin
			banner[i] <= banner[i+1];
		end
	end
end




reg [7:0] data;

always @(posedge clk) begin
	if (!rstn) begin
		char_count = 0;
	end
	else begin
		if (char_count == 10) begin
			char_count = 0;
		end
		char_count = char_count + 1;
	end
end

//-- Multiplexer with the 8-character string to transmit
always @*
	case (char_count)
		8'd0: data <= "1";
		8'd1: data <= "2";
		8'd2: data <= "3";
		8'd3: data <= "4";
		8'd4: data <= "5";
		8'd5: data <= "6";
		8'd6: data <= "7";
		8'd7: data <= "8";
		default: data <= "+";
	endcase


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

		tx_data <= " ";
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
		
		// if (!tx_busy) begin
			new_tx_data <= 1'b1;
			tx_data <= data;
		// end
	end
end







//--------------------- CONTROLLER

localparam INI = 0;
localparam TXCAR = 1;
localparam NEXTCAR = 2;
localparam STOP = 3;



//-- Transition between states
always @(posedge clk) begin
	if (!rstn)
		state <= INI;
	else
		state <= next_state;
end

//-- Control signal generation and next states
always @(*) begin
	next_state = state;
	tx_start = 0;
	cena = 0;

	case (state)
		//-- Initial state. Start the trasmission
		INI: begin
			tx_start = 1;
			next_state = TXCAR;
		end

		//-- Wait until one car is transmitted
		TXCAR: begin
			if (ready)
				next_state = NEXTCAR;
		end

		//-- Increment the character counter
		//-- Finish when it is the last character
		NEXTCAR: begin
			cena = 1;
			if (char_count == 7)
				next_state = STOP;
			else
				next_state = INI;
		end

	endcase
end


endmodule
