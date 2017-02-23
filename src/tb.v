
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

localparam NREGS = 19;
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


//================================================
// DUT Commands
//================================================

localparam
	RESET_CMD = "r",
	SET_STATE_CMD = "s",
	GET_STATE_CMD = "g",
	SET_INPUTS_CMD = "e",
	GET_OUTPUTS_CMD = "i",
	EXECUTE_CMD = "o",
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
	$display("- Data received: 0x%h|%0d|%0c", data_rcv, data_rcv, data_ascii);
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
	$display("- Sending data:  0x%h|%0d|%0c", data, data, data_ascii);
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
	$display("Reseting the DUT");
	send_task(RESET_CMD);
end
endtask

task execute_dut;
input [15:0] cycles;
begin
	$display("Task: Executing DUT");
	send_task(EXECUTE_CMD);
	send_task(cycles[15:8]);
	send_task(cycles[7:0]);
end
endtask

task free_run_dut;
input [15:0] cycles;
begin
	$display("Task: DUT running free");
	send_task(FREE_RUN_CMD);
	#cycles
	send_task(DONE_CMD);
	$display("- Stopped by user after %0d cycles", cycles);
	end
endtask

task get_dut;
input [7:0] cmd;
input [15:0] data_width;
integer i;
begin
	case (cmd)
		GET_STATE_CMD: $display("Task: Getting DUT internal state");
		GET_OUTPUTS_CMD: $display("Task: Getting DUT outputs state");
		default: begin
			$display("Task: ERROR, missing command to get DUT state");
			$finish;
		end
	endcase
	send_task(cmd);
	send_task(data_width[15:8]);
	send_task(data_width[7:0]);
	for (i=0; i<data_width; i=i+1) begin
		$write("  [%0d] ", i+1);
		recv_task;
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
		SET_STATE_CMD: $display("Task: Setting DUT internal state");
		SET_INPUTS_CMD: $display("Task: Setting DUT inputs state");
		default: begin
			$display("ERROR, missing command to set DUT state");
			$finish;
		end
	endcase
	send_task(cmd);
	send_task(data_width[15:8]);
	send_task(data_width[7:0]);
	for (i=0; i<data_width; i=i+1) begin
		$write("  [%0d] ", i+1);
		case (data[i])
			1: send_task("1");
			0: send_task("0");
			default: begin
				$display("ERROR, missing data");
				$finish;
			end

		endcase
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
	get_dut(GET_OUTPUTS_CMD, NPOS);
	// set_dut(SET_INPUTS_CMD, NPIS, "1010101010");
	// set_dut(SET_STATE_CMD, NREGS, "1010101010");
	// wait_for_idle_state;

	#1000 $finish;

end

endmodule
