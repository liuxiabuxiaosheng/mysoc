`timescale 1ns/1ps

module tb_cpu_bus_decoder;
    logic        clk;
    logic        rst_n;
    logic        cpu_req_valid;
    logic        cpu_req_write;
    logic [31:0] cpu_req_addr;
    logic [31:0] cpu_req_wdata;
    logic [3:0]  cpu_req_wstrb;
    logic [31:0] cpu_resp_rdata;
    logic        cpu_resp_ready;
    logic        cpu_resp_error;

    logic        ram_req_valid;
    logic        ram_req_write;
    logic [31:0] ram_req_addr;
    logic [31:0] ram_req_wdata;
    logic [3:0]  ram_req_wstrb;
    logic [31:0] ram_resp_rdata;
    logic        ram_resp_ready;
    logic        ram_resp_error;

    logic        apb_req_valid;
    logic        apb_req_write;
    logic [31:0] apb_req_addr;
    logic [31:0] apb_req_wdata;
    logic [3:0]  apb_req_wstrb;
    logic [31:0] apb_resp_rdata;
    logic        apb_resp_ready;
    logic        apb_resp_error;
    logic [31:0] apb_paddr;
    logic        apb_psel;
    logic        apb_penable;
    logic        apb_pwrite;
    logic [31:0] apb_pwdata;
    logic [3:0]  apb_pstrb;
    logic [31:0] apb_prdata;
    logic        apb_pready;
    logic        apb_pslverr;
    logic [7:0]  gpio_in;
    logic [7:0]  gpio_out;
    logic [7:0]  gpio_dir;
    logic        timer_irq;
    logic        uart_rx;
    logic        uart_tx;

    cpu_bus_decoder u_decoder (
        .clk(clk), .rst_n(rst_n),
        .cpu_req_valid(cpu_req_valid), .cpu_req_write(cpu_req_write),
        .cpu_req_addr(cpu_req_addr), .cpu_req_wdata(cpu_req_wdata), .cpu_req_wstrb(cpu_req_wstrb),
        .cpu_resp_rdata(cpu_resp_rdata), .cpu_resp_ready(cpu_resp_ready), .cpu_resp_error(cpu_resp_error),
        .ram_req_valid(ram_req_valid), .ram_req_write(ram_req_write),
        .ram_req_addr(ram_req_addr), .ram_req_wdata(ram_req_wdata), .ram_req_wstrb(ram_req_wstrb),
        .ram_resp_rdata(ram_resp_rdata), .ram_resp_ready(ram_resp_ready), .ram_resp_error(ram_resp_error),
        .apb_req_valid(apb_req_valid), .apb_req_write(apb_req_write),
        .apb_req_addr(apb_req_addr), .apb_req_wdata(apb_req_wdata), .apb_req_wstrb(apb_req_wstrb),
        .apb_resp_rdata(apb_resp_rdata), .apb_resp_ready(apb_resp_ready), .apb_resp_error(apb_resp_error)
    );

    onchip_ram u_ram (
        .clk(clk), .rst_n(rst_n),
        .req_valid(ram_req_valid), .req_write(ram_req_write), .req_addr(ram_req_addr),
        .req_wdata(ram_req_wdata), .req_wstrb(ram_req_wstrb),
        .resp_rdata(ram_resp_rdata), .resp_ready(ram_resp_ready), .resp_error(ram_resp_error)
    );

    cpu_apb_bridge u_bridge (
        .clk(clk), .rst_n(rst_n),
        .req_valid(apb_req_valid), .req_write(apb_req_write), .req_addr(apb_req_addr),
        .req_wdata(apb_req_wdata), .req_wstrb(apb_req_wstrb),
        .resp_rdata(apb_resp_rdata), .resp_ready(apb_resp_ready), .resp_error(apb_resp_error),
        .paddr(apb_paddr), .psel(apb_psel), .penable(apb_penable), .pwrite(apb_pwrite),
        .pwdata(apb_pwdata), .pstrb(apb_pstrb), .prdata(apb_prdata),
        .pready(apb_pready), .pslverr(apb_pslverr)
    );

    apb_subsystem u_apb_subsystem (
        .clk(clk), .rst_n(rst_n),
        .m_paddr(apb_paddr), .m_psel(apb_psel), .m_penable(apb_penable),
        .m_pwrite(apb_pwrite), .m_pwdata(apb_pwdata),
        .m_prdata(apb_prdata), .m_pready(apb_pready), .m_pslverr(apb_pslverr),
        .gpio_in(gpio_in), .gpio_out(gpio_out), .gpio_dir(gpio_dir),
        .timer_irq(timer_irq), .uart_rx(uart_rx), .uart_tx(uart_tx)
    );

    always #5 clk = ~clk;

    task automatic check(input logic condition, input string message);
        begin
            if (!condition) $fatal(1, "%s", message);
        end
    endtask

    task automatic cpu_access(
        input logic        write_op,
        input logic [31:0] addr,
        input logic [31:0] wdata,
        input logic [3:0]  wstrb,
        output logic [31:0] rdata,
        output logic         failed
    );
        begin
            @(negedge clk);
            cpu_req_valid = 1'b1;
            cpu_req_write = write_op;
            cpu_req_addr = addr;
            cpu_req_wdata = wdata;
            cpu_req_wstrb = wstrb;
            do @(posedge clk); while (!cpu_resp_ready && !cpu_resp_error);
            rdata = cpu_resp_rdata;
            failed = cpu_resp_error;
            @(negedge clk);
            cpu_req_valid = 1'b0;
            cpu_req_write = 1'b0;
            cpu_req_wstrb = '0;
        end
    endtask

    initial begin
        logic [31:0] rdata;
        logic        failed;

        clk = 1'b0;
        rst_n = 1'b0;
        cpu_req_valid = 1'b0;
        cpu_req_write = 1'b0;
        cpu_req_addr = '0;
        cpu_req_wdata = '0;
        cpu_req_wstrb = '0;
        gpio_in = '0;
        uart_rx = 1'b1;

        repeat (2) @(posedge clk);
        rst_n = 1'b1;

        cpu_access(1'b1, 32'h0000_0020, 32'hDEAD_BEEF, 4'hF, rdata, failed);
        check(!failed, "CPU RAM write failed");
        cpu_access(1'b0, 32'h0000_0020, '0, '0, rdata, failed);
        check(!failed && rdata == 32'hDEAD_BEEF, "CPU RAM read mismatch");

        cpu_access(1'b1, 32'h4000_0000, 32'h0000_005A, 4'hF, rdata, failed);
        check(!failed && gpio_out == 8'h5A, "CPU GPIO write did not reach APB");
        cpu_access(1'b0, 32'h4000_0000, '0, '0, rdata, failed);
        check(!failed && rdata[7:0] == 8'h5A, "CPU GPIO read did not return APB data");

        cpu_access(1'b0, 32'h0000_0002, '0, '0, rdata, failed);
        check(failed, "unaligned CPU address did not fail");
        cpu_access(1'b0, 32'h0001_0000, '0, '0, rdata, failed);
        check(failed, "out-of-range RAM address did not fail");
        cpu_access(1'b0, 32'h2000_0000, '0, '0, rdata, failed);
        check(failed, "unmapped CPU address did not fail");
        cpu_access(1'b0, 32'h4000_6000, '0, '0, rdata, failed);
        check(failed && rdata == 32'hDEAD_BEEF,
              "APB error did not propagate to CPU response");

        $display("PASS tb_cpu_bus_decoder");
        $finish;
    end
endmodule
