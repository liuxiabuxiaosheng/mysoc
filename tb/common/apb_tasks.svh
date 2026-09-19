task automatic apb_idle;
    begin
        paddr = '0; psel = 0; penable = 0; pwrite = 0; pwdata = '0;
    end
endtask

task automatic apb_write(input logic [31:0] addr,
                         input logic [31:0] data,
                         output logic error_seen);
    begin
        @(negedge pclk);
        paddr = addr; pwdata = data; pwrite = 1; psel = 1; penable = 0;
        @(negedge pclk);
        penable = 1;
        @(posedge pclk);
        while (!pready) @(posedge pclk);
        error_seen = pslverr;
        @(negedge pclk);
        apb_idle();
    end
endtask

task automatic apb_read(input logic [31:0] addr,
                        output logic [31:0] data,
                        output logic error_seen);
    begin
        @(negedge pclk);
        paddr = addr; pwrite = 0; psel = 1; penable = 0;
        @(negedge pclk);
        penable = 1;
        @(posedge pclk);
        while (!pready) @(posedge pclk);
        data = prdata; error_seen = pslverr;
        @(negedge pclk);
        apb_idle();
    end
endtask
