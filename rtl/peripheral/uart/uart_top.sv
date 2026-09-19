module uart_top (
    input  wire        pclk,
    input  wire        presetn,

    input  wire [31:0] paddr,
    input  wire        psel,
    input  wire        penable,
    input  wire        pwrite,
    input  wire [31:0] pwdata,

    output wire [31:0] prdata,
    output wire        pready,
    output wire        pslverr,

    input  wire        rx,
    output wire        tx
);

wire        tx_fifo_empty;
wire        tx_fifo_full;
wire        tx_fifo_wr_en;
wire [7:0]  tx_fifo_wr_data;
logic       tx_fifo_rd_en;
wire [7:0]  tx_fifo_rd_data;
wire [4:0]  tx_fifo_count;

wire        rx_fifo_empty;
wire        rx_fifo_full;
wire        rx_fifo_rd_en;
wire [7:0]  rx_fifo_rd_data;
wire [4:0]  rx_fifo_count;
logic       rx_fifo_wr_en;

wire        tx_enable;
wire        rx_enable;
wire [31:0] baud_div;

logic [7:0] tx_data;
logic       tx_start;
wire        tx_busy;
wire        tx_done;
logic [1:0] tx_state;

localparam logic [1:0] TX_IDLE = 2'd0;
localparam logic [1:0] TX_POP  = 2'd1;
localparam logic [1:0] TX_LOAD = 2'd2;

wire [7:0]  rx_data;
wire        rx_valid;
wire        rx_frame_error;
wire        frame_error_set;
wire        overflow_set;

uart_fifo #(
    .DATA_WIDTH(8),
    .DEPTH(16)
) u_tx_fifo (
    .clk(pclk),
    .rst_n(presetn),
    .wr_en(tx_fifo_wr_en),
    .wr_data(tx_fifo_wr_data),
    .full(tx_fifo_full),
    .rd_en(tx_fifo_rd_en),
    .rd_data(tx_fifo_rd_data),
    .empty(tx_fifo_empty),
    .count(tx_fifo_count)
);

uart_fifo #(
    .DATA_WIDTH(8),
    .DEPTH(16)
) u_rx_fifo (
    .clk(pclk),
    .rst_n(presetn),
    .wr_en(rx_fifo_wr_en),
    .wr_data(rx_data),
    .full(rx_fifo_full),
    .rd_en(rx_fifo_rd_en),
    .rd_data(rx_fifo_rd_data),
    .empty(rx_fifo_empty),
    .count(rx_fifo_count)
);

uart_tx u_tx (
    .clk(pclk),
    .rst_n(presetn),
    .data_in(tx_data),
    .start(tx_start),
    .baud_div(baud_div),
    .tx(tx),
    .busy(tx_busy),
    .done(tx_done)
);

uart_rx u_rx (
    .clk(pclk),
    .rst_n(presetn),
    .rx(rx),
    .baud_div(baud_div),
    .data_out(rx_data),
    .valid(rx_valid),
    .frame_error(rx_frame_error)
);

uart_regs u_regs (
    .pclk(pclk),
    .presetn(presetn),
    .paddr(paddr),
    .psel(psel),
    .penable(penable),
    .pwrite(pwrite),
    .pwdata(pwdata),
    .prdata(prdata),
    .pready(pready),
    .pslverr(pslverr),
    .tx_fifo_empty(tx_fifo_empty),
    .tx_fifo_full(tx_fifo_full),
    .tx_fifo_wr_en(tx_fifo_wr_en),
    .tx_fifo_wr_data(tx_fifo_wr_data),
    .rx_fifo_empty(rx_fifo_empty),
    .rx_fifo_full(rx_fifo_full),
    .rx_fifo_rd_en(rx_fifo_rd_en),
    .rx_fifo_rd_data(rx_fifo_rd_data),
    .frame_error_set(frame_error_set),
    .overflow_set(overflow_set),
    .tx_enable(tx_enable),
    .rx_enable(rx_enable),
    .baud_div(baud_div)
);

assign frame_error_set = rx_valid && rx_enable && rx_frame_error;
assign overflow_set    = rx_valid && rx_enable && rx_fifo_full;

always_comb begin
    rx_fifo_wr_en = rx_valid && rx_enable && !rx_fifo_full;
end

always_ff @(posedge pclk or negedge presetn) begin
    if (!presetn) begin
        tx_fifo_rd_en  <= 1'b0;
        tx_data        <= 8'd0;
        tx_start       <= 1'b0;
        tx_state       <= TX_IDLE;
    end else begin
        tx_fifo_rd_en <= 1'b0;
        tx_start      <= 1'b0;

        case (tx_state)
            TX_IDLE: begin
                if (tx_enable && !tx_busy && !tx_fifo_empty) begin
                    tx_fifo_rd_en <= 1'b1;
                    tx_state      <= TX_POP;
                end
            end

            TX_POP: begin
                tx_state <= TX_LOAD;
            end

            TX_LOAD: begin
                tx_data <= tx_fifo_rd_data;
                if (tx_enable && !tx_busy) begin
                    tx_start <= 1'b1;
                    tx_state <= TX_IDLE;
                end
            end

            default: begin
                tx_state <= TX_IDLE;
            end
        endcase
    end
end

endmodule
