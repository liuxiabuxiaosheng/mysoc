module uart_rx (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        rx,
    input  logic [31:0] baud_div,
    output logic [7:0]  data_out,
    output logic        valid,
    output logic        frame_error
);
    typedef enum logic [1:0] {
        S_IDLE,
        S_START,
        S_DATA,
        S_STOP
    } state_t;

    state_t      state;
    logic        rx_meta;
    logic        rx_sync;
    logic [31:0] baud_latched;
    logic [31:0] baud_count;
    logic [2:0]  bit_index;
    logic [7:0]  data_shift;

    wire [31:0] baud_clamped = (baud_div < 32'd2) ? 32'd2 : baud_div;
    wire [31:0] half_count = (baud_latched >> 1);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state        <= S_IDLE;
            rx_meta      <= 1'b1;
            rx_sync      <= 1'b1;
            baud_latched <= 32'd2;
            baud_count   <= 32'd0;
            bit_index    <= 3'd0;
            data_shift   <= 8'd0;
            data_out     <= 8'd0;
            valid        <= 1'b0;
            frame_error  <= 1'b0;
        end else begin
            rx_meta     <= rx;
            rx_sync     <= rx_meta;
            valid       <= 1'b0;
            frame_error <= 1'b0;

            case (state)
                S_IDLE: begin
                    baud_count <= 32'd0;
                    bit_index  <= 3'd0;

                    if (!rx_sync) begin
                        baud_latched <= baud_clamped;
                        state        <= S_START;
                    end
                end

                S_START: begin
                    if (baud_count == (half_count - 32'd1)) begin
                        baud_count <= 32'd0;
                        if (!rx_sync) begin
                            state <= S_DATA;
                        end else begin
                            state <= S_IDLE;
                        end
                    end else begin
                        baud_count <= baud_count + 32'd1;
                    end
                end

                S_DATA: begin
                    if (baud_count == (baud_latched - 32'd1)) begin
                        baud_count            <= 32'd0;
                        data_shift[bit_index] <= rx_sync;

                        if (bit_index == 3'd7) begin
                            bit_index <= 3'd0;
                            state     <= S_STOP;
                        end else begin
                            bit_index <= bit_index + 3'd1;
                        end
                    end else begin
                        baud_count <= baud_count + 32'd1;
                    end
                end

                S_STOP: begin
                    if (baud_count == (baud_latched - 32'd1)) begin
                        baud_count  <= 32'd0;
                        data_out    <= data_shift;
                        valid       <= 1'b1;
                        frame_error <= !rx_sync;
                        state       <= S_IDLE;
                    end else begin
                        baud_count <= baud_count + 32'd1;
                    end
                end

                default: begin
                    state <= S_IDLE;
                end
            endcase
        end
    end
endmodule
