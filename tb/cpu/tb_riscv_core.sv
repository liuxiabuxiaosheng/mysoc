`timescale 1ns/1ps
module tb_riscv_core;
    logic clk, rst_n;
    logic req_valid, req_write;
    logic [31:0] req_addr, req_wdata;
    logic [3:0] req_wstrb;
    logic [31:0] resp_rdata;
    logic resp_ready, resp_error;
    logic halted;
    logic [3:0] fault_code;
    logic [31:0] dbg_pc;
    logic [31:0] mem [0:255];
    integer i;

    riscv_core dut(
        .clk(clk), .rst_n(rst_n),
        .mem_req_valid(req_valid), .mem_req_write(req_write),
        .mem_req_addr(req_addr), .mem_req_wdata(req_wdata), .mem_req_wstrb(req_wstrb),
        .mem_resp_rdata(resp_rdata), .mem_resp_ready(resp_ready),
        .mem_resp_error(resp_error), .halted(halted), .fault_code(fault_code),
        .dbg_pc(dbg_pc)
    );

    always #5 clk = ~clk;
    always_comb begin
        resp_ready = req_valid;
        resp_error = 1'b0;
        resp_rdata = mem[req_addr[9:2]];
    end
    always_ff @(posedge clk) begin
        if (req_valid && req_write) begin
            if (req_wstrb[0]) mem[req_addr[9:2]][7:0] <= req_wdata[7:0];
            if (req_wstrb[1]) mem[req_addr[9:2]][15:8] <= req_wdata[15:8];
            if (req_wstrb[2]) mem[req_addr[9:2]][23:16] <= req_wdata[23:16];
            if (req_wstrb[3]) mem[req_addr[9:2]][31:24] <= req_wdata[31:24];
        end
    end

    function automatic [31:0] rtype(input [6:0] funct7, input [4:0] rs2,
        input [4:0] rs1, input [2:0] funct3, input [4:0] rd);
        rtype = {funct7,rs2,rs1,funct3,rd,7'b0110011};
    endfunction
    function automatic [31:0] itype(input integer imm, input [4:0] rs1,
        input [2:0] funct3, input [4:0] rd, input [6:0] opcode);
        itype = {imm[11:0],rs1,funct3,rd,opcode};
    endfunction
    function automatic [31:0] stype(input integer imm, input [4:0] rs2,
        input [4:0] rs1, input [2:0] funct3);
        stype = {imm[11:5],rs2,rs1,funct3,imm[4:0],7'b0100011};
    endfunction
    function automatic [31:0] btype(input integer imm, input [4:0] rs2,
        input [4:0] rs1, input [2:0] funct3);
        btype = {imm[12],imm[10:5],rs2,rs1,funct3,imm[4:1],imm[11],7'b1100011};
    endfunction

    initial begin
        clk=0; rst_n=0; resp_rdata=0;
        for (i=0;i<256;i=i+1) mem[i]=0;
        // x1=5; x2=7; x3=x1+x2; x4=x3-2; store/load; branch skip; fault on word 0x2
        mem[0] = itype(5,0,3'b000,1,7'b0010011);
        mem[1] = itype(7,0,3'b000,2,7'b0010011);
        mem[2] = rtype(0,2,1,3'b000,3);
        mem[3] = itype(-2,3,3'b000,4,7'b0010011);
        mem[4] = stype(16,4,0,3'b010);
        mem[5] = itype(16,0,3'b010,5,7'b0000011);
        mem[6] = btype(8,5,4,3'b000);
        mem[7] = itype(99,0,3'b000,6,7'b0010011);
        mem[8] = itype(1,5,3'b000,7,7'b0010011);
        mem[9] = 32'h0000_0000;
        repeat (3) @(posedge clk);
        rst_n=1;
        repeat (120) @(posedge clk);
        if (halted !== 1'b1 || fault_code !== 4'd1) $fatal(1, "core did not halt on illegal instruction");
        if (mem[4] !== 32'd10) $fatal(1, "store result mismatch: %h", mem[4]);
        if (dut.u_regfile.regs[5] !== 32'd10) $fatal(1, "load result mismatch");
        if (dut.u_regfile.regs[6] !== 32'd0) $fatal(1, "taken branch did not skip instruction");
        if (dut.u_regfile.regs[7] !== 32'd11) $fatal(1, "post-branch instruction failed");
        $display("PASS tb_riscv_core");
        $finish;
    end
endmodule
