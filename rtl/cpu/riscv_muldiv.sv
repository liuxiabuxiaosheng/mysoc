module riscv_muldiv (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        start,
    input  logic [2:0]  op,
    input  logic [31:0] a,
    input  logic [31:0] b,
    output logic        busy,
    output logic        done,
    output logic [31:0] result
);
    logic [31:0] result_q;
    logic        busy_q;
    logic        done_q;
    logic signed [63:0] prod_ss;
    logic signed [63:0] prod_su;
    logic        [63:0] prod_uu;
    logic        div_mode_q, sign_a_q, sign_q_q;
    logic [2:0]  op_q;
    logic [5:0]  div_count_q;
    logic [31:0] dividend_q, divisor_q, quotient_q;
    logic [32:0] remainder_q;
    logic [32:0] rem_shift, rem_next;
    logic [31:0] dividend_next, quotient_next;
    logic [31:0] quotient_final, remainder_final;

    assign busy   = busy_q;
    assign done   = done_q;
    assign result = result_q;
    assign prod_ss = $signed({{32{a[31]}}, a}) * $signed({{32{b[31]}}, b});
    assign prod_su = $signed({{32{a[31]}}, a}) * $signed({32'd0, b});
    assign prod_uu = a * b;

    always_comb begin
        rem_shift = {remainder_q[31:0], dividend_q[31]};
        dividend_next = {dividend_q[30:0], 1'b0};
        quotient_next = {quotient_q[30:0], 1'b0};
        if (rem_shift >= {1'b0, divisor_q}) begin
            rem_next = rem_shift - {1'b0, divisor_q};
            quotient_next[0] = 1'b1;
        end else begin
            rem_next = rem_shift;
        end
        quotient_final = sign_q_q ? (~quotient_next + 32'd1) : quotient_next;
        remainder_final = sign_a_q ? (~rem_next[31:0] + 32'd1) : rem_next[31:0];
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result_q <= 32'd0;
            busy_q   <= 1'b0;
            done_q   <= 1'b0;
            div_mode_q <= 1'b0;
            sign_a_q <= 1'b0;
            sign_q_q <= 1'b0;
            op_q <= 3'd0;
            div_count_q <= 6'd0;
            dividend_q <= 32'd0;
            divisor_q <= 32'd0;
            quotient_q <= 32'd0;
            remainder_q <= 33'd0;
        end else begin
            done_q <= 1'b0;
            if (start && !busy_q) begin
                busy_q <= 1'b1;
                op_q <= op;
                if (op <= 3) begin
                    div_mode_q <= 1'b0;
                    case (op)
                        3'd0: result_q <= prod_ss[31:0];
                        3'd1: result_q <= prod_ss[63:32];
                        3'd2: result_q <= prod_su[63:32];
                        3'd3: result_q <= prod_uu[63:32];
                        default: result_q <= 32'd0;
                    endcase
                end else if (b == 0) begin
                    div_mode_q <= 1'b0;
                    result_q <= (op == 3'd4 || op == 3'd5) ? 32'hffff_ffff : a;
                end else begin
                    div_mode_q <= 1'b1;
                    sign_a_q <= (op == 3'd4 || op == 3'd6) && a[31];
                    sign_q_q <= (op == 3'd4 || op == 3'd5) && (a[31] ^ b[31]);
                    dividend_q <= ((op == 3'd4 || op == 3'd6) && a[31]) ? (~a + 32'd1) : a;
                    divisor_q <= ((op == 3'd4 || op == 3'd6) && b[31]) ? (~b + 32'd1) : b;
                    quotient_q <= 32'd0;
                    remainder_q <= 33'd0;
                    div_count_q <= 6'd0;
                end
            end else if (busy_q) begin
                if (div_mode_q) begin
                    dividend_q <= dividend_next;
                    quotient_q <= quotient_next;
                    remainder_q <= rem_next;
                    if (div_count_q == 6'd31) begin
                        result_q <= (op_q == 3'd4 || op_q == 3'd5) ? quotient_final : remainder_final;
                        busy_q <= 1'b0;
                        done_q <= 1'b1;
                    end else begin
                        div_count_q <= div_count_q + 6'd1;
                    end
                end else begin
                    busy_q <= 1'b0;
                    done_q <= 1'b1;
                end
            end
        end
    end
endmodule
