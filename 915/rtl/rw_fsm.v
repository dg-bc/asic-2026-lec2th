`timescale 1ns/1ps

// 9.15 读写控制状态机：低有效异步复位，三段式描述。
// 修正课件的拼写、语法及读写反接问题，状态编码沿用第 30 页。
// 输出按次态译码后寄存：进入 S_WRITE 时 WRITE=1，进入 S_READ 时 READ=1。
// 因而输出与沿后状态一致，避免课件按当前状态译码再寄存造成的一拍延迟。
module rw_fsm (
    input  wire CLK,
    input  wire RST_N,
    input  wire FINISH,
    output wire READ,
    output wire WRITE
);
    localparam S_IDLE  = 2'b00;
    localparam S_WRITE = 2'b01;
    localparam S_READ  = 2'b10;

    reg [1:0] CURT_STATE, NXT_STATE;
    reg READ_CMB, WRITE_CMB;
    reg READ_REG, WRITE_REG;

    // 第一段：状态寄存器。
    always @(posedge CLK or negedge RST_N) begin
        if (!RST_N)
            CURT_STATE <= S_IDLE;
        else
            CURT_STATE <= NXT_STATE;
    end

    // 第二段：组合次态逻辑及次态输出译码，所有分支均完整赋值。
    always @(*) begin
        NXT_STATE = S_IDLE;
        READ_CMB  = 1'b0;
        WRITE_CMB = 1'b0;

        case (CURT_STATE)
            S_IDLE:  NXT_STATE = FINISH ? S_IDLE : S_WRITE;
            S_WRITE: NXT_STATE = S_READ;
            S_READ:  NXT_STATE = FINISH ? S_IDLE : S_WRITE;
            default: NXT_STATE = S_IDLE;
        endcase

        case (NXT_STATE)
            S_WRITE: WRITE_CMB = 1'b1;
            S_READ:  READ_CMB  = 1'b1;
            default: begin
                READ_CMB  = 1'b0;
                WRITE_CMB = 1'b0;
            end
        endcase
    end

    // 第三段：同步寄存输出；复位时两个控制信号均无效。
    always @(posedge CLK or negedge RST_N) begin
        if (!RST_N) begin
            READ_REG  <= 1'b0;
            WRITE_REG <= 1'b0;
        end
        else begin
            READ_REG  <= READ_CMB;
            WRITE_REG <= WRITE_CMB;
        end
    end

    assign READ  = READ_REG;
    assign WRITE = WRITE_REG;
endmodule
