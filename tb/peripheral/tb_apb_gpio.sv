`timescale 1ns/1ps

module tb_apb_gpio;
    logic        pclk;
    logic        presetn;
    logic [31:0] paddr;
    logic        psel;
    logic        penable;
    logic        pwrite;
    logic [31:0] pwdata;
    logic [31:0] prdata;
    logic        pready;
    logic        pslverr;
    logic [7:0]  gpio_in;
    logic [7:0]  gpio_out;
    logic [7:0]  gpio_dir;
    logic [31:0] rdata;
    logic        err;

    apb_gpio #(.GPIO_WIDTH(8)) dut (
        .pclk(pclk),
        .presetn(presetn),
        .paddr(paddr),
        .psel(psel),
        .penable(penable),
        .pwrite(pwrite),
        .pwdata(pwdata),
        .prdata(prdata),
        .pready(pready),
        .pslverr(pslverr),
        .gpio_in(gpio_in),
        .gpio_out(gpio_out),
        .gpio_dir(gpio_dir)
    );

    always #5 pclk = ~pclk;

    `include "apb_tasks.svh"

    initial begin
        pclk = 1'b0;
        presetn = 1'b0;
        gpio_in = 8'h00;
        apb_idle();

        repeat (4) @(posedge pclk);
        @(negedge pclk);
        presetn = 1'b1;

        apb_read(32'h4000_0000, rdata, err);
        if (err || rdata !== 32'h0) $fatal(1, "GPIO_DATA reset mismatch");
        apb_write(32'h4000_0000, 32'h0000_00A5, err);
        if (err || gpio_out !== 8'hA5) $fatal(1, "GPIO_DATA write failed");
        apb_write(32'h4000_0004, 32'h0000_003C, err);
        if (err || gpio_dir !== 8'h3C) $fatal(1, "GPIO_DIR write failed");
        gpio_in = 8'h5A;
        apb_read(32'h4000_0008, rdata, err);
        if (err || rdata !== 32'h0000_005A) $fatal(1, "GPIO_INPUT read failed");
        apb_read(32'h4000_000C, rdata, err);
        if (!err) $fatal(1, "invalid GPIO offset did not assert PSLVERR");
        apb_read(32'h4000_0100, rdata, err);
        if (!err) $fatal(1, "GPIO window alias did not assert PSLVERR");
        apb_read(32'h4000_0002, rdata, err);
        if (!err) $fatal(1, "unaligned GPIO access did not assert PSLVERR");

        $display("PASS tb_apb_gpio");
        $finish;
    end
endmodule
