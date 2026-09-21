module i2s_audio_bridge #(
    parameter integer FIFO_ADDR_WIDTH = 4
) (
    input  logic        i2s_bclk,
    input  logic        i2s_lrclk,
    input  logic        i2s_sdata_in,
    output logic        i2s_sdata_out,
    input  logic        i2s_rst_n,
    input  logic        audio_clk,
    input  logic        audio_rst_n,

    output logic        audio_in_valid,
    output logic [15:0] audio_in_data,
    input  logic        audio_in_ready,
    input  logic        audio_out_valid,
    input  logic [15:0] audio_out_data,
    output logic        audio_out_ready,

    output logic        rx_overflow,
    output logic        rx_frame_error,
    output logic        tx_underflow
);
    logic        rx_sample_valid;
    logic        rx_sample_valid_d_q;
    logic [15:0] rx_sample_data;
    logic        rx_sample_channel;

    logic        rx_fifo_full, rx_fifo_empty, rx_fifo_overflow, rx_fifo_underflow;
    logic        rx_fifo_wr_en, rx_fifo_rd_en;
    logic [15:0] rx_fifo_rd_data;
    logic        rx_prefetch_valid_q;

    logic        tx_fifo_full, tx_fifo_empty, tx_fifo_overflow, tx_fifo_underflow;
    logic        tx_fifo_wr_en, tx_fifo_rd_en;
    logic [15:0] tx_fifo_rd_data;
    logic        tx_prefetch_valid_q;
    logic [15:0] tx_prefetch_data_q;
    logic        tx_next_valid_q;
    logic [15:0] tx_next_data_q;
    logic        tx_read_pending_q;
    logic        tx_read_target_next_q;
    logic        tx_mask_q;
    logic        tx_consume_toggle_q;
    logic        tx_consume_sync1_q, tx_consume_sync2_q, tx_consume_seen_q;
    logic        tx_load_toggle_q;
    logic        tx_load_sync_q, tx_load_seen_q;
    logic        tx_load_ack_q;
    logic        tx_sample_valid;
    logic        tx_sample_ready;
    logic        tx_underrun;
    logic        tx_sample_fire;
    logic        tx_consume_pending;

    i2s_rx_slave u_rx (
        .i2s_bclk(i2s_bclk), .i2s_lrclk(i2s_lrclk), .i2s_sdata(i2s_sdata_in),
        .rst_n(i2s_rst_n), .sample_valid(rx_sample_valid),
        .sample_data(rx_sample_data), .sample_channel(rx_sample_channel),
        .frame_error(rx_frame_error)
    );

    assign rx_fifo_wr_en = rx_sample_valid_d_q && !rx_fifo_full;

    always_ff @(posedge i2s_bclk or negedge i2s_rst_n) begin
        if (!i2s_rst_n)
            rx_sample_valid_d_q <= 1'b0;
        else
            rx_sample_valid_d_q <= rx_sample_valid;
    end
    async_fifo #(.DATA_WIDTH(16), .ADDR_WIDTH(FIFO_ADDR_WIDTH)) u_rx_fifo (
        .wr_clk(i2s_bclk), .wr_rst_n(i2s_rst_n), .wr_en(rx_fifo_wr_en),
        .wr_data(rx_sample_data), .full(rx_fifo_full), .overflow(rx_fifo_overflow),
        .rd_clk(audio_clk), .rd_rst_n(audio_rst_n), .rd_en(rx_fifo_rd_en),
        .rd_data(rx_fifo_rd_data), .empty(rx_fifo_empty), .underflow(rx_fifo_underflow)
    );

    assign rx_fifo_rd_en = !rx_prefetch_valid_q && !rx_fifo_empty;
    assign audio_in_valid = rx_prefetch_valid_q;
    assign audio_in_data = rx_fifo_rd_data;

    always_ff @(posedge audio_clk or negedge audio_rst_n) begin
        if (!audio_rst_n) begin
            rx_prefetch_valid_q <= 1'b0;
        end else begin
            if (rx_fifo_rd_en)
                rx_prefetch_valid_q <= 1'b1;
            if (audio_in_valid && audio_in_ready)
                rx_prefetch_valid_q <= 1'b0;
        end
    end

    assign tx_fifo_wr_en = audio_out_valid && !tx_fifo_full;
    assign audio_out_ready = !tx_fifo_full;
    async_fifo #(.DATA_WIDTH(16), .ADDR_WIDTH(FIFO_ADDR_WIDTH)) u_tx_fifo (
        .wr_clk(audio_clk), .wr_rst_n(audio_rst_n), .wr_en(tx_fifo_wr_en),
        .wr_data(audio_out_data), .full(tx_fifo_full), .overflow(tx_fifo_overflow),
        .rd_clk(i2s_bclk), .rd_rst_n(i2s_rst_n), .rd_en(tx_fifo_rd_en),
        .rd_data(tx_fifo_rd_data), .empty(tx_fifo_empty), .underflow(tx_fifo_underflow)
    );

    assign tx_consume_pending = (tx_consume_toggle_q != tx_consume_sync2_q) ||
                                (tx_consume_sync2_q != tx_consume_seen_q);
    assign tx_fifo_rd_en = !tx_read_pending_q && !tx_fifo_empty && !tx_consume_pending &&
                           ((!tx_prefetch_valid_q) || !tx_next_valid_q);
    assign tx_sample_valid = tx_prefetch_valid_q && tx_load_ack_q && !tx_mask_q;
    assign tx_sample_fire = tx_sample_valid && tx_sample_ready;

    always_ff @(posedge i2s_bclk or negedge i2s_rst_n) begin
        if (!i2s_rst_n) begin
            tx_prefetch_valid_q <= 1'b0;
            tx_prefetch_data_q  <= 16'd0;
            tx_next_valid_q     <= 1'b0;
            tx_next_data_q      <= 16'd0;
            tx_read_pending_q   <= 1'b0;
            tx_read_target_next_q <= 1'b0;
            tx_consume_sync1_q  <= 1'b0;
            tx_consume_sync2_q  <= 1'b0;
            tx_consume_seen_q   <= 1'b0;
            tx_load_toggle_q    <= 1'b0;
        end else begin
            tx_consume_sync1_q <= tx_consume_toggle_q;
            tx_consume_sync2_q <= tx_consume_sync1_q;
            if (tx_read_pending_q) begin
                if (tx_read_target_next_q) begin
                    tx_next_data_q  <= tx_fifo_rd_data;
                    tx_next_valid_q <= 1'b1;
                end else begin
                    tx_prefetch_data_q  <= tx_fifo_rd_data;
                    tx_prefetch_valid_q <= 1'b1;
                    tx_load_toggle_q    <= ~tx_load_toggle_q;
                end
                tx_read_pending_q <= 1'b0;
            end else if (tx_consume_sync2_q != tx_consume_seen_q) begin
                tx_consume_seen_q   <= tx_consume_sync2_q;
                if (tx_next_valid_q) begin
                    tx_prefetch_data_q  <= tx_next_data_q;
                    tx_prefetch_valid_q <= 1'b1;
                    tx_next_valid_q     <= 1'b0;
                    tx_load_toggle_q    <= ~tx_load_toggle_q;
                end else begin
                    tx_prefetch_valid_q <= 1'b0;
                end
            end else if (tx_fifo_rd_en) begin
                tx_read_pending_q     <= 1'b1;
                tx_read_target_next_q <= tx_prefetch_valid_q;
            end
        end
    end

    always_ff @(negedge i2s_bclk or negedge i2s_rst_n) begin
        if (!i2s_rst_n) begin
            tx_mask_q      <= 1'b0;
            tx_consume_toggle_q <= 1'b0;
            tx_load_sync_q <= 1'b0;
            tx_load_seen_q <= 1'b0;
            tx_load_ack_q  <= 1'b0;
        end else begin
            tx_load_sync_q <= tx_load_toggle_q;
            if (tx_load_sync_q != tx_load_seen_q) begin
                tx_load_seen_q <= tx_load_sync_q;
                tx_mask_q      <= 1'b0;
                tx_load_ack_q  <= 1'b1;
            end
            if (tx_sample_fire) begin
                tx_mask_q          <= 1'b1;
                tx_consume_toggle_q <= ~tx_consume_toggle_q;
            end
        end
    end

    i2s_tx_slave u_tx (
        .i2s_bclk(i2s_bclk), .i2s_lrclk(i2s_lrclk), .rst_n(i2s_rst_n),
        .sample_valid(tx_sample_valid), .sample_data(tx_prefetch_data_q),
        .sample_ready(tx_sample_ready), .i2s_sdata(i2s_sdata_out),
        .underrun(tx_underrun)
    );

    always_comb begin
        rx_overflow = rx_fifo_overflow;
        tx_underflow = tx_underrun | tx_fifo_underflow;
    end
endmodule
