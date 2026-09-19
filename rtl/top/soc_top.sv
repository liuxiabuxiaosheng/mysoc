module soc_top #(
    parameter INTERNAL_CPU = 1'b0
)(
    input  wire       clk_50m,
    input  wire       rst_n,
    input  wire       uart_rx,
    input  wire [7:0] gpio_in,

    output wire       uart_tx,
    output wire [7:0] gpio_out,
    output wire [7:0] gpio_dir,
    output wire       timer_irq,
    output wire       phase1_ready,

    input  wire       cpu_req_valid,
    input  wire       cpu_req_write,
    input  wire [31:0] cpu_req_addr,
    input  wire [31:0] cpu_req_wdata,
    input  wire [3:0]  cpu_req_wstrb,
    output wire [31:0] cpu_resp_rdata,
    output wire        cpu_resp_ready,
    output wire        cpu_resp_error,
    output wire        cpu_halted,
    output wire [3:0]  cpu_fault_code
);

wire rst_sync;
wire clk_sys;
wire locked;

wire        ram_req_valid;
wire        ram_req_write;
wire [31:0] ram_req_addr;
wire [31:0] ram_req_wdata;
wire [3:0]  ram_req_wstrb;
wire [31:0] ram_resp_rdata;
wire        ram_resp_ready;
wire        ram_resp_error;

wire        apb_req_valid;
wire        apb_req_write;
wire [31:0] apb_req_addr;
wire [31:0] apb_req_wdata;
wire [3:0]  apb_req_wstrb;
wire [31:0] apb_resp_rdata;
wire        apb_resp_ready;
wire        apb_resp_error;

wire [31:0] apb_paddr;
wire        apb_psel;
wire        apb_penable;
wire        apb_pwrite;
wire [31:0] apb_pwdata;
wire [3:0]  apb_pstrb;
wire [31:0] apb_prdata;
wire        apb_pready;
wire        apb_pslverr;
wire [31:0] decoder_resp_rdata;
wire        decoder_resp_ready;
wire        decoder_resp_error;

wire        bus_cpu_req_valid;
wire        bus_cpu_req_write;
wire [31:0] bus_cpu_req_addr;
wire [31:0] bus_cpu_req_wdata;
wire [3:0]  bus_cpu_req_wstrb;
wire [31:0] core_resp_rdata;
wire        core_resp_ready;
wire        core_resp_error;
wire        core_halted;
wire [3:0]  core_fault_code;

generate
    if (INTERNAL_CPU) begin : g_internal_cpu
        riscv_core u_riscv_core (
            .clk(clk_sys), .rst_n(rst_sync),
            .mem_req_valid(bus_cpu_req_valid), .mem_req_write(bus_cpu_req_write),
            .mem_req_addr(bus_cpu_req_addr), .mem_req_wdata(bus_cpu_req_wdata),
            .mem_req_wstrb(bus_cpu_req_wstrb),
            .mem_resp_rdata(decoder_resp_rdata), .mem_resp_ready(decoder_resp_ready),
            .mem_resp_error(decoder_resp_error), .halted(core_halted),
            .fault_code(core_fault_code), .dbg_pc()
        );
    end else begin : g_external_cpu
        assign bus_cpu_req_valid = cpu_req_valid;
        assign bus_cpu_req_write = cpu_req_write;
        assign bus_cpu_req_addr = cpu_req_addr;
        assign bus_cpu_req_wdata = cpu_req_wdata;
        assign bus_cpu_req_wstrb = cpu_req_wstrb;
        assign core_halted = 1'b0;
        assign core_fault_code = 4'b0;
        assign core_resp_rdata = 32'b0;
        assign core_resp_ready = 1'b0;
        assign core_resp_error = 1'b0;
    end
endgenerate

assign cpu_halted = core_halted;
assign cpu_fault_code = core_fault_code;
assign cpu_resp_rdata = decoder_resp_rdata;
assign cpu_resp_ready = decoder_resp_ready;
assign cpu_resp_error = decoder_resp_error;

reset_sync u_reset(
    .clk(clk_50m),
    .rst_n(rst_n),
    .rst_sync(rst_sync)
);

clk_gen u_clk(
    .clk_in(clk_50m),
    .rst_n(rst_sync),
    .clk_sys(clk_sys),
    .locked(locked)
);

cpu_bus_decoder u_cpu_bus_decoder (
    .clk(clk_sys),
    .rst_n(rst_sync),
    .cpu_req_valid(bus_cpu_req_valid),
    .cpu_req_write(bus_cpu_req_write),
    .cpu_req_addr(bus_cpu_req_addr),
    .cpu_req_wdata(bus_cpu_req_wdata),
    .cpu_req_wstrb(bus_cpu_req_wstrb),
    .cpu_resp_rdata(decoder_resp_rdata),
    .cpu_resp_ready(decoder_resp_ready),
    .cpu_resp_error(decoder_resp_error),
    .ram_req_valid(ram_req_valid),
    .ram_req_write(ram_req_write),
    .ram_req_addr(ram_req_addr),
    .ram_req_wdata(ram_req_wdata),
    .ram_req_wstrb(ram_req_wstrb),
    .ram_resp_rdata(ram_resp_rdata),
    .ram_resp_ready(ram_resp_ready),
    .ram_resp_error(ram_resp_error),
    .apb_req_valid(apb_req_valid),
    .apb_req_write(apb_req_write),
    .apb_req_addr(apb_req_addr),
    .apb_req_wdata(apb_req_wdata),
    .apb_req_wstrb(apb_req_wstrb),
    .apb_resp_rdata(apb_resp_rdata),
    .apb_resp_ready(apb_resp_ready),
    .apb_resp_error(apb_resp_error)
);

onchip_ram u_onchip_ram (
    .clk(clk_sys),
    .rst_n(rst_sync),
    .req_valid(ram_req_valid),
    .req_write(ram_req_write),
    .req_addr(ram_req_addr),
    .req_wdata(ram_req_wdata),
    .req_wstrb(ram_req_wstrb),
    .resp_rdata(ram_resp_rdata),
    .resp_ready(ram_resp_ready),
    .resp_error(ram_resp_error)
);

cpu_apb_bridge u_cpu_apb_bridge (
    .clk(clk_sys),
    .rst_n(rst_sync),
    .req_valid(apb_req_valid),
    .req_write(apb_req_write),
    .req_addr(apb_req_addr),
    .req_wdata(apb_req_wdata),
    .req_wstrb(apb_req_wstrb),
    .resp_rdata(apb_resp_rdata),
    .resp_ready(apb_resp_ready),
    .resp_error(apb_resp_error),
    .paddr(apb_paddr),
    .psel(apb_psel),
    .penable(apb_penable),
    .pwrite(apb_pwrite),
    .pwdata(apb_pwdata),
    .pstrb(apb_pstrb),
    .prdata(apb_prdata),
    .pready(apb_pready),
    .pslverr(apb_pslverr)
);

apb_subsystem u_apb_subsystem (
    .clk(clk_sys),
    .rst_n(rst_sync),
    .m_paddr(apb_paddr),
    .m_psel(apb_psel),
    .m_penable(apb_penable),
    .m_pwrite(apb_pwrite),
    .m_pwdata(apb_pwdata),
    .m_prdata(apb_prdata),
    .m_pready(apb_pready),
    .m_pslverr(apb_pslverr),
    .gpio_in(gpio_in),
    .gpio_out(gpio_out),
    .gpio_dir(gpio_dir),
    .timer_irq(timer_irq),
    .uart_rx(uart_rx),
    .uart_tx(uart_tx)
);

assign phase1_ready = locked && rst_sync;

endmodule
