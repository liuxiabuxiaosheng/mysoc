`timescale 1ns/1ps

module tb_apb_interconnect;
    logic        pclk;
    logic [31:0] m_paddr;
    logic        m_psel;
    logic        m_penable;
    logic        m_pwrite;
    logic [31:0] m_pwdata;
    logic [31:0] m_prdata;
    logic        m_pready;
    logic        m_pslverr;

    logic        gpio_psel;
    logic [31:0] gpio_prdata;
    logic        gpio_pready;
    logic        gpio_pslverr;
    logic        timer_psel;
    logic [31:0] timer_prdata;
    logic        timer_pready;
    logic        timer_pslverr;
    logic        uart_psel;
    logic [31:0] uart_prdata;
    logic        uart_pready;
    logic        uart_pslverr;

    apb_interconnect dut (
        .m_paddr(m_paddr),
        .m_psel(m_psel),
        .m_penable(m_penable),
        .m_pwrite(m_pwrite),
        .m_pwdata(m_pwdata),
        .m_prdata(m_prdata),
        .m_pready(m_pready),
        .m_pslverr(m_pslverr),
        .gpio_psel(gpio_psel),
        .gpio_prdata(gpio_prdata),
        .gpio_pready(gpio_pready),
        .gpio_pslverr(gpio_pslverr),
        .timer_psel(timer_psel),
        .timer_prdata(timer_prdata),
        .timer_pready(timer_pready),
        .timer_pslverr(timer_pslverr),
        .uart_psel(uart_psel),
        .uart_prdata(uart_prdata),
        .uart_pready(uart_pready),
        .uart_pslverr(uart_pslverr)
    );

    always #5 pclk = ~pclk;

    task automatic check(input logic condition, input string message);
        begin
            if (!condition) $fatal(1, "%s", message);
        end
    endtask

    task automatic start_transfer(input logic [31:0] address,
                                  input logic write_enable,
                                  input logic [31:0] write_data);
        begin
            @(negedge pclk);
            m_paddr   = address;
            m_psel    = 1'b1;
            m_penable = 1'b0;
            m_pwrite  = write_enable;
            m_pwdata  = write_data;
            #1;
        end
    endtask

    task automatic enter_access;
        begin
            @(negedge pclk);
            m_penable = 1'b1;
            #1;
        end
    endtask

    task automatic finish_transfer;
        begin
            @(negedge pclk);
            m_psel    = 1'b0;
            m_penable = 1'b0;
            #1;
        end
    endtask

    initial begin
        pclk          = 1'b0;
        m_paddr       = 32'd0;
        m_psel        = 1'b0;
        m_penable     = 1'b0;
        m_pwrite      = 1'b0;
        m_pwdata      = 32'd0;
        gpio_prdata   = 32'h1111_0001;
        gpio_pready   = 1'b1;
        gpio_pslverr  = 1'b0;
        timer_prdata  = 32'h2222_0002;
        timer_pready  = 1'b1;
        timer_pslverr = 1'b1;
        uart_prdata   = 32'h3333_0003;
        uart_pready   = 1'b1;
        uart_pslverr  = 1'b0;

        #1;
        m_paddr = 32'h4000_0000;
        #1;
        check({uart_psel, timer_psel, gpio_psel} == 3'b000,
              "slave select asserted while master PSEL was low");
        check(m_prdata == 32'd0 && m_pready && !m_pslverr,
              "idle response depended on decoded slave");

        start_transfer(32'h4000_0000, 1'b0, 32'd0);
        check({uart_psel, timer_psel, gpio_psel} == 3'b001,
              "GPIO setup phase was not one-hot selected");
        check(m_prdata == gpio_prdata && m_pready == gpio_pready &&
              m_pslverr == gpio_pslverr, "GPIO response was not propagated");
        enter_access();
        check({uart_psel, timer_psel, gpio_psel} == 3'b001,
              "GPIO access phase selection changed");
        finish_transfer();

        start_transfer(32'h4000_1000, 1'b1, 32'hA5A5_5A5A);
        check({uart_psel, timer_psel, gpio_psel} == 3'b010,
              "timer setup phase was not one-hot selected");
        check(m_prdata == timer_prdata && m_pready == timer_pready &&
              m_pslverr == timer_pslverr, "timer response was not propagated");
        enter_access();
        check({uart_psel, timer_psel, gpio_psel} == 3'b010,
              "timer access phase selection changed");
        finish_transfer();

        uart_pready = 1'b0;
        start_transfer(32'h4000_2000, 1'b1, 32'h0000_00C7);
        check({uart_psel, timer_psel, gpio_psel} == 3'b100,
              "UART setup phase was not one-hot selected");
        check(m_prdata == uart_prdata && !m_pready && !m_pslverr,
              "UART setup response was not propagated");
        enter_access();
        @(posedge pclk); #1;
        check(uart_psel && !m_pready && m_prdata == uart_prdata &&
              m_pslverr == uart_pslverr,
              "UART wait response was not propagated on access cycle 1");
        check(m_paddr == 32'h4000_2000 && m_psel && m_penable && m_pwrite &&
              m_pwdata == 32'h0000_00C7,
              "master address/control changed during UART wait cycle 1");
        @(posedge pclk); #1;
        check(uart_psel && !m_pready && m_prdata == uart_prdata &&
              m_pslverr == uart_pslverr,
              "UART wait response was not propagated on access cycle 2");
        check(m_paddr == 32'h4000_2000 && m_psel && m_penable && m_pwrite &&
              m_pwdata == 32'h0000_00C7,
              "master address/control changed during UART wait cycle 2");
        @(negedge pclk);
        uart_pslverr = 1'b1;
        uart_pready  = 1'b1;
        @(posedge pclk); #1;
        check(m_psel && m_penable && uart_psel && m_pready &&
              m_prdata == uart_prdata && m_pslverr,
              "UART transfer did not complete with a valid access response");
        finish_transfer();

        start_transfer(32'h4000_6000, 1'b0, 32'd0);
        check({uart_psel, timer_psel, gpio_psel} == 3'b000,
              "unmapped setup selected a slave");
        check(m_prdata == 32'hDEAD_BEEF && m_pready && m_pslverr,
              "unmapped setup response mismatch");
        enter_access();
        check(m_prdata == 32'hDEAD_BEEF && m_pready && m_pslverr,
              "unmapped access response mismatch");
        finish_transfer();

        check({uart_psel, timer_psel, gpio_psel} == 3'b000,
              "slave select remained asserted after transfer");
        $display("PASS tb_apb_interconnect");
        $finish;
    end
endmodule
