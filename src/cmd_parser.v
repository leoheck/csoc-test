
module cmd_parser #(
	parameter SHOW_INIT_MSG = 1,
	parameter NPIS = 14,
	parameter NPOS = 11
)(
	input  wire       clk,
	input  wire       rstn,

	output wire       tx_start_o,  // Signs that transmitter is busy
	output wire [7:0] tx_data_o,   // data byte to transmit
	input  wire       tx_ready_i,

	input  wire [7:0] rx_data,      // Data byte received
	input  wire       new_rx_data,  // Signs that a new byte was received

	output reg  [7:0] leds,         // Board leds
	output wire [7:0] sseg,         // Board 7Segment Display
	output wire [3:0] an,           // 7 Segment Display enable

	output reg  [1:NPIS] part_pis_o,  // Part interface, primary inputs
	input  wire [1:NPOS] part_pos_i   // Part interface, primary outputs
);

// Standard names for scan chain inputs
wire clk_i;
reg scan_i, scan_i_nxt;
reg reset_i;
reg test_se_i;
reg test_tm_i;
reg scan_o;

//-- Number of bits needed for storing the baudrate divisor
`include "src/functions.vh"
localparam NPIS_WIDTH = clog2(NPIS);
localparam NPOS_WIDTH = clog2(NPOS);

reg [NPIS_WIDTH:0] cont_pis, cont_pis_nxt;
reg [NPOS_WIDTH:0] cont_pos, cont_pos_nxt;

reg [1:NPOS] part_pos;
reg [1:NPIS] part_pis;

always @(posedge clk or negedge rstn) begin
	if (!rstn) begin
		part_pis_o <= 0;
		part_pos <= 0;
		//
		scan_i <= 0;
		reset_i <= 0;
		test_se_i <= 0;
		test_tm_i <= 0;
		//
		scan_o <= 0;
	end
	else begin
		part_pis_o[01] <= csoc_clk; //clk_i;
		part_pis_o[09] <= scan_i;
		part_pis_o[10] <= csoc_rstn; //reset_i;
		part_pis_o[11] <= csoc_test_se; //test_se_i;
		part_pis_o[12] <= csoc_test_tm; //test_tm_i;
		//
		part_pos <= part_pos_i;
		//
		scan_o <= part_pos_i[9];
		//
		scan_i <= scan_i_nxt;
	end
end


// Put the bitgen creation time on display as a version

localparam VERSION_SIZE = 4;
reg [7:0] version [0:VERSION_SIZE-1];

initial begin
	$readmemh("version.txt", version);
end

sevenseg ss0 (
	.clk(clk),
	.rstn(rstn),
	.display_0(version[0]),
	.display_1(version[1]),
	.display_2(version[2]),
	.display_3(version[3]),
	.decplace(2'b10),
	.seg(sseg),
	.an(an)
);

always @(posedge clk or negedge rstn) begin
	if (!rstn)
		leds <= 0;
	else
		leds <= part_pos_i[2:9]; // joga nos leds os pinos
end



reg csoc_rstn, csoc_rstn_nxt;
reg csoc_test_se, csoc_test_se_nxt;
reg csoc_test_tm, csoc_test_tm_nxt;
reg csoc_uart_read, csoc_uart_read_nxt;
reg [7:0] csoc_data_o_reg, csoc_data_o_nxt;

// CSOC CLOCK
reg csoc_clk;
reg clk_en, clk_en_nxt;
always @(posedge clk or negedge rstn) begin
	if (!rstn) begin
		csoc_clk <= 0;
	end
	else
		if (clk_en)
			csoc_clk <= ~csoc_clk;
end

assign clk_i = csoc_clk;

// Serial command parser

reg [4:0] state, state_nxt;
reg tx_start, tx_start_nxt;
reg run_done, run_done_nxt;

// TODO: REORGANIZE STATES
// MAIN_STATES
localparam
	RESET = 0,
	AVOID_MSG = 18,
	INITIAL_MESSAGE = 1,
	S1 = 2,
	S2 = 3,
	S3 = 4,
	//
	WAITING_COMMAND = 5,
	//
	SET_DUT_STATE = 6,
	SA1 = 26,
	//
	GET_DUT_STATE = 7,
	SB5 = 27,
	SB6 = 28,
	//
	EXECUTE_DUT = 8,
	SET_INPUTS_STATE = 9,
	//
	GET_OUTPUTS_STATE = 10,
	S4 = 11,
	//
	FREE_RUN_DUT = 12,
	S5 = 13,
	S11 = 14,
	S21 = 15,
	S31 = 16,
	S111 = 17,
	S1111 = 19,
	//
	SX5 = 20,
	SX11 = 21,
	SX21 = 22,
	SX31 = 23,
	SX111 = 24,
	SX1111 = 25,
	//
	PAUSE_DUT = 29;


localparam
	RESET_CMD = "r",
	SET_STATE_CMD = "s",
	GET_STATE_CMD = "g",
	SET_INPUTS_CMD = "i",
	GET_OUTPUTS_CMD = "o",
	EXECUTE_CMD = "e",
	FREE_RUN_CMD = "f",
	PAUSE_CMD = "p";


assign tx_start_o = tx_start;

localparam MSG_SIZE = 20;
reg [7:0] mgs_mem [0:MSG_SIZE-1];
reg [7:0] msg_data, msg_data_nxt;
reg [5:0] msg_addr, msg_addr_nxt;

initial begin
	$readmemh("initial_message.txt", mgs_mem);
end

reg [7:0] tx_data, tx_data_nxt;
reg [15:0] clk_count, clk_count_nxt;
reg [6:0] col_break, col_break_nxt;
reg [15:0] nclks, nclks_nxt;
reg low_byte, low_byte_nxt;

assign tx_data_o = tx_data;

always @(posedge clk or negedge rstn) begin
	if (!rstn) begin
		state <= RESET;
		tx_start <= 0;
		tx_data <= 0;
		clk_count <= 0;
		col_break <= 0;
		msg_data <= 0;
		msg_addr <= 0;
		run_done <= 0;
		clk_en <= 0;
		nclks <= 0;
		low_byte <= 0;
		//
		csoc_rstn <= 0;
		csoc_test_se <= 1;
		csoc_test_tm <= 1;
		csoc_uart_read <= 0;
		csoc_data_o_reg <= 0;
		//
		cont_pos <= 0;
		cont_pis <= 0;
	end
	else begin
		state <= state_nxt;
		tx_start <= tx_start_nxt;
		clk_count <= clk_count_nxt;
		col_break <= col_break_nxt;
		msg_data <= mgs_mem[msg_addr];
		msg_addr <= msg_addr_nxt;
		tx_data <= tx_data_nxt;
		run_done <= run_done_nxt;
		clk_en <= clk_en_nxt;
		nclks <= nclks_nxt;
		low_byte <= low_byte_nxt;
		//
		csoc_rstn <= csoc_rstn_nxt;
		csoc_test_se <= csoc_test_se_nxt;
		csoc_test_tm <= csoc_test_tm_nxt;
		csoc_uart_read <= csoc_uart_read_nxt;
		csoc_data_o_reg <= csoc_data_o_nxt;
		//
		cont_pos <= cont_pos_nxt;
		cont_pis <= cont_pis_nxt;
	end
end

always @(*) begin
	state_nxt = state;
	tx_start_nxt = tx_start;
	tx_data_nxt = tx_data;
	clk_count_nxt = clk_count;
	col_break_nxt = col_break;
	msg_addr_nxt = msg_addr;
	run_done_nxt = run_done;
	clk_en_nxt = clk_en;
	nclks_nxt = nclks;
	low_byte_nxt = low_byte;
	//
	csoc_rstn_nxt = csoc_rstn;
	csoc_test_se_nxt = csoc_test_se;
	csoc_test_tm_nxt = csoc_test_tm;
	csoc_uart_read_nxt = csoc_uart_read;
	csoc_data_o_nxt = csoc_data_o_reg;
	//
	cont_pos_nxt = cont_pos;
	cont_pis_nxt = cont_pis;
	//
	scan_i_nxt = scan_i;
	case (state)


		// ===================================================

		RESET: begin
			//
			csoc_rstn_nxt = 1;
			csoc_test_se_nxt = 1;
			csoc_test_tm_nxt = 1;
			csoc_uart_read_nxt = 0;
			csoc_data_o_nxt = 0;
			//
			msg_addr_nxt = 0;
			//
			if (SHOW_INIT_MSG)
				state_nxt = INITIAL_MESSAGE;
			else
				state_nxt = AVOID_MSG;
		end

		AVOID_MSG: begin
			state_nxt = WAITING_COMMAND;
		end


		// ===================================================

		INITIAL_MESSAGE: begin
			if (tx_ready_i) begin
				tx_start_nxt = 1;
				state_nxt = S1;
			end
		end

		S1: begin
			if (!tx_ready_i) begin
				tx_start_nxt = 0;
				state_nxt = S2;
			end
		end

		S2: begin
			if (tx_ready_i) begin
				msg_addr_nxt = msg_addr + 1;
				if (msg_addr <= MSG_SIZE) begin
					state_nxt = S3;
				end
				else begin
					msg_addr_nxt = 0;
					state_nxt = WAITING_COMMAND;
				end
			end
		end

		S3: begin
			if (msg_addr <= MSG_SIZE) begin
				tx_data_nxt = msg_data;
			end
			else begin
				tx_data_nxt = "\n";
			end
			state_nxt = INITIAL_MESSAGE;
		end


		// ===================================================

		WAITING_COMMAND: begin

			csoc_rstn_nxt = 1;
			nclks_nxt = 0;
			clk_en_nxt = 0;
			clk_count_nxt = 0;

			if(new_rx_data) begin
				case (rx_data)
					RESET_CMD:       state_nxt = RESET;              // reset the tester

					EXECUTE_CMD:     state_nxt = EXECUTE_DUT;        // start PART execution for n cycles
					FREE_RUN_CMD:    state_nxt = FREE_RUN_DUT;       // start PART execution until stop command
					PAUSE_CMD:       state_nxt = PAUSE_DUT;          // pause PART execution

					SET_STATE_CMD:   state_nxt = SET_DUT_STATE;      // set PART internal state
					GET_STATE_CMD:   state_nxt = GET_DUT_STATE;      // get PART internal state

					SET_INPUTS_CMD:  state_nxt = SET_INPUTS_STATE;   // set PART inputs
					GET_OUTPUTS_CMD: state_nxt = GET_OUTPUTS_STATE;  // get PART outputs
				endcase
			end
		end


		// ===================================================

		SET_DUT_STATE:  begin
			csoc_test_se_nxt = 1;
			csoc_test_tm_nxt = 1;
			if(new_rx_data) begin
				if (low_byte) begin
					nclks_nxt[7:0] = rx_data;
					low_byte_nxt = 0;
					state_nxt = SB5;
					//
					clk_count_nxt = 1;
					clk_en_nxt = 0;
				end
				else begin
					nclks_nxt[15:8] = rx_data;
					low_byte_nxt = 1;
				end
			end
		end

		SB5: begin
			if(new_rx_data) begin
				case (rx_data)
					"0": scan_i_nxt = 0;
					"1": scan_i_nxt = 1;
				endcase
				clk_en_nxt = 1;
				state_nxt = SB6;
			end
		end

		SB6: begin
			clk_count_nxt = clk_count + 1;
			clk_en_nxt = 0;
			if (clk_count >= nclks) begin
				clk_en_nxt = 0;
				state_nxt = WAITING_COMMAND;
			end
			else begin
				state_nxt = SB5;
			end
		end


		// ===================================================

		GET_DUT_STATE: begin
			csoc_test_se_nxt = 1;
			csoc_test_tm_nxt = 1;
			if(new_rx_data) begin
				if (low_byte) begin
					nclks_nxt[7:0] = rx_data;
					low_byte_nxt = 0;
					state_nxt = S5;
					//
					clk_count_nxt = 1;
					clk_en_nxt = 0;
				end
				else begin
					nclks_nxt[15:8] = rx_data;
					low_byte_nxt = 1;
				end
			end
		end

		S5: begin
			clk_en_nxt = 0;
			if (tx_ready_i) begin
				if (scan_o)
					tx_data_nxt = "1";
				else
					tx_data_nxt = "0";

				clk_count_nxt = clk_count + 1;
				state_nxt = S1111;
			end
		end

		S1111: begin
			tx_start_nxt = 1;
			clk_en_nxt = 1;
			state_nxt = S111;
		end

		S111: begin
			tx_start_nxt = 0;
			if(!csoc_clk) begin
				clk_en_nxt = 0;
				state_nxt = S11;
			end
		end

		S11: begin
			if (!tx_ready_i) begin
				tx_start_nxt = 0;
				state_nxt = S21;
			end
		end

		S21: begin

			// if (clk_count > nclks) begin
			// 	clk_en_nxt = 0;
			// 	clk_count_nxt = 0;
			// 	state_nxt = WAITING_COMMAND;
			// end

			if (tx_ready_i)
				if (clk_count > nclks) begin
					clk_en_nxt = 0;
					clk_count_nxt = 0;
					state_nxt = WAITING_COMMAND;
				end
				else
					state_nxt = S31;
		end

		S31: begin
			if (scan_o)
				tx_data_nxt = "1";
			else
				tx_data_nxt = "0";
			state_nxt = S5;
		end


		// ===================================================

		EXECUTE_DUT: begin
			csoc_test_se_nxt = 0;
			csoc_test_tm_nxt = 0;
			if(new_rx_data) begin
				if (low_byte) begin
					nclks_nxt[7:0] = rx_data;
					low_byte_nxt = 0;
					state_nxt = S4;
				end
				else begin
					nclks_nxt[15:8] = rx_data;
					low_byte_nxt = 1;
				end
			end
		end

		S4: begin
			clk_en_nxt = 1;
			if (csoc_clk)
				if (clk_count == nclks-1) begin
					clk_en_nxt = 0;
					state_nxt = WAITING_COMMAND;
				end
				else
					clk_count_nxt = clk_count + 1;
		end


		// ===================================================

		FREE_RUN_DUT: begin
			clk_en_nxt = 1;
			if (csoc_clk)
				clk_count_nxt = clk_count + 1;
			if(new_rx_data)
				if (rx_data == PAUSE_CMD)
					state_nxt = WAITING_COMMAND;
		end

		PAUSE_DUT: begin
			clk_en_nxt = 0;
			state_nxt = WAITING_COMMAND;
		end


		// ===================================================

		GET_OUTPUTS_STATE: begin
			clk_en_nxt = 0;
			csoc_test_se_nxt = 1;
			csoc_test_tm_nxt = 1;
			if(new_rx_data) begin
				if (low_byte) begin
					nclks_nxt[7:0] = rx_data;
					low_byte_nxt = 0;
					state_nxt = SX5;
				end
				else begin
					nclks_nxt[15:8] = rx_data;
					low_byte_nxt = 1;
				end
			end
			cont_pos_nxt = 1;
		end

		SX5: begin
			if (tx_ready_i) begin
				if (part_pos[cont_pos])
					tx_data_nxt = "1";
				else
					tx_data_nxt = "0";

				cont_pos_nxt = cont_pos + 1;
				state_nxt = SX1111;
			end
		end

		SX1111: begin
			tx_start_nxt = 1;
			state_nxt = SX111;
		end

		SX111: begin
			tx_start_nxt = 0;
			state_nxt = SX11;
		end

		SX11: begin
			if (!tx_ready_i) begin
				tx_start_nxt = 0;
				state_nxt = SX21;
			end
		end

		SX21: begin
			if (tx_ready_i)
				if (cont_pos >= nclks) begin
					state_nxt = WAITING_COMMAND;
				end
				else
					state_nxt = SX31;
		end

		SX31: begin
			if (part_pos[cont_pos])
				tx_data_nxt = "1";
			else
				tx_data_nxt = "0";
			state_nxt = SX5;
		end


		// ===================================================

		SET_INPUTS_STATE: begin
			csoc_test_se_nxt = 1;
			csoc_test_tm_nxt = 1;
			if(new_rx_data) begin
				if (low_byte) begin
					nclks_nxt[7:0] = rx_data;
					low_byte_nxt = 0;
					state_nxt = SA1;
				end
				else begin
					nclks_nxt[15:8] = rx_data;
					low_byte_nxt = 1;
				end
			end
			cont_pis_nxt = 1;
		end

		SA1: begin
			// if (csoc_clk)
				clk_en_nxt = 1;

			if(new_rx_data) begin
				case (rx_data)
					"0" : part_pis[cont_pis] = rx_data;
					"1" : part_pis[cont_pis] = rx_data;
				endcase
				clk_en_nxt = 1;
				cont_pis_nxt = cont_pis + 1;
				if (cont_pis >= nclks) begin
					clk_en_nxt = 0;
					state_nxt = WAITING_COMMAND;
				end
			end
		end

	endcase
end

endmodule
