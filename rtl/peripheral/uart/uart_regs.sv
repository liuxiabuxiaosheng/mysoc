module uart_regs (
    input  wire        pclk,
    input  wire        presetn,

    input  wire [31:0] paddr,
    input  wire        psel,
    input  wire        penable,
    input  wire        pwrite,
    input  wire [31:0] pwdata,

    output reg  [31:0] prdata,
    output wire        pready,
    output wire        pslverr,

    input  wire        tx_fifo_empty,
    input  wire        tx_fifo_full,
    output wire        tx_fifo_wr_en,
    output wire [7:0]  tx_fifo_wr_data,

    input  wire        rx_fifo_empty,
    input  wire        rx_fifo_full,
    output wire        rx_fifo_rd_en,
    input  wire [7:0]  rx_fifo_rd_data,

    input  wire        frame_error_set,
    input  wire        overflow_set,

    output wire        tx_enable,
    output wire        rx_enable,
    output wire [31:0] baud_div
);

reg [31:0] ctrl_reg;
reg [31:0] baud_reg;
reg        frame_error_sticky;
reg        overflow_sticky;
reg        rx_read_wait;

wire        apb_access;
wire        valid_offset;
wire        data_offset;
wire        status_offset;
wire        ctrl_offset;
wire        baud_offset;
wire        data_write;
wire        data_read;
wire        ctrl_write;
wire        baud_write;
wire        ctrl_clear_errors;
wire        tx_write_illegal;
wire        rx_read_illegal;
wire [31:0] status_value;

assign apb_access   = psel && penable;
assign data_offset  = (paddr[11:0] == 12'h000);
assign status_offset = (paddr[11:0] == 12'h004);
assign ctrl_offset  = (paddr[11:0] == 12'h008);
assign baud_offset  = (paddr[11:0] == 12'h00C);
assign valid_offset = data_offset || status_offset || ctrl_offset || baud_offset;

assign data_write = apb_access && pwrite && data_offset && !rx_read_wait;
assign data_read  = apb_access && !pwrite && data_offset && !rx_read_wait;
assign ctrl_write = apb_access && pwrite && ctrl_offset && !rx_read_wait;
assign baud_write = apb_access && pwrite && baud_offset && !rx_read_wait;

assign tx_enable = ctrl_reg[0];
assign rx_enable = ctrl_reg[1];
assign baud_div  = baud_reg;

assign tx_write_illegal = data_write && (!tx_enable || tx_fifo_full);
assign rx_read_illegal  = data_read && (!rx_enable || rx_fifo_empty);
assign pslverr = apb_access && !rx_read_wait &&
                 (!valid_offset || tx_write_illegal || rx_read_illegal);

assign pready = rx_read_wait ? 1'b1 :
                (data_read && !rx_read_illegal) ? 1'b0 : 1'b1;

assign tx_fifo_wr_en   = data_write && !pslverr;
assign tx_fifo_wr_data = pwdata[7:0];
assign rx_fifo_rd_en   = data_read && !rx_read_illegal;
assign ctrl_clear_errors = ctrl_write && pwdata[8] && !pslverr;

assign status_value = {
    26'd0,
    overflow_sticky,
    frame_error_sticky,
    rx_fifo_full,
    rx_fifo_empty,
    tx_fifo_full,
    tx_fifo_empty
};

always_ff @(posedge pclk or negedge presetn) begin
    if (!presetn) begin
        ctrl_reg           <= 32'd0;
        baud_reg           <= 32'd868;
        frame_error_sticky <= 1'b0;
        overflow_sticky    <= 1'b0;
        rx_read_wait       <= 1'b0;
    end else begin
        if (ctrl_write && !pslverr)
            ctrl_reg <= {30'd0, pwdata[1:0]};

        if (baud_write && !pslverr)
            baud_reg <= (pwdata < 32'd8) ? 32'd8 : pwdata;

        if (ctrl_clear_errors) begin
            frame_error_sticky <= frame_error_set;
            overflow_sticky    <= overflow_set;
        end else begin
            if (frame_error_set)
                frame_error_sticky <= 1'b1;
            if (overflow_set)
                overflow_sticky <= 1'b1;
        end

        if (data_read && !rx_read_illegal)
            rx_read_wait <= 1'b1;
        else if (!psel || !penable)
            rx_read_wait <= 1'b0;
    end
end

always @(*) begin
    if (rx_read_wait) begin
        prdata = {24'd0, rx_fifo_rd_data};
    end else begin
        case (paddr[11:0])
            12'h000: prdata = 32'd0;
            12'h004: prdata = status_value;
            12'h008: prdata = ctrl_reg;
            12'h00C: prdata = baud_reg;
            default: prdata = 32'd0;
        endcase
    end
end

endmodule
