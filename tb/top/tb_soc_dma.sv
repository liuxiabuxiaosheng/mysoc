`timescale 1ns/1ps
module tb_soc_dma;
    logic clk_50m, rst_n, uart_rx;
    logic [7:0] gpio_in;
    wire uart_tx;
    wire [7:0] gpio_out, gpio_dir;
    wire timer_irq, phase1_ready;
    logic cpu_req_valid, cpu_req_write;
    logic [31:0] cpu_req_addr, cpu_req_wdata;
    logic [3:0] cpu_req_wstrb;
    wire [31:0] cpu_resp_rdata;
    wire cpu_resp_ready, cpu_resp_error, cpu_halted;
    wire [3:0] cpu_fault_code;

    soc_top dut (
        .clk_50m(clk_50m), .rst_n(rst_n), .uart_rx(uart_rx), .gpio_in(gpio_in),
        .uart_tx(uart_tx), .gpio_out(gpio_out), .gpio_dir(gpio_dir), .timer_irq(timer_irq),
        .phase1_ready(phase1_ready), .cpu_req_valid(cpu_req_valid), .cpu_req_write(cpu_req_write),
        .cpu_req_addr(cpu_req_addr), .cpu_req_wdata(cpu_req_wdata), .cpu_req_wstrb(cpu_req_wstrb),
        .cpu_resp_rdata(cpu_resp_rdata), .cpu_resp_ready(cpu_resp_ready), .cpu_resp_error(cpu_resp_error),
        .cpu_halted(cpu_halted), .cpu_fault_code(cpu_fault_code)
    );

    always #10 clk_50m = ~clk_50m;

    task automatic cpu_write(input [31:0] addr, input [31:0] data);
        begin
            @(negedge clk_50m);
            cpu_req_valid=1; cpu_req_write=1; cpu_req_addr=addr; cpu_req_wdata=data; cpu_req_wstrb=4'hf;
            do @(negedge clk_50m); while (!cpu_resp_ready);
            if (cpu_resp_error) $fatal(1, "CPU write error at %h", addr);
            cpu_req_valid=0; cpu_req_write=0; cpu_req_wstrb=0;
        end
    endtask

    task automatic cpu_read(input [31:0] addr, output [31:0] data);
        begin
            @(negedge clk_50m);
            cpu_req_valid=1; cpu_req_write=0; cpu_req_addr=addr; cpu_req_wdata=0; cpu_req_wstrb=0;
            do @(negedge clk_50m); while (!cpu_resp_ready);
            if (cpu_resp_error) $fatal(1, "CPU read error at %h", addr);
            data=cpu_resp_rdata;
            cpu_req_valid=0;
        end
    endtask

    logic [31:0] value;
    integer timeout;
    logic done_seen;
    initial begin
        clk_50m=0; rst_n=0; uart_rx=1; gpio_in=0;
        cpu_req_valid=0; cpu_req_write=0; cpu_req_addr=0; cpu_req_wdata=0; cpu_req_wstrb=0;
        #1;
        dut.u_onchip_ram.mem[16] = 32'h1111_2222;
        dut.u_onchip_ram.mem[17] = 32'h3333_4444;
        dut.u_onchip_ram.mem[18] = 32'h5555_6666;
        repeat (5) @(posedge clk_50m); rst_n=1;

        cpu_write(32'h4000_5000, 32'h40);
        cpu_write(32'h4000_5004, 32'h80);
        cpu_write(32'h4000_5008, 32'd3);
        cpu_write(32'h4000_500c, 32'h1);

        timeout = 0;
        done_seen = 1'b0;
        while ((timeout < 100) && !done_seen) begin
            cpu_read(32'h4000_5010, value);
            done_seen = value[1];
            timeout = timeout + 1;
        end
        if (!done_seen) $fatal(1, "DMA did not complete: %h", value);
        if (dut.u_onchip_ram.mem[32] !== 32'h1111_2222 ||
            dut.u_onchip_ram.mem[33] !== 32'h3333_4444 ||
            dut.u_onchip_ram.mem[34] !== 32'h5555_6666)
            $fatal(1, "DMA destination mismatch: %h %h %h", dut.u_onchip_ram.mem[32], dut.u_onchip_ram.mem[33], dut.u_onchip_ram.mem[34]);

        cpu_write(32'h4000_5010, 32'h2);
        cpu_write(32'h4000_5008, 32'd0);
        cpu_write(32'h4000_500c, 32'h1);
        cpu_read(32'h4000_5010, value);
        if (!value[2]) $fatal(1, "DMA zero-length error missing: %h", value);

        $display("PASS tb_soc_dma");
        $finish;
    end
endmodule
