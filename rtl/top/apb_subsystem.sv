module apb_subsystem (

    input  wire        clk,
    input  wire        rst_n,

    // APB Master Interface

    input  wire [31:0] m_paddr,
    input  wire        m_psel,
    input  wire        m_penable,
    input  wire        m_pwrite,
    input  wire [31:0] m_pwdata,

    output wire [31:0] m_prdata,
    output wire        m_pready,
    output wire        m_pslverr,

    // GPIO

    input  wire [7:0]  gpio_in,

    output wire [7:0]  gpio_out,
    output wire [7:0]  gpio_dir,

    // Timer

    output wire        timer_irq,
    output wire        cpu_timer_irq,
    output wire        cpu_external_irq,

    // UART

    input  wire        uart_rx,
    output wire        uart_tx,

    // DMA memory-master interface
    output wire        dma_mem_req_valid,
    output wire        dma_mem_req_write,
    output wire [31:0] dma_mem_req_addr,
    output wire [31:0] dma_mem_req_wdata,
    output wire [3:0]  dma_mem_req_wstrb,
    input  wire [31:0]  dma_mem_resp_rdata,
    input  wire         dma_mem_resp_ready,
    input  wire         dma_mem_resp_error,
    output wire         dma_fifo_in_valid,
    output wire signed [15:0] dma_fifo_in_data,
    input  wire          dma_fifo_in_ready,
    output wire          dma_fifo_out_ready,
    input  wire          dma_fifo_out_valid,
    input  wire signed [15:0] dma_fifo_out_data,

    // Audio control/status and FIR configuration
    output wire         audio_enable,
    output wire         audio_bypass,
    output wire         audio_clear_state,
    output wire         audio_coeff_we,
    output wire [3:0]   audio_coeff_index,
    output wire signed [15:0] audio_coeff_data,
    output wire [5:0]   audio_status_clear,
    input  wire [5:0]   audio_status,
    input  wire [31:0]  audio_sample_count,
    input  wire signed [15:0] audio_last_output

);


wire gpio_psel;
wire timer_psel;
wire uart_psel;
wire dma_psel;
wire audio_psel;
wire irq_psel;


// GPIO return
wire [31:0] gpio_prdata;
wire        gpio_pready;
wire        gpio_pslverr;


// Timer return
wire [31:0] timer_prdata;
wire        timer_pready;
wire        timer_pslverr;


// UART return
wire [31:0] uart_prdata;
wire        uart_pready;
wire        uart_pslverr;

wire [31:0] dma_prdata;
wire        dma_pready;
wire        dma_pslverr;
wire [31:0] audio_prdata;
wire        audio_pready;
wire        audio_pslverr;
wire [31:0] irq_prdata;
wire        irq_pready;
wire        irq_pslverr;
wire        dma_irq;
wire        uart_irq;



// =======================================
// APB Interconnect
// =======================================

apb_interconnect u_apb_interconnect (

    .m_paddr        (m_paddr),
    .m_psel         (m_psel),
    .m_penable      (m_penable),
    .m_pwrite       (m_pwrite),
    .m_pwdata       (m_pwdata),

    .m_prdata       (m_prdata),
    .m_pready       (m_pready),
    .m_pslverr      (m_pslverr),

    .gpio_psel      (gpio_psel),
    .gpio_prdata    (gpio_prdata),
    .gpio_pready    (gpio_pready),
    .gpio_pslverr   (gpio_pslverr),

    .timer_psel     (timer_psel),
    .timer_prdata   (timer_prdata),
    .timer_pready   (timer_pready),
    .timer_pslverr  (timer_pslverr),

    .uart_psel      (uart_psel),
    .uart_prdata    (uart_prdata),
    .uart_pready    (uart_pready),
    .uart_pslverr   (uart_pslverr),

    .dma_psel       (dma_psel),
    .dma_prdata     (dma_prdata),
    .dma_pready     (dma_pready),
    .dma_pslverr    (dma_pslverr),
    .audio_psel     (audio_psel),
    .audio_prdata   (audio_prdata),
    .audio_pready   (audio_pready),
    .audio_pslverr  (audio_pslverr),
    .irq_psel       (irq_psel),
    .irq_prdata     (irq_prdata),
    .irq_pready     (irq_pready),
    .irq_pslverr    (irq_pslverr)

);


// =======================================
// GPIO
// =======================================

apb_gpio #(

    .GPIO_WIDTH(8)

) u_gpio (

    .pclk       (clk),
    .presetn    (rst_n),

    .paddr      (m_paddr),
    .psel       (gpio_psel),
    .penable    (m_penable),
    .pwrite     (m_pwrite),
    .pwdata     (m_pwdata),

    .prdata     (gpio_prdata),
    .pready     (gpio_pready),
    .pslverr    (gpio_pslverr),

    .gpio_in    (gpio_in),
    .gpio_out   (gpio_out),
    .gpio_dir   (gpio_dir)

);


// =======================================
// Timer
// =======================================

apb_timer u_timer (

    .pclk       (clk),
    .presetn    (rst_n),

    .paddr      (m_paddr),
    .psel       (timer_psel),
    .penable    (m_penable),
    .pwrite     (m_pwrite),
    .pwdata     (m_pwdata),

    .prdata     (timer_prdata),
    .pready     (timer_pready),
    .pslverr    (timer_pslverr),

    .timer_irq  (timer_irq)

);


// =======================================
// UART
// =======================================

uart_top u_uart (

    .pclk       (clk),
    .presetn    (rst_n),

    .paddr      (m_paddr),
    .psel       (uart_psel),
    .penable    (m_penable),
    .pwrite     (m_pwrite),
    .pwdata     (m_pwdata),

    .prdata     (uart_prdata),
    .pready     (uart_pready),
    .pslverr    (uart_pslverr),

    .rx         (uart_rx),
    .tx         (uart_tx),
    .irq        (uart_irq)

);

dma_controller u_dma (
    .clk            (clk),
    .rst_n          (rst_n),
    .paddr          (m_paddr),
    .psel           (dma_psel),
    .penable        (m_penable),
    .pwrite         (m_pwrite),
    .pwdata         (m_pwdata),
    .prdata         (dma_prdata),
    .pready         (dma_pready),
    .pslverr        (dma_pslverr),
    .mem_req_valid  (dma_mem_req_valid),
    .mem_req_write  (dma_mem_req_write),
    .mem_req_addr   (dma_mem_req_addr),
    .mem_req_wdata  (dma_mem_req_wdata),
    .mem_req_wstrb  (dma_mem_req_wstrb),
    .mem_resp_rdata (dma_mem_resp_rdata),
    .mem_resp_ready (dma_mem_resp_ready),
    .mem_resp_error (dma_mem_resp_error),
    .fifo_in_valid  (dma_fifo_in_valid),
    .fifo_in_data   (dma_fifo_in_data),
    .fifo_in_ready  (dma_fifo_in_ready),
    .fifo_out_ready (dma_fifo_out_ready),
    .fifo_out_valid (dma_fifo_out_valid),
    .fifo_out_data  (dma_fifo_out_data),
    .irq            (dma_irq)
);

irq_controller u_irq_controller (
    .clk            (clk),
    .rst_n          (rst_n),
    .paddr          (m_paddr),
    .psel           (irq_psel),
    .penable        (m_penable),
    .pwrite         (m_pwrite),
    .pwdata         (m_pwdata),
    .prdata         (irq_prdata),
    .pready         (irq_pready),
    .pslverr        (irq_pslverr),
    .timer_src      (timer_irq),
    .dma_src        (dma_irq),
    .uart_src       (uart_irq),
    .cpu_timer_irq  (cpu_timer_irq),
    .cpu_external_irq(cpu_external_irq)
);

audio_ctrl u_audio_ctrl (
    .clk             (clk),
    .rst_n           (rst_n),
    .paddr           (m_paddr),
    .psel            (audio_psel),
    .penable         (m_penable),
    .pwrite          (m_pwrite),
    .pwdata          (m_pwdata),
    .prdata          (audio_prdata),
    .pready          (audio_pready),
    .pslverr         (audio_pslverr),
    .audio_enable    (audio_enable),
    .audio_bypass    (audio_bypass),
    .audio_clear_state(audio_clear_state),
    .coeff_we        (audio_coeff_we),
    .coeff_index     (audio_coeff_index),
    .coeff_data      (audio_coeff_data),
    .status_clear    (audio_status_clear),
    .status          (audio_status),
    .sample_count    (audio_sample_count),
    .last_output     (audio_last_output)
);


endmodule
