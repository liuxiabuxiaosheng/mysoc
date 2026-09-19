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

    output wire        timer_irq

);


wire gpio_psel;
wire timer_psel;


// GPIO return
wire [31:0] gpio_prdata;
wire        gpio_pready;
wire        gpio_pslverr;


// Timer return
wire [31:0] timer_prdata;
wire        timer_pready;
wire        timer_pslverr;



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
    .timer_pslverr  (timer_pslverr)

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


endmodule