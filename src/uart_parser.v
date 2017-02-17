
module cmd_parser
(
	input wire clk,
	input wire rstn,

	output wire        tx_start_o,     // signs that transmitter is busy
	output wire  [7:0] tx_data_o,      // data byte to transmit
	input  wire        tx_ready_i,

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

// #=====================================================================================================
// #=====================================================================================================
// #=====================================================================================================
// #=====================================================================================================

localparam BANNER_SPEED = 12000000; // 50MHz / BANNER_SPEED = (time in seconds for refresh)
localparam BANNER_SIZE = 32;
reg [7:0] banner [0:BANNER_SIZE-1];
reg [7:0] banner_ptr;
reg [27:0] sevenseg;

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

always @(posedge clk or negedge rstn) begin
	if (!rstn) begin
		sevenseg <= 1;
		banner_ptr <= 0;
		leds <= 0;
	end
	else begin
		leds <= 0;
		sevenseg <= sevenseg + 1;
		if (sevenseg == BANNER_SPEED) begin
			sevenseg <= 1;
			banner_ptr <= banner_ptr + 1;
			if (banner_ptr == BANNER_SIZE) begin
				banner_ptr <= 0;
			end
		end
	end
end






// #=====================================================================================================
// #=====================================================================================================
// #=====================================================================================================
// #=====================================================================================================

// UART TRANSMITTER

localparam
	TX_INIT = 0,
	TX_IDLE = 1,
	TX_START = 2,
	TX_SEND = 3;

reg [2:0] tx_state, tx_state_nxt;
reg has_new_data, has_new_data_nxt;
reg dta_sent, dta_sent_nxt;
reg tx_start, tx_start_nxt;

assign tx_start_o = tx_start;

always @(posedge clk or negedge rstn) begin
	if (!rstn) begin
		tx_state <= TX_INIT;
		tx_start <= 0;
	end
	else begin
		tx_state <= tx_state_nxt;
		tx_start <= tx_start_nxt;
	end
end

always @(*) begin
	tx_state_nxt = tx_state;
	tx_start_nxt = tx_start;
	case (tx_state)
		TX_INIT: begin
			tx_start_nxt = 0;
			tx_state_nxt = TX_IDLE;
		end
		TX_IDLE: begin
			tx_start_nxt = 0;
			if (tx_ready_i && has_new_data) begin
				tx_start_nxt = 1;
				tx_state_nxt = TX_START;
			end
		end
		TX_START: begin
			tx_start_nxt = 1;
			tx_state_nxt = TX_SEND;
		end
		TX_SEND: begin
			tx_start_nxt = 1;
			if (dta_sent) begin
				tx_start_nxt = 0;
				if (has_new_data)
					tx_state_nxt = TX_START;
				else begin
					tx_start_nxt = 0;
					tx_state_nxt = TX_IDLE;
				end
			end
		end
	endcase
end


// #=====================================================================================================
// #=====================================================================================================
// #=====================================================================================================
// #=====================================================================================================

localparam INITIAL_MSG_SIZE = 29;
reg [7:0] initial_msg [0:INITIAL_MSG_SIZE-1];
reg [5:0] msg_ptr, msg_ptr_nxt;

reg [7:0] csoc_data_i_s;
reg csoc_data_write_s;

initial begin
	$readmemh("initial_message.txt", initial_msg);
end

localparam
	INIT_STATE = 0,
	INITIAL_MESSAGE = 1,
	GET_INTERNAL_STATE = 2,
	CSOC_RUN = 3,
	PROCEDURE_DONE = 4;

localparam MAX_COL = 8;
localparam NUM_OF_REGS = 20;  // 1919 regs in the scan schain
localparam RUNNING_TICKS = 6; // deixar o soc executando ate preencher alguns registradores...

reg [2:0] state, state_nxt;
reg [7:0] tx_data, tx_data_nxt;
reg [11:0] pulse_count, pulse_count_nxt;
reg [6:0] col_break, col_break_nxt;

assign tx_data_o = tx_data;

always @(posedge clk or negedge rstn) begin
	if (!rstn) begin
		state <= INIT_STATE;
		tx_data <= 8'bz;
		pulse_count <= 0;
		col_break <= 0;
		msg_ptr <= 0;
		has_new_data <= 1;
		dta_sent <= 0;
	end
	else begin
		state <= state_nxt;
		pulse_count <= pulse_count_nxt;
		col_break <= col_break_nxt;
		msg_ptr <= msg_ptr_nxt;
		has_new_data <= has_new_data_nxt;
		dta_sent <= dta_sent_nxt;
		case (state)
			INIT_STATE: begin
				tx_data <= initial_msg[msg_ptr];
			end
			INITIAL_MESSAGE:
				tx_data <= initial_msg[msg_ptr];
			default:
				tx_data <= tx_data_nxt;
		endcase
	end
end

always @(*) begin
	state_nxt = state;
	tx_data_nxt = 8'bz;
	pulse_count_nxt = pulse_count;
	col_break_nxt = col_break;
	msg_ptr_nxt = msg_ptr;
	has_new_data_nxt = has_new_data;
	dta_sent_nxt = dta_sent;
	case (state)

		INIT_STATE: begin
			state_nxt = INITIAL_MESSAGE;
			has_new_data_nxt = 1;
		end

		INITIAL_MESSAGE: begin
			dta_sent_nxt = 0;
			has_new_data_nxt = 0;
			if (tx_state == TX_SEND && tx_ready_i) begin
				has_new_data_nxt = 1;
				dta_sent_nxt = 1;
				msg_ptr_nxt = msg_ptr + 1;
			end

			if (msg_ptr == INITIAL_MSG_SIZE-1) begin
				has_new_data_nxt = 0;
				// state_nxt = GET_INTERNAL_STATE;
				state_nxt = PROCEDURE_DONE;
			end
		end




		//
		// POR ENQUANTO ACABA POR AQUI
		//

		GET_INTERNAL_STATE: begin
			// if (csoc_clk) begin
			if (tx_ready_i) begin
				pulse_count_nxt = pulse_count + 1;
				col_break_nxt = col_break + 1;
			end

			if (col_break == MAX_COL) begin
				col_break_nxt = 0;
				tx_data_nxt = "\n";
			end
			else begin
				case (csoc_data_i[7])
					1'b0: tx_data_nxt = "L";
					1'b1: tx_data_nxt = "H";
				endcase
			end

			if (pulse_count == NUM_OF_REGS) begin
				pulse_count_nxt = 0;
				col_break_nxt = 0;
				state_nxt = CSOC_RUN;
			end
		end

		CSOC_RUN: begin
			pulse_count_nxt = pulse_count + 1;
			if (pulse_count == RUNNING_TICKS) begin
				pulse_count_nxt = 0;
				state_nxt = PROCEDURE_DONE;
			end
		end

	endcase
end


// #============================================

// CSOC CLOCK GEN

always @(posedge clk or negedge rstn) begin
	if (!rstn)
		csoc_clk <= 0;
	else

		case (state)
			GET_INTERNAL_STATE:
				// csoc_clk = ~csoc_clk;
				if (tx_ready_i & has_new_data & !csoc_clk)
					csoc_clk <= 1;
				else
					csoc_clk <= 0;

			CSOC_RUN:
				csoc_clk <= ~csoc_clk;

			GET_INTERNAL_STATE:
				if (tx_ready_i & has_new_data & !csoc_clk)
					csoc_clk <= 1;
				else
					csoc_clk <= 0;
		endcase

end

endmodule
