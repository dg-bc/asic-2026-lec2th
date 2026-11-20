`timescale 1ns/1ps

// 三段式状态机：方向状态寄存器、次态逻辑、时序计数器。
module counter_3stage (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       en,
    input  wire       up_down,
    output reg  [3:0] count
);
    localparam UP   = 1'b1;
    localparam DOWN = 1'b0;
    reg state;
    reg next_state;

    // 第一段：状态寄存器。
    always @(posedge clk) begin
        if (!rst_n)
            state <= UP;
        else
            state <= next_state;
    end

    // 第二段：状态转移。
    always @(*) begin
        next_state = state;
        case (state)
            UP: begin
                if (!up_down)
                    next_state = DOWN;
            end
            DOWN: begin
                if (up_down)
                    next_state = UP;
            end
            default: next_state = UP;
        endcase
    end

    reg [3:0] count_up ,count_down;
    always @(*) begin
        count_up = count +'b1;
        count_down = count -'b1;
    end

    // 第三段：状态控制
    always @(posedge clk) begin
        if (!rst_n)
            count <= 4'd0;
        else if (en) begin
            case (state)
                UP:      count <= count_up;
                DOWN:    count <= count_down;
                default: count <= count;
            endcase
        end
    end



endmodule
