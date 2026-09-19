module uart_tx (

    input  wire        clk,
    input  wire        rst_n,

    input  wire [7:0]  data_in,
    input  wire        tx_start,

    output reg         tx,
    output reg         busy

);
    //====================================================
    // Baud Rate Parameter
    // 50MHz / 115200 ≈ 434
    // 每434个clk发送1bit
    //====================================================
    parameter BAUD_CNT = 434;
    //====================================================
    // Registers
    //====================================================
    reg [8:0] baud_cnt;     // 波特率计数器
    reg [3:0] bit_cnt;      // 数据位计数器
    reg [7:0] data_reg;     // 数据缓存寄存器
    //====================================================
    // FSM State
    //====================================================
    typedef enum logic [1:0]
    {
        S_IDLE,     // 空闲
        S_START,    // 起始位
        S_DATA,     // 数据位
        S_STOP      // 停止位
    } state_t;
    state_t state;
    //====================================================
    // UART TX FSM
    //====================================================
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            state    <= S_IDLE;

            tx       <= 1'b1;
            busy     <= 1'b0;

            baud_cnt <= 9'd0;
            bit_cnt  <= 4'd0;
            data_reg <= 8'd0;
        end
        else begin
            case(state)
                //================================================
                // IDLE
                // UART空闲状态
                // TX保持高电平
                //================================================
                S_IDLE: begin
                    tx   <= 1'b1;
                    busy <= 1'b0;
                    if(tx_start) begin
                        data_reg <= data_in;
                        busy <= 1'b1;
                        state <= S_START;
                    end
                end
                //================================================
                // START BIT
                // 起始位 = 0
                //================================================
                S_START: begin
                    tx <= 1'b0;
                    if(baud_cnt == BAUD_CNT-1) begin
                        baud_cnt <= 0;
                        bit_cnt <= 0;
                        state <= S_DATA;
                    end
                    else begin
                        baud_cnt <= baud_cnt + 1'b1;
                    end
                end
                //================================================
                // DATA BIT
                // LSB first
                //================================================
                S_DATA: begin
                    tx <= data_reg[bit_cnt];
                    if(baud_cnt == BAUD_CNT-1) begin
                        baud_cnt <= 0;
                        if(bit_cnt == 7) begin
                            state <= S_STOP;
                        end
                        else begin
                            bit_cnt <= bit_cnt + 1'b1;
                        end
                    end
                    else begin
                        baud_cnt <= baud_cnt + 1'b1;
                    end
                end
                //================================================
                // STOP BIT
                // 停止位 = 1
                //================================================
                S_STOP: begin
                    tx <= 1'b1;
                    if(baud_cnt == BAUD_CNT-1) begin
                        baud_cnt <= 0;
                        state <= S_IDLE;
                    end
                    else begin
                        baud_cnt <= baud_cnt + 1'b1;
                    end
                end
                //================================================
                // 防止异常状态
                //================================================
                default: begin
                    state <= S_IDLE;
                end
            endcase
        end
    end
endmodule