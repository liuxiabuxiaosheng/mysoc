`timescale 1ns/1ps

module tb_onchip_ram;
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

    onchip_ram #(
        .INIT_FILE("tb/memory/onchip_ram_init.hex")
    ) dut (
        .clk(clk), .rst_n(rst_n),
        .req_valid(req_valid), .req_write(req_write),
        .req_addr(req_addr), .req_wdata(req_wdata), .req_wstrb(req_wstrb),
        .resp_rdata(resp_rdata), .resp_ready(resp_ready), .resp_error(resp_error)
    );

    always #5 clk = ~clk;

    task automatic check(input logic condition, input string message);
        begin
            if (!condition) $fatal(1, "%s", message);
        end
    endtask

    task automatic ram_access(
        input logic        write_op,
        input logic [31:0] addr,
        input logic [31:0] wdata,
        input logic [3:0]  wstrb,
        output logic [31:0] rdata,
        output logic         failed
    );
        begin
            @(negedge clk);
            req_write = write_op;
            req_addr = addr;
            req_wdata = wdata;
            req_wstrb = wstrb;
            req_valid = 1'b1;
            #1;
            check(!resp_ready && !resp_error,
                  "RAM responded combinationally to a new request");
            do @(posedge clk); while (!resp_ready && !resp_error);
            rdata = resp_rdata;
            failed = resp_error;
            @(negedge clk);
            req_valid = 1'b0;
            req_write = 1'b0;
            req_wstrb = '0;
        end
    endtask

    initial begin
        logic [31:0] rdata;
        logic        failed;

        clk = 1'b0;
        rst_n = 1'b0;
        req_valid = 1'b0;
        req_write = 1'b0;
        req_addr = '0;
        req_wdata = '0;
        req_wstrb = '0;

        repeat (2) @(posedge clk);
        rst_n = 1'b1;

        ram_access(1'b0, 32'h0000_0000, '0, '0, rdata, failed);
        check(!failed && rdata == 32'h1122_3344,
              "RAM initialization word zero mismatch");
        ram_access(1'b0, 32'h0000_0004, '0, '0, rdata, failed);
        check(!failed && rdata == 32'h5566_7788,
              "RAM initialization word one mismatch");

        ram_access(1'b1, 32'h0000_0010, 32'hAABB_CCDD, 4'b1111, rdata, failed);
        check(!failed, "whole-word RAM write failed");
        ram_access(1'b1, 32'h0000_0010, 32'h1100_2200, 4'b0101, rdata, failed);
        check(!failed, "byte-strobe RAM write failed");
        ram_access(1'b0, 32'h0000_0010, '0, '0, rdata, failed);
        check(!failed && rdata == 32'hAA00_CC00,
              "byte-strobe RAM update mismatch");

        ram_access(1'b1, 32'h0000_FFFC, 32'hCAFE_BABE, 4'b1111, rdata, failed);
        check(!failed, "last RAM word write failed");
        ram_access(1'b0, 32'h0000_FFFC, '0, '0, rdata, failed);
        check(!failed && rdata == 32'hCAFE_BABE,
              "last RAM word read mismatch");

        ram_access(1'b0, 32'h0000_0002, '0, '0, rdata, failed);
        check(failed, "unaligned RAM read did not fail");
        ram_access(1'b0, 32'h0000_0000, '0, '0, rdata, failed);
        check(!failed && rdata == 32'h1122_3344,
              "unaligned RAM read altered stored data");

        $display("PASS tb_onchip_ram");
        $finish;
    end
endmodule
