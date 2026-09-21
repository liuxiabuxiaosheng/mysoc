`timescale 1ns/1ps
module tb_uart_irq;
    logic pclk, presetn;
    logic [31:0] paddr, pwdata;
    logic psel, penable, pwrite;
    wire [31:0] prdata;
    wire pready, pslverr;
    logic tx_fifo_empty, tx_fifo_full, rx_fifo_empty, rx_fifo_full;
    logic [7:0] rx_fifo_rd_data;
    logic frame_error_set, overflow_set;
    wire tx_fifo_wr_en, rx_fifo_rd_en, tx_enable, rx_enable, irq;
    wire [7:0] tx_fifo_wr_data;
    wire [31:0] baud_div;
    logic err;

    uart_regs dut(
        .pclk(pclk), .presetn(presetn), .paddr(paddr), .psel(psel), .penable(penable),
        .pwrite(pwrite), .pwdata(pwdata), .prdata(prdata), .pready(pready), .pslverr(pslverr),
        .tx_fifo_empty(tx_fifo_empty), .tx_fifo_full(tx_fifo_full), .tx_fifo_wr_en(tx_fifo_wr_en),
        .tx_fifo_wr_data(tx_fifo_wr_data), .rx_fifo_empty(rx_fifo_empty), .rx_fifo_full(rx_fifo_full),
        .rx_fifo_rd_en(rx_fifo_rd_en), .rx_fifo_rd_data(rx_fifo_rd_data),
        .frame_error_set(frame_error_set), .overflow_set(overflow_set),
        .tx_enable(tx_enable), .rx_enable(rx_enable), .baud_div(baud_div), .irq(irq)
    );
    always #5 pclk=~pclk;
    `include "apb_tasks.svh"

    initial begin
        pclk=0; presetn=0; tx_fifo_empty=1; tx_fifo_full=0; rx_fifo_empty=1; rx_fifo_full=0;
        rx_fifo_rd_data=0; frame_error_set=0; overflow_set=0; apb_idle();
        repeat(2) @(posedge pclk); presetn=1;
        apb_write(32'h4000_2008, 32'h7, err);
        if (err || !tx_enable || !rx_enable) $fatal(1, "UART enable setup failed");
        rx_fifo_empty=0; #1;
        if (!irq) $fatal(1, "RX data did not assert UART IRQ");
        rx_fifo_empty=1; frame_error_set=1; @(posedge pclk); #1; frame_error_set=0;
        if (!irq) $fatal(1, "frame error did not assert UART IRQ");
        apb_write(32'h4000_2008, 32'h107, err);
        if (err || irq) $fatal(1, "UART IRQ error clear failed");
        $display("PASS tb_uart_irq");
        $finish;
    end
endmodule
