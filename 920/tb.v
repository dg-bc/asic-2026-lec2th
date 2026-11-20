`timescale 1ns/1ps

module tb;
    reg CLK, RST_N;
    wire RED, GREEN, YELLOW;
    integer phase, checked_ticks, reset_checks;
    integer red_ticks, green_ticks, yellow_ticks;

    traffic_light dut (
        .CLK(CLK), .RST_N(RST_N),
        .RED(RED), .GREEN(GREEN), .YELLOW(YELLOW)
    );

    /* verilator lint_off BLKSEQ */
    always #5 CLK = ~CLK;
    /* verilator lint_on BLKSEQ */

    // 用独立的模 20 时间轴检查输出，同时检查 X 和三灯互斥。
    task check_lights;
        reg [2:0] expected;
        begin
            if (phase < 10)
                expected = 3'b100;
            else if (phase < 17)
                expected = 3'b010;
            else
                expected = 3'b001;
            if ({RED, GREEN, YELLOW} !== expected)
                $fatal(1, "phase=%0d expected RGY=%b actual=%b at %0t",
                       phase, expected, {RED, GREEN, YELLOW}, $time);
        end
    endtask

    task tick;
        begin
            @(posedge CLK);
            #1;  // 等待非阻塞赋值及输出译码稳定。
            phase = (phase + 1) % 20;
            checked_ticks = checked_ticks + 1;
            check_lights;
        end
    endtask

    // 在非时钟沿拉低复位，确认立即回到红灯，并检查复位保持。
    task reset_controller;
        begin
            @(negedge CLK);
            #2 RST_N = 1'b0;
            #1;
            phase = 0;
            check_lights;
            if (dut.CURT_STATE !== 5'd0)
                $fatal(1, "asynchronous reset did not enter R0");
            repeat (2) begin
                @(posedge CLK);
                #1;
                check_lights;
                if (dut.CURT_STATE !== 5'd0)
                    $fatal(1, "state advanced while reset was held");
            end
            @(negedge CLK);
            RST_N = 1'b1;
            reset_checks = reset_checks + 1;
        end
    endtask

    // 从 R0 开始，按每个完整状态区间采样并统计四个周期的灯亮拍数。
    task check_four_periods;
        integer i;
        begin
            red_ticks = 0;
            green_ticks = 0;
            yellow_ticks = 0;
            for (i = 0; i < 80; i = i + 1) begin
                check_lights;
                if (RED) red_ticks = red_ticks + 1;
                if (GREEN) green_ticks = green_ticks + 1;
                if (YELLOW) yellow_ticks = yellow_ticks + 1;
                tick;
            end
            if (red_ticks != 40 || green_ticks != 28 || yellow_ticks != 12)
                $fatal(1, "wrong duration totals: R=%0d G=%0d Y=%0d",
                       red_ticks, green_ticks, yellow_ticks);
            $display("PERIODS: 4 x (red=10, green=7, yellow=3), total R/G/Y=%0d/%0d/%0d",
                     red_ticks, green_ticks, yellow_ticks);
        end
    endtask

    initial begin
        CLK = 1'b0;
        RST_N = 1'b1;
        phase = 0;
        checked_ticks = 0;
        reset_checks = 0;
        $dumpfile("build/wave.vcd");
        $dumpvars(0, tb);

        reset_controller;
        check_four_periods;

        // 分别在红、绿、黄阶段中途复位，再检查完整的下一轮。
        repeat (4) tick;
        reset_controller;
        repeat (20) tick;
        repeat (13) tick;
        reset_controller;
        repeat (20) tick;
        repeat (18) tick;
        reset_controller;
        repeat (40) tick;

        $display("PASS: ticks=%0d resets=%0d; sequence, durations and asynchronous reset verified",
                 checked_ticks, reset_checks);
        $finish;
    end

    initial begin
        #10000;
        $fatal(1, "simulation timeout");
    end
endmodule
