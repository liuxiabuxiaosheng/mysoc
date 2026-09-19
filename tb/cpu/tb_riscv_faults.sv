`timescale 1ns/1ps
module tb_riscv_faults;
    logic clk, rst_n, req_error_mode;
    wire req_valid, req_write;
    wire [31:0] req_addr, req_wdata;
    wire [3:0] req_wstrb;
    logic [31:0] resp_rdata;
    logic resp_ready, resp_error;
    wire halted;
    wire [3:0] fault_code;
    wire [31:0] dbg_pc;
    logic [31:0] mem [0:31];
    integer i;

    riscv_core dut(.clk(clk), .rst_n(rst_n), .mem_req_valid(req_valid),
        .mem_req_write(req_write), .mem_req_addr(req_addr), .mem_req_wdata(req_wdata),
        .mem_req_wstrb(req_wstrb), .mem_resp_rdata(resp_rdata),
        .mem_resp_ready(resp_ready), .mem_resp_error(resp_error),
        .halted(halted), .fault_code(fault_code), .dbg_pc(dbg_pc));
    always #5 clk=~clk;
    always_comb begin
        resp_ready = req_valid;
        resp_error = req_error_mode && !req_write;
        resp_rdata = mem[req_addr[6:2]];
    end

    initial begin
        clk=0; rst_n=0; req_error_mode=0;
        for(i=0;i<32;i=i+1) mem[i]=0;
        // LW x1, 2(x0) -> misaligned word fault before a data request.
        mem[0] = {12'd2,5'd0,3'b010,5'd1,7'b0000011};
        repeat(2) @(posedge clk); rst_n=1;
        repeat(20) @(posedge clk);
        if (!halted || fault_code !== 4'd2) $fatal(1, "misaligned access fault missing");

        rst_n=0; req_error_mode=1;
        repeat(2) @(posedge clk); rst_n=1;
        repeat(20) @(posedge clk);
        if (!halted || fault_code !== 4'd3) $fatal(1, "bus error fault missing");
        $display("PASS tb_riscv_faults");
        $finish;
    end
endmodule
