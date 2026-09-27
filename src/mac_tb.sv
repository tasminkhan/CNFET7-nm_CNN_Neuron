// Tests:
//   1. Reset clears acc to 0.
//   2. Directed dot-product with hand-checkable numbers.
//   3. Hold behaviour (en=0 must freeze acc).
//   4. Randomized stress: thousands of random ops mixing clear/accumulate/hold.
// -----------------------------------------------------------------------------
`timescale 1ns/1ps

module mac_tb;

    // Match these to the DUT instance below.
    localparam int WW   = 16;
    localparam int AW   = 16;
    localparam int ACCW = 40;

    logic                   clk, rst_n, en, clear;
    logic signed [WW-1:0]   w;
    logic signed [AW-1:0]   a;
    logic signed [ACCW-1:0] acc;

    // Device under test
    mac #(.WW(WW), .AW(AW), .ACCW(ACCW)) dut (
        .clk(clk), .rst_n(rst_n), .en(en), .clear(clear),
        .w(w), .a(a), .acc(acc)
    );

    // Reference accumulator (independent, 64-bit).
    longint ref_acc;

    // Book-keeping
    int errors = 0;
    int checks = 0;

    // 10 ns clock
    initial clk = 0;
    always #5 clk = ~clk;

    // ---- helper: apply one operation, update reference, then check ----------
    // Called after a posedge has been set up; it drives inputs, waits a clock,
    // updates the reference the same way the DUT should, and compares.
    task automatic do_op(input logic t_en, input logic t_clear,
                         input logic signed [WW-1:0] t_w,
                         input logic signed [AW-1:0] t_a);
        begin
            // drive inputs
            en    = t_en;
            clear = t_clear;
            w     = t_w;
            a     = t_a;

            // update the reference to match the DUT's next-state rule
            if (t_en) begin
                if (t_clear) ref_acc = longint'(t_w) * longint'(t_a);
                else         ref_acc = ref_acc + longint'(t_w) * longint'(t_a);
            end
            // else: hold -> ref_acc unchanged

            @(posedge clk);   // DUT latches
            #1;               // let acc settle for sampling

            checks++;
            if (acc !== ACCW'(ref_acc)) begin
                errors++;
                $display("  MISMATCH @%0t  en=%0b clear=%0b w=%0d a=%0d | got=%0d exp=%0d",
                         $time, t_en, t_clear, t_w, t_a, acc, ACCW'(ref_acc));
            end
        end
    endtask

    // ---- stimulus -----------------------------------------------------------
    int i;
    logic signed [WW-1:0] rw;
    logic signed [AW-1:0] ra;
    logic                 r_en, r_clear;

    initial begin
        // 1) Reset
        en = 0; clear = 0; w = 0; a = 0; ref_acc = 0;
        rst_n = 0;
        @(posedge clk); #1;
        if (acc !== '0) begin
            errors++; $display("  RESET FAIL: acc=%0d expected 0", acc);
        end
        rst_n = 1;
        @(posedge clk); #1;

        // 2) Directed dot-product:  (3*4) + (-2*5) + (7*(-6)) = 12 -10 -42 = -40
        $display("[directed] computing (3*4)+(-2*5)+(7*-6) ...");
        do_op(1, 1,  3,  4);   // start new sum -> 12
        do_op(1, 0, -2,  5);   // +(-10)       -> 2
        do_op(1, 0,  7, -6);   // +(-42)       -> -40
        if (acc == -40) $display("  directed sum = %0d  OK", acc);
        else            $display("  directed sum = %0d  (expected -40)", acc);

        // 3) Hold: two idle cycles must not change acc
        $display("[hold] acc must stay at -40 across en=0 cycles ...");
        do_op(0, 0, 100, 100); // en=0, should hold
        do_op(0, 1,  50,  50); // en=0 (clear ignored), should hold
        if (acc == -40) $display("  hold value = %0d  OK", acc);
        else            $display("  hold value = %0d  (expected -40)", acc);

        // 4) Randomized stress
        $display("[random] 100 mixed ops ...");
        for (i = 0; i < 100; i++) begin
            rw = $random;                 // full-width signed weight
            ra = $random;                 // full-width signed activation
            r_en = ($random % 5 != 0);    // ~80% enabled, ~20% hold

            // Force a fresh accumulation periodically so the running sum can't
            // grow past the ACCW range (keeps exact-equality meaningful).
            if ((i % 40) == 0) r_clear = 1;
            else               r_clear = ($random % 8 == 0); // occasional restart

            do_op(r_en, r_clear, rw, ra);
        end

        // ---- report ---------------------------------------------------------
        $display("--------------------------------------------------");
        $display("checks run : %0d", checks);
        $display("errors     : %0d", errors);
        if (errors == 0) $display("RESULT     : PASS");
        else             $display("RESULT     : FAIL");
        $display("--------------------------------------------------");
        $finish;
    end

    // Safety net: never hang
    initial begin
        #2000000;
        $display("TIMEOUT");
        $finish;
    end

endmodule
