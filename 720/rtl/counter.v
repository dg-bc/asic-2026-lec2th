`timescale 1ns/1ps

// 一段式状态机：switch 上升沿切换 UP/DOWN，当前 state 控制计数方向。
// rst_n 为低有效同步复位，回到 UP 并清零；en=0 时只暂停计数。
module counter (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       switch,
    input  wire       en,
    output reg  [3:0] count
);
    localparam UP   = 1'b1;
    localparam DOWN = 1'b0;
    reg state;
    reg switch_d;
    wire switch_rise = switch && !switch_d;

    always @(posedge clk) begin
        if (!rst_n) begin
            state <= UP;
            switch_d <= 1'b0;
            count <= 4'd0;
        end
        else begin
            switch_d <= switch;
            case (state)
                UP: begin
                    if (switch_rise)
                        state <= DOWN;
                    if (en)
                        count <= count + 4'd1;
                end
                DOWN: begin
                    if (switch_rise)
                        state <= UP;
                    if (en)
                        count <= count - 4'd1;
                end
                default: begin
                    state <= UP;
                    count <= count;
                end
            endcase
        end
    end
endmodule
