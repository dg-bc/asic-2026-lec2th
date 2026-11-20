`timescale 1ns/1ps

// 第 20 题：Moore 型交通灯，1 个 CLK 周期为 1 个时间单位。
// 红灯 R0~R9（10 拍）-> 绿灯 G0~G6（7 拍）-> 黄灯 Y0~Y2（3 拍）。
module traffic_light (
    input  wire CLK,
    input  wire RST_N,
    output reg  RED,
    output reg  GREEN,
    output reg  YELLOW
);
    localparam [4:0]
        R0 = 5'd0,  R1 = 5'd1,  R2 = 5'd2,  R3 = 5'd3,  R4 = 5'd4,
        R5 = 5'd5,  R6 = 5'd6,  R7 = 5'd7,  R8 = 5'd8,  R9 = 5'd9,
        G0 = 5'd10, G1 = 5'd11, G2 = 5'd12, G3 = 5'd13,
        G4 = 5'd14, G5 = 5'd15, G6 = 5'd16,
        Y0 = 5'd17, Y1 = 5'd18, Y2 = 5'd19;

    reg [4:0] CURT_STATE, NXT_STATE;

    // 状态寄存器：低有效异步复位，首先亮红灯。
    always @(posedge CLK or negedge RST_N) begin
        if (!RST_N)
            CURT_STATE <= R0;
        else
            CURT_STATE <= NXT_STATE;
    end

    // 组合次态逻辑：每拍前进一个状态，完整循环共 20 拍。
    always @(*) begin
        case (CURT_STATE)
            R0: NXT_STATE = R1;
            R1: NXT_STATE = R2;
            R2: NXT_STATE = R3;
            R3: NXT_STATE = R4;
            R4: NXT_STATE = R5;
            R5: NXT_STATE = R6;
            R6: NXT_STATE = R7;
            R7: NXT_STATE = R8;
            R8: NXT_STATE = R9;
            R9: NXT_STATE = G0;
            G0: NXT_STATE = G1;
            G1: NXT_STATE = G2;
            G2: NXT_STATE = G3;
            G3: NXT_STATE = G4;
            G4: NXT_STATE = G5;
            G5: NXT_STATE = G6;
            G6: NXT_STATE = Y0;
            Y0: NXT_STATE = Y1;
            Y1: NXT_STATE = Y2;
            Y2: NXT_STATE = R0;
            default: NXT_STATE = R0;
        endcase
    end

    // Moore 输出：仅由当前状态译码，不依赖次态或外部输入。
    always @(*) begin
        RED    = 1'b0;
        GREEN  = 1'b0;
        YELLOW = 1'b0;
        case (CURT_STATE)
            R0, R1, R2, R3, R4, R5, R6, R7, R8, R9: RED = 1'b1;
            G0, G1, G2, G3, G4, G5, G6:             GREEN = 1'b1;
            Y0, Y1, Y2:                             YELLOW = 1'b1;
            default: RED = 1'b1;  // 未用编码先亮红灯，下拍回到 R0。
        endcase
    end
endmodule
