`timescale 1ns/1ps
module tb_board_top;
    localparam integer BAUD_DIV = 868;
    localparam integer MESSAGE_LEN = 18;
    logic clk_50m = 1'b0;
    logic rst_n = 1'b0;
    logic uart_rx = 1'b1;
    wire uart_tx;
    wire [0:0] led;
    logic [7:0] received [0:MESSAGE_LEN-1];
    integer i;

    board_top dut (
        .clk_50m(clk_50m), .rst_n(rst_n), .uart_rx(uart_rx),
        .uart_tx(uart_tx), .led(led)
    );

    always #10 clk_50m = ~clk_50m;

    task automatic check(input logic condition, input string message);
        if (!condition) $fatal(1, "%s", message);
    endtask

    task automatic receive_byte(output logic [7:0] value);
        integer bit_index;
        begin
            @(negedge uart_tx);
            repeat (BAUD_DIV + BAUD_DIV/2) @(posedge clk_50m);
            for (bit_index = 0; bit_index < 8; bit_index = bit_index + 1) begin
                value[bit_index] = uart_tx;
                repeat (BAUD_DIV) @(posedge clk_50m);
            end
            check(uart_tx === 1'b1, "UART stop bit was not high");
        end
    endtask

    initial begin
        repeat (250000) @(posedge clk_50m);
        $fatal(1, "Timed out waiting for complete UART hello message");
    end

    initial begin
        repeat (3) @(posedge clk_50m);
        check(led[0] === 1'b0, "LED asserted while reset was active");
        rst_n = 1'b1;
        repeat (5) @(posedge clk_50m);
        check(led[0] === 1'b1, "LED did not assert after reset synchronization");
        for (i = 0; i < MESSAGE_LEN; i = i + 1)
            receive_byte(received[i]);
        check({received[0], received[1], received[2], received[3], received[4],
               received[5], received[6], received[7], received[8], received[9],
               received[10], received[11], received[12], received[13], received[14],
               received[15], received[16], received[17]} ==
              "Hello RISC-V SoC\r\n", "UART hello message mismatch");
        check(!dut.u_soc.cpu_halted, "Internal CPU halted while transmitting hello");
        $display("PASS tb_board_top");
        $finish;
    end
endmodule
