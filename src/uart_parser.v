
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
	output wire [7:0] csoc_data_o
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
	.decplace(2'b00),
	.seg(sseg),
	.an(an)
);

always @(posedge clk or negedge rstn) begin
	if (!rstn) begin
		sevenseg <= 0;
		banner_ptr <= 0;
	end
	else begin
		sevenseg <= sevenseg + 1;
		if (sevenseg == BANNER_SPEED) begin
			sevenseg <= 0;
			banner_ptr <= banner_ptr + 1;
			if (banner_ptr == BANNER_SIZE) begin
				banner_ptr <= 0;
			end
		end
	end
end




// #=====================================================================================================

// REDUZINDO OS WARNINGS
// TEMPORARIO JOGA ENTRADA data_i pros leds
reg [7:0] rx_data_reg;
always @(posedge clk or negedge rstn) begin
	if (!rstn) begin
		rx_data_reg <= 0;
		leds <= 0;
	end
	else begin
		if (new_rx_data)
			rx_data_reg <= rx_data;
		if (csoc_uart_write_i)
			leds <= csoc_data_i;
		else
			leds <= 0;
	end
end


// #=====================================================================================================
// #=====================================================================================================
// #=====================================================================================================
// #=====================================================================================================

reg [3:0] state, state_nxt;
reg run_done, run_done_nxt;

localparam
	INIT_STATE = 0,
	INITIAL_MESSAGE = 1,
	GET_INTERNAL_STATE = 2,
	CSOC_RUN = 3,
	PROCEDURE_DONE = 4,
	WAIT_1 = 5,
	WAIT_2 = 6,
	WAIT_3 = 7,
	WAIT_4 = 8,
	WAIT_5 = 9;

// UART TRANSMITTER

localparam
	TX_INIT = 0,
	TX_IDLE = 1,
	TX_START = 2,
	TX_SEND = 3,
	TX_WAIT = 4;

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
					tx_state_nxt = TX_WAIT;
				end
			end

			TX_WAIT: begin
				tx_state_nxt = TX_START;
			end

			TX_START: begin
				tx_start_nxt = 1;
				tx_state_nxt = TX_SEND;
			end
			TX_SEND: begin
				tx_start_nxt = 1;
				if (dta_sent) begin
					if (has_new_data) begin
						tx_start_nxt = 1;
						tx_state_nxt = TX_START;
					end
					else begin
						tx_start_nxt = 0;
						tx_state_nxt = TX_IDLE;
					end
				end
				if (run_done) begin
					tx_state_nxt = TX_IDLE;
				end
			end

	endcase
end


// #=====================================================================================================
// #=====================================================================================================
// #=====================================================================================================
// #=====================================================================================================

localparam INITIAL_MSG_SIZE = 24;
reg [7:0] initial_msg [0:INITIAL_MSG_SIZE-1];
reg [7:0] msg_char, msg_char_nxt;
reg [5:0] msg_ptr, msg_ptr_nxt;

reg [7:0] csoc_data_i_s;
reg csoc_data_write_s;

initial begin
	$readmemh("initial_message.txt", initial_msg);
end


localparam MAX_COL = 20; // 80 quebra as colunas na saida
localparam NUM_OF_REGS = 40; // 1919 regs in the scan schain
localparam RUNNING_TICKS = 4000; // deixar o soc executando ate preencher alguns registradores...

reg [7:0] tx_data, tx_data_nxt;
reg [11:0] pulse_count, pulse_count_nxt;
reg [6:0] col_break, col_break_nxt;
reg csoc_clk, csoc_clk_nxt;

assign tx_data_o = tx_data;
assign csoc_clk_o = csoc_clk;

always @(posedge clk or negedge rstn) begin
	if (!rstn) begin
		state <= INIT_STATE;
		tx_data <= 8'bz;
		pulse_count <= 0;
		col_break <= 0;
		msg_char <= "_";
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
			state_nxt = WAIT_1;
			csoc_clk_nxt = 0;
			run_done_nxt = 0;
		end

		WAIT_1: state_nxt = WAIT_2;
		WAIT_2: begin
			state_nxt = WAIT_3;
			has_new_data_nxt = 0;
		end
		WAIT_3: state_nxt = WAIT_4;
		WAIT_4: state_nxt = WAIT_5;
		WAIT_5: state_nxt = INITIAL_MESSAGE;

		// Envia a mensagem de boas vindas pela serial
		INITIAL_MESSAGE: begin
			dta_sent_nxt = 0;
			has_new_data_nxt = 0;

			// if (tx_state == TX_SEND && tx_ready_i) begin
			if (tx_ready_i) begin
				has_new_data_nxt = 1;
				dta_sent_nxt = 1;
				msg_ptr_nxt = msg_ptr + 1;
				tx_data_nxt = msg_char;	 // new teste

				if (msg_ptr >= INITIAL_MSG_SIZE) begin
					msg_ptr_nxt = 0;
					has_new_data_nxt = 0;
					tx_data_nxt = "\n";
					state_nxt = GET_INTERNAL_STATE;
				end
			end
		end

		// Pega o estado atual do CSOC
		// Atraves da escanchain

		GET_INTERNAL_STATE: begin

			dta_sent_nxt = 0;
			has_new_data_nxt = 0;

			if (tx_ready_i) begin
				if (col_break >= MAX_COL) begin
					col_break_nxt = 0;
					tx_data_nxt = "\n";
				end
				else begin
					csoc_clk_nxt = 1;
					has_new_data_nxt = 1;
					dta_sent_nxt = 1;
					pulse_count_nxt = pulse_count + 1;
					col_break_nxt = col_break + 1;
					case (csoc_data_i[7])
						1'b0: tx_data_nxt = "_";
						1'b1: tx_data_nxt = "#";
					endcase
				end
			end

			if (pulse_count >= NUM_OF_REGS) begin
				has_new_data_nxt = 0;
				pulse_count_nxt = 0;
				col_break_nxt = 0;
				if (run_done) begin
					state_nxt = PROCEDURE_DONE;
				end
				else begin
					state_nxt = CSOC_RUN;
				end
			end
		end

		// EXECUTA O SCSOC POR N CICLOS

		CSOC_RUN: begin
			has_new_data_nxt = 0;

			if (csoc_clk) begin
				pulse_count_nxt = pulse_count + 1;
			end

			if (pulse_count >= RUNNING_TICKS) begin
				has_new_data_nxt = 1;
				pulse_count_nxt = 0;
				run_done_nxt = 1;
				state_nxt = GET_INTERNAL_STATE;
			end
		end

		PROCEDURE_DONE: begin
			has_new_data_nxt = 0;
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


// ===========================================
// Clock DIV

// output reg out_clk;
// input clk ;
// input rst;
// always @(posedge clk or negedge rstn) begin
// 	if (~rst)
// 		out_clk <= 1'b0;
// 	else
// 		out_clk <= ~out_clk;
// end

endmodule
