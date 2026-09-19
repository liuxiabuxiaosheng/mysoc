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

    output reg         timer_irq

);


reg [31:0] ctrl_reg;
reg [31:0] counter_reg;
reg [31:0] compare_reg;


assign pready  = 1'b1;
assign pslverr = 1'b0;


wire apb_write;

assign apb_write =
        psel
      && penable
      && pwrite
      && pready;


// =============================
// Timer Counter
// =============================

always @(posedge pclk or negedge presetn) begin

    if (!presetn) begin

        counter_reg <= 32'd0;
        timer_irq   <= 1'b0;

    end
    else begin

        timer_irq <= 1'b0;

        if (ctrl_reg[0]) begin

            if (counter_reg == compare_reg) begin

                counter_reg <= 32'd0;
                timer_irq   <= 1'b1;

            end
            else begin

                counter_reg <= counter_reg + 1'b1;

            end

        end
        else begin

            counter_reg <= 32'd0;

        end

    end

end


// =============================
// APB Write
// =============================

always @(posedge pclk or negedge presetn) begin

    if (!presetn) begin

        ctrl_reg    <= 32'd0;
        compare_reg <= 32'd100;

    end
    else begin

        if (apb_write) begin

            case (paddr[5:2])

                4'h0:
                    ctrl_reg <= pwdata;

                4'h2:
                    compare_reg <= pwdata;

                default:
                    ;

            endcase

        end

    end

end


// =============================
// APB Read
// =============================

always @(*) begin

    case (paddr[5:2])

        4'h0:
            prdata = ctrl_reg;

        4'h1:
            prdata = counter_reg;

        4'h2:
            prdata = compare_reg;

        4'h3:
            prdata = {31'd0, timer_irq};

        default:
            prdata = 32'd0;

    endcase

end


endmodule