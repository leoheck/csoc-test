
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

wire csoc_clk;
wire csoc_rstn;
wire csoc_test_se;
wire csoc_test_tm;
reg csoc_uart_write;
wire csoc_uart_read;
reg [7:0] csoc_data_i;
wire [7:0] csoc_data_o;

localparam
	RESET_CMD = "r",
	SET_STATE_CMD = "s",
	GET_STATE_CMD = "g",
	SET_INPUTS_CMD = "e",
	GET_OUTPUTS_CMD = "i",
	EXECUTE_CMD = "o",
	FREE_RUN_CMD = "f",
	DONE_CMD = "d";


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

csoc_test #(.BAUDRATE(BAUDRATE)) csoc (
	.clk(clk),
	.rst(rst),
	// UART
	.rx(dut_rx),
	.tx(dut_tx),
	// DEBUG
	.leds(leds),
	.sseg(sseg),
	.an(an),
	// CSoC
	.csoc_clk(csoc_clk),
	.csoc_rstn(csoc_rstn),
	.csoc_test_se(csoc_test_se),
	.csoc_test_tm(csoc_test_tm),
	.csoc_uart_write(csoc_uart_write),
	.csoc_uart_read(csoc_uart_read),
	.csoc_data_i(csoc_data_i),
	.csoc_data_o(csoc_data_o)
);


// 50 MHz clock
always #20 clk = !clk;

assign rstn = ~rst;


//================================================
// SIMPLE TASKS
//================================================

task wait_for_idle_state;
begin
	while(csoc.cp0.state != 5) #1000;
	$display("DUT is waiting for commands");
end
endtask

task recv_task;
begin
	// $display("- Receiving data");
	@ (posedge rcv)
	$display("- Data received: 0x%h|%0d", data_rcv, data_rcv);
end
endtask

task send_task;
input [7:0] data;
begin
	$display("- Sending data:  0x%h|%0d", data, data);
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
begin
	case (cmd)
		GET_STATE_CMD: $display("Task: Getting DUT state");
		GET_OUTPUTS_CMD: $display("Task: Getting DUT outputs state");
		default: begin
			$display("Task: ERROR, missing command to get DUT state");
			$finish;
		end
	endcase
	send_task(cmd);
	send_task(data_width[15:8]);
	send_task(data_width[7:0]);
	repeat (data_width)
		recv_task;
end
endtask

task set_dut;
input [15:0] cmd;
input [15:0] n_regs;
input integer data;
begin
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

	csoc_uart_write = 0;
	csoc_data_i = 0;

	#70 rst = 0;

	wait_for_idle_state;
	// reset_csoc_test;
	// execute_dut(20);
	// free_run_dut(12);
	get_dut(GET_STATE_CMD, 13);
	// get_dut(GET_OUTPUTS_CMD, 10);
	// set_dut(SET_INPUTS_CMD, 14, "1010101010");
	// set_dut(SET_STATE_CMD, 10, "1010101010");
	wait_for_idle_state;

	// $monitor("%d,\t%b,\t%b,\t%b,\t%d",$time, clk,rst,enable,count);
	#1000 $finish;

end

endmodule
