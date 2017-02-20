
module cmd_parser
(
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





// #=====================================================================================================
// #=====================================================================================================
// #=====================================================================================================
// #=====================================================================================================

reg [3:0] state, state_nxt;
reg tx_start, tx_start_nxt;
reg run_done, run_done_nxt;

localparam
	INIT_STATE = 0,
	WAIT_1 = 5,
	WAIT_2 = 6,
	WAIT_3 = 7,
	WAIT_4 = 8,
	WAIT_5 = 9,
	WAIT_6 = 10,
	WAIT_7 = 11,
	WAIT_8 = 12,
	WAIT_9 = 13,
	INITIAL_MESSAGE = 1,
	GET_INTERNAL_STATE = 2,
	CSOC_RUN = 3,
	PROCEDURE_DONE = 4;

assign tx_start_o = tx_start;

localparam MSG_SIZE = 28;
reg [7:0] mgs_mem [0:MSG_SIZE-1];
reg [7:0] msg_data, msg_data_nxt;
reg [5:0] msg_addr, msg_addr_nxt;

initial begin
	$readmemh("initial_message.txt", mgs_mem);
end

localparam CSOC_NREGS = 1919; // Number of registers in CSOC chain (1919)
localparam RUN_CLKS = 10;   // Number of clock cycles for CSOC run
localparam MAX_COLS = 70;   // Maximum number of columns for Serial TX

reg [7:0] tx_data, tx_data_nxt;
reg [11:0] clk_count, clk_count_nxt;
reg [6:0] col_break, col_break_nxt;
reg csoc_clk, csoc_clk_nxt;

assign tx_data_o = tx_data;
assign csoc_clk_o = csoc_clk;

always @(posedge clk or negedge rstn) begin
	if (!rstn) begin
		state <= INIT_STATE;
		tx_start <= 0;
		// tx_data <= 8'bz;
		tx_data <= "\n";
		clk_count <= 0;
		col_break <= 0;
		msg_data <= 0;
		msg_addr <= 0;
		csoc_clk <= 0;
		run_done <= 0;
	end
	else begin
		state <= state_nxt;
		tx_start <= tx_start_nxt;
		clk_count <= clk_count_nxt;
		col_break <= col_break_nxt;
		msg_data <= mgs_mem[msg_addr];
		msg_addr <= msg_addr_nxt;
		tx_data <= tx_data_nxt;
		csoc_clk <= csoc_clk_nxt;
		run_done <= run_done_nxt;
	end
end

always @(*) begin
	state_nxt = state;
	tx_start_nxt = tx_start;
	tx_data_nxt = tx_data;
	clk_count_nxt = clk_count;
	col_break_nxt = col_break;
	msg_addr_nxt = msg_addr;
	csoc_clk_nxt = csoc_clk;
	run_done_nxt = run_done;
	case (state)

		INIT_STATE: begin
			run_done_nxt = 0;
			tx_start_nxt = 0;
			state_nxt = WAIT_1;
		end

		WAIT_1: begin
			state_nxt = WAIT_2;
		end
		WAIT_2: begin
			state_nxt = WAIT_3;
		end
		WAIT_3: begin
			state_nxt = WAIT_4;
		end
		WAIT_4: begin
			tx_start_nxt = 1;
			state_nxt = WAIT_5;
		end
		WAIT_5: begin
			state_nxt = WAIT_6;
		end

		WAIT_6: state_nxt = WAIT_7;
		WAIT_7: state_nxt = WAIT_8;
		WAIT_8: state_nxt = WAIT_9;
		WAIT_9: state_nxt = INITIAL_MESSAGE;


		// Envia a mensagem inicial e o menu
		// Fica neste estado ate toda mesnagem ser enviada

		INITIAL_MESSAGE: begin
			if (tx_ready_i) begin
				tx_start_nxt = 1;
				msg_addr_nxt = msg_addr + 1;
				tx_data_nxt = msg_data;
				if (msg_addr >= MSG_SIZE-1) begin
					tx_data_nxt = "\n";
					state_nxt = GET_INTERNAL_STATE;
				end
			end
		end

		GET_INTERNAL_STATE: begin


			if (tx_ready_i) begin
				if (col_break >= MAX_COLS-1) begin
					col_break_nxt = 0;
					tx_data_nxt = "\n";
				end
				else begin
					clk_count_nxt = clk_count + 1;
					col_break_nxt = col_break + 1;
					case (csoc_data_i[7])
						1'b0: tx_data_nxt = "0";
						1'b1: tx_data_nxt = "1";
					endcase
				end
			end

			if (clk_count > CSOC_NREGS) begin
				clk_count_nxt = 0;
				col_break_nxt = 0;
				if (run_done) begin
					state_nxt = PROCEDURE_DONE;
				end
				else begin
					tx_start_nxt = 0;
					state_nxt = CSOC_RUN;
				end
			end
		end

		CSOC_RUN: begin
			if (csoc_clk) begin
				clk_count_nxt = clk_count + 1;
			end
			if (clk_count > RUN_CLKS) begin
				run_done_nxt = 1;
				state_nxt = GET_INTERNAL_STATE;
			end
		end

	endcase
end

endmodule
