`timescale 1ns/1ps
module tb_smoke;
    initial begin
        if (32'h4000_2000 + 32'h0000_000C !== 32'h4000_200C)
            $fatal(1, "address arithmetic failed");
        $display("PASS tb_smoke");
        $finish;
    end
endmodule
