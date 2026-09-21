module i2s_tx_slave (
    input  logic        i2s_bclk,
    input  logic        i2s_lrclk,
    input  logic        rst_n,
    input  logic        sample_valid,
    input  logic [15:0] sample_data,
    output logic        sample_ready,
    output logic        i2s_sdata,
    output logic        underrun
);
    logic        lrclk_q;
    logic        seen_lrclk_q;
    logic        channel_q;
    logic        offset_q;
    logic        slot_active_q;
    logic [4:0]  bit_count_q;
    logic [15:0] shift_q;

    logic        expected_channel_q;
    logic [15:0] left_buf_q, right_buf_q;
    logic        left_valid_q, right_valid_q;

    always_comb begin
        sample_ready = expected_channel_q ? !right_valid_q : !left_valid_q;
    end

    always_ff @(negedge i2s_bclk or negedge rst_n) begin
        if (!rst_n) begin
            lrclk_q          <= 1'b0;
            seen_lrclk_q     <= 1'b0;
            channel_q        <= 1'b0;
            offset_q         <= 1'b0;
            slot_active_q    <= 1'b0;
            bit_count_q      <= 5'd0;
            shift_q          <= 16'd0;
            expected_channel_q <= 1'b0;
            left_buf_q       <= 16'd0;
            right_buf_q      <= 16'd0;
            left_valid_q     <= 1'b0;
            right_valid_q    <= 1'b0;
            i2s_sdata       <= 1'b0;
            underrun        <= 1'b0;
        end else begin
            if (sample_valid && sample_ready) begin
                if (expected_channel_q == 1'b0) begin
                    left_buf_q   <= sample_data;
                    left_valid_q <= 1'b1;
                end else begin
                    right_buf_q   <= sample_data;
                    right_valid_q <= 1'b1;
                end
                expected_channel_q <= ~expected_channel_q;
            end

            if (!seen_lrclk_q || i2s_lrclk != lrclk_q) begin
                lrclk_q       <= i2s_lrclk;
                seen_lrclk_q  <= 1'b1;
                channel_q     <= i2s_lrclk;
                offset_q      <= 1'b1;
                slot_active_q <= 1'b1;
                bit_count_q   <= 5'd0;
                shift_q       <= 16'd0;
                i2s_sdata     <= 1'b0;
            end else if (slot_active_q) begin
                if (offset_q) begin
                    offset_q   <= 1'b0;
                    if (channel_q == 1'b0) begin
                        if (left_valid_q) begin
                            i2s_sdata    <= left_buf_q[15];
                            shift_q      <= {left_buf_q[14:0], 1'b0};
                            left_valid_q <= 1'b0;
                        end else begin
                            i2s_sdata <= 1'b0;
                            shift_q   <= 16'd0;
                            underrun  <= 1'b1;
                        end
                    end else begin
                        if (right_valid_q) begin
                            i2s_sdata     <= right_buf_q[15];
                            shift_q       <= {right_buf_q[14:0], 1'b0};
                            right_valid_q <= 1'b0;
                        end else begin
                            i2s_sdata <= 1'b0;
                            shift_q   <= 16'd0;
                            underrun  <= 1'b1;
                        end
                    end
                    bit_count_q <= 5'd1;
                end else if (bit_count_q == 5'd0) begin
                    if (channel_q == 1'b0) begin
                        if (left_valid_q) begin
                            i2s_sdata   <= left_buf_q[15];
                            shift_q     <= {left_buf_q[14:0], 1'b0};
                            left_valid_q <= 1'b0;
                        end else begin
                            i2s_sdata <= 1'b0;
                            shift_q   <= 16'd0;
                            underrun  <= 1'b1;
                        end
                    end else begin
                        if (right_valid_q) begin
                            i2s_sdata    <= right_buf_q[15];
                            shift_q      <= {right_buf_q[14:0], 1'b0};
                            right_valid_q <= 1'b0;
                        end else begin
                            i2s_sdata <= 1'b0;
                            shift_q   <= 16'd0;
                            underrun  <= 1'b1;
                        end
                    end
                    bit_count_q <= 5'd1;
                end else if (bit_count_q < 5'd16) begin
                    i2s_sdata <= shift_q[15];
                    shift_q   <= {shift_q[14:0], 1'b0};
                    bit_count_q <= bit_count_q + 1'b1;
                end else begin
                    i2s_sdata <= 1'b0;
                end
            end else begin
                i2s_sdata <= 1'b0;
            end
        end
    end
endmodule
