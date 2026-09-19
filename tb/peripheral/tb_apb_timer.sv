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
        @(posedge pclk); #1;
        if (timer_irq !== 1'b0) $fatal(1, "one-shot expired too early on first beat");
        @(posedge pclk); #1;
        if (timer_irq !== 1'b0) $fatal(1, "one-shot expired too early on second beat");
        @(posedge pclk); #1;
        if (timer_irq !== 1'b1) $fatal(1, "one-shot did not expire on third beat");
        apb_read(32'h4000_1000, rdata, err);
        if (err || rdata[0] !== 1'b0) $fatal(1, "one-shot enable did not clear at expiry");
        apb_read(32'h4000_100C, rdata, err);
        if (err || rdata[0] !== 1'b1 || timer_irq !== 1'b1)
            $fatal(1, "one-shot expiry was not sticky");
        repeat (4) @(posedge pclk);
        if (timer_irq !== 1'b1) $fatal(1, "timer status disappeared without clear");
        apb_write(32'h4000_100C, 32'h1, err);
        if (err || timer_irq !== 1'b0) $fatal(1, "RW1C clear failed");

        apb_write(32'h4000_1008, 32'd1, err);
        if (err) $fatal(1, "same-cycle compare write failed");
        apb_write(32'h4000_1000, 32'h3, err);
        if (err) $fatal(1, "same-cycle periodic enable failed");
        @(posedge pclk); #1;
        if (timer_irq !== 1'b1) $fatal(1, "periodic setup expiry was not observed");
        apb_write(32'h4000_100C, 32'h1, err);
        if (err || timer_irq !== 1'b1)
            $fatal(1, "terminal expiry did not take precedence over same-cycle clear");
        apb_write(32'h4000_1000, 32'h0, err);
        if (err) $fatal(1, "same-cycle test disable failed");
        apb_write(32'h4000_100C, 32'h1, err);
        if (err || timer_irq !== 1'b0) $fatal(1, "same-cycle test cleanup failed");

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
        if (!err || rdata !== 32'h0000_0000)
            $fatal(1, "invalid timer offset response mismatch");
        apb_read(32'h4000_1100, rdata, err);
        if (!err || rdata !== 32'h0000_0000)
            $fatal(1, "timer alias offset response mismatch");
        apb_read(32'h4000_1002, rdata, err);
        if (!err || rdata !== 32'h0000_0000)
            $fatal(1, "unaligned timer offset response mismatch");

        $display("PASS tb_apb_timer");
        $finish;
    end
endmodule
