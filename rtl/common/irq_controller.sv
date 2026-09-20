module irq_controller (
    input  logic        clk,
    input  logic        rst_n,
    input  logic [31:0] paddr,
    input  logic        psel,
    input  logic        penable,
    input  logic        pwrite,
    input  logic [31:0] pwdata,
    output logic [31:0] prdata,
    output logic        pready,
    output logic        pslverr,
    input  logic        timer_src,
    input  logic        dma_src,
    input  logic        uart_src,
    output logic        cpu_timer_irq,
    output logic        cpu_external_irq
);
    logic [2:0] enable_q, pending_q;
    wire apb_access = psel && penable;
    wire valid_offset = (paddr[11:0] == 12'h000) ||
                        (paddr[11:0] == 12'h004) ||
                        (paddr[11:0] == 12'h008) ||
                        (paddr[11:0] == 12'h00c);
    wire apb_write = apb_access && pwrite && valid_offset;

    assign pready = 1'b1;
    assign pslverr = apb_access && !valid_offset;
    assign cpu_timer_irq = pending_q[0] && enable_q[0];
    assign cpu_external_irq = (pending_q[1] && enable_q[1]) ||
                              (pending_q[2] && enable_q[2]);

    always_comb begin
        case (paddr[11:0])
            12'h000: prdata = {29'd0, enable_q};
            12'h004: prdata = {29'd0, pending_q};
            12'h00c: prdata = {26'd0, cpu_external_irq, cpu_timer_irq, pending_q};
            default: prdata = 32'd0;
        endcase
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            enable_q <= 3'b000;
            pending_q <= 3'b000;
        end else begin
            if (apb_write && paddr[11:0] == 12'h000)
                enable_q <= pwdata[2:0];
            if (apb_write && paddr[11:0] == 12'h008)
                pending_q <= pending_q & ~pwdata[2:0];
            if (timer_src) pending_q[0] <= 1'b1;
            if (dma_src)   pending_q[1] <= 1'b1;
            if (uart_src)  pending_q[2] <= 1'b1;
        end
    end
endmodule
