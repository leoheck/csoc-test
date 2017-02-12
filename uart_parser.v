
module cmd_parser
(
	input clk,
	input rstn,

	output reg        tx_start_o,     // signs that transmitter is busy
	output reg  [7:0] tx_data_o,      // data byte to transmit
	input  wire       tx_ready_i,

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

parameter BANNER_SIZE = 30;
reg [7:0] banner [0:BANNER_SIZE-1];

// Banner ROM initialization
initial begin
	$readmemh("banner.txt", banner);
end

sevenseg ss0 (
	.clk(clk),
	.display_0(banner[0]),
	.display_1(banner[1]),
	.display_2(banner[2]),
	.display_3(banner[3]),
	.decplace(2'b10),
	.seg(sseg),
	.an(an),
	.dp(dp)
);

parameter TIMEOUT = 16000000;
always @(posedge clk) begin
	sevenseg <= sevenseg + 1;
	if (sevenseg == TIMEOUT) begin
		sevenseg <= 1;
		banner[BANNER_SIZE-1] <= banner[0];
		for(i=0; i<BANNER_SIZE-1; i=i+1) begin
			banner[i] <= banner[i+1];
		end
	end
end





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
	end
end





//-- Connecting wires
// wire ready;

//-- Characters counter
//-- It only counts when the cena control signal is enabled
reg [2:0] char_count;
reg cena; //-- Counter enable
reg [7:0] data;

always @(posedge clk) begin
	// if (!rstn) begin
	// 	cena <= 0;
		// char_count <= 0;
	// end
	// else 
	if (cena) begin
		char_count = char_count + 1;
	end
end

//-- Multiplexer with the 8-character string to transmit
always @(*) begin
	case (char_count)
		8'd0: tx_data_o <= "1";
		8'd1: tx_data_o <= "2";
		8'd2: tx_data_o <= "3";
		8'd3: tx_data_o <= "4";
		8'd4: tx_data_o <= "5";
		8'd5: tx_data_o <= "6";
		8'd6: tx_data_o <= "7";
		8'd7: tx_data_o <= " ";
		default: tx_data_o <= "_";
	endcase
end


//--------------------- CONTROLLER

localparam INI = 0;
localparam TXCAR = 1;
localparam NEXTCAR = 2;
localparam STOP = 3;

//-- fsm state
reg [1:0] state;
reg [1:0] next_state;

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
	tx_start_o = 0;
	cena = 0;

	case (state)
		//-- Initial state. Start the trasmission
		INI: begin
			tx_start_o = 1;
			next_state = TXCAR;
		end

		//-- Wait until one car is transmitted
		TXCAR: begin
			if (tx_ready_i)
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
