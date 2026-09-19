`timescale 1ns/1ps

module tb_uart_top;
    localparam logic [31:0] UART_BASE   = 32'h4000_2000;
    localparam logic [31:0] UART_DATA   = UART_BASE + 32'h0;
    localparam logic [31:0] UART_STATUS = UART_BASE + 32'h4;
    localparam logic [31:0] UART_CTRL   = UART_BASE + 32'h8;
    localparam logic [31:0] UART_BAUD   = UART_BASE + 32'hC;

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
    logic        tx;
    wire         rx;
    logic [31:0] rdata;
    logic        err;

    assign rx = tx;

    uart_top dut (
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
        .rx(rx),
        .tx(tx)
    );

    always #5 pclk = ~pclk;

    `include "apb_tasks.svh"

    task automatic check(input logic condition, input string message);
        begin
            if (!condition) $fatal(1, "%s", message);
        end
    endtask

    task automatic reset_dut;
        begin
            presetn = 1'b0;
            apb_idle();
            repeat (4) @(posedge pclk);
            @(negedge pclk);
            presetn = 1'b1;
        end
    endtask

    task automatic wait_rx_nonempty;
        int cycles;
        begin
            cycles = 0;
            do begin
                apb_read(UART_STATUS, rdata, err);
                check(!err, "UART_STATUS read failed while waiting for RX data");
                cycles = cycles + 1;
                check(cycles < 4000, "timed out waiting for RX nonempty");
            end while (rdata[2]);
        end
    endtask

    task automatic wait_tx_full;
        int writes;
        begin
            writes = 0;
            do begin
                apb_read(UART_STATUS, rdata, err);
                check(!err, "UART_STATUS read failed while waiting for TX full");
                if (!rdata[1]) begin
                    apb_write(UART_DATA, {24'h0, writes[7:0]}, err);
                    check(!err, "DATA write failed before TX full");
                    writes = writes + 1;
                    check(writes <= 20, "TX FIFO did not report full while transmitter was slow");
                end
            end while (!rdata[1]);
        end
    endtask

    initial begin
        pclk = 1'b0;
        reset_dut();

        apb_read(UART_BAUD, rdata, err);
        check(!err && rdata == 32'd868, "UART_BAUD reset value mismatch");

        apb_write(UART_BAUD, 32'd8, err);
        check(!err, "UART_BAUD write failed");
        apb_write(UART_CTRL, 32'h3, err);
        check(!err, "UART_CTRL enable failed");

        apb_write(UART_DATA, 32'h55, err);
        check(!err, "DATA write 55 failed");
        apb_write(UART_DATA, 32'hA3, err);
        check(!err, "DATA write A3 failed");
        apb_write(UART_DATA, 32'h00, err);
        check(!err, "DATA write 00 failed");

        wait_rx_nonempty();
        apb_read(UART_DATA, rdata, err);
        check(!err && rdata[7:0] == 8'h55,
              $sformatf("loopback byte 55 mismatch: err=%0b data=%02h", err, rdata[7:0]));
        wait_rx_nonempty();
        apb_read(UART_DATA, rdata, err);
        check(!err && rdata[7:0] == 8'hA3,
              $sformatf("loopback byte A3 mismatch: err=%0b data=%02h", err, rdata[7:0]));
        wait_rx_nonempty();
        apb_read(UART_DATA, rdata, err);
        check(!err && rdata[7:0] == 8'h00,
              $sformatf("loopback byte 00 mismatch: err=%0b data=%02h", err, rdata[7:0]));

        apb_read(UART_DATA, rdata, err);
        check(err, "RX-empty DATA read did not assert PSLVERR");
        apb_read(UART_BASE + 32'h10, rdata, err);
        check(err, "invalid UART offset did not assert PSLVERR");
        apb_read(UART_BASE + 32'h100, rdata, err);
        check(err, "UART window alias offset did not assert PSLVERR");
        apb_read(UART_BASE + 32'h2, rdata, err);
        check(err, "unaligned UART access did not assert PSLVERR");

        reset_dut();
        apb_write(UART_BAUD, 32'd2000, err);
        check(!err, "slow UART_BAUD write failed");
        apb_write(UART_CTRL, 32'h1, err);
        check(!err, "TX enable failed");
        wait_tx_full();
        apb_write(UART_DATA, 32'hEE, err);
        check(err, "TX-full DATA write did not assert PSLVERR");

        $display("PASS tb_uart_top");
        $finish;
    end
endmodule
