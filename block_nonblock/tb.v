`timescale 1ns/1ps

module tb;
    reg clk;
    reg rst_n;
    reg a_i, b_i;

    /* verilator lint_off BLKSEQ */
    always #5 clk = ~clk;

    // 图左：阻塞赋值。a 先变成旧 b，下一句 b 读到的就是更新后的 a。
    // 命名块中的 a、b 保持其值，波形路径为 tb.x_block.a / b。
    always @(posedge clk or negedge rst_n) begin : x_block
        reg a, b;
        if (!rst_n) begin
            a = a_i;
            b = b_i;
        end
        else begin
            a = b;
            b = a;
        end
    end
    /* verilator lint_on BLKSEQ */

    // 图右：非阻塞赋值。两个右值都取沿前的值，因而每拍交换 a、b。
    always @(posedge clk or negedge rst_n) begin : x_nonblock
        reg a, b;
        if (!rst_n) begin
            a <= a_i;
            b <= b_i;
        end
        else begin
            a <= b;
            b <= a;
        end
    end

    task check_values;
        input block_a, block_b;
        input nonblock_a, nonblock_b;
        begin
            if (x_block.a !== block_a || x_block.b !== block_b ||
                x_nonblock.a !== nonblock_a || x_nonblock.b !== nonblock_b)
                $fatal(1, "t=%0t x_block=(%b,%b) expected=(%b,%b); x_nonblock=(%b,%b) expected=(%b,%b)",
                       $time, x_block.a, x_block.b, block_a, block_b,
                       x_nonblock.a, x_nonblock.b, nonblock_a, nonblock_b);
        end
    endtask

    task run_example;
        input initial_a, initial_b;
        integer cycle;
        begin
            a_i = initial_a;
            b_i = initial_b;
            #1 rst_n = 1'b0;  // 在两个时钟沿之间拉低，验证异步复位。
            #1;              // 等待非阻塞赋值完成后再比较。
            check_values(initial_a, initial_b, initial_a, initial_b);
            $display("RESET t=%0t a_i=%b b_i=%b: both groups load (a_i,b_i)",
                     $time, a_i, b_i);

            @(posedge clk);
            #1;
            check_values(initial_a, initial_b, initial_a, initial_b);
            @(negedge clk);
            rst_n = 1'b1;

            for (cycle = 1; cycle <= 6; cycle = cycle + 1) begin
                @(posedge clk);
                #1;
                if (cycle % 2 == 1)
                    check_values(initial_b, initial_b, initial_b, initial_a);
                else
                    check_values(initial_b, initial_b, initial_a, initial_b);
                $display("t=%0t cycle=%0d x_block: a=%b b=%b | x_nonblock: a=%b b=%b",
                         $time, cycle, x_block.a, x_block.b,
                         x_nonblock.a, x_nonblock.b);
            end
        end
    endtask

    initial begin
        $dumpfile("build/wave.vcd");
        $dumpvars(0, tb);
        clk = 1'b0;
        rst_n = 1'b1;
        run_example(1'b1, 1'b0);
        run_example(1'b0, 1'b1);
        $display("PASS: asynchronous reset, blocking copy and nonblocking swap checked");
        #4;
        $finish;
    end

    initial begin
        #1000;
        $fatal(1, "simulation timeout");
    end
endmodule
