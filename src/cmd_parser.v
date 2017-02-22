
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
	output reg        csoc_rstn_o,
	output reg        csoc_test_se_o,    // Scan Enable
	output reg        csoc_test_tm_o,    // Test Mode
	input  wire       csoc_uart_write_i,
	output reg        csoc_uart_read_o,
	input  wire [7:0] csoc_data_i,
	output wire [7:0] csoc_data_o

	// Mudar a interface do CSOC pra esses nomes, como no TB do Cadence Encounter Test
	// output [1:14] PIs; // Primary input
	// input  [1:11] POs; // Primary outputs
);

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


// CSOC CLOCK
reg dut_clk;
reg clk_en, clk_en_nxt;
always @(posedge clk or negedge rstn) begin
	if (!rstn) begin
		dut_clk <= 0;
	end
	else
		if (clk_en)
			dut_clk <= ~dut_clk;
end


// Serial command parser

reg [3:0] state, state_nxt;
reg tx_start, tx_start_nxt;
reg run_done, run_done_nxt;

// MAIN_STATES
localparam
	INITIAL_MESSAGE = 0,
	S1 = 1,
	S2 = 2,
	S3 = 3,
	WAITING_COMMAND = 4,
	SET_DUT_STATE = 5,
	GET_DUT_STATE = 6,
	EXECUTE_DUT = 7,
	SET_DUT_INPUTS = 8,
	GET_DUT_OUTPUTS = 9,
	S4 = 10;

assign tx_start_o = tx_start;
assign csoc_clk_o = dut_clk;

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
reg [0:15] nclks, nclks_nxt;
reg times, times_nxt;

assign tx_data_o = tx_data;

always @(posedge clk or negedge rstn) begin
	if (!rstn) begin
		state <= INITIAL_MESSAGE;
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
	case (state)

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
				else

					state_nxt = WAITING_COMMAND;
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
					"r": state_nxt = INITIAL_MESSAGE;  // reset
					"s": state_nxt = SET_DUT_STATE;    // set the scan chain
					"g": state_nxt = GET_DUT_STATE;    // get the scan chain
					"e": state_nxt = EXECUTE_DUT;      // start DUT execution
					"i": state_nxt = SET_DUT_INPUTS;   // set DUT inputs
					"o": state_nxt = GET_DUT_OUTPUTS;  // get DUT outputs
				endcase
			end
		end


		// Wait for commands
		// ===================================================

		SET_DUT_STATE: begin
			// if(new_rx_data) begin
			// end
		end

		// Wait for commands
		// ===================================================

		GET_DUT_STATE: begin
			// if(new_rx_data) begin
			// end
		end


		EXECUTE_DUT: begin
			if(new_rx_data) begin
				if (times) begin
					nclks_nxt[8:15] = rx_data;
					times_nxt = 0;
					state_nxt = S4;
				end
				else begin
					nclks_nxt[0:7] = rx_data;
					times_nxt = 1;
				end
			end
		end

		S4: begin
			clk_en_nxt = 1;
			if (dut_clk)
				if (clk_count == nclks-1) begin
					clk_en_nxt = 0;
					state_nxt = WAITING_COMMAND;
				end
				else
					clk_count_nxt = clk_count + 1;
		end


		// Wait for commands
		// ===================================================

		SET_DUT_INPUTS: begin
			// if(new_rx_data) begin
			// end
		end

		// Wait for commands
		// ===================================================

		GET_DUT_OUTPUTS: begin
			// if(new_rx_data) begin
			// end
		end

	endcase
end

endmodule
