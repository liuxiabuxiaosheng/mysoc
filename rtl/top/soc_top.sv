module soc_top #(
    parameter INTERNAL_CPU = 1'b0,
    parameter EXTERNAL_AUDIO_CLOCK = 1'b0
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
    output wire [3:0]  cpu_fault_code,
    input  wire        audio_clk,
    input  wire        audio_rst_n
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
wire [31:0] ram_phys_resp_rdata;
wire        ram_phys_resp_ready;
wire        ram_phys_resp_error;

wire        dma_mem_req_valid;
wire        dma_mem_req_write;
wire [31:0] dma_mem_req_addr;
wire [31:0] dma_mem_req_wdata;
wire [3:0]  dma_mem_req_wstrb;
wire [31:0] dma_mem_resp_rdata;
wire        dma_mem_resp_ready;
wire        dma_mem_resp_error;
wire        dma_fifo_in_valid;
wire signed [15:0] dma_fifo_in_data;
wire        dma_fifo_in_ready;
wire        dma_fifo_out_ready;
wire        dma_fifo_out_valid;
wire signed [15:0] dma_fifo_out_data;
wire        audio_enable;
wire        audio_bypass;
wire        audio_clear_state;
wire        audio_coeff_we;
wire [3:0]  audio_coeff_index;
wire signed [15:0] audio_coeff_data;
wire [5:0]  audio_status_clear;
wire [5:0]  audio_status;
wire [31:0] audio_sample_count;
wire signed [15:0] audio_last_output;
wire        audio_clk_used;
wire        audio_rst_used;

reg         ram_master_req_valid;
reg         ram_master_req_write;
reg [31:0]  ram_master_req_addr;
reg [31:0]  ram_master_req_wdata;
reg [3:0]   ram_master_req_wstrb;

localparam [1:0] RAM_OWNER_NONE = 2'd0;
localparam [1:0] RAM_OWNER_CPU  = 2'd1;
localparam [1:0] RAM_OWNER_DMA  = 2'd2;
reg [1:0] ram_owner;

assign audio_clk_used = EXTERNAL_AUDIO_CLOCK ? audio_clk : clk_sys;
assign audio_rst_used = EXTERNAL_AUDIO_CLOCK ? audio_rst_n : rst_sync;

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
    .req_valid(ram_master_req_valid),
    .req_write(ram_master_req_write),
    .req_addr(ram_master_req_addr),
    .req_wdata(ram_master_req_wdata),
    .req_wstrb(ram_master_req_wstrb),
    .resp_rdata(ram_phys_resp_rdata),
    .resp_ready(ram_phys_resp_ready),
    .resp_error(ram_phys_resp_error)
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
    .uart_tx(uart_tx),
    .dma_mem_req_valid(dma_mem_req_valid),
    .dma_mem_req_write(dma_mem_req_write),
    .dma_mem_req_addr(dma_mem_req_addr),
    .dma_mem_req_wdata(dma_mem_req_wdata),
    .dma_mem_req_wstrb(dma_mem_req_wstrb),
    .dma_mem_resp_rdata(dma_mem_resp_rdata),
    .dma_mem_resp_ready(dma_mem_resp_ready),
    .dma_mem_resp_error(dma_mem_resp_error),
    .dma_fifo_in_valid(dma_fifo_in_valid),
    .dma_fifo_in_data(dma_fifo_in_data),
    .dma_fifo_in_ready(dma_fifo_in_ready),
    .dma_fifo_out_ready(dma_fifo_out_ready),
    .dma_fifo_out_valid(dma_fifo_out_valid),
    .dma_fifo_out_data(dma_fifo_out_data),
    .audio_enable(audio_enable),
    .audio_bypass(audio_bypass),
    .audio_clear_state(audio_clear_state),
    .audio_coeff_we(audio_coeff_we),
    .audio_coeff_index(audio_coeff_index),
    .audio_coeff_data(audio_coeff_data),
    .audio_status_clear(audio_status_clear),
    .audio_status(audio_status),
    .audio_sample_count(audio_sample_count),
    .audio_last_output(audio_last_output)
);

audio_pipeline u_audio_pipeline (
    .sys_clk(clk_sys),
    .sys_rst_n(rst_sync),
    .audio_clk(audio_clk_used),
    .audio_rst_n(audio_rst_used),
    .input_push_valid(dma_fifo_in_valid),
    .input_push_data(dma_fifo_in_data),
    .input_push_ready(dma_fifo_in_ready),
    .output_pop_valid(dma_fifo_out_valid),
    .output_pop_data(dma_fifo_out_data),
    .output_pop_ready(dma_fifo_out_ready),
    .enable(audio_enable),
    .bypass(audio_bypass),
    .clear_state(audio_clear_state),
    .coeff_we(audio_coeff_we),
    .coeff_index(audio_coeff_index),
    .coeff_data(audio_coeff_data),
    .status_clear(audio_status_clear),
    .status(audio_status),
    .sample_count(audio_sample_count),
    .last_output(audio_last_output)
);

always @(*) begin
    ram_master_req_valid = 1'b0;
    ram_master_req_write = 1'b0;
    ram_master_req_addr  = 32'b0;
    ram_master_req_wdata = 32'b0;
    ram_master_req_wstrb = 4'b0;
    if (ram_owner == RAM_OWNER_CPU) begin
        ram_master_req_valid = ram_req_valid;
        ram_master_req_write = ram_req_write;
        ram_master_req_addr  = ram_req_addr;
        ram_master_req_wdata = ram_req_wdata;
        ram_master_req_wstrb = ram_req_wstrb;
    end else if (ram_owner == RAM_OWNER_DMA) begin
        ram_master_req_valid = dma_mem_req_valid;
        ram_master_req_write = dma_mem_req_write;
        ram_master_req_addr  = dma_mem_req_addr;
        ram_master_req_wdata = dma_mem_req_wdata;
        ram_master_req_wstrb = dma_mem_req_wstrb;
    end else if (ram_req_valid) begin
        ram_master_req_valid = ram_req_valid;
        ram_master_req_write = ram_req_write;
        ram_master_req_addr  = ram_req_addr;
        ram_master_req_wdata = ram_req_wdata;
        ram_master_req_wstrb = ram_req_wstrb;
    end else begin
        ram_master_req_valid = dma_mem_req_valid;
        ram_master_req_write = dma_mem_req_write;
        ram_master_req_addr  = dma_mem_req_addr;
        ram_master_req_wdata = dma_mem_req_wdata;
        ram_master_req_wstrb = dma_mem_req_wstrb;
    end
end

assign ram_resp_ready = (ram_owner == RAM_OWNER_CPU) && ram_phys_resp_ready;
assign ram_resp_rdata = ram_phys_resp_rdata;
assign ram_resp_error = (ram_owner == RAM_OWNER_CPU) && ram_phys_resp_error;
assign dma_mem_resp_ready = (ram_owner == RAM_OWNER_DMA) && ram_phys_resp_ready;
assign dma_mem_resp_rdata = ram_phys_resp_rdata;
assign dma_mem_resp_error = (ram_owner == RAM_OWNER_DMA) && ram_phys_resp_error;

always @(posedge clk_sys or negedge rst_sync) begin
    if (!rst_sync) begin
        ram_owner <= RAM_OWNER_NONE;
    end else begin
        case (ram_owner)
            RAM_OWNER_NONE: begin
                if (ram_req_valid)
                    ram_owner <= RAM_OWNER_CPU;
                else if (dma_mem_req_valid)
                    ram_owner <= RAM_OWNER_DMA;
            end
            RAM_OWNER_CPU: begin
                if (ram_phys_resp_ready)
                    ram_owner <= RAM_OWNER_NONE;
            end
            RAM_OWNER_DMA: begin
                if (ram_phys_resp_ready)
                    ram_owner <= RAM_OWNER_NONE;
            end
            default: ram_owner <= RAM_OWNER_NONE;
        endcase
    end
end

assign phase1_ready = locked && rst_sync;

endmodule
