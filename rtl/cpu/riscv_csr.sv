module riscv_csr (
    input  logic        clk,
    input  logic        rst_n,
    input  logic [11:0] csr_addr,
    input  logic [2:0]  csr_cmd,
    input  logic [31:0] csr_wdata,
    output logic [31:0] csr_rdata,
    input  logic        trap_valid,
    input  logic        trap_interrupt,
    input  logic [31:0] trap_cause,
    input  logic [31:0] trap_pc,
    input  logic [31:0] trap_tval,
    input  logic        mret,
    input  logic        irq_timer,
    input  logic        irq_external,
    output logic [31:0] mtvec,
    output logic [31:0] mepc,
    output logic        mstatus_mie,
    output logic        mie_mtie,
    output logic        mie_meie,
    output logic        wfi_wakeup
);
    localparam logic [2:0] CSR_NONE = 3'd0;
    localparam logic [2:0] CSR_RW   = 3'd1;
    localparam logic [2:0] CSR_RS   = 3'd2;
    localparam logic [2:0] CSR_RC   = 3'd3;

    logic [31:0] mstatus_q, mie_q, mtvec_q, mscratch_q;
    logic [31:0] mepc_q, mcause_q, mtval_q;
    logic [31:0] cycle_q, time_q;
    logic        msip_q;
    logic [31:0] csr_next_value;
    logic [31:0] mip_value;

    assign mtvec       = mtvec_q;
    assign mepc        = mepc_q;
    assign mstatus_mie = mstatus_q[3];
    assign mie_mtie    = mie_q[7];
    assign mie_meie    = mie_q[11];
    assign mip_value   = {20'd0, irq_external, 3'd0, irq_timer, 3'd0, msip_q, 3'd0};
    assign wfi_wakeup  = (irq_timer && mie_q[7]) ||
                         (irq_external && mie_q[11]) ||
                         (msip_q && mie_q[3]);

    always_comb begin
        case (csr_addr)
            12'h300: csr_rdata = mstatus_q;
            12'h304: csr_rdata = mie_q;
            12'h305: csr_rdata = mtvec_q;
            12'h340: csr_rdata = mscratch_q;
            12'h341: csr_rdata = mepc_q;
            12'h342: csr_rdata = mcause_q;
            12'h343: csr_rdata = mtval_q;
            12'h344: csr_rdata = mip_value;
            12'hC00: csr_rdata = cycle_q;
            12'hC01: csr_rdata = time_q;
            default: csr_rdata = 32'h0;
        endcase
    end

    always_comb begin
        case (csr_cmd)
            CSR_RW: csr_next_value = csr_wdata;
            CSR_RS: csr_next_value = csr_rdata | csr_wdata;
            CSR_RC: csr_next_value = csr_rdata & ~csr_wdata;
            default: csr_next_value = csr_rdata;
        endcase
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mstatus_q  <= 32'h0000_1800;
            mie_q      <= 32'h0;
            mtvec_q     <= 32'h0;
            mscratch_q  <= 32'h0;
            mepc_q      <= 32'h0;
            mcause_q    <= 32'h0;
            mtval_q     <= 32'h0;
            cycle_q     <= 32'h0;
            time_q      <= 32'h0;
            msip_q      <= 1'b0;
        end else begin
            cycle_q <= cycle_q + 32'd1;
            time_q  <= time_q + 32'd1;

            if (trap_valid) begin
                mepc_q      <= trap_pc;
                mcause_q    <= {trap_interrupt, 31'd0} | trap_cause;
                mtval_q     <= trap_tval;
                mstatus_q[7] <= mstatus_q[3];
                mstatus_q[3] <= 1'b0;
                mstatus_q[12:11] <= 2'b11;
            end else if (mret) begin
                mstatus_q[3] <= mstatus_q[7];
                mstatus_q[7] <= 1'b1;
                mstatus_q[12:11] <= 2'b11;
            end else if (csr_cmd != CSR_NONE) begin
                case (csr_addr)
                    12'h300: mstatus_q <= {csr_next_value[31:13], 2'b11,
                                            csr_next_value[10:8],
                                            csr_next_value[7:3], 1'b0,
                                            csr_next_value[1:0]};
                    12'h304: mie_q <= csr_next_value & 32'h0000_0888;
                    12'h305: mtvec_q <= csr_next_value & 32'hffff_fffc;
                    12'h340: mscratch_q <= csr_next_value;
                    12'h341: mepc_q <= csr_next_value & 32'hffff_fffc;
                    12'h342: mcause_q <= csr_next_value;
                    12'h343: mtval_q <= csr_next_value;
                    12'h344: msip_q <= csr_next_value[3];
                    default: ;
                endcase
            end
        end
    end
endmodule
