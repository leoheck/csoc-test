
`timescale 1ns/1ns

module tb ();

parameter BAUDRATE = 9600;

reg clk;
reg rst;
wire rstn;

// transmitter
reg send;
reg [7:0] send_data;
wire dut_rx;
wire ready;

// receiver
wire dut_tx;
wire rcv;
wire [7:0] data_rcv;

// board interface
wire [7:0] leds;
wire [7:0] sseg;
wire [3:0] an;


//================================================
// Generic pat signal names to CSOC pin names
//================================================

localparam NREGS = 10;
localparam NPIS = 14;
localparam NPOS = 11;

// Generic part signals
wire [1:NPIS] part_pis; // primary inputs (this is output here)
wire [1:NPOS] part_pos; // primary outputs (this is input here)

// CSOC Interface
wire csoc_clk;
wire csoc_rstn;
wire csoc_test_se;
wire csoc_test_tm;
wire csoc_uart_read;
wire [7:0] csoc_data_i;

reg csoc_uart_write;
reg [7:0] csoc_data_o;

// part inputs mapping
assign csoc_clk = part_pis[1];
assign csoc_data_i = part_pis[2:9];
assign csoc_rstn = part_pis[10];
assign csoc_test_se = part_pis[11];
assign csoc_test_tm = part_pis[12];
assign csoc_uart_read = part_pis[13];

// part outputs mapping
assign part_pos[1]   = 0;
assign part_pos[2:9] = csoc_data_o;
assign part_pos[10]  = csoc_uart_write;
assign part_pos[11]  = 0;

reg [8*14:1] part_pos_names [1:NPOS];
reg [8*14:1] part_pis_names [1:NPIS];

initial begin
	part_pis_names[1]  = "clk";
	part_pis_names[2]  = "data_i_0";
	part_pis_names[3]  = "data_i_1";
	part_pis_names[4]  = "data_i_2";
	part_pis_names[5]  = "data_i_3";
	part_pis_names[6]  = "data_i_4";
	part_pis_names[7]  = "data_i_5";
	part_pis_names[8]  = "data_i_6";
	part_pis_names[9]  = "data_i_7";
	part_pis_names[10] = "rstn";
	part_pis_names[11] = "test_se";
	part_pis_names[12] = "test_tm";
	part_pis_names[13] = "uart_read";
	part_pis_names[14] = "none";
	//
	part_pos_names[1]  = "none";
	part_pos_names[2]  = "data_o_0";
	part_pos_names[3]  = "data_o_1";
	part_pos_names[4]  = "data_o_2";
	part_pos_names[5]  = "data_o_3";
	part_pos_names[6]  = "data_o_4";
	part_pos_names[7]  = "data_o_5";
	part_pos_names[8]  = "data_o_6";
	part_pos_names[9]  = "data_o_7";
	part_pos_names[10] = "uart_write";
	part_pos_names[11] = "none";
end

//================================================
// DUT Commands
//================================================

localparam
	RESET_CMD = "r",
	SET_STATE_CMD = "s",
	GET_STATE_CMD = "g",
	SET_INPUTS_CMD = "i",
	GET_OUTPUTS_CMD = "o",
	EXECUTE_CMD = "e",
	FREE_RUN_CMD = "f",
	PAUSE_CMD = "p";

//================================================
// Instances
//================================================

uart_rx #(.BAUDRATE(BAUDRATE)) rx0 (
	.clk(clk),
	.rstn(rstn),
	.rx(dut_tx),
	.rcv(rcv),
	.data(data_rcv)
);

uart_tx #(.BAUDRATE(BAUDRATE)) tx0 (
	.clk(clk),
	.rstn(rstn),
	.start(send),
	.data(send_data),
	.ready(ready),
	.tx(dut_rx)
);

part_tester #(.BAUDRATE(BAUDRATE)) part0 (
	.clk(clk),
	.rst(rst),
	// UART
	.rx(dut_rx),
	.tx(dut_tx),
	// DEBUG
	.leds(leds),
	.sseg(sseg),
	.an(an),
	// PART TO TEST
	.part_pis_o(part_pis),  // CSOC primary inputs  (this is output here)
	.part_pos_i(part_pos)   // CSOC primary outputs (this is input here)
);

csoc #(.NREGS(NREGS)) csoc0 (
	.clk_i(csoc_clk),
	.rstn_i(csoc_rstn),
	.uart_read_i(csoc_uart_write),
	.uart_write_o(csoc_uart_read),
	.data_i(csoc_data_o),
	.data_o(csoc_data_i),
	.xtal_a_i(),
	.xtal_b_o(),
	.clk_o(),
	.test_tm_i(csoc_test_tm),
	.test_se_i(csoc_test_se)
);

//================================================
// Some signals
//================================================

always #20 clk = !clk; // 50 MHz clock
assign rstn = ~rst;    // active-low reset


//================================================
// SIMPLE TASKS
//================================================

task initial_message;
begin
	$display("\nTASK: Receiving initial message");
	if(data_rcv == "\n") begin
		recv_task;
		$write("\n");
	end
	while(data_rcv != "\n")
	begin
		recv_task;
		$write("\n");
	end
end
endtask

task wait_for_idle_state;
begin
	while(part0.cp0.state != 5) #1;
	// $display("\nDUT is waiting for commands");
end
endtask

task recv_task;
integer data_ascii;
begin
	@ (posedge rcv)
	if ((data_rcv < 32) || (data_rcv > 126))
		data_ascii = "_";
	else
		data_ascii = data_rcv;
	$write("- Data received: ------- %3d|%0c|0x%h|%b", data_rcv, data_ascii, data_rcv, data_rcv);
end
endtask

task send_task;
input [7:0] data;
integer data_ascii;
begin
	if ((data < 32) || (data > 126))
		data_ascii = "_";
	else
		data_ascii = data;
	$write("- Sending data: -------- %3d|%0c|0x%h|%b", data, data_ascii, data, data);
	send_data = data;
	send = 1;
	@ (negedge ready)
	@ (posedge clk)
	send = 0;
	@ (posedge ready);
end
endtask

//================================================
// CSOC TASKS
//================================================

task reset_part_test;
begin
	$display("\nTASK: Reseting the DUT");
	send_task(RESET_CMD);
	$write("\n");
	initial_message;
	wait_for_idle_state;
end
endtask

task execute_dut;
input [15:0] cycles;
begin
	$display("\nTASK: Executing DUT for %0d cycles", cycles);
	send_task(EXECUTE_CMD);
	$write("\n");
	send_task(cycles[15:8]);
	$write("\n");
	send_task(cycles[7:0]);
	$write("\n");
	wait_for_idle_state;
end
endtask

task free_run_dut;
input [15:0] cycles;
begin
	$display("\nTASK: DUT running free");
	send_task(FREE_RUN_CMD);
	$write("\n");
	#cycles
	send_task(PAUSE_CMD);
	$write("\n");
	$display("- Stopped by user after %0d cycles", cycles);
	wait_for_idle_state;
end
endtask

task get_dut;
input [7:0] cmd;
input [15:0] data_width;
integer i;
begin
	case (cmd)
		GET_STATE_CMD: $display("\nTASK: Getting DUT internal state for %0d cycles (", data_width);
		GET_OUTPUTS_CMD: $display("\nTASK: Getting DUT outputs state for %0d cycles (", data_width);
		default: begin
			$display("\nTASK: ERROR, missing command to get DUT state");
			$finish;
		end
	endcase
	// for (i=0; i<data_width; i=i+1) begin
	// 	$write("%c", data[i]);
	// end
	$write(")\n");
	send_task(cmd);
	$write("\n");
	send_task(data_width[15:8]);
	$write("\n");
	send_task(data_width[7:0]);
	$write("\n");
	for (i=0; i<data_width; i=i+1) begin
		recv_task;
		if (cmd == GET_OUTPUTS_CMD)
			$write(" %4d %0s \n", i+1, part_pos_names[i+1]);
		else
			$write("\n");
	end
	wait_for_idle_state;
end
endtask

task set_dut;
input [15:0] cmd;
input [15:0] data_width;
input integer data;
integer i;
begin
	case (cmd)
		SET_STATE_CMD: $write("\nTASK: Setting DUT internal state for %0d cycles (", data_width);
		SET_INPUTS_CMD: $write("\nTASK: Setting DUT inputs state for %0d cycles (", data_width);
		default: begin
			$display("ERROR, missing command to set DUT state");
			$finish;
		end
	endcase
	// for (i=0; i<data_width; i=i+1) begin
	// 	$write("%c", data[i]);
	// end
	$write(")\n");
	send_task(cmd);
	$write("\n");
	send_task(data_width[15:8]);
	$write("\n");
	send_task(data_width[7:0]);
	$write("\n");
	for (i=0; i<data_width; i=i+1) begin
		case (data[i])
			1: send_task("1");
			0: send_task("0");
			default: begin
				$display("ERROR, missing data");
				$finish;
			end
		endcase
		$write(" %4d", i+1);
		if (cmd == SET_INPUTS_CMD)
			$write(" %0s \n", part_pis_names[i+1]);
		else
			$write("\n");
	end
	wait_for_idle_state;
end
endtask


initial begin

	$dumpfile("uart.vcd");
	$dumpvars(0);
	$write("\nCSoC Test Running...\n");

	clk = 0;
	rst = 1;

	send = 0;
	send_data = 0;

	csoc_data_o = 8'b1010_1001;
	csoc_uart_write = 0;

	#70 rst = 0;

	initial_message;

	get_dut(GET_STATE_CMD, 5);
	execute_dut(4);
	free_run_dut(6);
	get_dut(GET_STATE_CMD, 5);
	get_dut(GET_OUTPUTS_CMD, 3);
	set_dut(SET_STATE_CMD, 4, "1011");
	set_dut(SET_INPUTS_CMD, 5, "1001");

	reset_part_test;
	set_dut(SET_STATE_CMD, 20, "10001111100011110101");
	get_dut(GET_STATE_CMD, NREGS);
	get_dut(GET_OUTPUTS_CMD, NPOS);
	execute_dut(10);
	free_run_dut(12);
	set_dut(SET_INPUTS_CMD, NPIS, "10101010101111");

	#100 $finish;
end

endmodule
