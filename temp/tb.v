`timescale 1ns/1ps

module tb;
    reg        clk;
    reg        rst_n;
    reg        en;
    wire [7:0] count;
    reg  [7:0] expected;

    // 换成自己的 DUT，并在下面修改激励和检查逻辑。
    counter dut (
        .clk   (clk),
        .rst_n (rst_n),
        .en    (en),
        .count (count)
    );

    // 100 MHz 时钟。
    always #5 clk = ~clk;

    initial begin
        $dumpfile("build/wave.vcd");
        $dumpvars(0, tb);
    end

    // 参考模型。
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            expected <= 8'd0;
        else if (en)
            expected <= expected + 8'd1;
    end

    // 等待 1 ns，让 DUT 和参考模型的非阻塞赋值完成后再检查。
    always @(posedge clk) begin
        #1;
        if (count !== expected)
            $fatal(1, "count mismatch: got=%0d expected=%0d at %0t",
                   count, expected, $time);
    end

    initial begin
        clk   = 1'b0;
        rst_n = 1'b0;
        en    = 1'b0;

        // 在下降沿改变输入，避开 DUT 采样的上升沿。
        repeat (2) @(negedge clk);
        rst_n = 1'b1;
        en    = 1'b1;

        repeat (260) @(negedge clk);  // 覆盖 8 位计数器溢出。
        en = 1'b0;
        repeat (4) @(negedge clk);    // 检查暂停时保持。
        en = 1'b1;
        repeat (4) @(negedge clk);

        rst_n = 1'b0;                // 再次复位。
        repeat (2) @(negedge clk);
        rst_n = 1'b1;
        repeat (4) @(negedge clk);

        $display("PASS: reset, counting, overflow and enable checked");
        $finish;
    end

    // 防止忘记 $finish 或激励卡住，按需要调整。
    initial begin
        #10000;
        $fatal(1, "simulation timeout");
    end
endmodule
