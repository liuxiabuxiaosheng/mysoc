`timescale 1ns/1ps
module tb_i2s_rx_slave;
    logic bclk, lrclk, sdata, rst_n;
    wire sample_valid;
    wire [15:0] sample_data;
    wire sample_channel;
    wire frame_error;

    i2s_rx_slave dut (
        .i2s_bclk(bclk), .i2s_lrclk(lrclk), .i2s_sdata(sdata), .rst_n(rst_n),
        .sample_valid(sample_valid), .sample_data(sample_data),
        .sample_channel(sample_channel), .frame_error(frame_error)
    );

    task automatic bclk_cycle(input logic bit_value);
        begin
            sdata = bit_value;
            #1 bclk = 1'b1;
            #1 bclk = 1'b0;
        end
    endtask

    task automatic send_channel(input logic channel, input logic [15:0] value);
        integer bit_index;
        begin
            lrclk = channel;
            bclk_cycle(1'b0);
            bclk_cycle(1'b0);
            for (bit_index = 15; bit_index >= 0; bit_index = bit_index - 1)
                bclk_cycle(value[bit_index]);
        end
    endtask

    task automatic expect_sample(input logic [15:0] value, input logic channel);
        begin
            @(posedge sample_valid);
            #0;
            if (sample_data !== value || sample_channel !== channel)
                $fatal(1, "RX sample mismatch: got ch=%0d data=%h expected ch=%0d data=%h",
                       sample_channel, sample_data, channel, value);
        end
    endtask

    initial begin
        bclk = 1'b0;
        lrclk = 1'b1;
        sdata = 1'b0;
        rst_n = 1'b0;
        #5;
        rst_n = 1'b1;

        fork
            begin
                expect_sample(16'h1234, 1'b0);
                expect_sample(16'hfedc, 1'b1);
                expect_sample(16'ha55a, 1'b0);
                expect_sample(16'h0f0f, 1'b1);
            end
            begin
                send_channel(1'b0, 16'h1234);
                send_channel(1'b1, 16'hfedc);
                send_channel(1'b0, 16'ha55a);
                send_channel(1'b1, 16'h0f0f);
            end
        join

        if (frame_error)
            $fatal(1, "unexpected RX frame error");
        $display("PASS tb_i2s_rx_slave");
        $finish;
    end
endmodule
