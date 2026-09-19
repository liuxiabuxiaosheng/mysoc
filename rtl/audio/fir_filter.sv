module fir_filter #(
    parameter integer TAPS        = 16,
    parameter integer DATA_WIDTH  = 16,
    parameter integer COEFF_WIDTH = 16,
    parameter integer ACC_WIDTH   = 40
) (
    input  logic                         clk,
    input  logic                         rst_n,
    input  logic                         in_valid,
    output logic                         in_ready,
    input  logic signed [DATA_WIDTH-1:0] in_sample,
    input  logic                         coeff_we,
    input  logic [$clog2(TAPS)-1:0]      coeff_index,
    input  logic signed [COEFF_WIDTH-1:0] coeff_data,
    output logic                         out_valid,
    input  logic                         out_ready,
    output logic signed [DATA_WIDTH-1:0] out_sample
);
    localparam integer PROD_WIDTH = DATA_WIDTH + COEFF_WIDTH;
    localparam integer FRACTIONAL_BITS = COEFF_WIDTH - 1;
    localparam logic signed [DATA_WIDTH-1:0] MAX_OUTPUT = {1'b0, {(DATA_WIDTH-1){1'b1}}};
    localparam logic signed [DATA_WIDTH-1:0] MIN_OUTPUT = {1'b1, {(DATA_WIDTH-1){1'b0}}};

    logic signed [COEFF_WIDTH-1:0] coeffs [0:TAPS-1];
    logic signed [DATA_WIDTH-1:0]  history [0:TAPS-1];
    logic signed [ACC_WIDTH-1:0]   acc_work;
    logic signed [PROD_WIDTH-1:0]  prod_work;
    logic signed [ACC_WIDTH-1:0]   scaled_work;
    logic                          out_valid_q;
    logic signed [DATA_WIDTH-1:0]  out_sample_q;
    integer i;

    assign out_valid = out_valid_q;
    assign out_sample = out_sample_q;
    assign in_ready = !out_valid_q || out_ready;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            out_valid_q <= 1'b0;
            out_sample_q <= '0;
            for (i = 0; i < TAPS; i = i + 1) begin
                coeffs[i]  <= '0;
                history[i] <= '0;
            end
        end else begin
            if (coeff_we && (coeff_index < TAPS))
                coeffs[coeff_index] <= coeff_data;

            if (out_valid_q && out_ready)
                out_valid_q <= 1'b0;

            if (in_valid && in_ready) begin
                acc_work = '0;
                prod_work = $signed({{COEFF_WIDTH{in_sample[DATA_WIDTH-1]}}, in_sample}) * $signed(coeffs[0]);
                acc_work = acc_work + {{(ACC_WIDTH-PROD_WIDTH){prod_work[PROD_WIDTH-1]}}, prod_work};
                for (i = 1; i < TAPS; i = i + 1) begin
                    prod_work = $signed({{COEFF_WIDTH{history[i-1][DATA_WIDTH-1]}}, history[i-1]}) * $signed(coeffs[i]);
                    acc_work = acc_work + {{(ACC_WIDTH-PROD_WIDTH){prod_work[PROD_WIDTH-1]}}, prod_work};
                end
                if (acc_work >= 0)
                    scaled_work = (acc_work + (1 <<< (FRACTIONAL_BITS-1))) >>> FRACTIONAL_BITS;
                else
                    scaled_work = (acc_work - (1 <<< (FRACTIONAL_BITS-1))) >>> FRACTIONAL_BITS;
                if (scaled_work > MAX_OUTPUT)
                    out_sample_q <= MAX_OUTPUT;
                else if (scaled_work < MIN_OUTPUT)
                    out_sample_q <= MIN_OUTPUT;
                else
                    out_sample_q <= scaled_work[DATA_WIDTH-1:0];
                for (i = TAPS-1; i > 0; i = i - 1)
                    history[i] <= history[i-1];
                history[0] <= in_sample;
                out_valid_q <= 1'b1;
            end
        end
    end
endmodule
