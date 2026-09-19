`timescale 1ns/1ps
module tb_async_fifo;
    logic wr_clk, rd_clk;
    logic wr_rst_n, rd_rst_n;
    logic wr_en, rd_en;
    logic [15:0] wr_data;
    wire [15:0] rd_data;
    wire full, empty, overflow, underflow;
    integer i;

    async_fifo #(.DATA_WIDTH(16), .ADDR_WIDTH(4)) dut (
        .wr_clk(wr_clk), .wr_rst_n(wr_rst_n), .wr_en(wr_en), .wr_data(wr_data),
        .full(full), .overflow(overflow), .rd_clk(rd_clk), .rd_rst_n(rd_rst_n),
        .rd_en(rd_en), .rd_data(rd_data), .empty(empty), .underflow(underflow)
    );

    always #3 wr_clk = ~wr_clk;
    always #5 rd_clk = ~rd_clk;

    initial begin
        wr_clk=0; rd_clk=0; wr_rst_n=0; rd_rst_n=0; wr_en=0; rd_en=0; wr_data=0;
        repeat (3) @(posedge wr_clk);
        wr_rst_n=1;
        repeat (2) @(posedge rd_clk);
        rd_rst_n=1;
        repeat (3) @(posedge rd_clk);
        if (!empty) $fatal(1, "FIFO not empty after reset");

        for (i=0; i<16; i=i+1) begin
            @(negedge wr_clk);
            while (full) @(negedge wr_clk);
            wr_data=i;
            wr_en=1;
            @(negedge wr_clk);
            wr_en=0;
        end
        repeat (4) @(posedge wr_clk);
        if (!full) $fatal(1, "FIFO did not assert full");
        @(negedge wr_clk); wr_en=1; wr_data=16'hFFFF;
        @(negedge wr_clk); wr_en=0;
        if (!overflow) $fatal(1, "FIFO overflow flag missing");

        for (i=0; i<16; i=i+1) begin
            @(negedge rd_clk);
            while (empty) @(negedge rd_clk);
            rd_en=1;
            @(posedge rd_clk); #1;
            if (rd_data !== i[15:0]) $fatal(1, "FIFO order mismatch at %0d: %h", i, rd_data);
            rd_en=0;
        end
        repeat (4) @(posedge rd_clk);
        if (!empty) $fatal(1, "FIFO did not assert empty");
        @(negedge rd_clk); rd_en=1;
        @(posedge rd_clk); #1; rd_en=0;
        if (!underflow) $fatal(1, "FIFO underflow flag missing");

        wr_rst_n=0;
        rd_rst_n=0;
        repeat (3) @(posedge rd_clk);
        wr_rst_n=1;
        repeat (2) @(posedge wr_clk);
        rd_rst_n=1;
        repeat (3) @(posedge rd_clk);
        if (!empty || underflow) $fatal(1, "independent reset release did not clear local state");

        $display("PASS tb_async_fifo");
        $finish;
    end
endmodule
