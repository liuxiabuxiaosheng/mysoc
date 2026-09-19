`timescale 1ns/1ps
module tb_audio_ctrl;
    logic clk, rst_n;
    logic [31:0] paddr, pwdata;
    logic psel, penable, pwrite;
    wire [31:0] prdata;
    wire pready, pslverr;
    wire audio_enable, audio_bypass, audio_clear_state, coeff_we;
    wire [3:0] coeff_index;
    wire signed [15:0] coeff_data;
    logic [5:0] status;
    logic [31:0] sample_count;
    logic signed [15:0] last_output;

    audio_ctrl dut (
        .clk(clk), .rst_n(rst_n), .paddr(paddr), .psel(psel), .penable(penable), .pwrite(pwrite), .pwdata(pwdata),
        .prdata(prdata), .pready(pready), .pslverr(pslverr), .audio_enable(audio_enable), .audio_bypass(audio_bypass),
        .audio_clear_state(audio_clear_state), .coeff_we(coeff_we), .coeff_index(coeff_index), .coeff_data(coeff_data),
        .status(status), .sample_count(sample_count), .last_output(last_output)
    );
    always #5 clk = ~clk;

    task automatic apb_write(input [11:0] offset, input [31:0] data);
        begin @(negedge clk); paddr=offset; pwdata=data; pwrite=1; psel=1; penable=0;
        @(negedge clk); penable=1; if (!pready || pslverr) $fatal(1, "audio APB write failed");
        @(negedge clk); psel=0; penable=0; pwrite=0; end
    endtask
    task automatic apb_read(input [11:0] offset, output [31:0] data);
        begin @(negedge clk); paddr=offset; pwrite=0; psel=1; penable=0;
        @(negedge clk); penable=1; if (!pready || pslverr) $fatal(1, "audio APB read failed");
        #1 data=prdata; @(negedge clk); psel=0; penable=0; end
    endtask

    logic [31:0] value;
    initial begin
        clk=0; rst_n=0; paddr=0; pwdata=0; psel=0; penable=0; pwrite=0; status=0; sample_count=0; last_output=0;
        repeat (2) @(posedge clk); rst_n=1;
        apb_write(12'h000, 32'h7);
        if (!audio_enable || !audio_bypass) $fatal(1, "AUDIO_CTRL outputs wrong");
        apb_write(12'h010, 32'h3);
        apb_write(12'h014, 32'h0000_4000);
        if (!coeff_we || coeff_index !== 4'd3 || coeff_data !== 16'sh4000) $fatal(1, "coefficient write wrong");
        status=6'b10_1010; sample_count=32'd7; last_output=-16'sd123;
        apb_read(12'h004, value);
        if (value !== 32'h0000_002A) $fatal(1, "status read wrong: %h", value);
        apb_read(12'h018, value);
        if (value !== 32'd7) $fatal(1, "count read wrong: %h", value);
        apb_read(12'h00C, value);
        if (value !== 32'hFFFF_FF85) $fatal(1, "last output read wrong: %h", value);
        apb_write(12'h004, 32'h2A);
        $display("PASS tb_audio_ctrl");
        $finish;
    end
endmodule
