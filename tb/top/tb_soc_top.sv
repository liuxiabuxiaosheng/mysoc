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
    logic       cpu_req_valid;
    logic       cpu_req_write;
    logic [31:0] cpu_req_addr;
    logic [31:0] cpu_req_wdata;
    logic [3:0]  cpu_req_wstrb;
    logic [31:0] cpu_resp_rdata;
    logic        cpu_resp_ready;
    logic        cpu_resp_error;

    soc_top dut (
        .clk_50m(clk_50m),
        .rst_n(rst_n),
        .uart_rx(uart_rx),
        .uart_tx(uart_tx),
        .gpio_in(gpio_in),
        .gpio_out(gpio_out),
        .gpio_dir(gpio_dir),
        .timer_irq(timer_irq),
        .phase1_ready(phase1_ready),
        .cpu_req_valid(cpu_req_valid),
        .cpu_req_write(cpu_req_write),
        .cpu_req_addr(cpu_req_addr),
        .cpu_req_wdata(cpu_req_wdata),
        .cpu_req_wstrb(cpu_req_wstrb),
        .cpu_resp_rdata(cpu_resp_rdata),
        .cpu_resp_ready(cpu_resp_ready),
        .cpu_resp_error(cpu_resp_error)
    );

    always #10 clk_50m = ~clk_50m;

    task automatic check(input logic condition, input string message);
        begin
            if (!condition) $fatal(1, "%s", message);
        end
    endtask

    task automatic cpu_access(
        input logic        write_op,
        input logic [31:0] addr,
        input logic [31:0] wdata,
        input logic [3:0]  wstrb,
        output logic [31:0] rdata,
        output logic         failed
    );
        begin
            @(negedge clk_50m);
            cpu_req_valid = 1'b1;
            cpu_req_write = write_op;
            cpu_req_addr = addr;
            cpu_req_wdata = wdata;
            cpu_req_wstrb = wstrb;
            do @(posedge clk_50m); while (!cpu_resp_ready && !cpu_resp_error);
            rdata = cpu_resp_rdata;
            failed = cpu_resp_error;
            @(negedge clk_50m);
            cpu_req_valid = 1'b0;
            cpu_req_write = 1'b0;
            cpu_req_wstrb = '0;
        end
    endtask

    initial begin
        int cycles;
        logic [31:0] rdata;
        logic        failed;

        clk_50m = 1'b0;
        rst_n   = 1'b0;
        uart_rx = 1'b1;
        gpio_in = 8'hA5;
        cpu_req_valid = 1'b0;
        cpu_req_write = 1'b0;
        cpu_req_addr = '0;
        cpu_req_wdata = '0;
        cpu_req_wstrb = '0;

        repeat (5) @(posedge clk_50m);
        #1;
        check(phase1_ready === 1'b0,
              "phase1_ready asserted while reset was active");

        @(negedge clk_50m);
        rst_n = 1'b1;
        #1;
        check(phase1_ready === 1'b0,
              "phase1_ready asserted asynchronously with rst_n release");
        check(dut.rst_sync === 1'b0,
              "internal reset did not remain asserted at external release");
        check(dut.u_apb_subsystem.m_psel === 1'b0,
              "APB master selected a slave during reset release");

        @(posedge clk_50m); #1;
        check(phase1_ready === 1'b0 && dut.rst_sync === 1'b0,
              "phase1_ready bypassed synchronized reset release");
        check(dut.u_apb_subsystem.m_psel === 1'b0,
              "APB master selected a slave without a CPU request");

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

        cpu_access(1'b1, 32'h0000_0040, 32'h1357_9BDF, 4'hF, rdata, failed);
        check(!failed, "top-level CPU RAM write failed");
        cpu_access(1'b0, 32'h0000_0040, '0, '0, rdata, failed);
        check(!failed && rdata == 32'h1357_9BDF,
              "top-level CPU RAM read mismatch");
        cpu_access(1'b1, 32'h4000_0000, 32'h0000_00A5, 4'hF, rdata, failed);
        check(!failed && gpio_out == 8'hA5,
              "top-level CPU GPIO write did not reach APB");

        $display("PASS tb_soc_top");
        $finish;
    end
endmodule
