`timescale 1ns/1ps
module tb_soc_rv32im;
    logic clk, rst_n;
    wire req_valid, req_write;
    wire [31:0] req_addr, req_wdata;
    wire [3:0] req_wstrb;
    logic [31:0] resp_rdata;
    logic resp_ready, resp_error;
    logic halted;
    logic [3:0] fault_code;
    logic [31:0] dbg_pc;
    logic [31:0] mem [0:255];
    integer i;

    riscv_core dut(
        .clk(clk), .rst_n(rst_n), .mem_req_valid(req_valid), .mem_req_write(req_write),
        .mem_req_addr(req_addr), .mem_req_wdata(req_wdata), .mem_req_wstrb(req_wstrb),
        .mem_resp_rdata(resp_rdata), .mem_resp_ready(resp_ready), .mem_resp_error(resp_error),
        .irq_timer(1'b0), .irq_external(1'b0), .halted(halted), .fault_code(fault_code), .dbg_pc(dbg_pc)
    );
    always #5 clk=~clk;
    always_comb begin
        resp_ready=req_valid; resp_error=1'b0; resp_rdata=mem[req_addr[9:2]];
    end
    always_ff @(posedge clk) begin
        if (req_valid && req_write) begin
            if(req_wstrb[0]) mem[req_addr[9:2]][7:0] <= req_wdata[7:0];
            if(req_wstrb[1]) mem[req_addr[9:2]][15:8] <= req_wdata[15:8];
            if(req_wstrb[2]) mem[req_addr[9:2]][23:16] <= req_wdata[23:16];
            if(req_wstrb[3]) mem[req_addr[9:2]][31:24] <= req_wdata[31:24];
        end
    end
    function automatic [31:0] rtype(input [6:0] f7, input [4:0] rs2, input [4:0] rs1,
                                     input [2:0] f3, input [4:0] rd);
        rtype={f7,rs2,rs1,f3,rd,7'b0110011};
    endfunction
    function automatic [31:0] addi(input [4:0] rd, input [4:0] rs1, input integer imm);
        addi={imm[11:0],rs1,3'b000,rd,7'b0010011};
    endfunction
    initial begin
        clk=0; rst_n=0;
        for(i=0;i<256;i=i+1) mem[i]=0;
        mem[0]=addi(1,0,7);
        mem[1]=addi(2,0,6);
        mem[2]=rtype(7'b0000001,2,1,3'b000,3); // MUL
        mem[3]=rtype(7'b0000001,2,3,3'b100,4); // DIV
        mem[4]=rtype(7'b0000001,2,3,3'b110,5); // REM
        mem[5]=32'h0;
        repeat(3) @(posedge clk); rst_n=1;
        repeat(160) @(posedge clk);
        if (!halted || fault_code !== 4'd1) $fatal(1, "RV32IM program did not halt cleanly");
        if (dut.u_regfile.regs[3] !== 32'd42) $fatal(1, "MUL result mismatch: %h", dut.u_regfile.regs[3]);
        if (dut.u_regfile.regs[4] !== 32'd7) $fatal(1, "DIV result mismatch: %h", dut.u_regfile.regs[4]);
        if (dut.u_regfile.regs[5] !== 32'd0) $fatal(1, "REM result mismatch: %h", dut.u_regfile.regs[5]);
        $display("PASS tb_soc_rv32im");
        $finish;
    end
endmodule
