module soc_top(
    input wire clk,
    input wire rst_n

);

wire rst_sync;
reset_sync u_reset(
  .clk(clk),
  .rst_n(rst_n),
  .rst_sync(rst_sync)
);

wire clk_sys;
wire locked;

clk_gen u_clk(
  .clk_in(clk),
  .rst_n(rst_sync),
  .clk_sys(clk_sys),
  .locked(locked)
);

endmodule
