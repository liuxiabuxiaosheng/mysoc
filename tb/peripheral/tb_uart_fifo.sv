`timescale 1ns/1ps

module tb_uart_fifo;
    logic       clk;
    logic       rst_n;
    logic       wr_en;
    logic [7:0] wr_data;
    logic       full;
    logic       rd_en;
    logic [7:0] rd_data;
    logic       empty;
    logic [2:0] count;

    uart_fifo #(.DATA_WIDTH(8), .DEPTH(4)) dut (
        .clk(clk), .rst_n(rst_n),
        .wr_en(wr_en), .wr_data(wr_data), .full(full),
        .rd_en(rd_en), .rd_data(rd_data), .empty(empty), .count(count)
    );

    always #5 clk = ~clk;

    task automatic write_byte(input logic [7:0] value, input logic [2:0] expected_count,
                              input logic expected_full);
        begin
            @(negedge clk);
            wr_en = 1'b1;
            wr_data = value;
            rd_en = 1'b0;
            @(posedge clk); #1;
            wr_en = 1'b0;
            if (count !== expected_count) $fatal(1, "write %h count=%0d expected=%0d", value, count, expected_count);
            if (full !== expected_full) $fatal(1, "write %h full mismatch", value);
        end
    endtask

    task automatic read_byte(input logic [7:0] expected_data, input logic [2:0] expected_count,
                             input logic expected_empty);
        begin
            @(negedge clk);
            wr_en = 1'b0;
            rd_en = 1'b1;
            @(posedge clk); #1;
            rd_en = 1'b0;
            if (rd_data !== expected_data) $fatal(1, "read data=%h expected=%h", rd_data, expected_data);
            if (count !== expected_count) $fatal(1, "read count=%0d expected=%0d", count, expected_count);
            if (empty !== expected_empty) $fatal(1, "read empty mismatch");
        end
    endtask

    initial begin
        clk = 1'b0;
        rst_n = 1'b0;
        wr_en = 1'b0;
        wr_data = 8'h00;
        rd_en = 1'b0;

        repeat (2) @(posedge clk);
        @(negedge clk);
        rst_n = 1'b1;
        #1;
        if (count !== 3'd0 || empty !== 1'b1 || full !== 1'b0)
            $fatal(1, "reset state mismatch");

        write_byte(8'h11, 3'd1, 1'b0);
        write_byte(8'h22, 3'd2, 1'b0);
        write_byte(8'h33, 3'd3, 1'b0);
        write_byte(8'h44, 3'd4, 1'b1);
        write_byte(8'h55, 3'd4, 1'b1);

        read_byte(8'h11, 3'd3, 1'b0);
        read_byte(8'h22, 3'd2, 1'b0);
        write_byte(8'h55, 3'd3, 1'b0);
        write_byte(8'h66, 3'd4, 1'b1);
        read_byte(8'h33, 3'd3, 1'b0);
        read_byte(8'h44, 3'd2, 1'b0);
        read_byte(8'h55, 3'd1, 1'b0);
        read_byte(8'h66, 3'd0, 1'b1);
        read_byte(8'h66, 3'd0, 1'b1);

        $display("PASS tb_uart_fifo");
        $finish;
    end
endmodule
