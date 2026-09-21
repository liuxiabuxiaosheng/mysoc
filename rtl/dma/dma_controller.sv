module dma_controller #(
    parameter logic [31:0] AUDIO_IN_ADDR  = 32'h4000_3008,
    parameter logic [31:0] AUDIO_OUT_ADDR = 32'h4000_300c
) (
    input  logic        clk,
    input  logic        rst_n,
    input  logic [31:0] paddr,
    input  logic        psel,
    input  logic        penable,
    input  logic        pwrite,
    input  logic [31:0] pwdata,
    output logic [31:0] prdata,
    output logic        pready,
    output logic        pslverr,
    output logic        mem_req_valid,
    output logic        mem_req_write,
    output logic [31:0] mem_req_addr,
    output logic [31:0] mem_req_wdata,
    output logic [3:0]  mem_req_wstrb,
    input  logic [31:0] mem_resp_rdata,
    input  logic        mem_resp_ready,
    input  logic        mem_resp_error,
    output logic        fifo_in_valid,
    output logic signed [15:0] fifo_in_data,
    input  logic        fifo_in_ready,
    output logic        fifo_out_ready,
    input  logic        fifo_out_valid,
    input  logic signed [15:0] fifo_out_data,
    output logic        irq
);
    typedef enum logic [3:0] {
        IDLE, READ_REQ, READ_WAIT, WRITE_REQ, WRITE_WAIT,
        IN_PUSH_LO, IN_PUSH_HI, OUT_POP_LO, OUT_POP_HI, DONE
    } state_t;
    localparam logic [1:0] MODE_BRAM = 2'd0;
    localparam logic [1:0] MODE_IN   = 2'd1;
    localparam logic [1:0] MODE_OUT  = 2'd2;

    state_t state;
    logic [31:0] src_q, dst_q, length_q;
    logic [31:0] work_src_q, work_dst_q, remaining_q, read_data_q;
    logic [15:0] output_low_q;
    logic [1:0] mode_q;
    logic done_q, config_error_q, bus_error_q;

    wire apb_access = psel && penable;
    wire valid_offset = (paddr[11:0] == 12'h000) || (paddr[11:0] == 12'h004) ||
                        (paddr[11:0] == 12'h008) || (paddr[11:0] == 12'h00c) ||
                        (paddr[11:0] == 12'h010);
    wire apb_write = apb_access && pwrite && valid_offset;
    wire start_write = apb_write && (paddr[11:0] == 12'h00c) && pwdata[0];
    wire status_write = apb_write && (paddr[11:0] == 12'h010);
    wire busy = (state != IDLE) && (state != DONE);

    assign pready = 1'b1;
    assign pslverr = apb_access && !valid_offset;

    always_comb begin
        prdata = 32'h0;
        case (paddr[11:0])
            12'h000: prdata = src_q;
            12'h004: prdata = dst_q;
            12'h008: prdata = length_q;
            12'h010: prdata = {28'h0, bus_error_q, config_error_q, done_q, busy};
            default: prdata = 32'h0;
        endcase
    end

    always_comb begin
        mem_req_valid = (state == READ_REQ) || (state == READ_WAIT) ||
                        (state == WRITE_REQ) || (state == WRITE_WAIT);
        mem_req_write = (state == WRITE_REQ) || (state == WRITE_WAIT);
        mem_req_addr  = mem_req_write ? work_dst_q : work_src_q;
        mem_req_wdata = read_data_q;
        mem_req_wstrb = mem_req_write ? 4'hf : 4'h0;
        fifo_in_valid = (state == IN_PUSH_LO) || (state == IN_PUSH_HI);
        fifo_in_data  = (state == IN_PUSH_LO) ? read_data_q[15:0] : read_data_q[31:16];
        fifo_out_ready = (state == OUT_POP_LO) || (state == OUT_POP_HI);
    end

    assign irq = done_q || config_error_q || bus_error_q;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            src_q <= 0; dst_q <= 0; length_q <= 0;
            work_src_q <= 0; work_dst_q <= 0; remaining_q <= 0;
            read_data_q <= 0; output_low_q <= 0; mode_q <= MODE_BRAM;
            done_q <= 0; config_error_q <= 0; bus_error_q <= 0;
        end else begin
            if (status_write) begin
                if (pwdata[1]) done_q <= 1'b0;
                if (pwdata[2]) config_error_q <= 1'b0;
                if (pwdata[3]) bus_error_q <= 1'b0;
            end
            if (apb_write) begin
                case (paddr[11:0])
                    12'h000: src_q <= pwdata;
                    12'h004: dst_q <= pwdata;
                    12'h008: length_q <= pwdata;
                    default: ;
                endcase
            end
            if (start_write && busy)
                config_error_q <= 1'b1;

            case (state)
                IDLE: begin
                    if (start_write) begin
                        if ((length_q == 0) || (src_q[1:0] != 0) || (dst_q[1:0] != 0)) begin
                            config_error_q <= 1'b1;
                        end else if ((dst_q == AUDIO_IN_ADDR) && (src_q <= 32'h0000_FFFF)) begin
                            mode_q <= MODE_IN; work_src_q <= src_q; work_dst_q <= dst_q;
                            remaining_q <= length_q; state <= READ_REQ;
                        end else if ((src_q == AUDIO_OUT_ADDR) && (dst_q <= 32'h0000_FFFF)) begin
                            mode_q <= MODE_OUT; work_src_q <= src_q; work_dst_q <= dst_q;
                            remaining_q <= length_q; state <= OUT_POP_LO;
                        end else if ((src_q <= 32'h0000_FFFF) && (dst_q <= 32'h0000_FFFF)) begin
                            mode_q <= MODE_BRAM; work_src_q <= src_q; work_dst_q <= dst_q;
                            remaining_q <= length_q; state <= READ_REQ;
                        end else begin
                            config_error_q <= 1'b1;
                        end
                    end
                end
                READ_REQ, READ_WAIT: begin
                    if (mem_resp_error) begin
                        bus_error_q <= 1'b1; state <= IDLE;
                    end else if (mem_resp_ready) begin
                        read_data_q <= mem_resp_rdata;
                        if (mode_q == MODE_IN)
                            state <= IN_PUSH_LO;
                        else
                            state <= WRITE_REQ;
                    end else begin
                        state <= READ_WAIT;
                    end
                end
                IN_PUSH_LO: if (fifo_in_ready) state <= IN_PUSH_HI;
                IN_PUSH_HI: begin
                    if (fifo_in_ready) begin
                        if (remaining_q == 1) state <= DONE;
                        else begin
                            work_src_q <= work_src_q + 4;
                            remaining_q <= remaining_q - 1;
                            state <= READ_REQ;
                        end
                    end
                end
                OUT_POP_LO: if (fifo_out_valid) begin
                    output_low_q <= fifo_out_data;
                    state <= OUT_POP_HI;
                end
                OUT_POP_HI: if (fifo_out_valid) begin
                    read_data_q <= {fifo_out_data, output_low_q};
                    state <= WRITE_REQ;
                end
                WRITE_REQ, WRITE_WAIT: begin
                    if (mem_resp_error) begin
                        bus_error_q <= 1'b1; state <= IDLE;
                    end else if (mem_resp_ready) begin
                        if (remaining_q == 1) state <= DONE;
                        else begin
                            if (mode_q != MODE_OUT) work_src_q <= work_src_q + 4;
                            if (mode_q != MODE_IN) work_dst_q <= work_dst_q + 4;
                            remaining_q <= remaining_q - 1;
                            if (mode_q == MODE_OUT)
                                state <= OUT_POP_LO;
                            else
                                state <= READ_REQ;
                        end
                    end else begin
                        state <= WRITE_WAIT;
                    end
                end
                DONE: begin
                    done_q <= 1'b1;
                    state <= IDLE;
                end
                default: state <= IDLE;
            endcase
        end
    end
endmodule
