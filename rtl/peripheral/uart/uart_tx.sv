module uart_tx (
    input  logic        clk,
    input  logic        rst_n,
    input  logic [7:0]  data_in,
    input  logic        start,
    input  logic [31:0] baud_div,
    output logic        tx,
    output logic        busy,
    output logic        done
);
    typedef enum logic [1:0] {
        S_IDLE,
        S_START,
        S_DATA,
        S_STOP
    } state_t;

    state_t      state;
    logic [31:0] baud_count;
    logic [31:0] baud_latched;
    logic [2:0]  bit_index;
    logic [7:0]  data_latched;

    wire [31:0] baud_clamped = (baud_div < 32'd2) ? 32'd2 : baud_div;
    wire        bit_done = (baud_count == (baud_latched - 32'd1));

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state        <= S_IDLE;
            baud_count   <= 32'd0;
            baud_latched <= 32'd2;
            bit_index    <= 3'd0;
            data_latched <= 8'd0;
            tx           <= 1'b1;
            busy         <= 1'b0;
            done         <= 1'b0;
        end else begin
            done <= 1'b0;

            case (state)
                S_IDLE: begin
                    tx         <= 1'b1;
                    busy       <= 1'b0;
                    baud_count <= 32'd0;
                    bit_index  <= 3'd0;

                    if (start) begin
                        data_latched <= data_in;
                        baud_latched <= baud_clamped;
                        tx           <= 1'b0;
                        busy         <= 1'b1;
                        state        <= S_START;
                    end
                end

                S_START: begin
                    tx   <= 1'b0;
                    busy <= 1'b1;

                    if (bit_done) begin
                        baud_count <= 32'd0;
                        tx         <= data_latched[0];
                        bit_index  <= 3'd0;
                        state      <= S_DATA;
                    end else begin
                        baud_count <= baud_count + 32'd1;
                    end
                end

                S_DATA: begin
                    tx   <= data_latched[bit_index];
                    busy <= 1'b1;

                    if (bit_done) begin
                        baud_count <= 32'd0;
                        if (bit_index == 3'd7) begin
                            tx    <= 1'b1;
                            state <= S_STOP;
                        end else begin
                            bit_index <= bit_index + 3'd1;
                            tx        <= data_latched[bit_index + 3'd1];
                        end
                    end else begin
                        baud_count <= baud_count + 32'd1;
                    end
                end

                S_STOP: begin
                    tx   <= 1'b1;
                    busy <= 1'b1;

                    if (bit_done) begin
                        baud_count <= 32'd0;
                        busy       <= 1'b0;
                        done       <= 1'b1;
                        state      <= S_IDLE;
                    end else begin
                        baud_count <= baud_count + 32'd1;
                    end
                end

                default: begin
                    state <= S_IDLE;
                    tx    <= 1'b1;
                    busy  <= 1'b0;
                end
            endcase
        end
    end
endmodule
