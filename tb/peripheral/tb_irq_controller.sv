`timescale 1ns/1ps
module tb_irq_controller;
    logic pclk, rst_n;
    logic [31:0] paddr, pwdata;
    logic psel, penable, pwrite;
    wire [31:0] prdata;
    wire pready, pslverr;
    logic timer_src, dma_src, uart_src;
    wire cpu_timer_irq, cpu_external_irq;
    logic [31:0] rdata;
    logic err;

    irq_controller dut(
        .clk(pclk), .rst_n(rst_n), .paddr(paddr), .psel(psel), .penable(penable),
        .pwrite(pwrite), .pwdata(pwdata), .prdata(prdata), .pready(pready),
        .pslverr(pslverr), .timer_src(timer_src), .dma_src(dma_src),
        .uart_src(uart_src), .cpu_timer_irq(cpu_timer_irq),
        .cpu_external_irq(cpu_external_irq)
    );

    always #5 pclk=~pclk;
    `include "apb_tasks.svh"

    initial begin
        pclk=0; rst_n=0; timer_src=0; dma_src=0; uart_src=0; apb_idle();
        repeat(2) @(posedge pclk); rst_n=1;
        apb_write(32'h4000_7000, 32'h7, err);
        if (err) $fatal(1, "IRQ enable write failed");
        dma_src=1; @(posedge pclk); #1;
        if (!cpu_external_irq) $fatal(1, "DMA source did not reach external IRQ");
        apb_read(32'h4000_7004, rdata, err);
        if (err || rdata[1] !== 1'b1) $fatal(1, "DMA pending mismatch: %h", rdata);
        dma_src=0;
        apb_write(32'h4000_7008, 32'h2, err);
        @(posedge pclk); #1;
        if (cpu_external_irq) $fatal(1, "DMA pending clear failed pending=%h enable=%h", dut.pending_q, dut.enable_q);
        timer_src=1; @(posedge pclk); #1;
        if (!cpu_timer_irq) $fatal(1, "timer source did not reach timer IRQ");
        apb_write(32'h4000_7000, 32'h0, err);
        if (err || cpu_timer_irq) $fatal(1, "IRQ enable mask failed");
        apb_read(32'h4000_7010, rdata, err);
        if (!err) $fatal(1, "invalid IRQ offset did not error");
        $display("PASS tb_irq_controller");
        $finish;
    end
endmodule
