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
    logic        rx;
    logic        loopback_en;
    logic        manual_rx;
    logic [31:0] rdata;
    logic        err;

    assign rx = loopback_en ? tx : manual_rx;

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
            loopback_en = 1'b1;
            manual_rx = 1'b1;
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

    task automatic wait_status_bits(input logic [31:0] mask,
                                    input logic [31:0] expected,
                                    input string message);
        int cycles;
        begin
            cycles = 0;
            do begin
                apb_read(UART_STATUS, rdata, err);
                check(!err, "UART_STATUS read failed while waiting for status bits");
                cycles = cycles + 1;
                check(cycles < 8000, message);
            end while ((rdata & mask) !== expected);
        end
    endtask

    task automatic drive_manual_bit(input logic value, input int cycles);
        begin
            @(negedge pclk);
            manual_rx = value;
            repeat (cycles) @(posedge pclk);
        end
    endtask

    task automatic send_manual_frame(input logic [7:0] value,
                                     input logic stop_value,
                                     input int baud_cycles);
        begin
            loopback_en = 1'b0;
            drive_manual_bit(1'b1, baud_cycles * 2);
            drive_manual_bit(1'b0, baud_cycles);
            drive_manual_bit(value[0], baud_cycles);
            drive_manual_bit(value[1], baud_cycles);
            drive_manual_bit(value[2], baud_cycles);
            drive_manual_bit(value[3], baud_cycles);
            drive_manual_bit(value[4], baud_cycles);
            drive_manual_bit(value[5], baud_cycles);
            drive_manual_bit(value[6], baud_cycles);
            drive_manual_bit(value[7], baud_cycles);
            drive_manual_bit(stop_value, baud_cycles);
            drive_manual_bit(1'b1, baud_cycles * 3);
        end
    endtask

    task automatic check_reset_and_disabled_accesses;
        begin
            apb_read(UART_STATUS, rdata, err);
            check(!err, "UART_STATUS reset read failed");
            check(rdata[0] === 1'b1, "STATUS[0] TX empty reset mapping failed");
            check(rdata[2] === 1'b1, "STATUS[2] RX empty reset mapping failed");
            check(rdata[3] === 1'b0, "STATUS[3] RX full reset mapping failed");
            check(rdata[4] === 1'b0, "STATUS[4] frame error reset mapping failed");
            check(rdata[5] === 1'b0, "STATUS[5] overflow reset mapping failed");

            apb_write(UART_DATA, 32'h0000_0042, err);
            check(err, "TX-disabled DATA write did not assert PSLVERR");
            apb_read(UART_DATA, rdata, err);
            check(err, "RX-disabled DATA read did not assert PSLVERR");

            apb_write(UART_BAUD, 32'd0, err);
            check(!err, "UART_BAUD write 0 failed");
            apb_read(UART_BAUD, rdata, err);
            check(!err && rdata == 32'd8, "UART_BAUD did not clamp 0 to 8");
            apb_write(UART_BAUD, 32'd1, err);
            check(!err, "UART_BAUD write 1 failed");
            apb_read(UART_BAUD, rdata, err);
            check(!err && rdata == 32'd8, "UART_BAUD did not clamp 1 to 8");
            apb_write(UART_BAUD, 32'd7, err);
            check(!err, "UART_BAUD write 7 failed");
            apb_read(UART_BAUD, rdata, err);
            check(!err && rdata == 32'd8, "UART_BAUD did not clamp 7 to 8");

            apb_write(UART_BAUD, 32'd8, err);
            check(!err, "UART_BAUD manual RX setup failed");
            apb_write(UART_CTRL, 32'h2, err);
            check(!err, "RX enable failed for disabled-read coverage");
            loopback_en = 1'b0;
            send_manual_frame(8'h5A, 1'b1, 8);
            wait_rx_nonempty();
            apb_write(UART_CTRL, 32'h0, err);
            check(!err, "RX disable failed for disabled-read coverage");
            apb_read(UART_DATA, rdata, err);
            check(err, "RX-disabled DATA read with queued data did not assert PSLVERR");
        end
    endtask

    task automatic check_frame_error_sticky;
        begin
            reset_dut();
            apb_write(UART_BAUD, 32'd8, err);
            check(!err, "UART_BAUD frame-error setup failed");
            apb_write(UART_CTRL, 32'h2, err);
            check(!err, "RX enable failed for frame-error coverage");

            loopback_en = 1'b0;
            send_manual_frame(8'hC3, 1'b0, 8);
            wait_status_bits(32'h10, 32'h10, "frame error sticky bit did not set");

            apb_write(UART_CTRL, 32'h102, err);
            check(!err, "CTRL bit8 frame-error clear failed");
            apb_read(UART_STATUS, rdata, err);
            check(!err && rdata[4] === 1'b0, "STATUS[4] did not clear after CTRL[8]");

            send_manual_frame(8'h3C, 1'b0, 8);
            wait_status_bits(32'h10, 32'h10, "frame error sticky bit did not re-set after clear");
        end
    endtask

    task automatic check_rx_overflow_and_preserve;
        int index;
        begin
            reset_dut();
            apb_write(UART_BAUD, 32'd8, err);
            check(!err, "UART_BAUD overflow setup failed");
            apb_write(UART_CTRL, 32'h2, err);
            check(!err, "RX enable failed for overflow coverage");

            loopback_en = 1'b0;
            for (index = 0; index < 16; index = index + 1)
                send_manual_frame(index[7:0], 1'b1, 8);
            wait_status_bits(32'h08, 32'h08, "STATUS[3] RX full did not set");

            send_manual_frame(8'hF0, 1'b1, 8);
            wait_status_bits(32'h20, 32'h20, "STATUS[5] RX overflow did not set");

            for (index = 0; index < 16; index = index + 1) begin
                apb_read(UART_DATA, rdata, err);
                check(!err, $sformatf("RX FIFO read %0d failed", index));
                check(rdata[7:0] == index[7:0],
                      $sformatf("RX FIFO data changed at %0d: got %02h", index, rdata[7:0]));
            end
            apb_read(UART_DATA, rdata, err);
            check(err, "overflow byte was incorrectly enqueued after RX FIFO full");

            apb_write(UART_CTRL, 32'h102, err);
            check(!err, "CTRL bit8 overflow clear failed");
            apb_read(UART_STATUS, rdata, err);
            check(!err && rdata[5] === 1'b0, "STATUS[5] did not clear after CTRL[8]");
        end
    endtask

    initial begin
        pclk = 1'b0;
        reset_dut();

        check_reset_and_disabled_accesses();

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

        check_frame_error_sticky();
        check_rx_overflow_and_preserve();

        $display("PASS tb_uart_top");
        $finish;
    end
endmodule
