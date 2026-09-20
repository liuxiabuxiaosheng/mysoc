`timescale 1ns/1ps
module tb_riscv_muldiv;
    logic clk, rst_n, start;
    logic [2:0] op;
    logic [31:0] a, b;
    wire busy, done;
    wire [31:0] result;

    riscv_muldiv dut(.clk(clk), .rst_n(rst_n), .start(start), .op(op),
                     .a(a), .b(b), .busy(busy), .done(done), .result(result));
    always #5 clk=~clk;

    task automatic run_op(input [2:0] op_i, input [31:0] a_i, input [31:0] b_i,
                          input [31:0] expected);
        begin
            @(negedge clk); op=op_i; a=a_i; b=b_i; start=1;
            @(negedge clk); start=0;
            wait(done); #1;
            if (result !== expected) begin
                $fatal(1, "op %0d %h %h -> %h expected %h", op_i, a_i, b_i, result, expected);
            end
        end
    endtask

    initial begin
        clk=0; rst_n=0; start=0; op=0; a=0; b=0;
        repeat(2) @(posedge clk); rst_n=1;
        run_op(3'd0, 32'd7, 32'd6, 32'd42);
        run_op(3'd1, 32'hffff_fffe, 32'd3, 32'hffff_ffff);
        run_op(3'd2, 32'hffff_fffe, 32'hffff_ffff, 32'hffff_fffe);
        run_op(3'd3, 32'hffff_fffe, 32'hffff_ffff, 32'hffff_fffd);
        run_op(3'd4, 32'd42, 32'd5, 32'd8);
        run_op(3'd5, 32'd42, 32'd5, 32'd8);
        run_op(3'd6, 32'd42, 32'd5, 32'd2);
        run_op(3'd7, 32'd42, 32'd5, 32'd2);
        run_op(3'd4, 32'd1, 32'd0, 32'hffff_ffff);
        run_op(3'd6, 32'd1, 32'd0, 32'd1);
        run_op(3'd4, 32'h8000_0000, 32'hffff_ffff, 32'h8000_0000);
        run_op(3'd6, 32'h8000_0000, 32'hffff_ffff, 32'd0);
        $display("PASS tb_riscv_muldiv");
        $finish;
    end
endmodule
