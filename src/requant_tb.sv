// -----------------------------------------------------------------------------
`timescale 1ns/1ps

module requant_syn_tb;

    localparam int ACCW  = 40;
    localparam int OW    = 16;
    localparam int SHIFT = 12;   // MUST match the DUT parameter below

    logic signed [ACCW-1:0] acc;
    logic signed [OW-1:0]   q;
    logic                   sat;

    requant_syn #(.ACCW(ACCW), .OW(OW), .SHIFT(SHIFT)) dut (
        .acc(acc), .q(q), .sat(sat)
    );

    int errors = 0;
    int checks = 0;

    // golden model (sets exp_q, exp_sat) at the fixed SHIFT
    longint exp_q;
    logic   exp_sat;
    task automatic gold(input longint acc_in);
        longint bias, rounded, maxv, minv;
        begin
            bias    = (SHIFT == 0) ? 0 : (longint'(1) << (SHIFT-1));
            rounded = (SHIFT == 0) ? acc_in : ((acc_in + bias) >>> SHIFT);
            maxv = (longint'(1) << (OW-1)) - 1;
            minv = -(longint'(1) << (OW-1));
            if (rounded > maxv)      begin exp_q = maxv; exp_sat = 1'b1; end
            else if (rounded < minv) begin exp_q = minv; exp_sat = 1'b1; end
            else                     begin exp_q = rounded; exp_sat = 1'b0; end
        end
    endtask

    task automatic check(input longint acc_in, input string tag);
        begin
            acc = acc_in;
            #1;                       // settle combinational logic
            gold(acc_in);
            checks++;
            if (q !== exp_q[OW-1:0] || sat !== exp_sat) begin
                errors++;
                $display("  MISMATCH [%s] acc=%0d | got q=%0d sat=%0b  exp q=%0d sat=%0b",
                         tag, acc_in, q, sat, exp_q, exp_sat);
            end
        end
    endtask

    // handy reference points for SHIFT=12  (2^12 = 4096)
    localparam longint HALF = (longint'(1) << (SHIFT-1)); // 2048
    localparam longint STEP = (longint'(1) << SHIFT);     // 4096

    int i;
    longint racc;

    initial begin
        // ---- directed (hand-checked for SHIFT=12) ---------------------------
        $display("[directed] SHIFT=%0d (2^SHIFT=%0d)", SHIFT, STEP);
        check(0,            "zero -> 0");
        check(STEP,         "one step -> 1");          // 4096 >>12 = 1
        check(STEP*100,     "100 steps -> 100");       // 409600 >>12 = 100
        check(HALF,         "exactly .5 -> round up 1");// (2048+2048)>>12 = 1
        check(HALF-1,       "just under .5 -> 0");      // (2047+2048)>>12 = 0
        check(-HALF,        "neg half -> 0");           // (-2048+2048)>>12 = 0
        check(-HALF-1,      "just past -.5 -> -1");     // (-2049+2048)>>12 = -1
        check(STEP*40000,   "sat high -> 32767");       // way over max
        check(-STEP*40000,  "sat low -> -32768");       // way under min
        check(STEP*32767,   "exactly max -> 32767");    // 32767, no sat
        check(STEP*32768,   "one past max -> sat");     // 32768 -> clip
        if (errors == 0) $display("  directed OK");

        // ---- boundary sweep around the saturation edges ---------------------
        $display("[boundary] around +/- max ...");
        for (i = -5; i <= 5; i++) begin
            check(STEP*32767 + i*STEP, "near +max");
            check(-STEP*32768 + i*STEP, "near -max");
        end

        // ---- randomized -----------------------------------------------------
        // acc is a signed ACCW-bit port, so stimulus MUST fit in ACCW bits.
        // Build a random ACCW-bit pattern and interpret it as signed; this
        // exercises the full legal input range including both saturation edges.
        $display("[random] 100 cases (constrained to signed %0d-bit range) ...", ACCW);
        for (i = 0; i < 100; i++) begin
            racc = $random;                 // low 32 bits
            racc = (racc << 8) ^ $random;   // fill up to 40 bits of entropy
            racc = racc & ((longint'(1) << ACCW) - 1);  // mask to ACCW bits
            // sign-extend from bit ACCW-1 so it's a proper signed ACCW value
            if (racc[ACCW-1]) racc = racc - (longint'(1) << ACCW);
            check(racc, "rand");
        end

        $display("--------------------------------------------------");
        $display("checks run : %0d", checks);
        $display("errors     : %0d", errors);
        $display("RESULT     : %s", (errors==0) ? "PASS" : "FAIL");
        $display("--------------------------------------------------");
        $finish;
    end

endmodule
