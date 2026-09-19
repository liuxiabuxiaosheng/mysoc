`timescale 1ns/1ps

module tb_apb_timer;
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
    logic        timer_irq;
    logic [31:0] rdata;
    logic        err;

    apb_timer dut (
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
        .timer_irq(timer_irq)
    );

    always #5 pclk = ~pclk;

    `include "apb_tasks.svh"

    initial begin
        pclk = 1'b0;
        presetn = 1'b0;
        apb_idle();

        repeat (4) @(posedge pclk);
        @(negedge pclk);
        presetn = 1'b1;

        apb_write(32'h4000_1008, 32'd3, err);
        if (err) $fatal(1, "TIMER_COMPARE write failed");
        apb_write(32'h4000_1000, 32'h1, err);
        if (err) $fatal(1, "TIMER_CTRL one-shot write failed");
        repeat (4) @(posedge pclk);
        apb_read(32'h4000_100C, rdata, err);
        if (err || rdata[0] !== 1'b1 || timer_irq !== 1'b1)
            $fatal(1, "one-shot expiry was not sticky");
        repeat (4) @(posedge pclk);
        if (timer_irq !== 1'b1) $fatal(1, "timer status disappeared without clear");
        apb_write(32'h4000_100C, 32'h1, err);
        if (err || timer_irq !== 1'b0) $fatal(1, "RW1C clear failed");

        apb_write(32'h4000_1008, 32'd4, err);
        if (err) $fatal(1, "TIMER_COMPARE periodic write failed");
        apb_write(32'h4000_1000, 32'h3, err);
        if (err) $fatal(1, "TIMER_CTRL periodic write failed");
        repeat (4) @(posedge pclk);
        apb_read(32'h4000_100C, rdata, err);
        if (err || rdata[0] !== 1'b1 || timer_irq !== 1'b1)
            $fatal(1, "periodic expiry was not observed");
        apb_write(32'h4000_100C, 32'h1, err);
        if (err || timer_irq !== 1'b0) $fatal(1, "periodic RW1C clear failed");
        repeat (4) @(posedge pclk);
        apb_read(32'h4000_100C, rdata, err);
        if (err || rdata[0] !== 1'b1 || timer_irq !== 1'b1)
            $fatal(1, "periodic second expiry was not observed");

        apb_read(32'h4000_1010, rdata, err);
        if (!err) $fatal(1, "invalid timer offset did not assert PSLVERR");

        $display("PASS tb_apb_timer");
        $finish;
    end
endmodule
