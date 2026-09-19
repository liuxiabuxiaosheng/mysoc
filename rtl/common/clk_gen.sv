module clk_gen(

input wire clk_in,
input wire rst_n,
output wire clk_sys,
output reg locked
);

// Phase one uses the 50 MHz board clock directly. A later Vivado
// clocking task will replace this wrapper with the final clock generator.
assign clk_sys = clk_in;

always @(posedge clk_in or negedge rst_n)
begin
    if (!rst_n)
        locked <= 1'b0;
    else
        locked <= 1'b1;
end

endmodule
