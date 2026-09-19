`timescale 1ns/1ps

module tb_uart_tx;
    localparam int BAUD_DIV = 8;

    logic        clk;
    logic        rst_n;
    logic [7:0]  data_in;
    logic        start;
    logic [31:0] baud_div;
    logic        tx;
    logic        busy;
    logic        done;

    int done_count;

    uart_tx dut (
        .clk(clk),
        .rst_n(rst_n),
        .data_in(data_in),
        .start(start),
        .baud_div(baud_div),
        .tx(tx),
        .busy(busy),
        .done(done)
    );

    always #5 clk = ~clk;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            done_count <= 0;
        else if (done)
            done_count <= done_count + 1;
    end

    task automatic check(input logic condition, input string message);
        begin
            if (!condition) $fatal(1, "%s", message);
        end
    endtask

    task automatic sample_bit_after(input int wait_cycles, input int index, input logic expected_tx);
        begin
            repeat (wait_cycles) @(posedge clk);
            #1;
            check(tx === expected_tx, $sformatf("bit %0d tx=%0b expected=%0b", index, tx, expected_tx));
            check(busy === 1'b1, $sformatf("bit %0d busy deasserted inside frame", index));
            check(done === 1'b0, $sformatf("bit %0d done asserted before frame end", index));
        end
    endtask

    initial begin
        clk = 1'b0;
        rst_n = 1'b0;
        data_in = 8'h00;
        start = 1'b0;
        baud_div = BAUD_DIV;

        repeat (2) @(posedge clk);
        @(negedge clk);
        rst_n = 1'b1;
        #1;
        check(tx === 1'b1, "reset should leave tx idle high");
        check(busy === 1'b0, "reset should leave transmitter idle");
        check(done === 1'b0, "reset should clear done");

        @(negedge clk);
        data_in = 8'hA5;
        start = 1'b1;
        @(posedge clk);
        #1;
        check(busy === 1'b1, "start should make transmitter busy");
        check(done === 1'b0, "done should not assert on start");

        @(negedge clk);
        start = 1'b0;

        @(negedge clk);
        start = 1'b1;
        data_in = 8'h5A;
        @(posedge clk);
        #1;
        check(busy === 1'b1, "busy start should leave transmitter busy");
        @(negedge clk);
        start = 1'b0;

        sample_bit_after(BAUD_DIV / 2 - 2, 0, 1'b0);
        sample_bit_after(BAUD_DIV, 1, 1'b1);
        sample_bit_after(BAUD_DIV, 2, 1'b0);
        sample_bit_after(BAUD_DIV, 3, 1'b1);
        sample_bit_after(BAUD_DIV, 4, 1'b0);
        sample_bit_after(BAUD_DIV, 5, 1'b0);
        sample_bit_after(BAUD_DIV, 6, 1'b1);
        sample_bit_after(BAUD_DIV, 7, 1'b0);
        sample_bit_after(BAUD_DIV, 8, 1'b1);
        sample_bit_after(BAUD_DIV, 9, 1'b1);

        repeat (BAUD_DIV / 2) @(posedge clk);
        #1;
        check(done === 1'b1, "done should pulse after final stop-bit clock");
        check(done_count == 0, "done should not pulse before frame completion");

        @(posedge clk);
        #1;
        check(done === 1'b0, "done should be one clock wide");
        check(done_count == 1, "done should pulse exactly once");
        check(busy === 1'b0, "busy should clear after frame completion");
        check(tx === 1'b1, "tx should return idle high");

        repeat (4) @(posedge clk);
        check(done_count == 1, "busy start should have been ignored");

        $display("PASS tb_uart_tx");
        $finish;
    end
endmodule
