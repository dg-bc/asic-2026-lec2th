`timescale 1ns/1ps

// 三段式状态机：方向状态寄存器、次态逻辑、时序计数器。
module counter_3stage (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       switch,
    input  wire       en,
    output reg  [3:0] count
);
    localparam UP   = 1'b1;
    localparam DOWN = 1'b0;
    reg state;
    reg next_state;
    reg switch_d;
    wire switch_rise = switch && !switch_d;
    //上升沿采样
    always @(posedge clk) begin
        if (!rst_n) begin
            switch_d <= 1'b0;
        end
        else begin
            switch_d <= switch;
        end
    end

    // 第一段：状态寄存器与 switch 的上一拍采样。
    always @(posedge clk) begin
        if (!rst_n) begin
            state <= UP;
        end
        else begin
            state <= next_state;
        end
    end

    // 第二段：状态转移。
    always @(*) begin
        next_state = state;
        case (state)
            UP: begin
                if (switch_rise)
                    next_state = DOWN;
            end
            DOWN: begin
                if (switch_rise)
                    next_state = UP;
            end
            default: next_state = UP;
        endcase
    end

    reg [3:0] count_up ,count_down;
    always @(*) begin
        count_up = count + 4'd1;
        count_down = count - 4'd1;
    end

    // 第三段：沿前 state 控制本拍增减，方向切换在下一拍影响计数。
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
