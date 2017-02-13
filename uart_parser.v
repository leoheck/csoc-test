
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

parameter TIMEOUT = 12000000;
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
// always @(*) begin
// 	case (char_count)
// 		3'd0: tx_data_o <= "\n";
// 		3'd1: tx_data_o <= "1";
// 		3'd2: tx_data_o <= "2";
// 		3'd3: tx_data_o <= "3";
// 		3'd4: tx_data_o <= "4";
// 		3'd5: tx_data_o <= "5";
// 		3'd6: tx_data_o <= "6";
// 		3'd7: tx_data_o <= "7";
// 		default: tx_data_o <= "_";
// 	endcase
// end


//--------------------- CONTROLLER

localparam INI = 0;
localparam TXCAR = 1;
localparam NEXTCAR = 2;
localparam STOP = 3;

//-- fsm state
reg [1:0] state;
reg [1:0] next_state;

reg cenb;
reg tx_done;

//-- Transition between states
always @(posedge clk) begin
	if (!rstn) begin
		state <= INI;
	end
	else begin
		state <= next_state;
	end
end

// -- Control signal generation and next states
always @(*) begin
	next_state <= state;
	tx_start_o <= 0;
	tx_done <= 0;

	case (state)
		//-- Initial state. Start the trasmission
		INI: begin
			if (cenb) begin
				tx_start_o <= 1;
				next_state <= TXCAR;				
			end
		end

		//-- Wait until one car is transmitted
		TXCAR: begin
			if (tx_ready_i) begin
				tx_done <= 1;
				next_state <= NEXTCAR;
			end
		end

		//-- Increment the character counter
		//-- Finish when it is the last character
		NEXTCAR: begin
			next_state <= INI;
		end

	endcase
end




//================================================================================
//================================================================================

reg [1:0] my_state;
reg [1:0] my_next_state;

reg [6:0] column;
reg [7:0] tx_data;

reg [11:0] pulse_count;

localparam MAX_COL = 7;
localparam NUM_OF_REGS = 20;  // 1919 regs in the scan schain
localparam RUNNING_TICKS = 10; // deixar o soc executando ate preencher alguns registradores... 

localparam GET_INTERNAL_STATE = 0;
localparam CSOC_RUN = 1;
localparam PROCEDURE_DONE = 2;

always @(posedge clk) begin
	if (!rstn)
		my_state <= GET_INTERNAL_STATE;
	else
		my_state <= my_next_state;
end

always @(posedge clk) begin
	if (!rstn)
		csoc_clk <= 0;
	else
		if (tx_ready_i && !csoc_clk)
			csoc_clk <= 1;
		else
			csoc_clk <= 0;
end

always @(*) begin

	my_next_state <= my_state;

	tx_data <= ".";
	tx_data_o <= tx_data;
	cenb <= 0;

	column <= column;
	pulse_count <= pulse_count;

	csoc_test_tm <= 1;
	csoc_test_se <= 1;
	csoc_data_o[7] <= 1'b0;

	case (my_state)
		
		GET_INTERNAL_STATE: begin

			cenb <= 1;

			if (csoc_clk) begin
				pulse_count <= pulse_count + 1;
				column <= column + 1;
			end

			if (column > MAX_COL)
				tx_data <= "\n";
			else
				case (csoc_data_i[7])
					1'b0: tx_data <= "0";
					1'b1: tx_data <= "1";
				endcase

			if (pulse_count > NUM_OF_REGS) begin
				pulse_count <= 0;
				csoc_test_tm <= 0;
				csoc_test_se <= 0;
				my_next_state <= CSOC_RUN;
				cenb <= 0;
			end
		end

		CSOC_RUN: begin
			if (csoc_clk) begin
				pulse_count <= pulse_count + 1;
			end
			csoc_test_tm <= 0;
			csoc_test_se <= 0;
			if (pulse_count == RUNNING_TICKS) begin
				pulse_count <= 0;
				my_next_state <= PROCEDURE_DONE;
			end
		end	

		// PROCEDURE_DONE: begin
		// 	// -- TODO
		// end

	endcase
end



endmodule
