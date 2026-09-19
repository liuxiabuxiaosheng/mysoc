`timescale 1ns/1ps
module tb_apb_dma;
    logic clk, rst_n;
    logic [31:0] m_paddr, m_pwdata;
    logic m_psel, m_penable, m_pwrite;
    wire [31:0] m_prdata;
    wire m_pready, m_pslverr;
    logic [7:0] gpio_in;
    wire [7:0] gpio_out, gpio_dir;
    wire timer_irq;
    logic uart_rx;
    wire uart_tx;
    wire dma_mem_req_valid, dma_mem_req_write;
    wire [31:0] dma_mem_req_addr, dma_mem_req_wdata;
    wire [3:0] dma_mem_req_wstrb;

    apb_subsystem dut (
        .clk(clk), .rst_n(rst_n), .m_paddr(m_paddr), .m_psel(m_psel), .m_penable(m_penable),
        .m_pwrite(m_pwrite), .m_pwdata(m_pwdata), .m_prdata(m_prdata), .m_pready(m_pready),
        .m_pslverr(m_pslverr), .gpio_in(gpio_in), .gpio_out(gpio_out), .gpio_dir(gpio_dir),
        .timer_irq(timer_irq), .uart_rx(uart_rx), .uart_tx(uart_tx),
        .dma_mem_req_valid(dma_mem_req_valid), .dma_mem_req_write(dma_mem_req_write),
        .dma_mem_req_addr(dma_mem_req_addr), .dma_mem_req_wdata(dma_mem_req_wdata),
        .dma_mem_req_wstrb(dma_mem_req_wstrb), .dma_mem_resp_rdata(32'b0),
        .dma_mem_resp_ready(1'b0), .dma_mem_resp_error(1'b0)
    );

    always #5 clk = ~clk;

    task automatic apb_write(input [31:0] addr, input [31:0] data);
        begin
            @(negedge clk); m_paddr=addr; m_pwdata=data; m_pwrite=1; m_psel=1; m_penable=0;
            @(negedge clk); m_penable=1;
            if (!m_pready || m_pslverr) $fatal(1, "APB DMA write rejected");
            @(negedge clk); m_psel=0; m_penable=0; m_pwrite=0;
        end
    endtask

    task automatic apb_read(input [31:0] addr, output [31:0] data);
        begin
            @(negedge clk); m_paddr=addr; m_pwdata=0; m_pwrite=0; m_psel=1; m_penable=0;
            @(negedge clk); m_penable=1;
            if (!m_pready || m_pslverr) $fatal(1, "APB DMA read rejected");
            #1 data=m_prdata;
            @(negedge clk); m_psel=0; m_penable=0;
        end
    endtask

    logic [31:0] value;
    initial begin
        clk=0; rst_n=0; m_paddr=0; m_pwdata=0; m_psel=0; m_penable=0; m_pwrite=0; gpio_in=0; uart_rx=1;
        repeat (2) @(posedge clk); rst_n=1;
        apb_write(32'h4000_5000, 32'h100);
        apb_write(32'h4000_5004, 32'h200);
        apb_write(32'h4000_5008, 32'd1);
        apb_read(32'h4000_5000, value);
        if (value !== 32'h100) $fatal(1, "DMA SRC mismatch: %h", value);
        apb_read(32'h4000_5010, value);
        if (value !== 32'h0) $fatal(1, "DMA status mismatch: %h", value);
        if (dma_mem_req_valid) $fatal(1, "DMA unexpectedly active");
        $display("PASS tb_apb_dma");
        $finish;
    end
endmodule
