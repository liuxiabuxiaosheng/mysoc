`timescale 1ns/1ps
module tb_fir_filter;
    logic clk, rst_n;
    logic in_valid, out_ready, coeff_we;
    logic signed [15:0] in_sample, coeff_data;
    logic [3:0] coeff_index;
    wire in_ready, out_valid;
    wire signed [15:0] out_sample;

    fir_filter dut (
        .clk(clk), .rst_n(rst_n),
        .in_valid(in_valid), .in_ready(in_ready), .in_sample(in_sample),
        .coeff_we(coeff_we), .coeff_index(coeff_index), .coeff_data(coeff_data),
        .out_valid(out_valid), .out_ready(out_ready), .out_sample(out_sample)
    );

    always #5 clk = ~clk;

    task automatic coeff_write(input [3:0] index, input signed [15:0] value);
        begin
            @(negedge clk); coeff_index=index; coeff_data=value; coeff_we=1;
            @(negedge clk); coeff_we=0;
        end
    endtask

    task automatic sample_expect(input signed [15:0] value, input signed [15:0] expected);
        begin
            @(negedge clk);
            while (!in_ready) @(negedge clk);
            in_sample=value; in_valid=1;
            @(posedge clk); #1;
            in_valid=0;
            if (!out_valid || out_sample !== expected)
                $fatal(1, "FIR output mismatch: got %0d expected %0d", out_sample, expected);
        end
    endtask

    initial begin
        clk=0; rst_n=0; in_valid=0; in_sample=0; out_ready=1; coeff_we=0; coeff_index=0; coeff_data=0;
        repeat (2) @(posedge clk); rst_n=1;

        coeff_write(0, 16'sd16384);
        coeff_write(1, 16'sd8192);
        sample_expect(16'sd32767, 16'sd16384);
        sample_expect(16'sd0, 16'sd8192);
        sample_expect(16'sd0, 16'sd0);

        @(posedge clk); #1;
        out_ready=0;
        @(negedge clk); while (!in_ready) @(negedge clk); in_sample=16'sd100; in_valid=1;
        @(posedge clk); #1; in_valid=0;
        if (!out_valid || in_ready) $fatal(1, "FIR backpressure not applied");
        repeat (2) @(posedge clk);
        if (out_sample !== 16'sd50) $fatal(1, "FIR held output changed under backpressure");
        out_ready=1;
        @(posedge clk); #1;

        rst_n=0;
        repeat (2) @(posedge clk); rst_n=1;
        coeff_write(0, 16'sd32767);
        coeff_write(1, 16'sd32767);
        sample_expect(16'sd32767, 16'sd32766);
        sample_expect(16'sd32767, 16'sd32767);

        rst_n=0;
        repeat (2) @(posedge clk); rst_n=1;
        coeff_write(0, 16'sd32767);
        coeff_write(1, 16'sd32767);
        sample_expect(-16'sd32768, -16'sd32768);
        sample_expect(-16'sd32768, -16'sd32768);

        $display("PASS tb_fir_filter");
        $finish;
    end
endmodule
