`timescale 1ns/1ps

module tb_riscv_units;
    logic [31:0] a, b, y;
    logic [4:0] alu_op;
    logic zero, lt_signed, lt_unsigned;
    logic [31:0] instr;
    logic [31:0] imm_i, imm_s, imm_b, imm_u, imm_j;
    logic clk, rst_n, rf_we;
    logic [4:0] rf_waddr, rf_raddr1, rf_raddr2;
    logic [31:0] rf_wdata, rf_rdata1, rf_rdata2;
    logic dec_valid, dec_reg_write, dec_mem_read, dec_mem_write;
    logic dec_branch, dec_jump, dec_jalr, dec_alu_src_imm;
    logic [4:0] dec_alu_op;
    logic [1:0] dec_load_size;
    logic dec_load_unsigned;

    riscv_alu u_alu(.a(a), .b(b), .op(alu_op), .y(y), .zero(zero),
                    .lt_signed(lt_signed), .lt_unsigned(lt_unsigned));
    riscv_imm_gen u_imm(.instr(instr), .imm_i(imm_i), .imm_s(imm_s),
                        .imm_b(imm_b), .imm_u(imm_u), .imm_j(imm_j));
    riscv_regfile u_rf(.clk(clk), .rst_n(rst_n), .we(rf_we),
                       .waddr(rf_waddr), .wdata(rf_wdata),
                       .raddr1(rf_raddr1), .raddr2(rf_raddr2),
                       .rdata1(rf_rdata1), .rdata2(rf_rdata2));
    riscv_decoder u_dec(.instr(instr), .valid(dec_valid),
                        .reg_write(dec_reg_write), .mem_read(dec_mem_read),
                        .mem_write(dec_mem_write), .branch(dec_branch),
                        .jump(dec_jump), .jalr(dec_jalr),
                        .alu_src_imm(dec_alu_src_imm), .alu_op(dec_alu_op),
                        .load_size(dec_load_size),
                        .load_unsigned(dec_load_unsigned));

    always #5 clk = ~clk;

    function automatic [31:0] enc_i(input [11:0] imm, input [4:0] rs1,
                                     input [2:0] funct3, input [4:0] rd,
                                     input [6:0] opcode);
        enc_i = {imm, rs1, funct3, rd, opcode};
    endfunction

    initial begin
        clk=0; rst_n=0; rf_we=0; rf_waddr=0; rf_wdata=0;
        rf_raddr1=0; rf_raddr2=0; a=0; b=0; alu_op=0; instr=0;
        #1;
        alu_op = 5'd0; a=32'd7; b=32'd5; #1;
        if (y !== 32'd12 || zero) $fatal(1, "ADD failed");
        alu_op = 5'd1; #1;
        if (y !== 32'd2) $fatal(1, "SUB failed");
        alu_op = 5'd8; a=32'hffff_fffe; b=32'd1; #1;
        if (!lt_signed || lt_unsigned) $fatal(1, "signed compare flags failed");
        a=32'd1; b=32'd2; #1;
        if (!lt_unsigned) $fatal(1, "unsigned compare flags failed");

        instr = enc_i(12'hFFC, 5'd1, 3'b000, 5'd2, 7'b0010011); #1;
        if (imm_i !== 32'hffff_fffc) $fatal(1, "I immediate failed");
        instr = 32'b0000000_00010_00001_010_00100_0100011; #1;
        if (imm_s !== 32'h0000_0004) $fatal(1, "S immediate failed");
        instr = 32'b0; instr[31:25]=7'b0; instr[11:7]=5'd2; instr[6:0]=7'b1101111; #1;
        if (!dec_valid) begin end

        @(negedge clk); rst_n=1; rf_we=1; rf_waddr=5'd3; rf_wdata=32'h1234_5678;
        @(posedge clk); #1; rf_we=0; rf_raddr1=5'd3; rf_raddr2=0; #1;
        if (rf_rdata1 !== 32'h1234_5678 || rf_rdata2 !== 0) $fatal(1, "regfile failed");

        instr = enc_i(12'd4, 5'd1, 3'b010, 5'd2, 7'b0000011); #1;
        if (!dec_valid || !dec_reg_write || !dec_mem_read || dec_mem_write ||
            dec_load_size !== 2'd2 || dec_load_unsigned) $fatal(1, "LW decode failed");
        instr = 32'b0; #1;
        if (dec_valid) $fatal(1, "illegal decode accepted");
        $display("PASS tb_riscv_units");
        $finish;
    end
endmodule
