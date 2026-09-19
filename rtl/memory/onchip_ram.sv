module onchip_ram #(
    parameter integer MEM_BYTES = 65536,
    parameter string  INIT_FILE = ""
) (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        req_valid,
    input  logic        req_write,
    input  logic [31:0] req_addr,
    input  logic [31:0] req_wdata,
    input  logic [3:0]  req_wstrb,
    output logic [31:0] resp_rdata,
    output logic        resp_ready,
    output logic        resp_error
);
    localparam integer WORDS = MEM_BYTES / 4;

    typedef enum logic {IDLE, RESP} state_t;

    state_t state;
    logic [31:0] mem [0:WORDS-1];
    logic [31:0] read_data_q;
    logic        error_q;
    integer      i;

    initial begin
        for (i = 0; i < WORDS; i = i + 1)
            mem[i] = 32'h0000_0000;
        if (INIT_FILE != "")
            $readmemh(INIT_FILE, mem);
    end

    assign resp_rdata = read_data_q;
    assign resp_ready = (state == RESP);
    assign resp_error = (state == RESP) && error_q;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state       <= IDLE;
            read_data_q <= 32'h0000_0000;
            error_q     <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    if (req_valid) begin
                        error_q <= (req_addr[1:0] != 2'b00) ||
                                   (req_addr > (MEM_BYTES - 4));
                        if ((req_addr[1:0] == 2'b00) &&
                            (req_addr <= (MEM_BYTES - 4))) begin
                            if (req_write) begin
                                if (req_wstrb[0]) mem[req_addr[15:2]][7:0]   <= req_wdata[7:0];
                                if (req_wstrb[1]) mem[req_addr[15:2]][15:8]  <= req_wdata[15:8];
                                if (req_wstrb[2]) mem[req_addr[15:2]][23:16] <= req_wdata[23:16];
                                if (req_wstrb[3]) mem[req_addr[15:2]][31:24] <= req_wdata[31:24];
                            end else begin
                                read_data_q <= mem[req_addr[15:2]];
                            end
                        end
                        state <= RESP;
                    end
                end

                RESP: state <= IDLE;
            endcase
        end
    end
endmodule
