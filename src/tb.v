
`timescale 1ns/100ps

module tb ();

reg rst;
reg clk;

wire tx;
reg rx;

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

csoc_test csoc (
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

initial begin

	$display("UART Running...");
	$dumpfile("uart.vcd");
	// $dumpvars(0);
	$dumpvars(0, csoc);

	clk = 0;
	rst = 1;

	rx = 0;
	csoc_uart_write = 0;
	csoc_data_i = 0;

	#70 rst = 0;

	// $display("\t\ttime,\tclk,\trst,\tenable,\tcount");
	// $monitor("%d,\t%b,\t%b,\t%b,\t%d",$time, clk,rst,enable,count);

	#100000000  $finish;
end

endmodule
