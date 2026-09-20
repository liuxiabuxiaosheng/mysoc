`timescale 1ns/1ps
module tb_riscv_trap;
    logic clk, rst_n, irq_timer, irq_external;
    wire req_valid, req_write;
    wire [31:0] req_addr, req_wdata;
    wire [3:0] req_wstrb;
    logic [31:0] resp_rdata;
    logic resp_ready, resp_error;
    wire halted;
    wire [3:0] fault_code;
    wire [31:0] dbg_pc;
    logic [31:0] mem [0:255];
    integer i;

    riscv_core dut(.clk(clk), .rst_n(rst_n), .mem_req_valid(req_valid), .mem_req_write(req_write),
        .mem_req_addr(req_addr), .mem_req_wdata(req_wdata), .mem_req_wstrb(req_wstrb),
        .mem_resp_rdata(resp_rdata), .mem_resp_ready(resp_ready), .mem_resp_error(resp_error),
        .irq_timer(irq_timer), .irq_external(irq_external), .halted(halted),
        .fault_code(fault_code), .dbg_pc(dbg_pc));
    always #5 clk=~clk;
    always_comb begin
        resp_ready=req_valid; resp_error=1'b0; resp_rdata=mem[req_addr[9:2]];
    end
    always_ff @(posedge clk) begin
        if(req_valid && req_write) begin
            if(req_wstrb[0]) mem[req_addr[9:2]][7:0] <= req_wdata[7:0];
            if(req_wstrb[1]) mem[req_addr[9:2]][15:8] <= req_wdata[15:8];
            if(req_wstrb[2]) mem[req_addr[9:2]][23:16] <= req_wdata[23:16];
            if(req_wstrb[3]) mem[req_addr[9:2]][31:24] <= req_wdata[31:24];
        end
    end
    function automatic [31:0] csr_imm(input [4:0] rd, input [11:0] csr, input [4:0] zimm);
        csr_imm={csr,zimm,3'b101,rd,7'b1110011};
    endfunction
    function automatic [31:0] csrrw(input [4:0] rd, input [4:0] rs1, input [11:0] csr);
        csrrw={csr,rs1,3'b001,rd,7'b1110011};
    endfunction
    function automatic [31:0] addi(input [4:0] rd, input [4:0] rs1, input integer imm);
        addi={imm[11:0],rs1,3'b000,rd,7'b0010011};
    endfunction
    initial begin
        clk=0; rst_n=0; irq_timer=0; irq_external=0;
        for(i=0;i<256;i=i+1) mem[i]=0;
        // mtvec=0x20, mie.MEIE=1, mstatus.MIE=1
        mem[0]=addi(1,0,32);
        mem[1]=csrrw(0,1,12'h305);
        mem[2]=addi(3,0,32'h800);
        mem[3]=csrrw(0,3,12'h304);
        mem[4]=csr_imm(4,12'h300,8);
        mem[5]=addi(6,0,1);
        mem[6]=addi(6,6,1);
        mem[7]=addi(6,6,1);
        // Handler at 0x20: x5=0x55; MRET
        mem[8]=addi(5,0,8'h55);
        mem[9]=32'h3020_0073;
        repeat(3) @(posedge clk); rst_n=1;
        repeat(65) @(posedge clk);
        @(negedge clk); irq_external=1;
        @(negedge clk); irq_external=0;
        repeat(90) @(posedge clk);
        if (dut.u_regfile.regs[5] !== 32'h55) $fatal(1, "interrupt handler did not run: %h", dut.u_regfile.regs[5]);
        if (dut.u_regfile.regs[6] === 32'd0) $fatal(1, "main program did not resume");
        $display("PASS tb_riscv_trap");
        $finish;
    end
endmodule
