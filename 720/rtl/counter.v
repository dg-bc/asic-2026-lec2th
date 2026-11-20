`timescale 1ns/1ps

// 一段式状态机：方向状态转移和计数器更新放在同一个时序块。
// rst_n 为低有效同步复位；up_down 请求方向，由当前 state 控制本拍增减。
module counter (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       en,
    input  wire       up_down,
    output reg  [3:0] count
);
    localparam UP   = 1'b1;
    localparam DOWN = 1'b0;
    reg state;

always @(posedge clk) begin
    if (!rst_n) begin
        state <= UP;
        count <= 4'd0;
    end
    else begin
        case (state)
            UP: begin
                if (up_down) begin
                    state <= UP;
                end
                else begin
                    state <= DOWN;
                end
                if (en)
                    count <= count + 4'd1;
            end
            DOWN: begin
                if (up_down) begin
                    state <= UP;
                end
                else begin
                    state <= DOWN;
                end
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
