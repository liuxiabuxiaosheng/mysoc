module i2s_rx_slave (
    input  logic        i2s_bclk,
    input  logic        i2s_lrclk,
    input  logic        i2s_sdata,
    input  logic        rst_n,
    output logic        sample_valid,
    output logic [15:0] sample_data,
    output logic        sample_channel,
    output logic        frame_error
);
    logic        lrclk_q;
    logic        seen_lrclk_q;
    logic        channel_q;
    logic        active_q;
    logic        skip_bit_q;
    logic [4:0]  bit_count_q;
    logic [15:0] shift_q;

    always_ff @(posedge i2s_bclk or negedge rst_n) begin
        if (!rst_n) begin
            lrclk_q        <= 1'b0;
            seen_lrclk_q   <= 1'b0;
            channel_q      <= 1'b0;
            active_q       <= 1'b0;
            skip_bit_q     <= 1'b0;
            bit_count_q    <= 5'd0;
            shift_q        <= 16'd0;
            sample_valid   <= 1'b0;
            sample_data    <= 16'd0;
            sample_channel <= 1'b0;
            frame_error    <= 1'b0;
        end else begin
            sample_valid <= 1'b0;

            if (!seen_lrclk_q || i2s_lrclk != lrclk_q) begin
                if (active_q && seen_lrclk_q)
                    frame_error <= 1'b1;
                lrclk_q     <= i2s_lrclk;
                seen_lrclk_q <= 1'b1;
                channel_q   <= i2s_lrclk;
                active_q    <= 1'b1;
                skip_bit_q  <= 1'b1;
                bit_count_q <= 5'd0;
                shift_q     <= 16'd0;
            end else if (active_q) begin
                if (skip_bit_q) begin
                    skip_bit_q <= 1'b0;
                end else begin
                    shift_q <= {shift_q[14:0], i2s_sdata};
                    if (bit_count_q == 5'd15) begin
                        sample_data    <= {shift_q[14:0], i2s_sdata};
                        sample_channel <= channel_q;
                        sample_valid   <= 1'b1;
                        active_q       <= 1'b0;
                        bit_count_q    <= 5'd0;
                    end else begin
                        bit_count_q <= bit_count_q + 1'b1;
                    end
                end
            end
        end
    end
endmodule
