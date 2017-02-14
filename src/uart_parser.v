
module cmd_parser
(
	input wire clk,
	input wire rstn,

	output reg        tx_start_o,     // signs that transmitter is busy
	output reg  [7:0] tx_data_o,      // data byte to transmit
	input  wire       tx_ready_i,

	input wire      [7:0] rx_data,      // data byte received
	input wire            new_rx_data,  // signs that a new byte was received

	output reg  [7:0] leds,         // -- Board leds
	output wire [7:0] sseg,         // -- Board 7Segment Display
	output wire [3:0] an,           // -- 7Segment Display enable

	// CSoC
	output reg        csoc_clk,
	output reg        csoc_rstn,
	output reg        csoc_test_se,    // Scan Enable
	output reg        csoc_test_tm,    // Test Mode
	input  wire       csoc_uart_write,
	output reg        csoc_uart_read,
	input  wire [7:0] csoc_data_i,
	output wire  [7:0] csoc_data_o
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
	.rstn(rstn),
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
		leds <= 0;
	end
	else begin
		leds <= 0;
		sevenseg <= sevenseg + 1;
		if (sevenseg == TIMEOUT) begin
			sevenseg <= 1;
			banner_ptr <= banner_ptr + 1;
			if (banner_ptr == BANNER_SIZE) begin
				banner_ptr <= 0;
			end
		end
	end
end




//-- Characters counter
//-- It only counts when the cena control signal is enabled
// reg [2:0] char_count;
// reg cena; //-- Counter enable
// reg [7:0] data;

// always @(posedge clk) begin
// 	if (!rstn) begin
// 		char_count <= 0;
// 	end
// 	else if (cena) begin
// 		char_count <= char_count + 1;
// 	end
// end

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


//================================================================================

localparam INI = 0;
localparam TXCAR = 1;
localparam NEXTCAR = 2;
localparam STOP = 3;

//-- fsm state
reg [1:0] state;
reg [1:0] next_state;

reg cenb;

always @(posedge clk) begin
	if (!rstn) begin
		state <= INI;
	end
	else
		state <= next_state;
end

always @(*) begin
	next_state <= state;
	tx_start_o <= 0;

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
			tx_start_o <= 1;
			if (tx_ready_i) begin
				// tx_start_o <= 0;
				next_state <= NEXTCAR;
			end
		end

		//-- Increment the character counter
		//-- Finish when it is the last character
		NEXTCAR: begin
			tx_start_o <= 1;
			next_state <= INI;
		end

	endcase
end




//================================================================================
//================================================================================

reg [7:0] my_state;
reg [7:0] my_next_state;

reg [6:0] column;
reg [6:0] column_nxt;

reg [7:0] tx_data;
reg [7:0] tx_data_nxt;

reg [11:0] pulse_count;
reg [11:0] pulse_count_nxt;

localparam MAX_COL = 8;
localparam NUM_OF_REGS = 20;  // 1919 regs in the scan schain
localparam RUNNING_TICKS = 6; // deixar o soc executando ate preencher alguns registradores...

localparam INIT_STATE = 0;
localparam GET_INTERNAL_STATE = 1;
localparam CSOC_RUN = 2;
localparam GET_INTERNAL_STATE_2 = 3;
localparam PROCEDURE_DONE = 4;

always @(posedge clk) begin
	if (!rstn) begin
		my_state <= INIT_STATE;
		pulse_count <= 0;
		tx_data <= "x";
		column <= 0;
	end
	else begin
		my_state <= my_next_state;
		pulse_count <= pulse_count_nxt;
		tx_data <= tx_data_nxt;
		tx_data_o = tx_data;
		column <= column_nxt;
	end
end

always @(*) begin
	pulse_count_nxt <= pulse_count;
	my_next_state <= my_state;
	tx_data_nxt <= tx_data;
	column_nxt <= column;
	case (my_state)

		INIT_STATE: begin
			pulse_count_nxt <= 1;
			my_next_state <= GET_INTERNAL_STATE;
		end

		GET_INTERNAL_STATE: begin
			if (tx_ready_i) begin
				pulse_count_nxt <= pulse_count + 1;
				column_nxt <= column + 1;
			end

			if (column == MAX_COL) begin
				column_nxt <= 0;
				tx_data_nxt <= "\n";
			end
			else begin
				case (csoc_data_i[7])
					1'b0: tx_data_nxt <= "L";
					1'b1: tx_data_nxt <= "H";
				endcase
			end

			if (pulse_count == NUM_OF_REGS) begin
				tx_data_nxt <= "\n";
				pulse_count_nxt <= 0;
				column_nxt <= 0;
				my_next_state <= CSOC_RUN;
			end
		end

		CSOC_RUN: begin

			pulse_count_nxt <= pulse_count + 1;

			if (pulse_count == RUNNING_TICKS) begin
				pulse_count_nxt <= 0;
				my_next_state <= GET_INTERNAL_STATE_2;
			end
		end

		GET_INTERNAL_STATE_2: begin
			if (tx_ready_i) begin
				pulse_count_nxt <= pulse_count + 1;
				column_nxt <= column + 1;
			end

			if (column == MAX_COL) begin
				column_nxt <= 0;
			end
			else begin
				case (csoc_data_i[7])
					1'b0: tx_data_nxt <= "L";
					1'b1: tx_data_nxt <= "H";
				endcase
			end

			if (pulse_count == NUM_OF_REGS) begin
				tx_data_nxt <= "\n";
				pulse_count_nxt <= 0;
				column_nxt <= 0;
				my_next_state <= PROCEDURE_DONE;
			end
		end

		PROCEDURE_DONE: begin
			pulse_count_nxt <= 0;
			my_next_state <= PROCEDURE_DONE;
		end
	endcase
end

always @(posedge clk) begin
	if (!rstn)
		csoc_clk <= 0;
	else

		case (my_state)
			GET_INTERNAL_STATE:
				// csoc_clk = ~csoc_clk;
				if (tx_ready_i & cenb & !csoc_clk)
					csoc_clk <= 1;
				else
					csoc_clk <= 0;

			CSOC_RUN:
				csoc_clk <= ~csoc_clk;

			GET_INTERNAL_STATE:
				if (tx_ready_i & cenb & !csoc_clk)
					csoc_clk <= 1;
				else
					csoc_clk <= 0;
		endcase

end

always @(*) begin

	cenb <= 0;
	csoc_test_tm <= 1;
	csoc_test_se <= 1;
	csoc_uart_read <= 0;
	csoc_rstn <= 0;
	// csoc_data_o <= 0;

	case (my_state)

		GET_INTERNAL_STATE: begin
			cenb <= 1;
			if (pulse_count == NUM_OF_REGS) begin
				cenb <= 0;
			end
		end

		CSOC_RUN: begin
			if (pulse_count == RUNNING_TICKS) begin
				cenb <= 1;
			end
		end

		GET_INTERNAL_STATE_2: begin
			cenb <= 1;
			if (pulse_count == NUM_OF_REGS) begin
				cenb <= 0;
			end
		end

		PROCEDURE_DONE: begin
			// my_next_state <= PROCEDURE_DONE;
		end

	endcase
end






// always @(posedge clk) begin
// 	if (!rstn)
// 		csoc_clk <= 0;
// 	else
// 		if (tx_ready_i && !csoc_clk)
// 			csoc_clk <= 1;
// 		else
// 			csoc_clk <= 0;
// end

// always @(posedge clk) begin
// 	if (!rstn) begin
// 		tx_data_o <= " ";
// 		pulse_count <= 0;
// 		column <= 0;
// 	end
// 	else begin
// 		case (my_state)
// 			INIT_STATE: begin
// 				column <= 0;
// 				pulse_count <= 0;
// 			end
// 			GET_INTERNAL_STATE: begin
// 				if (csoc_clk) begin
// 					pulse_count <= pulse_count + 1;

// 					if (column == MAX_COL)
// 						tx_data_o <= "\n";
// 					else
// 						case (csoc_data_i[7])
// 							1'b0: tx_data_o <= "L";
// 							1'b1: tx_data_o <= "H";
// 						endcase

// 					column <= column + 1;
// 				end

// 			end

// 			CSOC_RUN: begin
// 				pulse_count <= pulse_count + 1;
// 			end

// 			default:
// 				pulse_count <= 0;
// 		endcase

// 	end
// end

// always @(*) begin

// 	my_next_state <= my_state;

// 	cenb <= 0;
// 	csoc_test_tm <= 1;
// 	csoc_test_se <= 1;

// 	csoc_uart_read <= 0;
// 	csoc_rstn <= 0;
// 	csoc_data_o <= 0;

// 	case (my_state)

// 		INIT_STATE: begin
// 			my_next_state <= GET_INTERNAL_STATE;
// 		end

// 		GET_INTERNAL_STATE: begin
// 			cenb <= 1;
// 			if (pulse_count == NUM_OF_REGS) begin
// 				cenb <= 0;
// 				pulse_count <= 0;
// 				my_next_state <= CSOC_RUN;
// 			end
// 		end

// 		CSOC_RUN: begin
// 			csoc_test_tm <= 0;
// 			csoc_test_se <= 0;
// 			if (pulse_count == RUNNING_TICKS) begin
// 				pulse_count <= 0;
// 				my_next_state <= PROCEDURE_DONE;
// 			end
// 		end

// 		PROCEDURE_DONE: begin
// 			my_next_state <= PROCEDURE_DONE;
// 		end

// 	endcase
// end



endmodule
