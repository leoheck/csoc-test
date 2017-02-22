
`timescale 1ns/1ns

module tb ();

parameter BAUDRATE = 9600;

reg clk;
reg rst;
wire rstn;

wire tx;

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

// 50 MHz clock
always #20 clk = !clk;

reg send;
reg [7:0] send_data;
wire rx;
wire ready;

uart_tx #(.BAUDRATE(BAUDRATE)) tx0 (
	.clk(clk),
	.rstn(rstn),
	.start(send),
	.data(send_data),
	.ready(ready),
	.tx(rx)
);

csoc_test #(.BAUDRATE(BAUDRATE)) csoc (
	.clk(clk),
	.rst(rst),
	// UART
	.rx(rx),
	.tx(tx),
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

assign rstn = ~rst;

task wait_for_idle_state;
begin
	while(csoc.cp0.state != 5) #1000;
	$display("Waiting commands");
end
endtask

localparam
	RESET_CMD = "r",
	SET_STATE_CMD = "s",
	GET_STATE_CMD = "g",
	SET_INPUTS_CMD = "e",
	GET_OUTPUTS_CMD = "i",
	EXECUTE_CMD = "o",
	FREE_RUN_CMD = "7";

task reset_csoc_test;
begin
	$display("Reseting the DUT");
	send_data = RESET_CMD;
	send = 1;
	@ (negedge ready)
	@ (posedge clk) send = 0;
end
endtask

task execute_dut;
input [15:0] cycles;
begin
	$display("Executing DUT");
	send_data = EXECUTE_CMD;
	send = 1;
	@ (negedge ready)
	@ (posedge clk) send = 0;
	@ (posedge ready)
	//
	send_data = cycles[15:8];
	send = 1;
	@ (negedge ready)
	@ (posedge clk) send = 0;
	@ (posedge ready)
	//
	send_data = cycles[7:0];
	send = 1;
	@ (negedge ready)
	@ (posedge clk) send = 0;
	// @ (posedge ready)
end
endtask

task free_run_dut;
input [15:0] cycles;
begin
end
endtask

task set_dut;
input [15:0] cmd;
input [15:0] n_regs;
input integer data;
begin
end
endtask

task get_dut;
input [15:0] cmd;
input [15:0] n_regs;
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
	// set_dut(SET_STATE_CMD, 10, "1010101010");
	// get_dut(GET_STATE_CMD, 10);
	// set_dut(SET_INPUTS_CMD, 14, "1010101010");
	// get_dut(GET_OUTPUTS_CMD, 10);
	// free_run_dut(1000);
	wait_for_idle_state;



	// $display("\t\ttime,\tclk,\trst,\tenable,\tcount");
	// $monitor("%d,\t%b,\t%b,\t%b,\t%d",$time, clk,rst,enable,count);
	#1000 $finish;

end

endmodule
