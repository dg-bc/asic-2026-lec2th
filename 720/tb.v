`timescale 1ns/1ps

module tb;
    reg        clk;
    reg        rst_n;
    reg        switch;
    reg        en;
    wire [3:0] count;
    wire [3:0] count_3stage;
    reg  [3:0] expected;
    reg        expected_state;
    reg        expected_switch_d;

    integer model_value;
    reg model_valid;
    integer checked_cycles;
    integer reset_cycles;
    integer hold_cycles;
    integer up_cycles;
    integer down_cycles;
    integer overflow_events;
    integer underflow_events;
    integer toggle_events;
    reg [15:0] count_seen;
    reg [511:0] transition_seen;
    integer transition_index;
    integer covered_transitions;
    integer target;
    integer previous_direction;
    integer previous_switch;
    integer controls;
    integer i;
    reg [31:0] rng;
    reg [31:0] seed;
    reg [3:0] saved_count;

    counter dut (
        .clk(clk), .rst_n(rst_n), .switch(switch), .en(en), .count(count)
    );

    counter_3stage dut_3stage (
        .clk(clk), .rst_n(rst_n), .switch(switch), .en(en), .count(count_3stage)
    );

    /* verilator lint_off BLKSEQ */
    always #5 clk = ~clk;

    initial begin
        $dumpfile("build/wave.vcd");
        $dumpvars(0, tb);
    end

    // 独立模型：整数模 16 计数，按相邻两拍 switch 样本切换方向。
    // 先按沿前方向计数，再更新方向状态和 switch 历史。
    always @(posedge clk) begin
        if (model_valid) begin
            transition_index = model_value * 32;
            if (expected_state)    transition_index = transition_index + 16;
            if (expected_switch_d) transition_index = transition_index + 8;
            if (rst_n)             transition_index = transition_index + 4;
            if (en)                transition_index = transition_index + 2;
            if (switch)            transition_index = transition_index + 1;
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
        if (!rst_n) begin
            expected_state = 1'b1;
            expected_switch_d = 1'b0;
        end
        else begin
            if (!expected_switch_d && switch) begin
                expected_state = !expected_state;
                toggle_events = toggle_events + 1;
            end
            expected_switch_d = switch;
        end
        #1;
        if (count !== expected || count_3stage !== expected)
            $fatal(1, "t=%0t rst_n=%b switch=%b en=%b one=%0d three=%0d expected=%0d",
                   $time, rst_n, switch, en, count, count_3stage, expected);
        if (dut.state !== expected_state || dut_3stage.state !== expected_state)
            $fatal(1, "UP/DOWN state mismatch at %0t: one=%b three=%b expected=%b",
                   $time, dut.state, dut_3stage.state, expected_state);
        if (dut.switch_d !== expected_switch_d ||
            dut_3stage.switch_d !== expected_switch_d)
            $fatal(1, "switch history mismatch at %0t", $time);
        checked_cycles = checked_cycles + 1;
        count_seen[model_value] = 1'b1;
    end
    /* verilator lint_on BLKSEQ */

    task check_unchanged;
        input [3:0] previous;
        begin
            if (count !== previous || count_3stage !== previous)
                $fatal(1, "output changed without a clock rising edge at %0t", $time);
            if (dut.state !== expected_state || dut_3stage.state !== expected_state ||
                dut.switch_d !== expected_switch_d ||
                dut_3stage.switch_d !== expected_switch_d)
                $fatal(1, "register changed without a clock rising edge at %0t", $time);
        end
    endtask

    // 下降沿改变输入，检查同步寄存器保持，再等待上升沿。
    task tick;
        input reset_value;
        input switch_value;
        input enable_value;
        reg [3:0] previous;
        begin
            @(negedge clk);
            previous = count;
            rst_n = reset_value;
            switch = switch_value;
            en = enable_value;
            #1;
            check_unchanged(previous);
            @(posedge clk);
            #2;
        end
    endtask

    // 只用正常输入准备任意计数值、方向与 switch 历史，不修改 DUT 寄存器。
    task prepare;
        input integer value;
        input up_value;
        input history_value;
        integer step;
        begin
            tick(1'b0, 1'b0, 1'b0);
            for (step = 0; step < value; step = step + 1)
                tick(1'b1, 1'b0, 1'b1);
            tick(1'b1, 1'b1, 1'b0);  // UP -> DOWN，计数保持。
            if (up_value) begin
                tick(1'b1, 1'b0, 1'b0);
                tick(1'b1, 1'b1, 1'b0);  // DOWN -> UP。
            end
            tick(1'b1, history_value, 1'b0);
        end
    endtask

    initial begin
        clk = 1'b0;
        rst_n = 1'b0;
        switch = 1'b0;
        en = 1'b0;
        expected = 4'd0;
        expected_state = 1'b1;
        expected_switch_d = 1'b0;
        model_value = 0;
        model_valid = 1'b0;
        checked_cycles = 0;
        reset_cycles = 0;
        hold_cycles = 0;
        up_cycles = 0;
        down_cycles = 0;
        overflow_events = 0;
        underflow_events = 0;
        toggle_events = 0;
        count_seen = 16'd0;
        transition_seen = 512'd0;
        transition_index = 0;
        covered_transitions = 0;
        if (!$value$plusargs("SEED=%d", seed))
            seed = 32'h07202020;
        if (seed == 0)
            seed = 32'd1;
        rng = seed;

        tick(1'b0, 1'b1, 1'b1);
        tick(1'b0, 1'b1, 1'b1);
        tick(1'b1, 1'b0, 1'b0);
        if (dut.state !== 1'b1 || count !== 4'd0)
            $fatal(1, "reset must restore UP and clear count");
        tick(1'b1, 1'b1, 1'b0);
        repeat (5) tick(1'b1, 1'b1, 1'b0);
        if (dut.state !== 1'b0)
            $fatal(1, "a held-high switch must toggle only once");
        tick(1'b1, 1'b0, 1'b0);
        if (dut.state !== 1'b0)
            $fatal(1, "falling switch edge must not toggle");
        tick(1'b0, 1'b1, 1'b1);
        if (dut.state !== 1'b1 || count !== 4'd0)
            $fatal(1, "reset must override a simultaneous switch rising edge");
        // 历史采样复位为 0；释放复位时若 switch 为 1，作为一次上升沿。
        tick(1'b1, 1'b1, 1'b0);
        if (dut.state !== 1'b0)
            $fatal(1, "high switch after reset must be detected once");
        $display("CHECK: reset to UP, reset priority, one toggle per rising edge and no falling-edge toggle");

        prepare(5, 1'b1, 1'b0);
        tick(1'b1, 1'b1, 1'b1);  // UP -> DOWN，本拍仍加 1。
        if (count !== 4'd6 || dut.state !== 1'b0)
            $fatal(1, "UP -> DOWN edge must count using the old UP state");
        tick(1'b1, 1'b1, 1'b1);  // 持续高电平，DOWN 保持，减回 5。
        tick(1'b1, 1'b0, 1'b0);  // 下降沿不切换，暂停计数。
        tick(1'b1, 1'b1, 1'b1);  // DOWN -> UP，本拍仍减 1。
        if (count !== 4'd4 || dut.state !== 1'b1)
            $fatal(1, "DOWN -> UP edge must count using the old DOWN state");
        tick(1'b1, 1'b1, 1'b1);
        if (count !== 4'd5)
            $fatal(1, "new UP state must control the following clock");
        $display("CHECK: pre-edge state controls direction, sequence 5 -> 6 -> 5 -> 4 -> 5");

        prepare(5, 1'b1, 1'b0);
        @(negedge clk);
        saved_count = count;
        rst_n = 1'b0;
        switch = 1'b1;
        en = 1'b1;
        #1;
        check_unchanged(saved_count);
        rst_n = 1'b1;
        switch = 1'b0;
        en = 1'b0;
        #1;
        check_unchanged(saved_count);
        @(posedge clk);
        #2;
        check_unchanged(saved_count);
        $display("CHECK: enable hold and pulses between clock rising edges");

        prepare(0, 1'b1, 1'b0);
        repeat (32) tick(1'b1, 1'b0, 1'b1);
        tick(1'b1, 1'b1, 1'b0);
        repeat (32) tick(1'b1, 1'b1, 1'b1);
        $display("CHECK: two full up/down cycles and modulo-16 wraparound");

        // 16 计数值 x 2 方向 x 2 历史值 x 8 组输入 = 512 项。
        for (target = 0; target < 16; target = target + 1)
            for (previous_direction = 0; previous_direction < 2;
                 previous_direction = previous_direction + 1)
                for (previous_switch = 0; previous_switch < 2;
                     previous_switch = previous_switch + 1)
                    for (controls = 0; controls < 8; controls = controls + 1) begin
                        prepare(target, previous_direction[0], previous_switch[0]);
                        tick(controls[2], controls[0], controls[1]);
                    end
        $display("CHECK: all 512 count/direction/switch-history/input combinations");

        for (i = 0; i < 256; i = i + 1) begin
            rng = rng ^ (rng << 13);
            rng = rng ^ (rng >> 17);
            rng = rng ^ (rng << 5);
            tick(rng[3:0] != 4'd0, rng[12], rng[8]);
        end

        for (i = 0; i < 512; i = i + 1)
            if (transition_seen[i])
                covered_transitions = covered_transitions + 1;
        if (count_seen !== 16'hffff || covered_transitions != 512)
            $fatal(1, "coverage incomplete: count_values=%h combinations=%0d/512",
                   count_seen, covered_transitions);
        if (reset_cycles == 0 || hold_cycles == 0 || up_cycles == 0 ||
            down_cycles == 0 || toggle_events == 0 ||
            overflow_events == 0 || underflow_events == 0)
            $fatal(1, "a required scenario was not exercised");

        $display("PASS: both FSMs match the model, cycles=%0d count_values=16/16 combinations=%0d/512 seed=%0d",
                 checked_cycles, covered_transitions, seed);
        $display("COVER: reset=%0d hold=%0d up=%0d down=%0d toggles=%0d overflow=%0d underflow=%0d",
                 reset_cycles, hold_cycles, up_cycles, down_cycles, toggle_events,
                 overflow_events, underflow_events);
        $finish;
    end

    initial begin
        #1000000;
        $fatal(1, "simulation timeout");
    end
endmodule
