`timescale 1ns/1ps

// 测试用 256 x 8 bit 寄存器堆：单地址端口，同步写、同步读。
// INIT_EN=1 时从 INIT_FILE 加载初始内容；设为 0 时不做文件初始化。
// READ 有效的上升沿采样地址，DATA_OUT 在该沿的 NBA 更新后有效。
module regfile_256x8 #(
    parameter INIT_EN = 1'b0,
    parameter INIT_FILE = "init.hex"
) (
    input  wire       CLK,
    input  wire       WRITE,
    input  wire       READ,
    input  wire [7:0] ADDR,
    input  wire [7:0] DATA_IN,
    output reg  [7:0] DATA_OUT
);
    reg [7:0] mem [0:255];

    initial begin
        if (INIT_EN)
            $readmemh(INIT_FILE, mem, 0, 255);
    end

    always @(posedge CLK) begin
        if (WRITE)
            mem[ADDR] <= DATA_IN;
        if (READ)
            DATA_OUT <= mem[ADDR];
    end
endmodule
