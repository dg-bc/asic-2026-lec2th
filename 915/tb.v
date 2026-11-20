`timescale 1ns/1ps

module tb;
    localparam INIT_FILE = "init.hex";
    reg CLK, RST_N, FINISH;
    wire READ, WRITE;
    reg write_en, read_en;
    reg [7:0] addr, data_in;
    wire [7:0] data_out;
    reg [7:0] expected [0:255];
    reg [7:0] readback [0:255];
    reg [7:0] value;
    integer i, errors;

    rw_fsm dut (
        .CLK(CLK), .RST_N(RST_N), .FINISH(FINISH),
        .READ(READ), .WRITE(WRITE)
    );

    // 控制器循环经过 WRITE/READ；task 只在相应状态提交一次有效访问。
    regfile_256x8 #(.INIT_EN(1'b1), .INIT_FILE(INIT_FILE)) regfile (
        .CLK(CLK), .WRITE(WRITE && write_en), .READ(READ && read_en),
        .ADDR(addr), .DATA_IN(data_in), .DATA_OUT(data_out)
    );

    /* verilator lint_off BLKSEQ */
    always #5 CLK = ~CLK;

    task write_byte;
        input [7:0] address;
        input [7:0] data;
        begin
            @(negedge CLK);
            while (!WRITE) @(negedge CLK);
            addr = address;
            data_in = data;
            write_en = 1'b1;
            @(posedge CLK);
            #1;
            $display("[%0t] WRITE addr=%02h data=%02h", $time, address, data);
            @(negedge CLK);
            write_en = 1'b0;
        end
    endtask

    task read_byte;
        input [7:0] address;
        output [7:0] data;
        begin
            @(negedge CLK);
            while (!READ) @(negedge CLK);
            addr = address;
            read_en = 1'b1;
            @(posedge CLK);
            #1;  // 等同步读的非阻塞赋值完成。
            data = data_out;
            $display("[%0t] READ  addr=%02h data=%02h", $time, address, data);
            @(negedge CLK);
            read_en = 1'b0;
        end
    endtask
    /* verilator lint_on BLKSEQ */

    initial begin
        CLK = 0; RST_N = 0; FINISH = 1;
        write_en = 0; read_en = 0;
        addr = 0; data_in = 0; errors = 0;
        $dumpfile("build/wave.vcd");
        $dumpvars(0, tb);
        $readmemh(INIT_FILE, expected);  // 仅作比较；regfile 自己加载初始化文件。
        #12 RST_N = 1;
        @(negedge CLK);
        FINISH = 0;

        // 读出文件初始化的全部内容，导出 hex，并打印比较结果。
        for (i = 0; i < 256; i = i + 1) begin
            read_byte(i[7:0], readback[i]);
            if (readback[i] !== expected[i]) begin
                errors = errors + 1;
                $display("MISMATCH addr=%02h expected=%02h actual=%02h",
                         i[7:0], expected[i], readback[i]);
            end
        end
        $writememh("build/readback.hex", readback);
        $display("HEX compare: %0d/256 bytes match, errors=%0d", 256-errors, errors);

        // 简单写后读演示，结果直接看日志及波形。
        write_byte(8'h00, 8'h3c);
        read_byte(8'h00, value);
        $display("CHECK addr=00 expected=3c actual=%02h", value);
        write_byte(8'hff, 8'hc3);
        read_byte(8'hff, value);
        $display("CHECK addr=ff expected=c3 actual=%02h", value);
        FINISH = 1;
        #30 $finish;
    end

    initial begin
        #10000;
        $display("TIMEOUT: check the waveform");
        $finish;
    end
endmodule
