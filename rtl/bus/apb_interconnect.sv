/*1. 地址译码
  2. 返回数据MUX
*/

module apb_interconnect (

    // =========================
    // Master side
    // =========================
    input  wire [31:0] m_paddr,
    input  wire        m_psel,
    input  wire        m_penable,
    input  wire        m_pwrite,
    input  wire [31:0] m_pwdata,

    output reg  [31:0] m_prdata,
    output reg         m_pready,
    output reg         m_pslverr,

    // =========================
    // GPIO Slave
    // =========================
    output wire        gpio_psel,

    input  wire [31:0] gpio_prdata,
    input  wire        gpio_pready,
    input  wire        gpio_pslverr,

    // =========================
    // TIMER Slave
    // =========================
    output wire        timer_psel,

    input  wire [31:0] timer_prdata,
    input  wire        timer_pready,
    input  wire        timer_pslverr,

    // =========================
    // UART Slave
    // =========================
    output wire        uart_psel,

    input  wire [31:0] uart_prdata,
    input  wire        uart_pready,
    input  wire        uart_pslverr,

    // =========================
    // DMA Slave
    // =========================
    output wire        dma_psel,

    input  wire [31:0] dma_prdata,
    input  wire        dma_pready,
    input  wire        dma_pslverr
);


wire gpio_sel;
wire timer_sel;
wire uart_sel;
wire dma_sel;


// GPIO:
// 0x4000_0000 ~ 0x4000_0FFF
assign gpio_sel =
    (m_paddr[31:12] == 20'h40000);


// TIMER:
// 0x4000_1000 ~ 0x4000_1FFF
assign timer_sel =
    (m_paddr[31:12] == 20'h40001);


// UART:
// 0x4000_2000 ~ 0x4000_2FFF
assign uart_sel =
    (m_paddr[31:12] == 20'h40002);

// DMA:
// 0x4000_5000 ~ 0x4000_5FFF
assign dma_sel =
    (m_paddr[31:12] == 20'h40005);


assign gpio_psel  = m_psel && gpio_sel;
assign timer_psel = m_psel && timer_sel;
assign uart_psel  = m_psel && uart_sel;
assign dma_psel   = m_psel && dma_sel;


// =========================
// 返回数据 MUX
// =========================

always @(*) begin

    m_prdata  = 32'h0000_0000;
    m_pready  = 1'b1;
    m_pslverr = 1'b0;

    if (m_psel && gpio_sel) begin

        m_prdata  = gpio_prdata;
        m_pready  = gpio_pready;
        m_pslverr = gpio_pslverr;

    end
    else if (m_psel && timer_sel) begin

        m_prdata  = timer_prdata;
        m_pready  = timer_pready;
        m_pslverr = timer_pslverr;

    end
    else if (m_psel && uart_sel) begin

        m_prdata  = uart_prdata;
        m_pready  = uart_pready;
        m_pslverr = uart_pslverr;

    end
    else if (m_psel && dma_sel) begin

        m_prdata  = dma_prdata;
        m_pready  = dma_pready;
        m_pslverr = dma_pslverr;

    end
    else if (m_psel) begin

        // 地址没有对应任何 Slave
        m_prdata  = 32'hDEAD_BEEF;
        m_pready  = 1'b1;
        m_pslverr = 1'b1;

    end

end


endmodule
