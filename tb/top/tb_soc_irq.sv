`timescale 1ns/1ps
module tb_soc_irq;
    logic pclk, rst_n;
    logic [31:0] paddr, pwdata;
    logic psel, penable, pwrite;
    wire [31:0] prdata;
    wire pready, pslverr;
    wire [7:0] gpio_out, gpio_dir;
    logic [7:0] gpio_in;
    logic uart_rx;
    wire uart_tx, timer_irq, cpu_timer_irq, cpu_external_irq;
    wire dma_mem_req_valid, dma_mem_req_write;
    wire [31:0] dma_mem_req_addr, dma_mem_req_wdata;
    wire [3:0] dma_mem_req_wstrb;
    logic [31:0] dma_mem_resp_rdata;
    logic dma_mem_resp_ready, dma_mem_resp_error;
    wire dma_fifo_in_valid, dma_fifo_out_ready;
    wire signed [15:0] dma_fifo_in_data;
    logic dma_fifo_in_ready, dma_fifo_out_valid;
    logic signed [15:0] dma_fifo_out_data;
    wire audio_enable, audio_bypass, audio_clear_state, audio_coeff_we;
    wire [3:0] audio_coeff_index;
    wire signed [15:0] audio_coeff_data;
    wire [5:0] audio_status_clear;
    logic [5:0] audio_status;
    logic [31:0] audio_sample_count;
    logic signed [15:0] audio_last_output;
    logic err;

    apb_subsystem dut(
        .clk(pclk), .rst_n(rst_n), .m_paddr(paddr), .m_psel(psel), .m_penable(penable),
        .m_pwrite(pwrite), .m_pwdata(pwdata), .m_prdata(prdata), .m_pready(pready),
        .m_pslverr(pslverr), .gpio_in(gpio_in), .gpio_out(gpio_out), .gpio_dir(gpio_dir),
        .timer_irq(timer_irq), .cpu_timer_irq(cpu_timer_irq), .cpu_external_irq(cpu_external_irq),
        .uart_rx(uart_rx), .uart_tx(uart_tx), .dma_mem_req_valid(dma_mem_req_valid),
        .dma_mem_req_write(dma_mem_req_write), .dma_mem_req_addr(dma_mem_req_addr),
        .dma_mem_req_wdata(dma_mem_req_wdata), .dma_mem_req_wstrb(dma_mem_req_wstrb),
        .dma_mem_resp_rdata(dma_mem_resp_rdata), .dma_mem_resp_ready(dma_mem_resp_ready),
        .dma_mem_resp_error(dma_mem_resp_error), .dma_fifo_in_valid(dma_fifo_in_valid),
        .dma_fifo_in_data(dma_fifo_in_data), .dma_fifo_in_ready(dma_fifo_in_ready),
        .dma_fifo_out_ready(dma_fifo_out_ready), .dma_fifo_out_valid(dma_fifo_out_valid),
        .dma_fifo_out_data(dma_fifo_out_data), .audio_enable(audio_enable), .audio_bypass(audio_bypass),
        .audio_clear_state(audio_clear_state), .audio_coeff_we(audio_coeff_we),
        .audio_coeff_index(audio_coeff_index), .audio_coeff_data(audio_coeff_data),
        .audio_status_clear(audio_status_clear), .audio_status(audio_status),
        .audio_sample_count(audio_sample_count), .audio_last_output(audio_last_output)
    );
    always #5 pclk=~pclk;
    `include "apb_tasks.svh"
    initial begin
        pclk=0; rst_n=0; paddr=0; pwdata=0; psel=0; penable=0; pwrite=0;
        gpio_in=0; uart_rx=1; dma_mem_resp_rdata=0; dma_mem_resp_ready=0; dma_mem_resp_error=0;
        dma_fifo_in_ready=1; dma_fifo_out_valid=0; dma_fifo_out_data=0; audio_status=0;
        audio_sample_count=0; audio_last_output=0; apb_idle();
        repeat(2) @(posedge pclk); rst_n=1;
        apb_write(32'h4000_7000, 32'h1, err);
        apb_write(32'h4000_1008, 32'd2, err);
        apb_write(32'h4000_1000, 32'h1, err);
        repeat(3) @(posedge pclk); #1;
        if (!timer_irq || !cpu_timer_irq) $fatal(1, "Timer IRQ did not reach CPU path timer=%b cpu=%b enable=%b pending=%b", timer_irq, cpu_timer_irq, dut.u_irq_controller.enable_q, dut.u_irq_controller.pending_q);
        apb_read(32'h4000_7004, paddr, err);
        if (err || paddr[0] !== 1'b1) $fatal(1, "IRQ pending register mismatch: %h", paddr);
        apb_write(32'h4000_100c, 32'h1, err);
        apb_write(32'h4000_7008, 32'h1, err);
        if (cpu_timer_irq) $fatal(1, "Timer IRQ clear failed");
        $display("PASS tb_soc_irq");
        $finish;
    end
endmodule
