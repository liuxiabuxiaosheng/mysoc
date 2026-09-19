/*异步释放可能造成：
不同寄存器不同步启动。

标准：
异步拉低，同步释放*/
module reset_sync(

    input  wire clk,
    input  wire rst_n,

    output wire rst_sync

);

reg rst_ff1;
reg rst_ff2;

always @(posedge clk or negedge rst_n)
begin

    if(!rst_n)begin
       rst_ff1 <= 1'b0;
       rst_ff2 <= 1'b0;
    end
    else begin
        rst_ff1 <= 1'b1;
        rst_ff2 <= rst_ff1;
    end
end
assign rst_sync = rst_ff2;
endmodule
