module clk_gen(

input wire clk_in,
input wire rst_n,
output wire clk_sys,
output wire locked
);

assign clk_sys = clk_in;
assign locked = rst_n;
endmodule
