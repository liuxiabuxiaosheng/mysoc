`timescale 1ns/1ps

module tb_uart_rx;
    localparam int BAUD_DIV = 8;

    logic        clk;
    logic        rst_n;
    logic        rx;
    logic [31:0] baud_div;
    logic [7:0]  data_out;
    logic        valid;
    logic        frame_error;

    uart_rx dut (
        .clk(clk),
        .rst_n(rst_n),
        .rx(rx),
        .baud_div(baud_div),
        .data_out(data_out),
        .valid(valid),
        .frame_error(frame_error)
    );

    always #5 clk = ~clk;

    task automatic check(input logic condition, input string message);
        begin
            if (!condition) $fatal(1, "%s", message);
        end
    endtask

    task automatic drive_bit(input logic value, input int cycles);
        begin
            @(negedge clk);
            rx = value;
            repeat (cycles) @(posedge clk);
        end
    endtask

    task automatic send_frame(input logic [7:0] value, input logic stop_value);
        begin
            drive_bit(1'b0, BAUD_DIV);
            drive_bit(value[0], BAUD_DIV);
            drive_bit(value[1], BAUD_DIV);
            drive_bit(value[2], BAUD_DIV);
            drive_bit(value[3], BAUD_DIV);
            drive_bit(value[4], BAUD_DIV);
            drive_bit(value[5], BAUD_DIV);
            drive_bit(value[6], BAUD_DIV);
            drive_bit(value[7], BAUD_DIV);
            drive_bit(stop_value, BAUD_DIV);
            drive_bit(1'b1, BAUD_DIV * 2);
        end
    endtask

    task automatic expect_byte(input logic [7:0] expected_data,
                               input logic expected_frame_error);
        int cycles;
        int seen;
        begin
            seen = 0;
            for (cycles = 0; cycles < BAUD_DIV * 14; cycles = cycles + 1) begin
                @(posedge clk);
                #1;
                if (valid) begin
                    check(seen == 0, "valid should pulse only once per frame");
                    check(data_out === expected_data,
                          $sformatf("data_out=%h expected=%h", data_out, expected_data));
                    check(frame_error === expected_frame_error,
                          $sformatf("frame_error=%0b expected=%0b", frame_error, expected_frame_error));
                    seen = seen + 1;
                    @(posedge clk);
                    #1;
                    check(valid === 1'b0, "valid should be one clock wide");
                    check(frame_error === 1'b0, "frame_error should be one clock wide");
                end
            end
            check(seen == 1, "expected one received byte");
        end
    endtask

    task automatic expect_no_byte(input int cycles_to_watch);
        int cycles;
        begin
            for (cycles = 0; cycles < cycles_to_watch; cycles = cycles + 1) begin
                @(posedge clk);
                #1;
                check(valid === 1'b0, "glitch should not produce valid");
                check(frame_error === 1'b0, "glitch should not produce frame_error");
            end
        end
    endtask

    initial begin
        clk = 1'b0;
        rst_n = 1'b0;
        rx = 1'b1;
        baud_div = BAUD_DIV;

        repeat (2) @(posedge clk);
        @(negedge clk);
        rst_n = 1'b1;
        #1;
        check(valid === 1'b0, "reset should clear valid");
        check(frame_error === 1'b0, "reset should clear frame_error");

        fork
            send_frame(8'h3C, 1'b1);
            expect_byte(8'h3C, 1'b0);
        join

        fork
            send_frame(8'h3C, 1'b0);
            expect_byte(8'h3C, 1'b1);
        join

        fork
            begin
                drive_bit(1'b0, BAUD_DIV / 2 - 1);
                drive_bit(1'b1, BAUD_DIV * 13);
            end
            expect_no_byte(BAUD_DIV * 12 + 8);
        join

        $display("PASS tb_uart_rx");
        $finish;
    end
endmodule
