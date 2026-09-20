`timescale 1ns/1ps
module tb_riscv_csr;
    logic clk, rst_n;
    logic [11:0] csr_addr;
    logic [2:0] csr_cmd;
    logic [31:0] csr_wdata, csr_rdata;
    logic trap_valid, trap_interrupt, mret;
    logic [31:0] trap_cause, trap_pc, trap_tval;
    logic irq_timer, irq_external;
    logic [31:0] mtvec;
    logic mstatus_mie, mie_mtie, mie_meie, wfi_wakeup;

    localparam [2:0] CSR_NONE=3'd0, CSR_RW=3'd1, CSR_RS=3'd2, CSR_RC=3'd3;

    riscv_csr dut (
        .clk(clk), .rst_n(rst_n), .csr_addr(csr_addr), .csr_cmd(csr_cmd),
        .csr_wdata(csr_wdata), .csr_rdata(csr_rdata),
        .trap_valid(trap_valid), .trap_interrupt(trap_interrupt),
        .trap_cause(trap_cause), .trap_pc(trap_pc), .trap_tval(trap_tval),
        .mret(mret), .irq_timer(irq_timer), .irq_external(irq_external),
        .mtvec(mtvec), .mstatus_mie(mstatus_mie), .mie_mtie(mie_mtie),
        .mie_meie(mie_meie), .wfi_wakeup(wfi_wakeup)
    );

    always #5 clk = ~clk;

    task automatic csr_write(input [11:0] addr, input [31:0] data);
        begin
            @(negedge clk); csr_addr=addr; csr_wdata=data; csr_cmd=CSR_RW;
            @(negedge clk); csr_cmd=CSR_NONE;
        end
    endtask

    task automatic csr_read(input [11:0] addr, output [31:0] data);
        begin
            @(negedge clk); csr_addr=addr; csr_cmd=CSR_NONE; #1; data=csr_rdata;
        end
    endtask

    logic [31:0] value;
    initial begin
        clk=0; rst_n=0; csr_addr=0; csr_cmd=CSR_NONE; csr_wdata=0;
        trap_valid=0; trap_interrupt=0; trap_cause=0; trap_pc=0; trap_tval=0;
        mret=0; irq_timer=0; irq_external=0;
        repeat (2) @(posedge clk); rst_n=1;

        csr_write(12'h305, 32'h0000_0103);
        csr_read(12'h305, value);
        if (value !== 32'h0000_0100 || mtvec !== 32'h0000_0100)
            $fatal(1, "mtvec direct alignment failed: %h", value);

        csr_write(12'h304, 32'h0000_0880);
        csr_write(12'h300, 32'h0000_0008);
        if (!mstatus_mie || !mie_mtie || !mie_meie)
            $fatal(1, "interrupt enables were not stored");
        irq_timer=1;
        #1;
        if (!wfi_wakeup) $fatal(1, "enabled timer interrupt did not wake WFI");

        @(negedge clk);
        trap_valid=1; trap_interrupt=0; trap_cause=32'd8;
        trap_pc=32'h0000_0020; trap_tval=32'h0000_0073;
        @(negedge clk); trap_valid=0;
        csr_read(12'h341, value);
        if (value !== 32'h0000_0020) $fatal(1, "mepc mismatch: %h", value);
        csr_read(12'h342, value);
        if (value !== 32'd8) $fatal(1, "mcause mismatch: %h", value);
        csr_read(12'h343, value);
        if (value !== 32'h0000_0073) $fatal(1, "mtval mismatch: %h", value);
        if (mstatus_mie) $fatal(1, "MIE was not cleared on trap");

        @(negedge clk); mret=1;
        @(negedge clk); mret=0;
        if (!mstatus_mie) $fatal(1, "MIE was not restored by MRET");
        $display("PASS tb_riscv_csr");
        $finish;
    end
endmodule
