module cpu_bus_decoder (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        cpu_req_valid,
    input  logic        cpu_req_write,
    input  logic [31:0] cpu_req_addr,
    input  logic [31:0] cpu_req_wdata,
    input  logic [3:0]  cpu_req_wstrb,
    output logic [31:0] cpu_resp_rdata,
    output logic        cpu_resp_ready,
    output logic        cpu_resp_error,

    output logic        ram_req_valid,
    output logic        ram_req_write,
    output logic [31:0] ram_req_addr,
    output logic [31:0] ram_req_wdata,
    output logic [3:0]  ram_req_wstrb,
    input  logic [31:0] ram_resp_rdata,
    input  logic        ram_resp_ready,
    input  logic        ram_resp_error,

    output logic        apb_req_valid,
    output logic        apb_req_write,
    output logic [31:0] apb_req_addr,
    output logic [31:0] apb_req_wdata,
    output logic [3:0]  apb_req_wstrb,
    input  logic [31:0] apb_resp_rdata,
    input  logic        apb_resp_ready,
    input  logic        apb_resp_error
);
    typedef enum logic [1:0] {IDLE, RAM_WAIT, APB_WAIT, RESP} state_t;

    state_t      state;
    logic        write_q;
    logic [31:0] addr_q;
    logic [31:0] wdata_q;
    logic [3:0]  wstrb_q;
    logic [31:0] rdata_q;
    logic        error_q;

    assign ram_req_valid = (state == RAM_WAIT);
    assign ram_req_write = write_q;
    assign ram_req_addr = addr_q;
    assign ram_req_wdata = wdata_q;
    assign ram_req_wstrb = wstrb_q;

    assign apb_req_valid = (state == APB_WAIT);
    assign apb_req_write = write_q;
    assign apb_req_addr = addr_q;
    assign apb_req_wdata = wdata_q;
    assign apb_req_wstrb = wstrb_q;

    assign cpu_resp_rdata = rdata_q;
    assign cpu_resp_ready = (state == RESP);
    assign cpu_resp_error = (state == RESP) && error_q;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state   <= IDLE;
            write_q <= 1'b0;
            addr_q  <= '0;
            wdata_q <= '0;
            wstrb_q <= '0;
            rdata_q <= '0;
            error_q <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    if (cpu_req_valid) begin
                        write_q <= cpu_req_write;
                        addr_q  <= cpu_req_addr;
                        wdata_q <= cpu_req_wdata;
                        wstrb_q <= cpu_req_wstrb;
                        if (cpu_req_addr[1:0] != 2'b00) begin
                            rdata_q <= '0;
                            error_q <= 1'b1;
                            state   <= RESP;
                        end else if (cpu_req_addr <= 32'h0000_FFFF) begin
                            error_q <= 1'b0;
                            state   <= RAM_WAIT;
                        end else if (cpu_req_addr >= 32'h4000_0000) begin
                            error_q <= 1'b0;
                            state   <= APB_WAIT;
                        end else begin
                            rdata_q <= '0;
                            error_q <= 1'b1;
                            state   <= RESP;
                        end
                    end
                end

                RAM_WAIT: begin
                    if (ram_resp_ready) begin
                        rdata_q <= ram_resp_rdata;
                        error_q <= ram_resp_error;
                        state   <= RESP;
                    end
                end

                APB_WAIT: begin
                    if (apb_resp_ready) begin
                        rdata_q <= apb_resp_rdata;
                        error_q <= apb_resp_error;
                        state   <= RESP;
                    end
                end

                RESP: state <= IDLE;
            endcase
        end
    end
endmodule
