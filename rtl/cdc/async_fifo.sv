module async_fifo #(
    parameter integer DATA_WIDTH = 16,
    parameter integer ADDR_WIDTH = 4
) (
    input  logic                  wr_clk,
    input  logic                  wr_rst_n,
    input  logic                  wr_en,
    input  logic [DATA_WIDTH-1:0] wr_data,
    output logic                  full,
    output logic                  overflow,

    input  logic                  rd_clk,
    input  logic                  rd_rst_n,
    input  logic                  rd_en,
    output logic [DATA_WIDTH-1:0] rd_data,
    output logic                  empty,
    output logic                  underflow
);
    localparam integer PTR_WIDTH = ADDR_WIDTH + 1;
    localparam integer DEPTH = (1 << ADDR_WIDTH);

    logic [DATA_WIDTH-1:0] mem [0:DEPTH-1];

    logic [PTR_WIDTH-1:0] wr_ptr_bin, wr_ptr_gray;
    logic [PTR_WIDTH-1:0] rd_ptr_bin, rd_ptr_gray;
    logic [PTR_WIDTH-1:0] rd_gray_wr_meta, rd_gray_wr_sync;
    logic [PTR_WIDTH-1:0] wr_gray_rd_meta, wr_gray_rd_sync;

    logic [PTR_WIDTH-1:0] wr_ptr_bin_next, wr_ptr_gray_next;
    logic [PTR_WIDTH-1:0] rd_ptr_bin_next, rd_ptr_gray_next;
    logic [PTR_WIDTH-1:0] rd_gray_full_cmp;
    logic                  full_next, empty_next;

    wire wr_fire = wr_en && !full;
    wire rd_fire = rd_en && !empty;

    initial begin
        if (ADDR_WIDTH < 1)
            $fatal(1, "async_fifo ADDR_WIDTH must be at least 1");
    end

    generate
        if (PTR_WIDTH == 2) begin : g_full_cmp_depth2
            assign rd_gray_full_cmp = ~rd_gray_wr_sync;
        end else begin : g_full_cmp_general
            assign rd_gray_full_cmp = {
                ~rd_gray_wr_sync[PTR_WIDTH-1:PTR_WIDTH-2],
                 rd_gray_wr_sync[PTR_WIDTH-3:0]
            };
        end
    endgenerate

    always_comb begin
        wr_ptr_bin_next  = wr_ptr_bin + wr_fire;
        wr_ptr_gray_next = (wr_ptr_bin_next >> 1) ^ wr_ptr_bin_next;
        full_next = (wr_ptr_gray_next == rd_gray_full_cmp);
    end

    always_comb begin
        rd_ptr_bin_next  = rd_ptr_bin + rd_fire;
        rd_ptr_gray_next = (rd_ptr_bin_next >> 1) ^ rd_ptr_bin_next;
        empty_next = (rd_ptr_gray_next == wr_gray_rd_sync);
    end

    always_ff @(posedge wr_clk or negedge wr_rst_n) begin
        if (!wr_rst_n) begin
            wr_ptr_bin      <= '0;
            wr_ptr_gray     <= '0;
            rd_gray_wr_meta <= '0;
            rd_gray_wr_sync <= '0;
            full            <= 1'b0;
            overflow        <= 1'b0;
        end else begin
            rd_gray_wr_meta <= rd_ptr_gray;
            rd_gray_wr_sync <= rd_gray_wr_meta;
            if (wr_fire)
                mem[wr_ptr_bin[ADDR_WIDTH-1:0]] <= wr_data;
            wr_ptr_bin  <= wr_ptr_bin_next;
            wr_ptr_gray <= wr_ptr_gray_next;
            full        <= full_next;
            if (wr_en && full)
                overflow <= 1'b1;
        end
    end

    always_ff @(posedge rd_clk or negedge rd_rst_n) begin
        if (!rd_rst_n) begin
            rd_ptr_bin      <= '0;
            rd_ptr_gray     <= '0;
            wr_gray_rd_meta <= '0;
            wr_gray_rd_sync <= '0;
            rd_data         <= '0;
            empty           <= 1'b1;
            underflow       <= 1'b0;
        end else begin
            wr_gray_rd_meta <= wr_ptr_gray;
            wr_gray_rd_sync <= wr_gray_rd_meta;
            if (rd_fire)
                rd_data <= mem[rd_ptr_bin[ADDR_WIDTH-1:0]];
            rd_ptr_bin  <= rd_ptr_bin_next;
            rd_ptr_gray <= rd_ptr_gray_next;
            empty       <= empty_next;
            if (rd_en && empty)
                underflow <= 1'b1;
        end
    end
endmodule
