module apb_gpio #(
    parameter GPIO_WIDTH = 8
)(
    input  wire                   pclk,
    input  wire                   presetn,

    input  wire [31:0]            paddr,
    input  wire                   psel,
    input  wire                   penable,
    input  wire                   pwrite,
    input  wire [31:0]            pwdata,

    output reg  [31:0]            prdata,
    output wire                   pready,
    output wire                   pslverr,

    input  wire [GPIO_WIDTH-1:0]  gpio_in,

    output reg  [GPIO_WIDTH-1:0]  gpio_out,
    output reg  [GPIO_WIDTH-1:0]  gpio_dir
);

reg [GPIO_WIDTH-1:0] gpio_in_meta;
reg [GPIO_WIDTH-1:0] gpio_in_sync;

wire [3:0] reg_offset = paddr[5:2];
wire valid_offset = (paddr[11:0] == 12'h000) ||
                    (paddr[11:0] == 12'h004) ||
                    (paddr[11:0] == 12'h008);
wire apb_write;

assign pready  = 1'b1;
assign pslverr = psel && penable && !valid_offset;
assign apb_write = psel && penable && pwrite && pready && valid_offset;

always @(posedge pclk or negedge presetn) begin
    if (!presetn) begin
        gpio_in_meta <= {GPIO_WIDTH{1'b0}};
        gpio_in_sync <= {GPIO_WIDTH{1'b0}};
    end else begin
        gpio_in_meta <= gpio_in;
        gpio_in_sync <= gpio_in_meta;
    end
end

always @(posedge pclk or negedge presetn) begin
    if (!presetn) begin
        gpio_out <= {GPIO_WIDTH{1'b0}};
        gpio_dir <= {GPIO_WIDTH{1'b0}};
    end else if (apb_write) begin
        case (reg_offset)
            4'h0: gpio_out <= pwdata[GPIO_WIDTH-1:0];
            4'h1: gpio_dir <= pwdata[GPIO_WIDTH-1:0];
            default: ;
        endcase
    end
end

always @(*) begin
    prdata = 32'h0000_0000;

    case (paddr[11:0])
        12'h000: prdata = {{(32-GPIO_WIDTH){1'b0}}, gpio_out};
        12'h004: prdata = {{(32-GPIO_WIDTH){1'b0}}, gpio_dir};
        12'h008: prdata = {{(32-GPIO_WIDTH){1'b0}}, gpio_in_sync};
        default: prdata = 32'h0000_0000;
    endcase
end

endmodule
