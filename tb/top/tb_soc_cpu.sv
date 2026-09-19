`timescale 1ns/1ps
module tb_soc_cpu;
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

    soc_top #(.INTERNAL_CPU(1'b1)) dut(
        .clk_50m(clk_50m), .rst_n(rst_n), .uart_rx(uart_rx), .gpio_in(gpio_in),
        .uart_tx(uart_tx), .gpio_out(gpio_out), .gpio_dir(gpio_dir),
        .timer_irq(timer_irq), .phase1_ready(phase1_ready),
        .cpu_req_valid(cpu_req_valid), .cpu_req_write(cpu_req_write),
        .cpu_req_addr(cpu_req_addr), .cpu_req_wdata(cpu_req_wdata),
        .cpu_req_wstrb(cpu_req_wstrb), .cpu_resp_rdata(cpu_resp_rdata),
        .cpu_resp_ready(cpu_resp_ready), .cpu_resp_error(cpu_resp_error),
        .cpu_halted(cpu_halted), .cpu_fault_code(cpu_fault_code)
    );

    always #10 clk_50m = ~clk_50m;

    function automatic [31:0] lui(input [4:0] rd, input [19:0] imm);
        lui = {imm,rd,7'b0110111};
    endfunction
    function automatic [31:0] addi(input [4:0] rd, input [4:0] rs1, input integer imm);
        addi = {imm[11:0],rs1,3'b000,rd,7'b0010011};
    endfunction
    function automatic [31:0] sw(input [4:0] rs2, input [4:0] rs1, input integer imm);
        sw = {imm[11:5],rs2,rs1,3'b010,imm[4:0],7'b0100011};
    endfunction

    initial begin
        clk_50m=0; rst_n=0; uart_rx=1; gpio_in=0;
        cpu_req_valid=0; cpu_req_write=0; cpu_req_addr=0; cpu_req_wdata=0; cpu_req_wstrb=0;
        #1;
        dut.u_onchip_ram.mem[0] = addi(1,0,8'h5A);
        dut.u_onchip_ram.mem[1] = lui(2,20'h40000);
        dut.u_onchip_ram.mem[2] = sw(1,2,0);
        dut.u_onchip_ram.mem[3] = lui(3,20'h12345);
        dut.u_onchip_ram.mem[4] = addi(3,3,12'h678);
        dut.u_onchip_ram.mem[5] = sw(3,0,32);
        dut.u_onchip_ram.mem[6] = 32'h0000_0000;
        repeat (5) @(posedge clk_50m);
        rst_n=1;
        repeat (250) @(posedge clk_50m);
        if (!cpu_halted || cpu_fault_code !== 4'd1) $fatal(1, "CPU did not reach expected illegal-instruction halt");
        if (gpio_out !== 8'h5A) $fatal(1, "CPU GPIO program failed: %h", gpio_out);
        if (dut.u_onchip_ram.mem[8] !== 32'h1234_5678) $fatal(1, "CPU RAM store failed: %h", dut.u_onchip_ram.mem[8]);
        $display("PASS tb_soc_cpu");
        $finish;
    end
endmodule
