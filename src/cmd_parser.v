
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

	// CSOC interface
	output wire       csoc_clk_o,
	output wire       csoc_rstn_o,
	output wire       csoc_test_se_o,    // Scan Enable
	output wire       csoc_test_tm_o,    // Test Mode
	input  wire       csoc_uart_write_i,
	output wire       csoc_uart_read_o,
	input  wire [7:0] csoc_data_i,
	output wire [7:0] csoc_data_o

	// Mudar a interface do CSOC pra esses nomes, como no TB do Cadence Encounter Test
	// output [1:14] PIs; // Primary input
	// input  [1:11] POs; // Primary outputs
);

// ORIGINAL NAMES
reg [1:14] pis, pis_nxt; // Primary input
reg [1:11] pos, pos_nxt; // Primary outputs

// FROM CADENCE ET TESTBENCH
// part_PIs[0001] // pinName = clk_i;
// part_PIs[0010] // pinName = reset_i;
// part_PIs[0013] // pinName = uart_read_i;
// part_POs[0010] // pinName = uart_write_o;
// part_PIs[0009] // pinName = data_i[7];
// part_PIs[0008] // pinName = data_i[6];
// part_PIs[0007] // pinName = data_i[5];
// part_PIs[0006] // pinName = data_i[4];
// part_PIs[0005] // pinName = data_i[3];
// part_PIs[0004] // pinName = data_i[2];
// part_PIs[0003] // pinName = data_i[1];
// part_PIs[0002] // pinName = data_i[0];
// part_POs[0009] // pinName = data_o[7];
// part_POs[0008] // pinName = data_o[6];
// part_POs[0007] // pinName = data_o[5];
// part_POs[0006] // pinName = data_o[4];
// part_POs[0005] // pinName = data_o[3];
// part_POs[0004] // pinName = data_o[2];
// part_POs[0003] // pinName = data_o[1];
// part_POs[0002] // pinName = data_o[0];
// part_PIs[0014] // pinName = xtal_a_i;
// part_POs[0011] // pinName = xtal_b_o;
// part_POs[0001] // pinName = clk_o;
// part_PIs[0012] // pinName = test_t
// part_PIs[0011] // pinName = test_se_i;

// TEST PINS
// test_tm_i 	test_function= +TI; 	# test_mode
// reset_i 	    test_function= +SC; 	# test_mode
// test_se_i 	test_function= +SE; 	# shift_enable
// clk_i 	    test_function= -ES;
// data_i[7] 	test_function= SI0;
// data_o[7] 	test_function= SO0;


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


// Serial command parser

reg [3:0] state, state_nxt;
reg tx_start, tx_start_nxt;
reg run_done, run_done_nxt;

// MAIN_STATES
localparam
	RESET = 0,
	INITIAL_MESSAGE = 1,
	S1 = 2,
	S2 = 3,
	S3 = 4,
	WAITING_COMMAND = 5,
	SET_DUT_STATE = 6,
	GET_DUT_STATE = 7,
	EXECUTE_DUT = 8,
	SET_DUT_INPUTS = 9,
	GET_DUT_OUTPUTS = 10,
	S4 = 11,
	FREE_RUN_DUT = 12;

localparam
	RESET_CMD = "r",
	SET_STATE_CMD = "s",
	GET_STATE_CMD = "g",
	SET_INPUTS_CMD = "e",
	GET_OUTPUTS_CMD = "i",
	EXECUTE_CMD = "o",
	FREE_RUN_CMD = "7";

assign tx_start_o = tx_start;

assign csoc_clk_o = csoc_clk;
assign csoc_rstn_o = csoc_rstn;
assign csoc_test_se_o = csoc_test_se;
assign csoc_test_tm_o = csoc_test_tm;
assign csoc_uart_read_o = csoc_uart_read;
assign csoc_data_o = csoc_data_o_reg;

localparam MSG_SIZE = 20;
reg [7:0] mgs_mem [0:MSG_SIZE-1];
reg [7:0] msg_data, msg_data_nxt;
reg [5:0] msg_addr, msg_addr_nxt;

initial begin
	$readmemh("initial_message.txt", mgs_mem);
end

localparam CSOC_NREGS = 1919; // Number of registers in CSOC chain (1919)
localparam MAX_COLS = 70;     // Maximum number of columns for Serial TX
localparam RUN_CLKS = 10;     // Number of clock cycles for CSOC run

reg [7:0] tx_data, tx_data_nxt;
reg [11:0] clk_count, clk_count_nxt;
reg [6:0] col_break, col_break_nxt;
reg [15:0] nclks, nclks_nxt;
reg times, times_nxt;

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
		times <= 0;
		//
		csoc_rstn <= 0;
		csoc_test_se <= 1;
		csoc_test_tm <= 1;
		csoc_uart_read <= 0;
		csoc_data_o_reg <= 0;
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
		times <= times_nxt;
		//
		csoc_rstn <= csoc_rstn_nxt;
		csoc_test_se <= csoc_test_se_nxt;
		csoc_test_tm <= csoc_test_tm_nxt;
		csoc_uart_read <= csoc_uart_read_nxt;
		csoc_data_o_reg <= csoc_data_o_nxt;
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
	times_nxt = times;
	//
	csoc_rstn_nxt = csoc_rstn;
	csoc_test_se_nxt = csoc_test_se;
	csoc_test_tm_nxt = csoc_test_tm;
	csoc_uart_read_nxt = csoc_uart_read;
	csoc_data_o_nxt = csoc_data_o;
	case (state)

		// DESCRIPTION
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
			state_nxt = INITIAL_MESSAGE;
		end


		// Initial Mesasge states
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

		// Atualiza os dados pra saida
		S3: begin

			if (msg_addr <= MSG_SIZE) begin
				tx_data_nxt = msg_data;
			end
			else begin
				tx_data_nxt = "\n";
			end

			state_nxt = INITIAL_MESSAGE;
		end


		// Wait for commands
		// ===================================================

		WAITING_COMMAND: begin
			if(new_rx_data) begin
				case (rx_data)
					RESET_CMD:       state_nxt = RESET;            // (ok) reset
					SET_STATE_CMD:   state_nxt = SET_DUT_STATE;    // (  ) set the scan chain
					GET_STATE_CMD:   state_nxt = GET_DUT_STATE;    // (  ) get the scan chain
					EXECUTE_CMD:     state_nxt = EXECUTE_DUT;      // (ok) start DUT execution for n cycles
					FREE_RUN_CMD:    state_nxt = FREE_RUN_DUT;     // (ok) start DUT execution until stop command
					SET_INPUTS_CMD:  state_nxt = SET_DUT_INPUTS;   // (  ) set DUT inputs
					GET_OUTPUTS_CMD: state_nxt = GET_DUT_OUTPUTS;  // (  ) get DUT outputs
				endcase
			end
		end


		// DESCRIPTION
		// ===================================================

		SET_DUT_STATE: begin
			// if(new_rx_data) begin
			// end
		end

		// DESCRIPTION
		// ===================================================

		GET_DUT_STATE: begin
			// if(new_rx_data) begin
			// end
		end

		// DESCRIPTION
		// ===================================================

		EXECUTE_DUT: begin
			csoc_rstn_nxt = 1;
			csoc_test_se_nxt = 0;
			csoc_test_tm_nxt = 0;
			csoc_uart_read_nxt = 0;
			csoc_data_o_nxt = 0;
			if(new_rx_data) begin
				if (times) begin
					nclks_nxt[7:0] = rx_data;
					times_nxt = 0;
					state_nxt = S4;
				end
				else begin
					nclks_nxt[15:8] = rx_data;
					times_nxt = 1;
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


		// DESCRIPTION
		// ===================================================

		SET_DUT_INPUTS: begin
			// if(new_rx_data) begin
			// end
		end

		// DESCRIPTION
		// ===================================================

		GET_DUT_OUTPUTS: begin
			// if(new_rx_data) begin
			// end
		end

	endcase
end

endmodule
