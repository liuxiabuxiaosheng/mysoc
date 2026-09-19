`timescale 1ns/1ps

module tb_apb_subsystem;
    localparam logic [31:0] GPIO_DATA    = 32'h4000_0000;
    localparam logic [31:0] GPIO_DIR     = 32'h4000_0004;
    localparam logic [31:0] GPIO_INPUT   = 32'h4000_0008;
    localparam logic [31:0] TIMER_CTRL   = 32'h4000_1000;
    localparam logic [31:0] TIMER_COMPARE = 32'h4000_1008;
    localparam logic [31:0] TIMER_STATUS = 32'h4000_100C;
    localparam logic [31:0] UART_DATA    = 32'h4000_2000;
    localparam logic [31:0] UART_STATUS  = 32'h4000_2004;
    localparam logic [31:0] UART_CTRL    = 32'h4000_2008;
    localparam logic [31:0] UART_BAUD    = 32'h4000_200C;

    logic        pclk;
    logic        rst_n;
    logic [31:0] paddr;
    logic        psel;
    logic        penable;
    logic        pwrite;
    logic [31:0] pwdata;
    logic [31:0] prdata;
    logic        pready;
    logic        pslverr;
    logic [7:0]  gpio_in;
    logic [7:0]  gpio_out;
    logic [7:0]  gpio_dir;
    logic        timer_irq;
    logic        uart_rx;
    logic        uart_tx;
    logic [31:0] rdata;
    logic        err;

    assign uart_rx = uart_tx;

    apb_subsystem dut (
        .clk(pclk),
        .rst_n(rst_n),
        .m_paddr(paddr),
        .m_psel(psel),
        .m_penable(penable),
        .m_pwrite(pwrite),
        .m_pwdata(pwdata),
        .m_prdata(prdata),
        .m_pready(pready),
        .m_pslverr(pslverr),
        .gpio_in(gpio_in),
        .gpio_out(gpio_out),
        .gpio_dir(gpio_dir),
        .timer_irq(timer_irq),
        .uart_rx(uart_rx),
        .uart_tx(uart_tx)
    );

    always #5 pclk = ~pclk;

    `include "apb_tasks.svh"

    task automatic check(input logic condition, input string message);
        begin
            if (!condition) $fatal(1, "%s", message);
        end
    endtask

    task automatic wait_rx_nonempty;
        int cycles;
        begin
            cycles = 0;
            do begin
                apb_read(UART_STATUS, rdata, err);
                check(!err, "UART STATUS read failed while waiting for loopback");
                cycles = cycles + 1;
                check(cycles < 4000, "timed out waiting for UART loopback byte");
            end while (rdata[2]);
        end
    endtask

    task automatic check_reset_state;
        begin
            check(gpio_out == 8'h00 && gpio_dir == 8'h00,
                  "GPIO outputs did not reset");
            check(timer_irq == 1'b0, "timer IRQ did not reset");
            check(uart_tx == 1'b1, "UART TX did not return to idle on reset");

            apb_read(GPIO_DATA, rdata, err);
            check(!err && rdata == 32'd0, "GPIO DATA reset value mismatch");
            apb_read(GPIO_DIR, rdata, err);
            check(!err && rdata == 32'd0, "GPIO DIR reset value mismatch");
            apb_read(TIMER_CTRL, rdata, err);
            check(!err && rdata == 32'd0, "timer CTRL reset value mismatch");
            apb_read(TIMER_COMPARE, rdata, err);
            check(!err && rdata == 32'd100, "timer COMPARE reset value mismatch");
            apb_read(TIMER_STATUS, rdata, err);
            check(!err && rdata == 32'd0, "timer STATUS reset value mismatch");
            apb_read(UART_CTRL, rdata, err);
            check(!err && rdata == 32'd0, "UART CTRL reset value mismatch");
            apb_read(UART_BAUD, rdata, err);
            check(!err && rdata == 32'd868, "UART BAUD reset value mismatch");
            apb_read(UART_STATUS, rdata, err);
            check(!err && rdata[5:0] == 6'b000101,
                  "UART STATUS reset value mismatch");
        end
    endtask

    initial begin
        pclk    = 1'b0;
        rst_n   = 1'b0;
        gpio_in = 8'h00;
        apb_idle();

        repeat (4) @(posedge pclk);
        @(negedge pclk);
        rst_n = 1'b1;

        apb_write(GPIO_DATA, 32'h0000_00A5, err);
        check(!err && gpio_out == 8'hA5, "GPIO DATA write failed");
        apb_read(GPIO_DATA, rdata, err);
        check(!err && rdata == 32'h0000_00A5, "GPIO DATA readback failed");
        apb_write(GPIO_DIR, 32'h0000_003C, err);
        check(!err && gpio_dir == 8'h3C, "GPIO DIR write failed");
        apb_read(GPIO_DIR, rdata, err);
        check(!err && rdata == 32'h0000_003C, "GPIO DIR readback failed");
        gpio_in = 8'h5A;
        apb_read(GPIO_INPUT, rdata, err);
        check(!err && rdata == 32'h0000_005A, "GPIO INPUT read failed");

        apb_write(TIMER_COMPARE, 32'd3, err);
        check(!err, "timer COMPARE write failed");
        apb_write(TIMER_CTRL, 32'h1, err);
        check(!err, "timer CTRL write failed");
        repeat (3) @(posedge pclk);
        #1;
        check(timer_irq == 1'b1, "timer IRQ did not become sticky");
        repeat (3) @(posedge pclk);
        check(timer_irq == 1'b1, "timer IRQ did not remain sticky");

        apb_write(UART_BAUD, 32'd8, err);
        check(!err, "UART BAUD write failed");
        apb_read(UART_BAUD, rdata, err);
        check(!err && rdata == 32'd8, "UART BAUD readback failed");
        apb_write(UART_CTRL, 32'h3, err);
        check(!err, "UART TX/RX enable failed");
        apb_write(UART_DATA, 32'h0000_00C7, err);
        check(!err, "UART C7 transmit write failed");
        wait_rx_nonempty();
        apb_read(UART_DATA, rdata, err);
        check(!err && rdata[7:0] == 8'hC7,
              $sformatf("UART loopback mismatch: err=%0b data=%02h", err, rdata[7:0]));

        apb_read(32'h4000_6000, rdata, err);
        check(err && rdata == 32'hDEAD_BEEF,
              "system-level unmapped access response mismatch");

        apb_write(UART_DATA, 32'h0000_005A, err);
        check(!err, "UART reset-transfer setup write failed");
        wait_rx_nonempty();

        @(negedge pclk);
        paddr   = UART_DATA;
        pwrite  = 1'b0;
        psel    = 1'b1;
        penable = 1'b0;
        @(negedge pclk);
        penable = 1'b1;
        #1;
        check(!pready, "UART DATA read did not enter its wait state");
        rst_n = 1'b0;
        #1;
        check(psel && penable, "UART transfer was not active when reset asserted");
        apb_idle();
        repeat (3) @(posedge pclk);
        @(negedge pclk);
        rst_n = 1'b1;

        check_reset_state();

        $display("PASS tb_apb_subsystem");
        $finish;
    end
endmodule
