`timescale 1ns/1ps
module tb_soc_audio;
    localparam integer N = 40;
    localparam [31:0] SRC_ADDR = 32'h0000_0040;
    localparam [31:0] DST_ADDR = 32'h0000_0100;
    localparam [31:0] DMA_BASE = 32'h4000_5000;
    localparam [31:0] AUDIO_BASE = 32'h4000_3000;

    logic clk_50m, audio_clk, rst_n, audio_rst_n, uart_rx;
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

    logic signed [15:0] samples [0:N-1];
    logic signed [15:0] expected [0:N-1];

    soc_top #(.EXTERNAL_AUDIO_CLOCK(1'b1)) dut (
        .clk_50m(clk_50m), .rst_n(rst_n), .uart_rx(uart_rx), .gpio_in(gpio_in),
        .uart_tx(uart_tx), .gpio_out(gpio_out), .gpio_dir(gpio_dir), .timer_irq(timer_irq),
        .phase1_ready(phase1_ready), .cpu_req_valid(cpu_req_valid), .cpu_req_write(cpu_req_write),
        .cpu_req_addr(cpu_req_addr), .cpu_req_wdata(cpu_req_wdata), .cpu_req_wstrb(cpu_req_wstrb),
        .cpu_resp_rdata(cpu_resp_rdata), .cpu_resp_ready(cpu_resp_ready), .cpu_resp_error(cpu_resp_error),
        .cpu_halted(cpu_halted), .cpu_fault_code(cpu_fault_code),
        .audio_clk(audio_clk), .audio_rst_n(audio_rst_n)
    );

    always #10 clk_50m = ~clk_50m;
    always #40 audio_clk = ~audio_clk;


    task automatic cpu_write(input [31:0] addr, input [31:0] data);
        begin
            @(negedge clk_50m);
            cpu_req_valid = 1'b1; cpu_req_write = 1'b1;
            cpu_req_addr = addr; cpu_req_wdata = data; cpu_req_wstrb = 4'hf;
            do @(negedge clk_50m); while (!cpu_resp_ready && !cpu_resp_error);
            if (cpu_resp_error) $fatal(1, "CPU write error at %h", addr);
            cpu_req_valid = 1'b0; cpu_req_write = 1'b0; cpu_req_wstrb = 4'h0;
        end
    endtask

    task automatic cpu_read(input [31:0] addr, output [31:0] data);
        begin
            @(negedge clk_50m);
            cpu_req_valid = 1'b1; cpu_req_write = 1'b0;
            cpu_req_addr = addr; cpu_req_wdata = 32'h0; cpu_req_wstrb = 4'h0;
            do @(negedge clk_50m); while (!cpu_resp_ready && !cpu_resp_error);
            if (cpu_resp_error) $fatal(1, "CPU read error at %h", addr);
            data = cpu_resp_rdata;
            cpu_req_valid = 1'b0;
        end
    endtask

    function automatic signed [15:0] q15_identity(input signed [15:0] value);
        integer signed product;
        integer signed scaled;
        begin
            product = value * 16'sh7fff;
            if (product >= 0) scaled = (product + 16384) >>> 15;
            else scaled = (product - 16384) >>> 15;
            if (scaled > 32767) q15_identity = 16'sh7fff;
            else if (scaled < -32768) q15_identity = 16'sh8000;
            else q15_identity = scaled[15:0];
        end
    endfunction

    integer i, timeout;
    logic [31:0] value;
    logic input_done, output_done;
    initial begin
        clk_50m = 1'b0; audio_clk = 1'b0;
        rst_n = 1'b0; audio_rst_n = 1'b0; uart_rx = 1'b1; gpio_in = 8'h0;
        cpu_req_valid = 1'b0; cpu_req_write = 1'b0;
        cpu_req_addr = 32'h0; cpu_req_wdata = 32'h0; cpu_req_wstrb = 4'h0;

        for (i = 0; i < N; i = i + 1) begin
            samples[i] = (i[0]) ? (16'sd700 - i * 16'sd83) : (i * 16'sd137 - 16'sd900);
            expected[i] = q15_identity(samples[i]);
        end
        for (i = 0; i < N; i = i + 2) begin
                dut.u_onchip_ram.mem[16 + i/2] = {samples[i+1], samples[i]};
        end

        repeat (5) @(posedge clk_50m);
        rst_n = 1'b1;
        timeout = 0;
        while (!phase1_ready && timeout < 20) begin @(posedge clk_50m); timeout = timeout + 1; end
        if (!phase1_ready) $fatal(1, "system did not leave reset");
        repeat (3) @(posedge audio_clk);
        audio_rst_n = 1'b1;

        for (i = 0; i < 16; i = i + 1) begin
            cpu_write(AUDIO_BASE + 32'h10, i);
            cpu_write(AUDIO_BASE + 32'h14, (i == 0) ? 32'h0000_7fff : 32'h0000_0000);
        end
        cpu_write(AUDIO_BASE + 32'h00, 32'h1);

        cpu_write(DMA_BASE + 32'h00, SRC_ADDR);
        cpu_write(DMA_BASE + 32'h04, AUDIO_BASE + 32'h08);
        cpu_write(DMA_BASE + 32'h08, N/2);
        cpu_write(DMA_BASE + 32'h0c, 32'h1);
        input_done = 1'b0; timeout = 0;
        while (!input_done && timeout < 5000) begin
            cpu_read(DMA_BASE + 32'h10, value);
            input_done = value[1];
            timeout = timeout + 1;
        end
        if (!input_done) $fatal(1, "input DMA did not complete: %h", value);

        cpu_write(DMA_BASE + 32'h10, 32'h2);
        cpu_write(DMA_BASE + 32'h00, AUDIO_BASE + 32'h0c);
        cpu_write(DMA_BASE + 32'h04, DST_ADDR);
        cpu_write(DMA_BASE + 32'h08, N/2);
        cpu_write(DMA_BASE + 32'h0c, 32'h1);
        output_done = 1'b0; timeout = 0;
        while (!output_done && timeout < 5000) begin
            cpu_read(DMA_BASE + 32'h10, value);
            output_done = value[1];
            timeout = timeout + 1;
        end
        if (!output_done) $fatal(1, "output DMA did not complete: %h", value);

        timeout = 0;
        while (timeout < 1000) begin
            cpu_read(AUDIO_BASE + 32'h18, value);
            if (value == N) timeout = 1000;
            else timeout = timeout + 1;
        end
        if (dut.u_audio_pipeline.sample_count !== N)
            $fatal(1, "audio sample count mismatch: %0d", dut.u_audio_pipeline.sample_count);

        for (i = 0; i < N/2; i = i + 1) begin
            if (dut.u_onchip_ram.mem[64+i] !== {expected[2*i+1], expected[2*i]})
                $fatal(1, "audio output mismatch word %0d: got %h expected %h",
                       i, dut.u_onchip_ram.mem[64+i], {expected[2*i+1], expected[2*i]});
        end
        cpu_read(AUDIO_BASE + 32'h04, value);
        if (value[0] || value[1] || value[2] || value[3])
            $fatal(1, "audio FIFO status error: %h", value);
        if (!value[5])
            $fatal(1, "audio completion status missing: %h", value);
        $display("PASS tb_soc_audio");
        $finish;
    end
endmodule
