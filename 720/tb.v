`timescale 1ns/1ps

module tb;
    reg        clk;
    reg        rst_n;
    reg        en;
    reg        up_down;
    wire [3:0] count;
    wire [3:0] count_3stage;
    reg  [3:0] expected;
    reg        expected_state;

    integer model_value;
    reg model_valid;
    integer checked_cycles;
    integer reset_cycles;
    integer hold_cycles;
    integer up_cycles;
    integer down_cycles;
    integer overflow_events;
    integer underflow_events;
    reg [15:0] state_seen;
    reg [255:0] transition_seen;
    integer transition_index;
    integer covered_transitions;
    integer target;
    integer previous_direction;
    integer controls;
    integer i;
    reg [31:0] rng;
    reg [31:0] seed;
    reg [3:0] saved_count;

    counter dut (
        .clk(clk), .rst_n(rst_n), .en(en), .up_down(up_down),
        .count(count)
    );

    counter_3stage dut_3stage (
        .clk(clk), .rst_n(rst_n), .en(en), .up_down(up_down),
        .count(count_3stage)
    );

    // 测试平台中的时钟与参考模型使用阻塞赋值，检查延后至 NBA 完成。
    /* verilator lint_off BLKSEQ */
    always #5 clk = ~clk;

    initial begin
        $dumpfile("build/wave.vcd");
        $dumpvars(0, tb);
    end

    // 用整数的模 16 运算建模，不依赖 DUT 的 4 位算术截断。
    // 先按沿前的 expected_state 计数，再采样 up_down 更新方向模型。
    always @(posedge clk) begin
        if (model_valid) begin
            transition_index = model_value * 16;
            if (expected_state) transition_index = transition_index + 8;
            if (rst_n)   transition_index = transition_index + 4;
            if (en)      transition_index = transition_index + 2;
            if (up_down) transition_index = transition_index + 1;
            transition_seen[transition_index] = 1'b1;
            if (rst_n && en && expected_state && model_value == 15)
                overflow_events = overflow_events + 1;
            if (rst_n && en && !expected_state && model_value == 0)
                underflow_events = underflow_events + 1;
        end

        if (!rst_n) begin
            model_value = 0;
            model_valid = 1'b1;
            reset_cycles = reset_cycles + 1;
        end
        else if (!model_valid)
            $fatal(1, "reference model requires an initial reset");
        else if (!en)
            hold_cycles = hold_cycles + 1;
        else if (expected_state) begin
            model_value = (model_value + 1) % 16;
            up_cycles = up_cycles + 1;
        end
        else begin
            model_value = (model_value + 15) % 16;
            down_cycles = down_cycles + 1;
        end

        expected = model_value[3:0];
        if (!rst_n)
            expected_state = 1'b1;
        else
            expected_state = up_down;
        #1;
        if (count !== expected || count_3stage !== expected)
            $fatal(1, "t=%0t rst_n=%b en=%b up_down=%b one=%0d three=%0d expected=%0d",
                   $time, rst_n, en, up_down, count, count_3stage, expected);
        if (dut.state !== expected_state || dut_3stage.state !== expected_state)
            $fatal(1, "direction state mismatch at %0t: one=%b three=%b expected=%b",
                   $time, dut.state, dut_3stage.state, expected_state);
        checked_cycles = checked_cycles + 1;
        state_seen[model_value] = 1'b1;
    end
    /* verilator lint_on BLKSEQ */

    task check_unchanged;
        input [3:0] previous;
        begin
            if (count !== previous || count_3stage !== previous)
                $fatal(1, "output changed without a rising edge at %0t: one=%0d three=%0d previous=%0d",
                       $time, count, count_3stage, previous);
            if (dut.state !== expected_state || dut_3stage.state !== expected_state)
                $fatal(1, "direction register changed without a rising edge at %0t", $time);
        end
    endtask

    // 下降沿改变输入；先检查输入变化不会立即改变输出，再等待上升沿。
    task tick;
        input reset_value;
        input enable_value;
        input direction_value;
        reg [3:0] previous;
        begin
            @(negedge clk);
            previous = count;
            rst_n = reset_value;
            en = enable_value;
            up_down = direction_value;
            #1;
            check_unchanged(previous);
            @(posedge clk);
            #2;
        end
    endtask

    task set_state;
        input integer value;
        integer step;
        begin
            tick(1'b0, 1'b0, 1'b1);
            for (step = 0; step < value; step = step + 1)
                tick(1'b1, 1'b1, 1'b1);
        end
    endtask

    initial begin
        clk = 1'b0;
        rst_n = 1'b0;
        en = 1'b0;
        up_down = 1'b1;
        expected = 4'd0;
        expected_state = 1'b1;
        model_value = 0;
        model_valid = 1'b0;
        checked_cycles = 0;
        reset_cycles = 0;
        hold_cycles = 0;
        up_cycles = 0;
        down_cycles = 0;
        overflow_events = 0;
        underflow_events = 0;
        state_seen = 16'd0;
        transition_seen = 256'd0;
        transition_index = 0;
        covered_transitions = 0;
        if (!$value$plusargs("SEED=%d", seed))
            seed = 32'h07202020;
        if (seed == 0)
            seed = 32'd1;
        rng = seed;

        // 复位优先于使能和方向，包含复位保持、释放、运行中再次复位。
        tick(1'b0, 1'b0, 1'b1);
        tick(1'b0, 1'b1, 1'b0);
        tick(1'b0, 1'b1, 1'b1);
        tick(1'b1, 1'b0, 1'b1);
        repeat (7) tick(1'b1, 1'b1, 1'b1);
        tick(1'b0, 1'b1, 1'b0);
        tick(1'b1, 1'b0, 1'b0);
        $display("CHECK: synchronous reset and reset priority");

        set_state(5);
        repeat (2) tick(1'b1, 1'b0, 1'b1);
        repeat (2) tick(1'b1, 1'b0, 1'b0);

        // 两个上升沿之间的复位、使能、方向短脉冲都不能改变输出。
        @(negedge clk);
        saved_count = count;
        rst_n = 1'b0;
        en = 1'b1;
        up_down = 1'b0;
        #1;
        check_unchanged(saved_count);
        rst_n = 1'b1;
        en = 1'b0;
        up_down = 1'b1;
        #1;
        check_unchanged(saved_count);
        @(posedge clk);
        #2;
        check_unchanged(saved_count);
        tick(1'b1, 1'b1, 1'b1);
        tick(1'b1, 1'b1, 1'b0);
        $display("CHECK: enable hold, resume and pulses between rising edges");

        set_state(0);
        repeat (32) tick(1'b1, 1'b1, 1'b1);
        $display("CHECK: two full up-count cycles including 15 -> 0 overflow");
        tick(1'b1, 1'b0, 1'b0);  // 保持计数值，先把方向状态切到 DOWN。
        repeat (32) tick(1'b1, 1'b1, 1'b0);
        $display("CHECK: two full down-count cycles including 0 -> 15 underflow");

        // 明确检查 state 控制计数：切换当拍用旧状态，下一拍用新状态。
        set_state(5);
        tick(1'b1, 1'b1, 1'b0);  // UP -> DOWN，本拍仍加 1。
        if (count !== 4'd6 || count_3stage !== 4'd6)
            $fatal(1, "UP -> DOWN transition must still count up on this edge");
        tick(1'b1, 1'b1, 1'b0);  // 已在 DOWN，减回 5。
        tick(1'b1, 1'b1, 1'b1);  // DOWN -> UP，本拍仍减 1。
        if (count !== 4'd4 || count_3stage !== 4'd4)
            $fatal(1, "DOWN -> UP transition must still count down on this edge");
        tick(1'b1, 1'b1, 1'b1);  // 已在 UP，加回 5。
        $display("CHECK: pre-edge state controls direction, sequence 5 -> 6 -> 5 -> 4 -> 5");

        set_state(8);
        for (i = 0; i < 16; i = i + 1) begin
            tick(1'b1, 1'b1, 1'b1);
            tick(1'b1, 1'b1, 1'b0);
        end
        set_state(15);
        tick(1'b1, 1'b1, 1'b1);
        tick(1'b1, 1'b0, 1'b0);  // 在边界暂停并切到 DOWN。
        tick(1'b1, 1'b1, 1'b0);
        tick(1'b0, 1'b0, 1'b0);
        set_state(11);
        tick(1'b0, 1'b1, 1'b1);
        $display("CHECK: direction changes, boundary reversal and reset during operation");

        // 穷举 16 个旧计数值 x 2 个旧方向状态 x 8 组控制，共 256 项。
        // 每次都通过正常输入到达目标状态，不使用 force 或层次赋值。
        for (target = 0; target < 16; target = target + 1) begin
            for (previous_direction = 0; previous_direction < 2;
                 previous_direction = previous_direction + 1) begin
                for (controls = 0; controls < 8; controls = controls + 1) begin
                    set_state(target);
                    tick(1'b1, 1'b0, previous_direction[0]);
                    tick(controls[2], controls[1], controls[0]);
                end
            end
        end
        $display("CHECK: all 256 count/direction-state/control combinations");

        // 可复现的混合序列，覆盖连续切换控制信号的情况。
        for (i = 0; i < 256; i = i + 1) begin
            rng = rng ^ (rng << 13);
            rng = rng ^ (rng >> 17);
            rng = rng ^ (rng << 5);
            tick(rng[3:0] != 4'd0, rng[8], rng[16]);
        end

        for (i = 0; i < 256; i = i + 1)
            if (transition_seen[i])
                covered_transitions = covered_transitions + 1;
        if (state_seen !== 16'hffff || covered_transitions != 256)
            $fatal(1, "coverage incomplete: count_values=%h combinations=%0d/256",
                   state_seen, covered_transitions);
        if (reset_cycles == 0 || hold_cycles == 0 || up_cycles == 0 ||
            down_cycles == 0 || overflow_events == 0 || underflow_events == 0)
            $fatal(1, "a required scenario was not exercised");

        $display("PASS: both FSMs match the model, cycles=%0d count_values=16/16 combinations=%0d/256 seed=%0d",
                 checked_cycles, covered_transitions, seed);
        $display("COVER: reset=%0d hold=%0d up=%0d down=%0d overflow=%0d underflow=%0d",
                 reset_cycles, hold_cycles, up_cycles, down_cycles,
                 overflow_events, underflow_events);
        $finish;
    end

    initial begin
        #100000;
        $fatal(1, "simulation timeout");
    end
endmodule
