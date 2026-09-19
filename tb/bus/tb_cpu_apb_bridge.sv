`timescale 1ns/1ps

module tb_cpu_apb_bridge;
    logic        clk;
    logic        rst_n;
    logic        req_valid;
    logic        req_write;
    logic [31:0] req_addr;
    logic [31:0] req_wdata;
    logic [3:0]  req_wstrb;
    logic [31:0] resp_rdata;
    logic        resp_ready;
    logic        resp_error;
    logic [31:0] paddr;
    logic        psel;
    logic        penable;
    logic        pwrite;
    logic [31:0] pwdata;
    logic [3:0]  pstrb;
    logic [31:0] prdata;
    logic        pready;
    logic        pslverr;

    cpu_apb_bridge dut (
        .clk(clk), .rst_n(rst_n),
        .req_valid(req_valid), .req_write(req_write),
        .req_addr(req_addr), .req_wdata(req_wdata), .req_wstrb(req_wstrb),
        .resp_rdata(resp_rdata), .resp_ready(resp_ready), .resp_error(resp_error),
        .paddr(paddr), .psel(psel), .penable(penable), .pwrite(pwrite),
        .pwdata(pwdata), .pstrb(pstrb),
        .prdata(prdata), .pready(pready), .pslverr(pslverr)
    );

    always #5 clk = ~clk;

    task automatic check(input logic condition, input string message);
        begin
            if (!condition) $fatal(1, "%s", message);
        end
    endtask

    task automatic start_request(
        input logic write_op,
        input logic [31:0] addr,
        input logic [31:0] wdata,
        input logic [3:0] strb
    );
        begin
            @(negedge clk);
            req_valid = 1'b1;
            req_write = write_op;
            req_addr = addr;
            req_wdata = wdata;
            req_wstrb = strb;
        end
    endtask

    task automatic finish_response;
        begin
            @(negedge clk);
            req_valid = 1'b0;
            req_write = 1'b0;
            req_addr = '0;
            req_wdata = '0;
            req_wstrb = '0;
        end
    endtask

    initial begin
        clk = 1'b0;
        rst_n = 1'b0;
        req_valid = 1'b0;
        req_write = 1'b0;
        req_addr = '0;
        req_wdata = '0;
        req_wstrb = '0;
        prdata = '0;
        pready = 1'b0;
        pslverr = 1'b0;

        repeat (2) @(posedge clk);
        rst_n = 1'b1;

        start_request(1'b1, 32'h4000_0000, 32'hCAFE_BABE, 4'hF);
        @(posedge clk); #1;
        check(psel && !penable, "bridge did not drive APB setup phase");
        check(paddr == 32'h4000_0000 && pwrite && pwdata == 32'hCAFE_BABE && pstrb == 4'hF,
              "bridge setup fields mismatch");
        @(posedge clk); #1;
        check(psel && penable, "bridge did not drive APB access phase");

        @(negedge clk);
        req_write = 1'b0;
        req_addr = 32'hDEAD_0000;
        req_wdata = 32'h0000_0000;
        req_wstrb = 4'h0;
        repeat (2) begin
            @(posedge clk); #1;
            check(psel && penable && !pready,
                  "bridge left APB access before the slave was ready");
            check(paddr == 32'h4000_0000 && pwrite && pwdata == 32'hCAFE_BABE && pstrb == 4'hF,
                  "bridge changed APB fields during a wait state");
        end

        @(negedge clk);
        prdata = 32'h1234_5678;
        pslverr = 1'b1;
        pready = 1'b1;
        @(posedge clk); #1;
        check(resp_ready && resp_error && resp_rdata == 32'h1234_5678,
              "bridge did not convert APB error response to CPU response");
        check(!psel && !penable, "bridge selected APB after transfer completion");
        finish_response();

        pready = 1'b1;
        pslverr = 1'b0;
        prdata = 32'h89AB_CDEF;
        start_request(1'b0, 32'h4000_0004, '0, 4'h0);
        @(posedge clk); #1;
        check(psel && !penable && !pwrite, "bridge read setup phase mismatch");
        @(posedge clk); #1;
        check(psel && penable && !pwrite, "bridge read access phase mismatch");
        @(posedge clk); #1;
        check(resp_ready && !resp_error && resp_rdata == 32'h89AB_CDEF,
              "bridge did not return successful APB read data");
        finish_response();

        $display("PASS tb_cpu_apb_bridge");
        $finish;
    end
endmodule
