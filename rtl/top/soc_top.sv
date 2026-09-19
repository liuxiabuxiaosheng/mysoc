module soc_top(
    input  wire       clk_50m,
    input  wire       rst_n,
    input  wire       uart_rx,
    input  wire [7:0] gpio_in,

    output wire       uart_tx,
    output wire [7:0] gpio_out,
    output wire [7:0] gpio_dir,
    output wire       timer_irq,
    output wire       phase1_ready
);

wire rst_sync;
wire clk_sys;
wire locked;

wire [31:0] idle_prdata;
wire        idle_pready;
wire        idle_pslverr;

reset_sync u_reset(
    .clk(clk_50m),
    .rst_n(rst_n),
    .rst_sync(rst_sync)
);

clk_gen u_clk(
    .clk_in(clk_50m),
    .rst_n(rst_sync),
    .clk_sys(clk_sys),
    .locked(locked)
);

apb_subsystem u_apb_subsystem (
    .clk(clk_sys),
    .rst_n(rst_sync),
    .m_paddr(32'h0000_0000),
    .m_psel(1'b0),
    .m_penable(1'b0),
    .m_pwrite(1'b0),
    .m_pwdata(32'h0000_0000),
    .m_prdata(idle_prdata),
    .m_pready(idle_pready),
    .m_pslverr(idle_pslverr),
    .gpio_in(gpio_in),
    .gpio_out(gpio_out),
    .gpio_dir(gpio_dir),
    .timer_irq(timer_irq),
    .uart_rx(uart_rx),
    .uart_tx(uart_tx)
);

assign phase1_ready = locked && rst_sync;

endmodule
