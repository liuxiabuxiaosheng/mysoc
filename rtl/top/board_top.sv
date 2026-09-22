module board_top (
    input  wire       clk_50m,
    input  wire       rst_n,
    input  wire       uart_rx,
    output wire       uart_tx,
    output wire [0:0] led
);
    wire phase1_ready;

    soc_top #(
        .INTERNAL_CPU(1'b1)
    ) u_soc (
        .clk_50m(clk_50m), .rst_n(rst_n), .uart_rx(uart_rx), .gpio_in(8'd0),
        .uart_tx(uart_tx), .gpio_out(), .gpio_dir(), .timer_irq(),
        .phase1_ready(phase1_ready),
        .cpu_req_valid(1'b0), .cpu_req_write(1'b0), .cpu_req_addr(32'd0),
        .cpu_req_wdata(32'd0), .cpu_req_wstrb(4'd0), .cpu_resp_rdata(),
        .cpu_resp_ready(), .cpu_resp_error(), .cpu_halted(), .cpu_fault_code(),
        .audio_clk(1'b0), .audio_rst_n(1'b0), .i2s_bclk(1'b0),
        .i2s_lrclk(1'b0), .i2s_sdata_in(1'b0), .i2s_sdata_out()
    );

    defparam u_soc.u_onchip_ram.INIT_FILE = "firmware/hello_uart.hex";

    assign led[0] = phase1_ready;
endmodule
