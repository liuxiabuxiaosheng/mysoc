`timescale 1ns/1ps
module tb_audio_pipeline;
    logic sys_clk, audio_clk, sys_rst_n, audio_rst_n;
    logic input_push_valid;
    logic signed [15:0] input_push_data;
    wire input_push_ready;
    wire output_pop_valid;
    wire signed [15:0] output_pop_data;
    logic output_pop_ready;
    logic enable, bypass, clear_state;
    logic coeff_we;
    logic [3:0] coeff_index;
    logic signed [15:0] coeff_data;
    wire [5:0] status;
    wire [31:0] sample_count;
    wire signed [15:0] last_output;
    logic [5:0] status_clear;

    audio_pipeline dut (
        .sys_clk(sys_clk), .sys_rst_n(sys_rst_n),
        .audio_clk(audio_clk), .audio_rst_n(audio_rst_n),
        .input_push_valid(input_push_valid), .input_push_data(input_push_data),
        .input_push_ready(input_push_ready),
        .output_pop_valid(output_pop_valid), .output_pop_data(output_pop_data),
        .output_pop_ready(output_pop_ready),
        .enable(enable), .bypass(bypass), .clear_state(clear_state),
        .coeff_we(coeff_we), .coeff_index(coeff_index), .coeff_data(coeff_data),
        .status_clear(status_clear),
        .status(status), .sample_count(sample_count), .last_output(last_output)
    );

    always #10 sys_clk = ~sys_clk;
    always #37 audio_clk = ~audio_clk;

    task automatic push_sample(input logic signed [15:0] sample);
        begin
            @(negedge sys_clk);
            input_push_data = sample;
            input_push_valid = 1'b1;
            do @(negedge sys_clk); while (!input_push_ready);
            input_push_valid = 1'b0;
        end
    endtask

    initial begin
        sys_clk = 1'b0; audio_clk = 1'b0;
        sys_rst_n = 1'b0; audio_rst_n = 1'b0;
        input_push_valid = 1'b0; input_push_data = '0;
        output_pop_ready = 1'b1;
        enable = 1'b0; bypass = 1'b1; clear_state = 1'b0;
        coeff_we = 1'b0; coeff_index = '0; coeff_data = '0;
        status_clear = '0;
        repeat (3) @(posedge sys_clk);
        sys_rst_n = 1'b1; audio_rst_n = 1'b1;
        enable = 1'b1;
        push_sample(16'sd123);
        push_sample(-16'sd45);
        repeat (200) @(posedge sys_clk);
        if (sample_count !== 32'd2) $fatal(1, "pipeline count mismatch: %0d", sample_count);
        if (last_output !== -16'sd45) $fatal(1, "pipeline last output mismatch: %0d", last_output);
        $display("PASS tb_audio_pipeline");
        $finish;
    end
endmodule
