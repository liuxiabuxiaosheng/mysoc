`timescale 1ns/1ps
module tb_dma_controller;
    logic clk, rst_n;
    logic [31:0] paddr, pwdata;
    logic psel, penable, pwrite;
    wire [31:0] prdata;
    wire pready, pslverr;
    wire mem_req_valid, mem_req_write;
    wire [31:0] mem_req_addr, mem_req_wdata;
    wire [3:0] mem_req_wstrb;
    logic [31:0] mem_resp_rdata;
    logic mem_resp_ready, mem_resp_error;

    dma_controller dut (
        .clk(clk), .rst_n(rst_n),
        .paddr(paddr), .psel(psel), .penable(penable), .pwrite(pwrite), .pwdata(pwdata),
        .prdata(prdata), .pready(pready), .pslverr(pslverr),
        .mem_req_valid(mem_req_valid), .mem_req_write(mem_req_write),
        .mem_req_addr(mem_req_addr), .mem_req_wdata(mem_req_wdata), .mem_req_wstrb(mem_req_wstrb),
        .mem_resp_rdata(mem_resp_rdata), .mem_resp_ready(mem_resp_ready), .mem_resp_error(mem_resp_error)
    );

    always #5 clk = ~clk;

    task automatic apb_write(input [11:0] offset, input [31:0] data);
        begin
            @(negedge clk); paddr = offset; pwdata = data; pwrite = 1'b1; psel = 1'b1; penable = 1'b0;
            @(negedge clk); penable = 1'b1;
            @(negedge clk); psel = 1'b0; penable = 1'b0; pwrite = 1'b0;
        end
    endtask

    task automatic apb_read(input [11:0] offset, output [31:0] data);
        begin
            @(negedge clk); paddr = offset; pwrite = 1'b0; psel = 1'b1; penable = 1'b0;
            @(negedge clk); penable = 1'b1;
            #1 data = prdata;
            @(negedge clk); psel = 1'b0; penable = 1'b0;
        end
    endtask

    logic [31:0] status;
    initial begin
        clk = 0; rst_n = 0; paddr = 0; pwdata = 0; psel = 0; penable = 0; pwrite = 0;
        mem_resp_rdata = 0; mem_resp_ready = 0; mem_resp_error = 0;
        repeat (2) @(posedge clk); rst_n = 1;

        apb_write(12'h000, 32'h0000_0100);
        apb_write(12'h004, 32'h0000_0200);
        apb_write(12'h008, 32'd2);
        apb_write(12'h00C, 32'h1);

        @(posedge clk);
        if (!mem_req_valid || mem_req_write || mem_req_addr !== 32'h100) $fatal(1, "missing first read request");
        mem_resp_rdata <= 32'hAABB_CCDD; mem_resp_ready <= 1'b1;
        @(posedge clk); mem_resp_ready <= 1'b0;
        @(posedge clk);
        if (!mem_req_valid || !mem_req_write || mem_req_addr !== 32'h200 || mem_req_wdata !== 32'hAABB_CCDD || mem_req_wstrb !== 4'hF)
            $fatal(1, "missing first write request");
        mem_resp_ready <= 1'b1;
        @(posedge clk); mem_resp_ready <= 1'b0;
        @(posedge clk);
        if (!mem_req_valid || mem_req_write || mem_req_addr !== 32'h104) $fatal(1, "missing second read request");
        mem_resp_rdata <= 32'h1122_3344; mem_resp_ready <= 1'b1;
        @(posedge clk); mem_resp_ready <= 1'b0;
        @(posedge clk);
        if (!mem_req_valid || !mem_req_write || mem_req_addr !== 32'h204 || mem_req_wdata !== 32'h1122_3344)
            $fatal(1, "missing second write request");
        mem_resp_ready <= 1'b1;
        @(posedge clk); mem_resp_ready <= 1'b0;
        repeat (2) @(posedge clk);

        apb_read(12'h010, status);
        if (status !== 32'h2) $fatal(1, "done status mismatch: %h", status);

        apb_write(12'h010, 32'h2);
        apb_read(12'h010, status);
        if (status !== 32'h0) $fatal(1, "status clear mismatch: %h", status);

        apb_write(12'h008, 32'd0);
        apb_write(12'h00C, 32'h1);
        apb_read(12'h010, status);
        if (status !== 32'h4) $fatal(1, "zero-length error mismatch: %h", status);

        $display("PASS tb_dma_controller");
        $finish;
    end
endmodule
