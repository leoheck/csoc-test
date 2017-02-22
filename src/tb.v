
// `timescale 1ns/100ps
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

	#86000000


	// ROTINA DE EXECUCAO DO CSOC

	send_data = "e";
	send = 1;
	@ (negedge ready)
	@ (posedge clk) send = 0;
	@ (posedge ready)

	send_data = 8'h00;
	send = 1;
	@ (negedge ready)
	@ (posedge clk) send = 0;
	@ (posedge ready)

	send_data = 8'h8;
	send = 1;
	@ (negedge ready)
	@ (posedge clk) send = 0;
	@ (posedge ready)


	// $display("\t\ttime,\tclk,\trst,\tenable,\tcount");
	// $monitor("%d,\t%b,\t%b,\t%b,\t%d",$time, clk,rst,enable,count);

	#20000000 $finish;

end

endmodule
