module riscv_alu (
    input  logic [31:0] a,
    input  logic [31:0] b,
    input  logic [4:0]  op,
    output logic [31:0] y,
    output logic        zero,
    output logic        lt_signed,
    output logic        lt_unsigned
);
    localparam ALU_ADD=5'd0, ALU_SUB=5'd1, ALU_SLL=5'd2, ALU_SLT=5'd3,
               ALU_SLTU=5'd4, ALU_XOR=5'd5, ALU_SRL=5'd6, ALU_SRA=5'd7,
               ALU_CMP=5'd8, ALU_OR=5'd9, ALU_AND=5'd10;
    always_comb begin
        case (op)
            ALU_SUB, ALU_CMP: y = a - b;
            ALU_SLL: y = a << b[4:0];
            ALU_SLT: y = {{31{1'b0}}, $signed(a) < $signed(b)};
            ALU_SLTU: y = {{31{1'b0}}, a < b};
            ALU_XOR: y = a ^ b;
            ALU_SRL: y = a >> b[4:0];
            ALU_SRA: y = $signed(a) >>> b[4:0];
            ALU_OR: y = a | b;
            ALU_AND: y = a & b;
            default: y = a + b;
        endcase
    end
    assign zero = (y == 32'b0);
    assign lt_signed = ($signed(a) < $signed(b));
    assign lt_unsigned = (a < b);
endmodule
