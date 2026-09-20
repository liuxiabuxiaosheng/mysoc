module riscv_core (
    input  logic        clk,
    input  logic        rst_n,
    output logic        mem_req_valid,
    output logic        mem_req_write,
    output logic [31:0] mem_req_addr,
    output logic [31:0] mem_req_wdata,
    output logic [3:0]  mem_req_wstrb,
    input  logic [31:0] mem_resp_rdata,
    input  logic        mem_resp_ready,
    input  logic        mem_resp_error,
    input  logic        irq_timer,
    input  logic        irq_external,
    output logic        halted,
    output logic [3:0]  fault_code,
    output logic [31:0] dbg_pc
);
    localparam [3:0] S_FETCH=4'd0, S_DECODE=4'd1, S_EXECUTE=4'd2,
                     S_MEMORY=4'd3, S_WRITEBACK=4'd4, S_FAULT=4'd5,
                     S_MEXT_WAIT=4'd6, S_WFI=4'd7;
    localparam [3:0] F_ILLEGAL=4'd1, F_MISALIGNED=4'd2, F_BUS=4'd3;
    localparam [6:0] OP_LUI=7'b0110111, OP_AUIPC=7'b0010111,
                     OP_JAL=7'b1101111, OP_JALR=7'b1100111,
                     OP_BRANCH=7'b1100011, OP_LOAD=7'b0000011,
                     OP_STORE=7'b0100011;

    logic [3:0] state;
    logic [31:0] pc_q, instr_q, result_q, next_pc_q;
    logic [31:0] eff_addr_q, store_data_q;
    logic [3:0]  store_strb_q;
    logic [1:0]  load_size_q;
    logic        load_unsigned_q, mem_write_q, reg_write_q;
    logic [4:0]  rd_q;
    logic [3:0] fault_q;

    logic dec_valid, dec_reg_write, dec_mem_read, dec_mem_write;
    logic dec_branch, dec_jump, dec_jalr, dec_alu_src_imm;
    logic [4:0] dec_alu_op;
    logic [1:0] dec_load_size;
    logic dec_load_unsigned;
    logic [31:0] imm_i, imm_s, imm_b, imm_u, imm_j;
    logic [31:0] rs1_val, rs2_val, alu_b, alu_y;
    logic [31:0] eff_calc;
    logic alu_zero, alu_lt_signed, alu_lt_unsigned;
    logic rf_we;
    logic dec_csr_valid, dec_csr_imm;
    logic [2:0] dec_csr_cmd;
    logic dec_system_ecall, dec_system_ebreak, dec_system_mret, dec_system_wfi;
    logic dec_m_ext;
    logic [2:0] dec_m_ext_op;
    logic [11:0] csr_addr;
    logic [31:0] csr_wdata, csr_rdata, mtvec, mepc;
    logic csr_trap_valid, csr_trap_interrupt, csr_mret;
    logic [31:0] csr_trap_cause, csr_trap_pc, csr_trap_tval;
    logic csr_mstatus_mie, csr_mie_mtie, csr_mie_meie, csr_wfi_wakeup;
    logic muldiv_start, muldiv_busy, muldiv_done;
    logic [31:0] muldiv_result;
    logic [31:0] irq_timer_i, irq_external_i;
    logic trap_pending, exception_pending;
    logic exception_misaligned;

    riscv_decoder u_decoder(
        .instr(instr_q), .valid(dec_valid), .reg_write(dec_reg_write),
        .mem_read(dec_mem_read), .mem_write(dec_mem_write), .branch(dec_branch),
        .jump(dec_jump), .jalr(dec_jalr), .alu_src_imm(dec_alu_src_imm),
        .alu_op(dec_alu_op), .load_size(dec_load_size),
        .load_unsigned(dec_load_unsigned), .csr_valid(dec_csr_valid),
        .csr_cmd(dec_csr_cmd), .csr_imm(dec_csr_imm),
        .system_ecall(dec_system_ecall), .system_ebreak(dec_system_ebreak),
        .system_mret(dec_system_mret), .system_wfi(dec_system_wfi),
        .m_ext(dec_m_ext), .m_ext_op(dec_m_ext_op));
    riscv_imm_gen u_imm(.instr(instr_q), .imm_i(imm_i), .imm_s(imm_s),
                        .imm_b(imm_b), .imm_u(imm_u), .imm_j(imm_j));
    riscv_regfile u_regfile(
        .clk(clk), .rst_n(rst_n), .we(rf_we), .waddr(rd_q), .wdata(result_q),
        .raddr1(instr_q[19:15]), .raddr2(instr_q[24:20]),
        .rdata1(rs1_val), .rdata2(rs2_val));
    riscv_alu u_alu(.a(rs1_val), .b(alu_b), .op(dec_alu_op), .y(alu_y),
                    .zero(alu_zero), .lt_signed(alu_lt_signed),
                    .lt_unsigned(alu_lt_unsigned));

    riscv_csr u_csr (
        .clk(clk), .rst_n(rst_n), .csr_addr(csr_addr),
        .csr_cmd(((state == S_EXECUTE) && dec_csr_valid) ? dec_csr_cmd : 3'd0),
        .csr_wdata(csr_wdata), .csr_rdata(csr_rdata),
        .trap_valid(csr_trap_valid), .trap_interrupt(csr_trap_interrupt),
        .trap_cause(csr_trap_cause), .trap_pc(csr_trap_pc), .trap_tval(csr_trap_tval),
        .mret(csr_mret), .irq_timer(irq_timer_i[0]), .irq_external(irq_external_i[0]),
        .mtvec(mtvec), .mepc(mepc), .mstatus_mie(csr_mstatus_mie), .mie_mtie(csr_mie_mtie),
        .mie_meie(csr_mie_meie), .wfi_wakeup(csr_wfi_wakeup));

    riscv_muldiv u_muldiv (
        .clk(clk), .rst_n(rst_n), .start(muldiv_start), .op(dec_m_ext_op),
        .a(rs1_val), .b(rs2_val), .busy(muldiv_busy), .done(muldiv_done),
        .result(muldiv_result));

    assign alu_b = dec_alu_src_imm ? imm_i : rs2_val;
    assign eff_calc = rs1_val + (dec_mem_write ? imm_s : imm_i);
    assign rf_we = (state == S_WRITEBACK) && reg_write_q && !halted;
    assign trap_pending = (mtvec != 0) && csr_mstatus_mie &&
                          ((irq_timer_i[0] && csr_mie_mtie) ||
                           (irq_external_i[0] && csr_mie_meie));
    assign exception_misaligned = (state == S_EXECUTE) && (dec_mem_read || dec_mem_write) &&
                                  ((dec_load_size == 2'd1 && eff_calc[0]) ||
                                   (dec_load_size == 2'd2 && (eff_calc[1:0] != 0)));
    assign exception_pending = (state == S_DECODE && !dec_valid) ||
                               (state == S_EXECUTE && (dec_system_ecall || dec_system_ebreak || exception_misaligned)) ||
                               (state == S_FETCH && mem_resp_ready && mem_resp_error) ||
                               (state == S_MEMORY && mem_resp_ready && mem_resp_error);
    assign mem_req_valid = ((state == S_FETCH) && !trap_pending) || (state == S_MEMORY);
    assign mem_req_write = (state == S_MEMORY) && mem_write_q;
    assign mem_req_addr = (state == S_FETCH) ? pc_q : eff_addr_q;
    assign mem_req_wdata = store_data_q;
    assign mem_req_wstrb = (state == S_MEMORY) ? store_strb_q : 4'b0000;
    assign halted = (state == S_FAULT);
    assign fault_code = fault_q;
    assign dbg_pc = pc_q;
    assign irq_timer_i = {31'd0, (irq_timer === 1'b1)};
    assign irq_external_i = {31'd0, (irq_external === 1'b1)};
    assign csr_addr = instr_q[31:20];
    assign csr_wdata = dec_csr_imm ? {27'd0, instr_q[19:15]} : rs1_val;
    assign csr_trap_valid = trap_pending || ((mtvec != 0) && exception_pending);
    assign csr_trap_interrupt = trap_pending;
    assign csr_trap_cause = trap_pending ?
                            ((irq_timer_i[0] && csr_mie_mtie) ? 32'd7 : 32'd11) :
                            ((state == S_DECODE && !dec_valid) ? 32'd2 :
                             (state == S_FETCH && mem_resp_ready && mem_resp_error) ? 32'd5 :
                             (state == S_MEMORY && mem_resp_ready && mem_resp_error) ?
                                (mem_write_q ? 32'd7 : 32'd5) :
                             (dec_system_ecall ? 32'd8 :
                              dec_system_ebreak ? 32'd3 :
                              dec_mem_write ? 32'd6 : 32'd4));
    assign csr_trap_pc = pc_q;
    assign csr_trap_tval = (state == S_MEMORY) ? eff_addr_q :
                           ((state == S_EXECUTE && (dec_mem_read || dec_mem_write)) ? eff_calc : instr_q);
    assign csr_mret = (state == S_EXECUTE) && dec_system_mret;
    assign muldiv_start = (state == S_EXECUTE) && dec_m_ext;

    function automatic [31:0] load_format(input [31:0] data, input [1:0] size,
                                           input logic uns, input [1:0] offs);
        reg [31:0] shifted;
        begin
            shifted = data >> (offs * 8);
            case (size)
                2'd0: load_format = uns ? {24'b0,shifted[7:0]} : {{24{shifted[7]}},shifted[7:0]};
                2'd1: load_format = uns ? {16'b0,shifted[15:0]} : {{16{shifted[15]}},shifted[15:0]};
                default: load_format = shifted;
            endcase
        end
    endfunction

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_FETCH; pc_q <= 32'b0; instr_q <= 32'b0;
            result_q <= 32'b0; next_pc_q <= 32'b0; eff_addr_q <= 32'b0;
            store_data_q <= 32'b0; store_strb_q <= 4'b0; load_size_q <= 2'd2;
            load_unsigned_q <= 1'b0; mem_write_q <= 1'b0; reg_write_q <= 1'b0;
            rd_q <= 5'b0; fault_q <= 4'b0;
        end else begin
            case (state)
                S_FETCH: begin
                    if (trap_pending) begin
                        pc_q <= mtvec;
                        state <= S_FETCH;
                    end else if (mem_resp_ready) begin
                        if (mem_resp_error) begin fault_q<=F_BUS; state<=S_FAULT; end
                        else begin instr_q<=mem_resp_rdata; state<=S_DECODE; end
                    end
                end
                S_DECODE: begin
                    if (mtvec != 0 && !dec_valid) begin
                        pc_q <= mtvec;
                        state <= S_FETCH;
                    end else if (!dec_valid) begin fault_q<=F_ILLEGAL; state<=S_FAULT; end
                    else state<=S_EXECUTE;
                end
                S_EXECUTE: begin
                    rd_q <= instr_q[11:7];
                    next_pc_q <= pc_q + 32'd4;
                    if (mtvec != 0 && (dec_system_ecall || dec_system_ebreak ||
                        ((dec_mem_read || dec_mem_write) &&
                         ((dec_load_size==2'd1 && eff_calc[0]) ||
                          (dec_load_size==2'd2 && (eff_calc[1:0] != 0)))))) begin
                        pc_q <= mtvec;
                        state <= S_FETCH;
                    end else if (dec_csr_valid) begin
                        result_q <= csr_rdata;
                        reg_write_q <= dec_reg_write;
                        state <= S_WRITEBACK;
                    end else if (dec_system_mret) begin
                        pc_q <= mepc;
                        reg_write_q <= 1'b0;
                        state <= S_FETCH;
                    end else if (dec_system_wfi) begin
                        reg_write_q <= 1'b0;
                        state <= S_WFI;
                    end else if (dec_m_ext) begin
                        reg_write_q <= 1'b1;
                        state <= S_MEXT_WAIT;
                    end else if (instr_q[6:0] == OP_LUI) begin
                        result_q<=imm_u; reg_write_q<=1'b1; state<=S_WRITEBACK;
                    end else if (instr_q[6:0] == OP_AUIPC) begin
                        result_q<=pc_q + imm_u; reg_write_q<=1'b1; state<=S_WRITEBACK;
                    end else if (instr_q[6:0] == OP_JAL) begin
                        result_q<=pc_q+32'd4; reg_write_q<=1'b1; pc_q<=pc_q+imm_j; state<=S_WRITEBACK;
                    end else if (instr_q[6:0] == OP_JALR) begin
                        result_q<=pc_q+32'd4; reg_write_q<=1'b1; pc_q<=(rs1_val+imm_i)&32'hffff_fffe; state<=S_WRITEBACK;
                    end else if (dec_branch) begin
                        reg_write_q<=1'b0;
                        case (instr_q[14:12])
                            3'b000: if (rs1_val==rs2_val) pc_q<=pc_q+imm_b; else pc_q<=pc_q+4;
                            3'b001: if (rs1_val!=rs2_val) pc_q<=pc_q+imm_b; else pc_q<=pc_q+4;
                            3'b100: if ($signed(rs1_val)<$signed(rs2_val)) pc_q<=pc_q+imm_b; else pc_q<=pc_q+4;
                            3'b101: if ($signed(rs1_val)>=$signed(rs2_val)) pc_q<=pc_q+imm_b; else pc_q<=pc_q+4;
                            3'b110: if (rs1_val<rs2_val) pc_q<=pc_q+imm_b; else pc_q<=pc_q+4;
                            3'b111: if (rs1_val>=rs2_val) pc_q<=pc_q+imm_b; else pc_q<=pc_q+4;
                            default: begin fault_q<=F_ILLEGAL; state<=S_FAULT; end
                        endcase
                        if (state != S_FAULT) state<=S_FETCH;
                    end else if (dec_mem_read || dec_mem_write) begin
                        eff_addr_q <= eff_calc;
                        mem_write_q <= dec_mem_write; reg_write_q <= dec_mem_read;
                        load_size_q <= dec_load_size; load_unsigned_q <= dec_load_unsigned;
                        if (dec_mem_write) begin
                            case (instr_q[14:12])
                                3'b000: begin store_strb_q<=4'b0001<<(eff_calc&3); store_data_q<=rs2_val<<((eff_calc&3)*8); end
                                3'b001: begin store_strb_q<=((eff_calc&2) != 0) ? 4'b1100 : 4'b0011; store_data_q<=rs2_val<<((eff_calc&2)*8); end
                                default: begin store_strb_q<=4'b1111; store_data_q<=rs2_val; end
                            endcase
                        end else begin store_strb_q<=4'b0000; store_data_q<=32'b0; end
                        if ((dec_load_size==2'd1 && eff_calc[0]) ||
                            (dec_load_size==2'd2 && (eff_calc[1:0] != 0))) begin
                            fault_q<=F_MISALIGNED; state<=S_FAULT;
                        end else state<=S_MEMORY;
                    end else begin
                        result_q<=alu_y; reg_write_q<=dec_reg_write; state<=S_WRITEBACK;
                    end
                end
                S_MEMORY: begin
                    if (mem_resp_ready) begin
                        if (mem_resp_error && mtvec != 0) begin
                            pc_q <= mtvec;
                            state <= S_FETCH;
                        end else if (mem_resp_error) begin fault_q<=F_BUS; state<=S_FAULT; end
                        else if (mem_write_q) begin pc_q<=next_pc_q; state<=S_FETCH; end
                        else begin result_q<=load_format(mem_resp_rdata,load_size_q,load_unsigned_q,eff_addr_q[1:0]); state<=S_WRITEBACK; end
                    end
                end
                S_MEXT_WAIT: begin
                    if (muldiv_done) begin
                        result_q <= muldiv_result;
                        reg_write_q <= 1'b1;
                        state <= S_WRITEBACK;
                    end
                end
                S_WFI: begin
                    if (csr_wfi_wakeup || trap_pending)
                        state <= S_FETCH;
                end
                S_WRITEBACK: begin
                    if (instr_q[6:0] != OP_JAL && instr_q[6:0] != OP_JALR) pc_q<=next_pc_q;
                    state<=S_FETCH;
                end
                default: state<=S_FAULT;
            endcase
        end
    end
endmodule
