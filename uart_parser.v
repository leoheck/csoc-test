
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


wire scan_i_s;
wire scan_o_s;
assign scan_i_s = csoc_data_i[7];
assign scan_o_s = csoc_data_o[7];


reg [7:0] csoc_data_i_s;
reg csoc_data_write_s;


wire dp;
reg        counting;
reg [27:0] sevenseg;
integer i;

parameter BANNER_SIZE = 32;
reg [7:0] banner [0:BANNER_SIZE-1];
reg [7:0] banner_ptr;

// Banner ROM initialization
initial begin
	$readmemh("banner.txt", banner);
end

sevenseg ss0 (
	.clk(clk),
	.display_0(banner[banner_ptr + 0]),
	.display_1(banner[banner_ptr + 1]),
	.display_2(banner[banner_ptr + 2]),
	.display_3(banner[banner_ptr + 3]),
	.decplace(2'b10),
	.seg(sseg),
	.an(an)
);

parameter TIMEOUT = 14000000;
always @(posedge clk) begin
	if (!rstn) begin
		sevenseg <= 1;
		banner_ptr <= 0;
	end
	sevenseg <= sevenseg + 1;
	if (sevenseg == TIMEOUT) begin
		sevenseg <= 1;
		banner_ptr <= banner_ptr + 1;
		if (banner_ptr == BANNER_SIZE) begin
			banner_ptr <= 0;
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
		
		// por enquanto removendo warnings do bitgen
		csoc_data_i_s <= ~csoc_data_i_s;
		csoc_data_write_s <= ~csoc_data_write_s;
	end
end


//-- Characters counter
//-- It only counts when the cena control signal is enabled
reg [2:0] char_count;
reg cena; //-- Counter enable
reg [7:0] data;

always @(posedge clk) begin
	if (!rstn) begin
		char_count <= 0;
	end
	else if (cena) begin
		char_count <= char_count + 1;
	end
end

//-- Multiplexer with the 8-character string to transmit
always @(*) begin
	case (char_count)
		3'd0: tx_data_o <= "\n";
		3'd1: tx_data_o <= "1";
		3'd2: tx_data_o <= "2";
		3'd3: tx_data_o <= "3";
		3'd4: tx_data_o <= "4";
		3'd5: tx_data_o <= "5";
		3'd6: tx_data_o <= "6";
		3'd7: tx_data_o <= "7";
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
	if (!rstn) begin
		state <= INI;
	end
	else begin
		state <= next_state;
	end
end

//-- Control signal generation and next states
always @(*) begin
	next_state <= state;
	tx_start_o <= 0;
	cena <= 0;

	case (state)
		//-- Initial state. Start the trasmission
		INI: begin
			tx_start_o <= 1;
			next_state <= TXCAR;
		end

		//-- Wait until one car is transmitted
		TXCAR: begin
			if (tx_ready_i)
				next_state <= NEXTCAR;
		end

		//-- Increment the character counter
		//-- Finish when it is the last character
		NEXTCAR: begin
			cena <= 1;
			if (char_count == 7) begin
				next_state <= STOP;
			end
			else
				next_state <= INI;
		end

	endcase
end


reg [7:0] column;
reg [7:0] tx_data;
always @(*) begin
	column <= column;
	tx_data <= tx_data;
	if (tx_start_o) begin
		column <= column + 1;
	end
	if (column == 79) begin
		tx_data <= "\n";
	end
end


endmodule
