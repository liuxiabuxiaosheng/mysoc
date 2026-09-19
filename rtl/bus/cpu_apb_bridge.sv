module cpu_apb_bridge (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        req_valid,
    input  logic        req_write,
    input  logic [31:0] req_addr,
    input  logic [31:0] req_wdata,
    input  logic [3:0]  req_wstrb,
    output logic [31:0] resp_rdata,
    output logic        resp_ready,
    output logic        resp_error,

    output logic [31:0] paddr,
    output logic        psel,
    output logic        penable,
    output logic        pwrite,
    output logic [31:0] pwdata,
    output logic [3:0]  pstrb,
    input  logic [31:0] prdata,
    input  logic        pready,
    input  logic        pslverr
);
    typedef enum logic [1:0] {IDLE, SETUP, ACCESS, RESP} state_t;

    state_t      state;
    logic        write_q;
    logic [31:0] addr_q;
    logic [31:0] wdata_q;
    logic [3:0]  strb_q;
    logic [31:0] rdata_q;
    logic        error_q;

    assign paddr = addr_q;
    assign pwrite = write_q;
    assign pwdata = wdata_q;
    assign pstrb = strb_q;
    assign psel = (state == SETUP) || (state == ACCESS);
    assign penable = (state == ACCESS);

    assign resp_rdata = rdata_q;
    assign resp_ready = (state == RESP);
    assign resp_error = (state == RESP) && error_q;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state   <= IDLE;
            write_q <= 1'b0;
            addr_q  <= '0;
            wdata_q <= '0;
            strb_q  <= '0;
            rdata_q <= '0;
            error_q <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    if (req_valid) begin
                        write_q <= req_write;
                        addr_q  <= req_addr;
                        wdata_q <= req_wdata;
                        strb_q  <= req_wstrb;
                        state   <= SETUP;
                    end
                end

                SETUP: state <= ACCESS;

                ACCESS: begin
                    if (pready) begin
                        rdata_q <= prdata;
                        error_q <= pslverr;
                        state   <= RESP;
                    end
                end

                RESP: state <= IDLE;
            endcase
        end
    end
endmodule
