
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

reg       clk;
reg       rstn;
reg       uart_read;
reg       uart_write, uart_write_nxt;
reg [7:0] data_ir;
reg [7:0] data_or, data_or_nxt;
reg       test_tm;
reg       test_se;

// reg    xtal_a;
// reg    xtal_b;
// reg    clk_or, clk_or_nxt;

always @(posedge clk_i or negedge rstn_i) begin
	if (!rstn_i) begin
		clk <= 0;
		rstn <= 0;
		uart_read <= 0;
		uart_write <= 0;
		data_ir <= 0;
		data_or <= 0;
		// xtal_a <= 0;
		// xtal_b <= 0;
		// clk_or <= 0;
		test_tm <= 0;
		test_se <= 0;
		//
		ffs_chain <= 0;
	end
	else begin
		clk <= clk_i;
		rstn <= rstn_i;
		uart_read <= uart_read_i;
		data_ir <= data_i;
		// xtal_a <= xtal_a_i;
		test_tm <= test_tm_i;
		test_se <= test_se_i;
		//
		data_or <= data_or_nxt;
		uart_write <= uart_write_nxt;
		// clk_or <= clk_or_nxt;
		//
		ffs_chain <= ffs_chain_nxt;
	end
end

always @(*) begin
	data_or_nxt = data_or;
	uart_write_nxt = uart_write;
	// clk_or_nxt = clk_or;
	//
	if (test_se_i) begin
		ffs_chain_nxt[0] = data_i[0];
		ffs_chain_nxt = ffs_chain[NREGS-2:1];
	end
	else begin
		ffs_chain_nxt = ffs_chain;
	end
end

assign uart_write_o = uart_write;
assign data_o = data_or;


assign clk_o = xtal_a_i;
assign xtal_b_o = ~ xtal_a_i;

endmodule
