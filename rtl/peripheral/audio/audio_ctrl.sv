module audio_ctrl (
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

    output logic        audio_enable,
    output logic        audio_bypass,
    output logic        audio_clear_state,
    output logic        coeff_we,
    output logic [3:0]  coeff_index,
    output logic signed [15:0] coeff_data,
    output logic [5:0]  status_clear,
    input  logic [5:0]  status,
    input  logic [31:0] sample_count,
    input  logic signed [15:0] last_output
);
    wire apb_access = psel && penable;
    wire valid_offset = (paddr[11:0] == 12'h000) ||
                        (paddr[11:0] == 12'h004) ||
                        (paddr[11:0] == 12'h008) ||
                        (paddr[11:0] == 12'h00c) ||
                        (paddr[11:0] == 12'h010) ||
                        (paddr[11:0] == 12'h014) ||
                        (paddr[11:0] == 12'h018);
    wire apb_write = apb_access && pwrite && valid_offset;

    assign pready = 1'b1;
    assign pslverr = apb_access && !valid_offset;

    always_comb begin
        prdata = 32'h0;
        case (paddr[11:0])
            12'h000: prdata = {29'h0, audio_clear_state, audio_bypass, audio_enable};
            12'h004: prdata = {26'h0, status};
            12'h00c: prdata = {{16{last_output[15]}}, last_output};
            12'h010: prdata = {28'h0, coeff_index};
            12'h018: prdata = sample_count;
            default: prdata = 32'h0;
        endcase
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            audio_enable     <= 1'b0;
            audio_bypass     <= 1'b0;
            audio_clear_state<= 1'b0;
            coeff_we         <= 1'b0;
            coeff_index      <= 4'h0;
            coeff_data       <= 16'sd0;
            status_clear     <= 6'h0;
        end else begin
            audio_clear_state <= 1'b0;
            coeff_we          <= 1'b0;
            status_clear      <= 6'h0;
            if (apb_write) begin
                case (paddr[11:0])
                    12'h000: begin
                        audio_enable      <= pwdata[0];
                        audio_bypass      <= pwdata[1];
                        audio_clear_state <= pwdata[2];
                    end
                    12'h004: status_clear <= pwdata[5:0];
                    12'h010: coeff_index  <= pwdata[3:0];
                    12'h014: begin
                        coeff_data <= pwdata[15:0];
                        coeff_we   <= 1'b1;
                    end
                    default: ;
                endcase
            end
        end
    end
endmodule
