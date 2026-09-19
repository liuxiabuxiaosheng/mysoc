module audio_pipeline #(
    parameter integer FIFO_ADDR_WIDTH = 4,
    parameter integer OUTPUT_FIFO_ADDR_WIDTH = 6
) (
    input  logic                   sys_clk,
    input  logic                   sys_rst_n,
    input  logic                   audio_clk,
    input  logic                   audio_rst_n,

    input  logic                   input_push_valid,
    input  logic signed [15:0]     input_push_data,
    output logic                   input_push_ready,
    output logic                   output_pop_valid,
    output logic signed [15:0]     output_pop_data,
    input  logic                   output_pop_ready,

    input  logic                   enable,
    input  logic                   bypass,
    input  logic                   clear_state,
    input  logic                   coeff_we,
    input  logic [3:0]             coeff_index,
    input  logic signed [15:0]     coeff_data,
    input  logic [5:0]             status_clear,

    output logic [5:0]             status,
    output logic [31:0]            sample_count,
    output logic signed [15:0]     last_output
);
    logic signed [15:0] coeff_shadow [0:15];
    logic [31:0] coeff_version_q;

    logic in_fifo_full, in_fifo_empty, in_fifo_overflow, in_fifo_underflow;
    logic out_fifo_full, out_fifo_empty, out_fifo_overflow, out_fifo_underflow;
    logic [15:0] in_fifo_rd_data;
    logic [15:0] out_fifo_rd_data;
    logic in_fifo_wr_en, in_fifo_rd_en;
    logic out_fifo_wr_en, out_fifo_rd_en;
    logic [15:0] out_fifo_wr_data;

    logic enable_a1, enable_a2, bypass_a1, bypass_a2;
    logic enable_a_prev;
    logic clear_toggle_q;
    logic clear_toggle_a1, clear_toggle_a2, clear_toggle_seen;
    wire clear_event_a = clear_toggle_a2 ^ clear_toggle_seen;

    logic [31:0] coeff_version_a1, coeff_version_a2, coeff_version_seen;
    logic coeff_load_pending;
    logic [3:0] coeff_load_index;

    logic in_prefetch_valid_q;
    logic bypass_valid_q;
    logic signed [15:0] bypass_data_q;
    logic fir_in_valid, fir_in_ready;
    logic fir_out_valid, fir_out_ready;
    logic signed [15:0] fir_out_data;
    logic producer_valid, producer_fire;
    logic signed [15:0] producer_data;
    logic bypass_input_fire, input_consumed;
    logic seen_input_q, complete_q, active_a;
    logic [31:0] sample_count_a_q;
    logic signed [15:0] last_output_a_q;

    logic out_prefetch_valid_q;

    logic in_underflow_a1, in_underflow_a2;
    logic out_overflow_a1, out_overflow_a2;
    logic active_s1, active_s2;
    logic complete_s1, complete_s2;
    logic [31:0] sample_count_s1, sample_count_s2;
    logic signed [15:0] last_output_s1, last_output_s2;
    logic in_overflow_prev, out_underflow_prev;
    logic in_underflow_prev, out_overflow_prev;
    logic complete_prev;
    logic [5:0] status_q;

    assign input_push_ready = enable && !in_fifo_full;
    assign in_fifo_wr_en = input_push_valid && input_push_ready;

    async_fifo #(.DATA_WIDTH(16), .ADDR_WIDTH(FIFO_ADDR_WIDTH)) u_input_fifo (
        .wr_clk(sys_clk), .wr_rst_n(sys_rst_n),
        .wr_en(in_fifo_wr_en), .wr_data(input_push_data),
        .full(in_fifo_full), .overflow(in_fifo_overflow),
        .rd_clk(audio_clk), .rd_rst_n(audio_rst_n),
        .rd_en(in_fifo_rd_en), .rd_data(in_fifo_rd_data),
        .empty(in_fifo_empty), .underflow(in_fifo_underflow)
    );

    async_fifo #(.DATA_WIDTH(16), .ADDR_WIDTH(OUTPUT_FIFO_ADDR_WIDTH)) u_output_fifo (
        .wr_clk(audio_clk), .wr_rst_n(audio_rst_n),
        .wr_en(out_fifo_wr_en), .wr_data(out_fifo_wr_data),
        .full(out_fifo_full), .overflow(out_fifo_overflow),
        .rd_clk(sys_clk), .rd_rst_n(sys_rst_n),
        .rd_en(out_fifo_rd_en), .rd_data(out_fifo_rd_data),
        .empty(out_fifo_empty), .underflow(out_fifo_underflow)
    );

    always_ff @(posedge sys_clk or negedge sys_rst_n) begin
        integer i;
        if (!sys_rst_n) begin
            coeff_version_q <= 32'd0;
            clear_toggle_q <= 1'b0;
            for (i = 0; i < 16; i = i + 1)
                coeff_shadow[i] <= 16'sd0;
        end else begin
            if (coeff_we) begin
                coeff_shadow[coeff_index] <= coeff_data;
                coeff_version_q <= coeff_version_q + 1'b1;
            end
            if (clear_state)
                clear_toggle_q <= ~clear_toggle_q;
        end
    end

    always_ff @(posedge audio_clk or negedge audio_rst_n) begin
        if (!audio_rst_n) begin
            enable_a1 <= 1'b0;
            enable_a2 <= 1'b0;
            bypass_a1 <= 1'b0;
            bypass_a2 <= 1'b0;
            enable_a_prev <= 1'b0;
            clear_toggle_a1 <= 1'b0;
            clear_toggle_a2 <= 1'b0;
            clear_toggle_seen <= 1'b0;
            coeff_version_a1 <= 32'd0;
            coeff_version_a2 <= 32'd0;
            coeff_version_seen <= 32'd0;
        end else begin
            enable_a1 <= enable;
            enable_a2 <= enable_a1;
            bypass_a1 <= bypass;
            bypass_a2 <= bypass_a1;
            enable_a_prev <= enable_a2;
            clear_toggle_a1 <= clear_toggle_q;
            clear_toggle_a2 <= clear_toggle_a1;
            if (clear_event_a)
                clear_toggle_seen <= clear_toggle_a2;
            coeff_version_a1 <= coeff_version_q;
            coeff_version_a2 <= coeff_version_a1;
            if (coeff_version_a2 != coeff_version_seen)
                coeff_version_seen <= coeff_version_a2;
        end
    end

    assign in_fifo_rd_en = enable_a2 && !in_prefetch_valid_q && !in_fifo_empty;
    assign fir_in_valid = enable_a2 && !bypass_a2 && in_prefetch_valid_q && !coeff_load_pending;
    assign fir_out_ready = !out_fifo_full;
    assign bypass_input_fire = enable_a2 && bypass_a2 && in_prefetch_valid_q &&
                               (!bypass_valid_q || !out_fifo_full);
    assign input_consumed = (fir_in_valid && fir_in_ready) || bypass_input_fire;

    assign producer_valid = bypass_a2 ? bypass_valid_q : fir_out_valid;
    assign producer_data  = bypass_a2 ? bypass_data_q : fir_out_data;
    assign out_fifo_wr_en = producer_valid && !out_fifo_full;
    assign out_fifo_wr_data = producer_data;
    assign producer_fire = out_fifo_wr_en;

    always_ff @(posedge audio_clk or negedge audio_rst_n) begin
        if (!audio_rst_n) begin
            in_prefetch_valid_q <= 1'b0;
            bypass_valid_q <= 1'b0;
            bypass_data_q <= 16'sd0;
            seen_input_q <= 1'b0;
            complete_q <= 1'b0;
            sample_count_a_q <= 32'd0;
            last_output_a_q <= 16'sd0;
        end else begin
            if (clear_event_a) begin
                in_prefetch_valid_q <= 1'b0;
                bypass_valid_q <= 1'b0;
                seen_input_q <= 1'b0;
                complete_q <= 1'b0;
                sample_count_a_q <= 32'd0;
                last_output_a_q <= 16'sd0;
            end else begin
                if (in_fifo_rd_en)
                    in_prefetch_valid_q <= 1'b1;
                if (input_consumed)
                    in_prefetch_valid_q <= 1'b0;

                if (bypass_a2) begin
                    if (bypass_input_fire) begin
                        bypass_valid_q <= 1'b1;
                        bypass_data_q <= in_fifo_rd_data;
                    end else if (producer_fire) begin
                        bypass_valid_q <= 1'b0;
                    end
                end else begin
                    bypass_valid_q <= 1'b0;
                end

                if (input_consumed)
                    seen_input_q <= 1'b1;
                if (producer_fire) begin
                    sample_count_a_q <= sample_count_a_q + 1'b1;
                    last_output_a_q <= producer_data;
                end
                if (seen_input_q && in_fifo_empty && !in_prefetch_valid_q &&
                    !fir_out_valid && !bypass_valid_q)
                    complete_q <= 1'b1;
            end
        end
    end

    assign active_a = enable_a2 && (in_prefetch_valid_q || !in_fifo_empty ||
                                     fir_out_valid || bypass_valid_q || coeff_load_pending);

    always_ff @(posedge audio_clk or negedge audio_rst_n) begin
        if (!audio_rst_n) begin
            coeff_load_pending <= 1'b0;
            coeff_load_index <= 4'd0;
        end else begin
            if (clear_event_a) begin
                coeff_load_pending <= 1'b1;
                coeff_load_index <= 4'd0;
            end else if (coeff_version_a2 != coeff_version_seen) begin
                coeff_load_pending <= 1'b1;
                coeff_load_index <= 4'd0;
            end else if (coeff_load_pending) begin
                if (coeff_load_index == 4'd15)
                    coeff_load_pending <= 1'b0;
                else
                    coeff_load_index <= coeff_load_index + 1'b1;
            end
        end
    end

    fir_filter u_fir (
        .clk(audio_clk), .rst_n(audio_rst_n && !clear_event_a),
        .in_valid(fir_in_valid), .in_ready(fir_in_ready), .in_sample(in_fifo_rd_data),
        .coeff_we(coeff_load_pending), .coeff_index(coeff_load_index),
        .coeff_data(coeff_shadow[coeff_load_index]),
        .out_valid(fir_out_valid), .out_ready(fir_out_ready), .out_sample(fir_out_data)
    );

    assign out_fifo_rd_en = enable && !out_prefetch_valid_q && !out_fifo_empty;
    assign output_pop_valid = out_prefetch_valid_q;
    assign output_pop_data = out_fifo_rd_data;

    always_ff @(posedge sys_clk or negedge sys_rst_n) begin
        if (!sys_rst_n) begin
            out_prefetch_valid_q <= 1'b0;
            in_underflow_a1 <= 1'b0;
            in_underflow_a2 <= 1'b0;
            out_overflow_a1 <= 1'b0;
            out_overflow_a2 <= 1'b0;
            active_s1 <= 1'b0;
            active_s2 <= 1'b0;
            complete_s1 <= 1'b0;
            complete_s2 <= 1'b0;
            sample_count_s1 <= 32'd0;
            sample_count_s2 <= 32'd0;
            last_output_s1 <= 16'sd0;
            last_output_s2 <= 16'sd0;
            in_overflow_prev <= 1'b0;
            out_underflow_prev <= 1'b0;
            in_underflow_prev <= 1'b0;
            out_overflow_prev <= 1'b0;
            complete_prev <= 1'b0;
            status_q <= 6'd0;
        end else begin
            if (out_fifo_rd_en)
                out_prefetch_valid_q <= 1'b1;
            if (output_pop_valid && output_pop_ready)
                out_prefetch_valid_q <= 1'b0;

            in_underflow_a1 <= in_fifo_underflow;
            in_underflow_a2 <= in_underflow_a1;
            out_overflow_a1 <= out_fifo_overflow;
            out_overflow_a2 <= out_overflow_a1;
            active_s1 <= active_a;
            active_s2 <= active_s1;
            complete_s1 <= complete_q;
            complete_s2 <= complete_s1;
            sample_count_s1 <= sample_count_a_q;
            sample_count_s2 <= sample_count_s1;
            last_output_s1 <= last_output_a_q;
            last_output_s2 <= last_output_s1;

            if (in_fifo_overflow && !in_overflow_prev)
                status_q[0] <= 1'b1;
            if (in_underflow_a2 && !in_underflow_prev)
                status_q[1] <= 1'b1;
            if (out_overflow_a2 && !out_overflow_prev)
                status_q[2] <= 1'b1;
            if (out_fifo_underflow && !out_underflow_prev)
                status_q[3] <= 1'b1;
            if (complete_s2 && !complete_prev)
                status_q[5] <= 1'b1;
            if (clear_state) begin
                status_q <= 6'd0;
            end else begin
                if (status_clear[0]) status_q[0] <= 1'b0;
                if (status_clear[1]) status_q[1] <= 1'b0;
                if (status_clear[2]) status_q[2] <= 1'b0;
                if (status_clear[3]) status_q[3] <= 1'b0;
                if (status_clear[5]) status_q[5] <= 1'b0;
            end
            in_overflow_prev <= in_fifo_overflow;
            out_underflow_prev <= out_fifo_underflow;
            in_underflow_prev <= in_underflow_a2;
            out_overflow_prev <= out_overflow_a2;
            complete_prev <= complete_s2;
        end
    end

    always_comb begin
        status = status_q;
        status[4] = active_s2;
        sample_count = sample_count_s2;
        last_output = last_output_s2;
    end
endmodule
