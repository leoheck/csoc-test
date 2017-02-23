
`timescale 1ns/1ns

module tb ();

parameter BAUDRATE = 9600;
localparam NREGS = 8;

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
wire csoc_data_i;

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
	DONE_CMD = "d";

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

//================================================
// Some signals
//================================================

always #20 clk = !clk; // 50 MHz clock
assign rstn = ~rst;    // active-low reset


//================================================
// SIMPLE TASKS
//================================================

task wait_for_idle_state;
begin
	while(part0.cp0.state != 5) #1000;
	$display("DUT is waiting for commands");
end
endtask

task recv_task;
integer data_ascii;
begin
	@ (posedge rcv)
	if ((data_rcv < 32) || (data_rcv > 126))
		data_ascii = " ";
	else
		data_ascii = data_rcv;
	$write("- Data received: %3d|%0c|0x%h|%b", data_rcv, data_ascii, data_rcv, data_rcv);
end
endtask

task send_task;
input [7:0] data;
integer data_ascii;
begin
	if ((data < 32) || (data > 126))
		data_ascii = " ";
	else
		data_ascii = data;
	$write("- Sending data: -------- %3d|%0c|0x%h|%b", data, data_ascii, data, data);
	send_data = data;
	send = 1;
	@ (negedge ready)
	// @ (posedge clk)
	send = 0;
	@ (posedge ready);
end
endtask

//================================================
// CSOC TASKS
//================================================

task reset_csoc_test;
begin
	$display("TASK: Reseting the DUT");
	send_task(RESET_CMD);
	$write("\n");
end
endtask

task execute_dut;
input [15:0] cycles;
begin
	$display("TASK: Executing DUT");
	send_task(EXECUTE_CMD);
	$write("\n");
	send_task(cycles[15:8]);
	$write("\n");
	send_task(cycles[7:0]);
	$write("\n");
end
endtask

task free_run_dut;
input [15:0] cycles;
begin
	$display("TASK: DUT running free");
	send_task(FREE_RUN_CMD);
	$write("\n");
	#cycles
	send_task(DONE_CMD);
	$write("\n");
	$display("- Stopped by user after %0d cycles", cycles);
	end
endtask

task get_dut;
input [7:0] cmd;
input [15:0] data_width;
integer i;
begin
	case (cmd)
		GET_STATE_CMD: $display("TASK: Getting DUT internal state");
		GET_OUTPUTS_CMD: $display("TASK: Getting DUT outputs state");
		default: begin
			$display("TASK: ERROR, missing command to get DUT state");
			$finish;
		end
	endcase
	send_task(cmd);
	$write("\n");
	send_task(data_width[15:8]);
	$write("\n");
	send_task(data_width[7:0]);
	$write("\n");
	for (i=0; i<data_width; i=i+1) begin
		$write("  %4d: ", i+1);
		recv_task;
		if (cmd == GET_OUTPUTS_CMD)
			$write("  %0s \n", part_pos_names[i+1]);
		else
			$write("\n");
	end
end
endtask

task set_dut;
input [15:0] cmd;
input [15:0] data_width;
input integer data;
integer i;
begin
	case (cmd)
		SET_STATE_CMD: $display("TASK: Setting DUT internal state");
		SET_INPUTS_CMD: $display("TASK: Setting DUT inputs state");
		default: begin
			$display("ERROR, missing command to set DUT state");
			$finish;
		end
	endcase
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
		$write(" %4d:", i+1);
		if (cmd == SET_INPUTS_CMD)
			$write(" %0s \n", part_pis_names[i+1]);
		else
			$write("\n");

	end
end
endtask


initial begin

	$display("CSoC Test Running...");
	$dumpfile("uart.vcd");
	$dumpvars(0);

	clk = 0;
	rst = 1;

	send = 0;
	send_data = 0;

	csoc_data_o = 8'b1010_1001;
	csoc_uart_write = 0;

	#70 rst = 0;
	wait_for_idle_state;

	// reset_csoc_test;
	// execute_dut(10);
	// free_run_dut(12);
	// get_dut(GET_STATE_CMD, NREGS);
	// get_dut(GET_OUTPUTS_CMD, NPOS);
	// set_dut(SET_STATE_CMD, NREGS, "10101010");
	set_dut(SET_STATE_CMD, NREGS, "10001111");
	// set_dut(SET_INPUTS_CMD, NPIS, "1010101010");

	wait_for_idle_state;
	#1000 $finish;

end

endmodule
