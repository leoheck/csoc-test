
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
	output wire       csoc_clk_o,
	output reg        csoc_rstn_o,
	output reg        csoc_test_se_o,    // Scan Enable
	output reg        csoc_test_tm_o,    // Test Mode
	input  wire       csoc_uart_write_i,
	output reg        csoc_uart_read_o,
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
reg [7:0] msg_char;
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

localparam MAX_COL = 10; // 80 quebra as colunas na saida
localparam NUM_OF_REGS = 19;  // 1919 regs in the scan schain
localparam RUNNING_TICKS = 4000; // deixar o soc executando ate preencher alguns registradores...

reg [2:0] state, state_nxt;
reg [7:0] tx_data, tx_data_nxt;
reg [11:0] pulse_count, pulse_count_nxt;
reg [6:0] col_break, col_break_nxt;
reg csoc_clk, csoc_clk_nxt;
reg run_done, run_done_nxt;

assign tx_data_o = tx_data;
assign csoc_clk_o = csoc_clk;

always @(posedge clk or negedge rstn) begin
	if (!rstn) begin
		state <= INIT_STATE;
		tx_data <= 8'bz;
		pulse_count <= 0;
		col_break <= 0;
		msg_ptr <= 0;
		has_new_data <= 1;
		dta_sent <= 0;
		csoc_clk <= 0;
		run_done <= 0;
	end
	else begin
		state <= state_nxt;
		pulse_count <= pulse_count_nxt;
		col_break <= col_break_nxt;
		msg_char <= initial_msg[msg_ptr];
		msg_ptr <= msg_ptr_nxt;
		has_new_data <= has_new_data_nxt;
		dta_sent <= dta_sent_nxt;
		tx_data <= tx_data_nxt;
		csoc_clk <= csoc_clk_nxt;
		run_done <= run_done_nxt;
	end
end

always @(*) begin
	state_nxt = state;
	tx_data_nxt = tx_data;
	pulse_count_nxt = pulse_count;
	col_break_nxt = col_break;
	msg_ptr_nxt = msg_ptr;
	has_new_data_nxt = has_new_data;
	dta_sent_nxt = dta_sent;
	csoc_clk_nxt = csoc_clk;
	run_done_nxt = run_done;
	case (state)

		INIT_STATE: begin
			has_new_data_nxt = 1;
			tx_data_nxt = msg_char;
			state_nxt = INITIAL_MESSAGE;
			csoc_clk_nxt = 0;
			run_done_nxt = 0;
		end

		// Envia a mensagem de boas vindas pela serial

		INITIAL_MESSAGE: begin
			dta_sent_nxt = 0;
			has_new_data_nxt = 0;
			tx_data_nxt = msg_char;	 // new teste
			if (tx_state == TX_SEND && tx_ready_i) begin
				has_new_data_nxt = 1;
				dta_sent_nxt = 1;
				msg_ptr_nxt = msg_ptr + 1;
			end

			if (msg_ptr == INITIAL_MSG_SIZE-1) begin
				has_new_data_nxt = 0;
				// tx_start_nxt = 0;
				state_nxt = GET_INTERNAL_STATE;
			end
		end

		// Pega o estado atual do CSOC
		// Atraves da escanchain

		GET_INTERNAL_STATE: begin
			// if (csoc_clk) begin
			if (tx_ready_i) begin
				csoc_clk_nxt = 1;
				pulse_count_nxt = pulse_count + 1;
				col_break_nxt = col_break + 1;
			end
			else
				csoc_clk_nxt = 1;

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
				// tx_start_nxt = 0;
				pulse_count_nxt = 0;
				col_break_nxt = 0;
				if (run_done)
					state_nxt = PROCEDURE_DONE;
				else
					state_nxt = CSOC_RUN;
			end
		end

		// EXECUTA O SCSOC POR N CICLOS

		CSOC_RUN: begin
			// tx_start_nxt = 0;
			csoc_clk_nxt = ~csoc_clk;
			if (csoc_clk)
				pulse_count_nxt = pulse_count + 1;
			if (pulse_count == RUNNING_TICKS) begin
				// tx_start_nxt = 1;
				pulse_count_nxt = 0;
				run_done_nxt = 1;
				state_nxt = GET_INTERNAL_STATE;
			end
		end

		PROCEDURE_DONE: begin
			// tx_start_nxt = 0;
		end

	endcase
end


// #============================================

// CSOC CLOCK GEN

// always @(posedge clk or negedge rstn) begin
// 	if (!rstn)
// 		csoc_clk <= 0;
// 	else

// 		case (state)
// 			GET_INTERNAL_STATE:
// 				// csoc_clk = ~csoc_clk;
// 				if (tx_ready_i & has_new_data & !csoc_clk)
// 					csoc_clk <= 1;
// 				else
// 					csoc_clk <= 0;

// 			CSOC_RUN:
// 				csoc_clk <= ~csoc_clk;

// 			GET_INTERNAL_STATE:
// 				if (tx_ready_i & has_new_data & !csoc_clk)
// 					csoc_clk <= 1;
// 				else
// 					csoc_clk <= 0;
// 		endcase

// end

endmodule
