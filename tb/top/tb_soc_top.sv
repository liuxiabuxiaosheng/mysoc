`timescale 1ns/1ps

module tb_soc_top;
    logic       clk_50m;
    logic       rst_n;
    logic       uart_rx;
    logic       uart_tx;
    logic [7:0] gpio_in;
    logic [7:0] gpio_out;
    logic [7:0] gpio_dir;
    logic       timer_irq;
    logic       phase1_ready;

    soc_top dut (
        .clk_50m(clk_50m),
        .rst_n(rst_n),
        .uart_rx(uart_rx),
        .uart_tx(uart_tx),
        .gpio_in(gpio_in),
        .gpio_out(gpio_out),
        .gpio_dir(gpio_dir),
        .timer_irq(timer_irq),
        .phase1_ready(phase1_ready)
    );

    always #10 clk_50m = ~clk_50m;

    task automatic check(input logic condition, input string message);
        begin
            if (!condition) $fatal(1, "%s", message);
        end
    endtask

    initial begin
        int cycles;

        clk_50m = 1'b0;
        rst_n   = 1'b0;
        uart_rx = 1'b1;
        gpio_in = 8'hA5;

        repeat (5) @(posedge clk_50m);
        #1;
        check(phase1_ready === 1'b0,
              "phase1_ready asserted while reset was active");

        @(negedge clk_50m);
        rst_n = 1'b1;

        cycles = 0;
        while ((phase1_ready !== 1'b1) && (cycles < 20)) begin
            @(posedge clk_50m);
            #1;
            cycles = cycles + 1;
        end

        check(phase1_ready === 1'b1,
              "phase1_ready did not assert within 20 input clocks");
        check(uart_tx === 1'b1, "UART TX was not idle high after reset");
        check(gpio_out === 8'h00, "GPIO outputs did not remain zero");
        check(gpio_dir === 8'h00, "GPIO directions did not remain zero");
        check(timer_irq === 1'b0, "timer IRQ did not remain clear");

        $display("PASS tb_soc_top");
        $finish;
    end
endmodule
