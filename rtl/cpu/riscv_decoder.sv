module riscv_decoder (
    input  logic [31:0] instr,
    output logic        valid,
    output logic        reg_write,
    output logic        mem_read,
    output logic        mem_write,
    output logic        branch,
    output logic        jump,
    output logic        jalr,
    output logic        alu_src_imm,
    output logic [4:0]  alu_op,
    output logic [1:0]  load_size,
    output logic        load_unsigned,
    output logic        csr_valid,
    output logic [2:0]  csr_cmd,
    output logic        csr_imm,
    output logic        system_ecall,
    output logic        system_ebreak,
    output logic        system_mret,
    output logic        system_wfi,
    output logic        m_ext,
    output logic [2:0]  m_ext_op
);
    localparam ALU_ADD=5'd0, ALU_SUB=5'd1, ALU_SLL=5'd2, ALU_SLT=5'd3,
               ALU_SLTU=5'd4, ALU_XOR=5'd5, ALU_SRL=5'd6, ALU_SRA=5'd7,
               ALU_OR=5'd9, ALU_AND=5'd10;
    logic [6:0] opcode;
    always_comb begin
        opcode = instr[6:0];
        valid=1'b0; reg_write=1'b0; mem_read=1'b0; mem_write=1'b0;
        branch=1'b0; jump=1'b0; jalr=1'b0; alu_src_imm=1'b0;
        alu_op=ALU_ADD; load_size=2'd2; load_unsigned=1'b0;
        csr_valid=1'b0; csr_cmd=3'd0; csr_imm=1'b0;
        system_ecall=1'b0; system_ebreak=1'b0; system_mret=1'b0; system_wfi=1'b0;
        m_ext=1'b0; m_ext_op=3'd0;
        case (opcode)
            7'b0110111: begin valid=1; reg_write=1; alu_src_imm=1; end // LUI
            7'b0010111: begin valid=1; reg_write=1; alu_src_imm=1; end // AUIPC
            7'b1101111: begin valid=1; reg_write=1; jump=1; end
            7'b1100111: begin if (instr[14:12]==3'b000) begin valid=1; reg_write=1; jump=1; jalr=1; alu_src_imm=1; end end
            7'b1100011: begin if (instr[14:12] <= 3'b111) begin valid=1; branch=1; end end
            7'b0000011: begin
                if (instr[14:12] <= 3'b110 && instr[14:12] != 3'b011) begin
                    valid=1; reg_write=1; mem_read=1; alu_src_imm=1;
                    case (instr[14:12])
                        3'b000,3'b100: load_size=0;
                        3'b001,3'b101: load_size=1;
                        default: load_size=2;
                    endcase
                    load_unsigned = instr[14];
                end
            end
            7'b0100011: begin
                if (instr[14:12] <= 3'b010) begin valid=1; mem_write=1; alu_src_imm=1; end
            end
            7'b0010011: begin
                valid=1; reg_write=1; alu_src_imm=1;
                case (instr[14:12])
                    3'b000: alu_op=ALU_ADD; 3'b010: alu_op=ALU_SLT;
                    3'b011: alu_op=ALU_SLTU; 3'b100: alu_op=ALU_XOR;
                    3'b110: alu_op=ALU_OR; 3'b111: alu_op=ALU_AND;
                    3'b001: alu_op=ALU_SLL;
                    3'b101: alu_op=instr[30] ? ALU_SRA : ALU_SRL;
                    default: valid=0;
                endcase
            end
            7'b0110011: begin
                valid=1; reg_write=1;
                if (instr[31:25] == 7'b0000001) begin
                    m_ext = 1'b1;
                    m_ext_op = instr[14:12];
                end else case ({instr[30],instr[14:12]})
                    4'b0000: alu_op=ALU_ADD; 4'b1000: alu_op=ALU_SUB;
                    4'b0001: alu_op=ALU_SLL; 4'b0010: alu_op=ALU_SLT;
                    4'b0011: alu_op=ALU_SLTU; 4'b0100: alu_op=ALU_XOR;
                    4'b0101: alu_op=ALU_SRL; 4'b1101: alu_op=ALU_SRA;
                    4'b0110: alu_op=ALU_OR; 4'b0111: alu_op=ALU_AND;
                    default: valid=0;
                endcase
            end
            7'b1110011: begin
                if (instr[14:12] != 3'b000) begin
                    valid = 1'b1;
                    reg_write = 1'b1;
                    csr_valid = 1'b1;
                    csr_imm = instr[14];
                    case (instr[14:12])
                        3'b001, 3'b101: csr_cmd = 3'd1;
                        3'b010, 3'b110: csr_cmd = 3'd2;
                        3'b011, 3'b111: csr_cmd = 3'd3;
                        default: begin valid=1'b0; csr_valid=1'b0; end
                    endcase
                end else begin
                    case (instr[31:20])
                        12'h000: begin valid=1'b1; system_ecall=1'b1; end
                        12'h001: begin valid=1'b1; system_ebreak=1'b1; end
                        12'h302: begin valid=1'b1; system_mret=1'b1; end
                        12'h105: begin valid=1'b1; system_wfi=1'b1; end
                        default: valid=1'b0;
                    endcase
                end
            end
            default: valid=0;
        endcase
    end
endmodule
