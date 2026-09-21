`timescale 1ns/1ps
module tb_i2s_tx_slave;
    logic bclk, lrclk, rst_n;
    logic sample_valid;
    logic [15:0] sample_data;
    wire sample_ready;
    wire sdata;
    wire underrun;

    wire rx_valid;
    wire [15:0] rx_data;
    wire rx_channel;
    wire rx_error;

    i2s_tx_slave dut (
        .i2s_bclk(bclk), .i2s_lrclk(lrclk), .rst_n(rst_n),
        .sample_valid(sample_valid), .sample_data(sample_data),
        .sample_ready(sample_ready), .i2s_sdata(sdata), .underrun(underrun)
    );

    i2s_rx_slave rx_checker (
        .i2s_bclk(bclk), .i2s_lrclk(lrclk), .i2s_sdata(sdata), .rst_n(rst_n),
        .sample_valid(rx_valid), .sample_data(rx_data),
        .sample_channel(rx_channel), .frame_error(rx_error)
    );

    always #1 bclk = ~bclk;

    task automatic push_sample(input logic [15:0] value);
        begin
            while (!sample_ready)
                @(negedge bclk);
            sample_data = value;
            sample_valid = 1'b1;
            @(negedge bclk);
            #0 sample_valid = 1'b0;
        end
    endtask

    task automatic send_channel(input logic channel);
        begin
            lrclk = channel;
            repeat (18) @(posedge bclk);
        end
    endtask

    task automatic expect_sample(input logic [15:0] value, input logic channel);
        begin
            @(posedge rx_valid);
            #0;
            if (rx_data !== value || rx_channel !== channel)
                $fatal(1, "TX stream mismatch: got ch=%0d data=%h expected ch=%0d data=%h",
                       rx_channel, rx_data, channel, value);
        end
    endtask

    initial begin
        bclk = 1'b0;
        lrclk = 1'b0;
        rst_n = 1'b0;
        sample_valid = 1'b0;
        sample_data = 16'd0;
        #5;
        rst_n = 1'b1;

        push_sample(16'h1357);
        push_sample(16'h2468);

        fork
            begin
                expect_sample(16'h1357, 1'b0);
                expect_sample(16'h2468, 1'b1);
            end
            begin
                send_channel(1'b0);
                send_channel(1'b1);
            end
        join

        if (rx_error)
            $fatal(1, "TX loopback caused RX frame error");
        $display("PASS tb_i2s_tx_slave");
        $finish;
    end
endmodule
