`timescale 1ns/1ps
module tb_dma_audio_endpoints;
    logic clk, rst_n;
    logic [31:0] paddr, pwdata;
    logic psel, penable, pwrite;
    wire [31:0] prdata; wire pready, pslverr;
    wire mem_req_valid, mem_req_write; wire [31:0] mem_req_addr, mem_req_wdata; wire [3:0] mem_req_wstrb;
    logic [31:0] mem_resp_rdata; logic mem_resp_ready, mem_resp_error;
    wire fifo_in_valid; wire signed [15:0] fifo_in_data; logic fifo_in_ready;
    wire fifo_out_ready; logic fifo_out_valid; logic signed [15:0] fifo_out_data;
    logic [31:0] mem [0:255]; logic signed [15:0] input_samples [0:3];
    logic signed [15:0] output_samples [0:3]; integer in_count, out_count, i, timeout;

    dma_controller dut (
        .clk(clk), .rst_n(rst_n), .paddr(paddr), .psel(psel), .penable(penable), .pwrite(pwrite), .pwdata(pwdata),
        .prdata(prdata), .pready(pready), .pslverr(pslverr), .mem_req_valid(mem_req_valid), .mem_req_write(mem_req_write),
        .mem_req_addr(mem_req_addr), .mem_req_wdata(mem_req_wdata), .mem_req_wstrb(mem_req_wstrb),
        .mem_resp_rdata(mem_resp_rdata), .mem_resp_ready(mem_resp_ready), .mem_resp_error(mem_resp_error),
        .fifo_in_valid(fifo_in_valid), .fifo_in_data(fifo_in_data), .fifo_in_ready(fifo_in_ready),
        .fifo_out_ready(fifo_out_ready), .fifo_out_valid(fifo_out_valid), .fifo_out_data(fifo_out_data)
    );
    always #5 clk = ~clk;

    assign fifo_out_valid = (out_count < 4);
    assign fifo_out_data = output_samples[out_count];
    always_comb begin
        mem_resp_rdata = mem[mem_req_addr[9:2]];
        mem_resp_ready = mem_req_valid;
        mem_resp_error = 1'b0;
    end
    always @(posedge clk) begin
        if (fifo_in_valid && fifo_in_ready) begin input_samples[in_count] <= fifo_in_data; in_count <= in_count + 1; end
        if (fifo_out_ready && fifo_out_valid) out_count <= out_count + 1;
        if (mem_req_valid && mem_req_write && mem_resp_ready) mem[mem_req_addr[9:2]] <= mem_req_wdata;
    end

    task automatic apb_write(input [11:0] offset, input [31:0] data);
        begin @(negedge clk); paddr=offset; pwdata=data; pwrite=1; psel=1; penable=0; @(negedge clk); penable=1;
        @(negedge clk); psel=0; penable=0; pwrite=0; end
    endtask
    task automatic wait_done;
        begin timeout=0; while ((timeout < 100) && !prdata[1]) begin apb_write(12'h010, 0); @(negedge clk); paddr=12'h010; pwrite=0; psel=1; penable=0; @(negedge clk); penable=1; #1; timeout=timeout+1; @(negedge clk); psel=0; penable=0; end
        if (timeout >= 100) $fatal(1, "DMA endpoint timeout"); end
    endtask

    initial begin
        clk=0; rst_n=0; paddr=0; pwdata=0; psel=0; penable=0; pwrite=0; fifo_in_ready=1; in_count=0; out_count=0;
        output_samples[0]=-16'sd100; output_samples[1]=16'sd200; output_samples[2]=16'sd300; output_samples[3]=-16'sd400;
        repeat (2) @(posedge clk); rst_n=1;
        mem[16]=32'h2222_1111; mem[17]=32'h4444_3333;
        apb_write(12'h000, 32'h40); apb_write(12'h004, 32'h4000_3008); apb_write(12'h008, 32'd2); apb_write(12'h00c, 1);
        timeout=0; while ((timeout<100) && (in_count<4)) begin @(posedge clk); timeout=timeout+1; end
        if (input_samples[0] !== 16'h1111 || input_samples[1] !== 16'h2222 || input_samples[2] !== 16'h3333 || input_samples[3] !== 16'h4444) $fatal(1, "input endpoint packing failed");
        apb_write(12'h010, 32'h2);
        apb_write(12'h000, 32'h4000_300c); apb_write(12'h004, 32'h80); apb_write(12'h008, 32'd2); apb_write(12'h00c, 1);
        timeout=0; while ((timeout<100) && (out_count<4)) begin @(posedge clk); timeout=timeout+1; end
        repeat (5) @(posedge clk);
        if (mem[32] !== {output_samples[1], output_samples[0]} || mem[33] !== {output_samples[3], output_samples[2]}) $fatal(1, "output endpoint packing failed: %h %h", mem[32], mem[33]);
        $display("PASS tb_dma_audio_endpoints"); $finish;
    end
endmodule
