module apb_timer (

    input  wire        pclk,
    input  wire        presetn,

    input  wire [31:0] paddr,
    input  wire        psel,
    input  wire        penable,
    input  wire        pwrite,
    input  wire [31:0] pwdata,

    output reg  [31:0] prdata,
    output wire        pready,
    output wire        pslverr,

    output wire        timer_irq

);

reg [31:0] ctrl_reg;
reg [31:0] counter_reg;
reg [31:0] compare_reg;
reg [31:0] status_reg;

wire apb_access;
wire apb_write;
wire valid_offset;

assign pready       = 1'b1;
assign apb_access   = psel && penable && pready;
assign apb_write    = apb_access && pwrite;
assign valid_offset = (paddr[5:2] <= 4'h3);
assign pslverr      = apb_access && !valid_offset;
assign timer_irq    = status_reg[0];


// =============================
// Timer and APB state
// =============================

always_ff @(posedge pclk or negedge presetn) begin
    if (!presetn) begin
        ctrl_reg    <= 32'd0;
        counter_reg <= 32'd0;
        compare_reg <= 32'd100;
        status_reg  <= 32'd0;
    end
    else begin
        // APB writes are applied before timer updates. Invalid offsets are ignored.
        if (apb_write && !pslverr) begin
            case (paddr[5:2])
                4'h0: ctrl_reg <= pwdata;
                4'h2: compare_reg <= pwdata;
                4'h3: status_reg[0] <= status_reg[0] && !pwdata[0];
                default: ;
            endcase
        end

        if (ctrl_reg[0]) begin
            if ((compare_reg == 0) || (counter_reg + 32'd1 >= compare_reg)) begin
                counter_reg <= 32'd0;
                status_reg[0] <= 1'b1;
                if (!ctrl_reg[1]) ctrl_reg[0] <= 1'b0;
            end
            else begin
                counter_reg <= counter_reg + 32'd1;
            end
        end
        else begin
            counter_reg <= 32'd0;
        end
    end
end


// =============================
// APB Read
// =============================

always @(*) begin
    case (paddr[5:2])
        4'h0: prdata = ctrl_reg;
        4'h1: prdata = counter_reg;
        4'h2: prdata = compare_reg;
        4'h3: prdata = status_reg;
        default: prdata = 32'd0;
    endcase
end


endmodule
