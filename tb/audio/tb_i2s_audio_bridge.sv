`timescale 1ns/1ps
module tb_i2s_audio_bridge;
    logic bclk, audio_clk;
    logic i2s_rst_n, audio_rst_n;
    logic lrclk, sdata_in;
    wire sdata_out;

    wire audio_in_valid;
    wire [15:0] audio_in_data;
    logic audio_in_ready;
    logic audio_out_valid;
    logic [15:0] audio_out_data;
    wire audio_out_ready;
    wire rx_overflow, rx_frame_error, tx_underflow;

    i2s_audio_bridge dut (
        .i2s_bclk(bclk), .i2s_lrclk(lrclk), .i2s_sdata_in(sdata_in),
        .i2s_sdata_out(sdata_out), .i2s_rst_n(i2s_rst_n),
        .audio_clk(audio_clk), .audio_rst_n(audio_rst_n),
        .audio_in_valid(audio_in_valid), .audio_in_data(audio_in_data),
        .audio_in_ready(audio_in_ready), .audio_out_valid(audio_out_valid),
        .audio_out_data(audio_out_data), .audio_out_ready(audio_out_ready),
        .rx_overflow(rx_overflow), .rx_frame_error(rx_frame_error),
        .tx_underflow(tx_underflow)
    );

    always #1 bclk = ~bclk;
    always #3 audio_clk = ~audio_clk;



    integer input_count;
    logic [15:0] input_seen [0:1];

    always @(posedge audio_clk) begin
        if (audio_in_valid && audio_in_ready) begin
            if (input_count < 2)
                input_seen[input_count] <= audio_in_data;
            input_count <= input_count + 1;
        end
    end




    task automatic drive_i2s_channel(input logic channel, input logic [15:0] value);
        integer i;
        begin
            lrclk = channel;
            sdata_in = 1'b0;
            repeat (3) @(posedge bclk);
            for (i = 15; i >= 0; i = i - 1) begin
                sdata_in = value[i];
                @(posedge bclk);
            end
            @(negedge bclk);
        end
    endtask

    task automatic push_audio_sample(input logic [15:0] value);
        begin
            while (!audio_out_ready)
                @(posedge audio_clk);
            audio_out_data = value;
            audio_out_valid = 1'b1;
            @(posedge audio_clk);
            #0 audio_out_valid = 1'b0;
        end
    endtask

    task automatic clock_i2s_channel(input logic channel);
        begin
            lrclk = channel;
            repeat (2) @(posedge bclk);
            @(negedge bclk);
        end
    endtask

    initial begin
        bclk = 1'b0;
        audio_clk = 1'b0;
        lrclk = 1'b1;
        sdata_in = 1'b0;
        i2s_rst_n = 1'b0;
        audio_rst_n = 1'b0;
        audio_in_ready = 1'b1;
        audio_out_valid = 1'b0;
        audio_out_data = 16'd0;
        input_count = 0;
        #8;
        i2s_rst_n = 1'b1;
        audio_rst_n = 1'b1;

        drive_i2s_channel(1'b0, 16'h1234);
        drive_i2s_channel(1'b1, 16'hfedc);
        repeat (8) @(posedge audio_clk);
        if (input_count != 2 || input_seen[0] !== 16'h1234 || input_seen[1] !== 16'hfedc)
            $fatal(1, "bridge RX mismatch count=%0d data0=%h data1=%h",
                   input_count, input_seen[0], input_seen[1]);

        i2s_rst_n = 1'b0;
        audio_rst_n = 1'b0;
        #4;
        i2s_rst_n = 1'b1;
        audio_rst_n = 1'b1;
        lrclk = 1'b1;
        push_audio_sample(16'h1357);
        push_audio_sample(16'h2468);
        repeat (20) @(posedge bclk);
        if (dut.u_tx.left_buf_q !== 16'h1357 || dut.u_tx.right_buf_q !== 16'h2468)
            $fatal(1, "bridge TX sample handoff mismatch left=%h right=%h",
                   dut.u_tx.left_buf_q, dut.u_tx.right_buf_q);

        if (rx_overflow || rx_frame_error)
            $fatal(1, "bridge RX status error rxov=%0d rxerr=%0d",
                   rx_overflow, rx_frame_error);

        drive_i2s_channel(1'b0, 16'd0);
        if (!tx_underflow)
            $fatal(1, "bridge TX underflow was not reported");
        $display("PASS tb_i2s_audio_bridge");
        $finish;
    end
endmodule
