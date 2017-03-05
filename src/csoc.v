
// Emulate CSOC Scan Chain and IOs

module csoc #(
	parameter NREGS = 1918
)(
	input        clk_i,
	input        rstn_i,
	input        uart_read_i,
	output       uart_write_o,
	input  [7:0] data_i,
	output [7:0] data_o,
	input        xtal_a_i,
	output       xtal_b_o,
	output       clk_o,
	input        test_tm_i,
	input        test_se_i
);

reg [NREGS-1:0] ffs_chain, ffs_chain_nxt;

reg uart_write, uart_write_nxt;
reg [7:0] data_or, data_or_nxt;
reg xtal_b, xtal_b_nxt;
reg clk_or, clk_or_nxt;

always @(posedge clk_i or negedge rstn_i) begin
	if (!rstn_i) begin
		uart_write <= 0;
		data_or <= 0;
		ffs_chain <= 0;
		xtal_b <= 0;
		clk_or <= 0;
	end
	else begin
		data_or <= data_or_nxt;
		uart_write <= uart_write_nxt;
		clk_or <= clk_or_nxt;
		xtal_b <= xtal_b_nxt;
		ffs_chain <= ffs_chain_nxt;
	end
end

always @(*) begin
	uart_write_nxt = uart_write;
	clk_or_nxt = clk_or;
	xtal_b_nxt = xtal_b;
	if (test_se_i) begin
		ffs_chain_nxt = {data_i[0], ffs_chain[NREGS-1:1]};
		data_or_nxt = ffs_chain[0];
	end
	else begin
		ffs_chain_nxt = ffs_chain;
		data_or_nxt = data_or;
	end
end

assign uart_write_o = uart_write;
assign data_o = data_or;
assign clk_o = xtal_a_i;
assign xtal_b_o = ~ xtal_a_i;

endmodule
