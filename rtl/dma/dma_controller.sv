module dma_controller (
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
    input  logic        mem_resp_error
);
    typedef enum logic [2:0] {
        IDLE,
        READ_REQ,
        READ_WAIT,
        WRITE_REQ,
        WRITE_WAIT,
        DONE
    } state_t;

    state_t state;
    logic [31:0] src_q, dst_q, length_q;
    logic [31:0] work_src_q, work_dst_q, remaining_q, read_data_q;
    logic        done_q, config_error_q, bus_error_q;

    wire apb_access = psel && penable;
    wire valid_offset = (paddr[11:0] == 12'h000) ||
                        (paddr[11:0] == 12'h004) ||
                        (paddr[11:0] == 12'h008) ||
                        (paddr[11:0] == 12'h00c) ||
                        (paddr[11:0] == 12'h010);
    wire apb_write = apb_access && pwrite && valid_offset;
    wire start_write = apb_write && (paddr[11:0] == 12'h00c) && pwdata[0];
    wire status_write = apb_write && (paddr[11:0] == 12'h010);
    wire busy = (state != IDLE) && (state != DONE);

    assign pready = 1'b1;
    assign pslverr = apb_access && !valid_offset;

    always_comb begin
        prdata = 32'h0000_0000;
        case (paddr[11:0])
            12'h000: prdata = src_q;
            12'h004: prdata = dst_q;
            12'h008: prdata = length_q;
            12'h00c: prdata = 32'h0000_0000;
            12'h010: prdata = {28'h0, bus_error_q, config_error_q, done_q, busy};
            default: prdata = 32'h0000_0000;
        endcase
    end

    always_comb begin
        mem_req_valid = (state == READ_REQ) || (state == READ_WAIT) ||
                         (state == WRITE_REQ) || (state == WRITE_WAIT);
        mem_req_write = (state == WRITE_REQ) || (state == WRITE_WAIT);
        mem_req_addr  = mem_req_write ? work_dst_q : work_src_q;
        mem_req_wdata = read_data_q;
        mem_req_wstrb = mem_req_write ? 4'hf : 4'h0;
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state         <= IDLE;
            src_q         <= 32'h0;
            dst_q         <= 32'h0;
            length_q      <= 32'h0;
            work_src_q    <= 32'h0;
            work_dst_q    <= 32'h0;
            remaining_q   <= 32'h0;
            read_data_q   <= 32'h0;
            done_q        <= 1'b0;
            config_error_q<= 1'b0;
            bus_error_q   <= 1'b0;
        end else begin
            if (status_write) begin
                if (pwdata[1]) done_q <= 1'b0;
                if (pwdata[2]) config_error_q <= 1'b0;
                if (pwdata[3]) bus_error_q <= 1'b0;
            end

            if (apb_write) begin
                case (paddr[11:0])
                    12'h000: src_q    <= pwdata;
                    12'h004: dst_q    <= pwdata;
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
                        end else begin
                            work_src_q  <= src_q;
                            work_dst_q  <= dst_q;
                            remaining_q <= length_q;
                            state       <= READ_REQ;
                        end
                    end
                end

                READ_REQ: begin
                    if (mem_resp_error) begin
                        bus_error_q <= 1'b1;
                        state       <= IDLE;
                    end else if (mem_resp_ready) begin
                        read_data_q <= mem_resp_rdata;
                        state       <= WRITE_REQ;
                    end else begin
                        state       <= READ_WAIT;
                    end
                end

                READ_WAIT: begin
                    if (mem_resp_error) begin
                        bus_error_q <= 1'b1;
                        state       <= IDLE;
                    end else if (mem_resp_ready) begin
                        read_data_q <= mem_resp_rdata;
                        state       <= WRITE_REQ;
                    end
                end

                WRITE_REQ: begin
                    if (mem_resp_error) begin
                        bus_error_q <= 1'b1;
                        state       <= IDLE;
                    end else if (mem_resp_ready) begin
                        if (remaining_q == 1) begin
                            state <= DONE;
                        end else begin
                            work_src_q  <= work_src_q + 32'd4;
                            work_dst_q  <= work_dst_q + 32'd4;
                            remaining_q <= remaining_q - 32'd1;
                            state       <= READ_REQ;
                        end
                    end else begin
                        state <= WRITE_WAIT;
                    end
                end

                WRITE_WAIT: begin
                    if (mem_resp_error) begin
                        bus_error_q <= 1'b1;
                        state       <= IDLE;
                    end else if (mem_resp_ready) begin
                        if (remaining_q == 1) begin
                            state <= DONE;
                        end else begin
                            work_src_q  <= work_src_q + 32'd4;
                            work_dst_q  <= work_dst_q + 32'd4;
                            remaining_q <= remaining_q - 32'd1;
                            state       <= READ_REQ;
                        end
                    end
                end

                DONE: begin
                    done_q <= 1'b1;
                    state  <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule
