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


// 无 wait state
assign pready  = 1'b1;

assign pslverr = 1'b0;


// APB 写完成条件
wire apb_write;

assign apb_write =
        psel
      && penable
      && pwrite
      && pready;


// ==============================
// Write Register
// ==============================

always @(posedge pclk or negedge presetn) begin

    if (!presetn) begin

        gpio_out <= {GPIO_WIDTH{1'b0}};
        gpio_dir <= {GPIO_WIDTH{1'b0}};

    end
    else begin

        if (apb_write) begin

            case (paddr[5:2])

                // offset 0x00
                4'h0:
                    gpio_out <= pwdata[GPIO_WIDTH-1:0];

                // offset 0x04
                4'h1:
                    gpio_dir <= pwdata[GPIO_WIDTH-1:0];

                default:
                    ;

            endcase

        end

    end

end


// ==============================
// Read Register
// ==============================

always @(*) begin

    prdata = 32'h0000_0000;

    case (paddr[5:2])

        // 0x00
        4'h0:
            prdata = {{(32-GPIO_WIDTH){1'b0}},
                       gpio_out};

        // 0x04
        4'h1:
            prdata = {{(32-GPIO_WIDTH){1'b0}},
                       gpio_dir};

        // 0x08
        4'h2:
            prdata = {{(32-GPIO_WIDTH){1'b0}},
                       gpio_in};

        default:
            prdata = 32'h0000_0000;

    endcase

end


endmodule