
`timescale 1ns/1ps
module neuron_syn_tb;
    localparam int WW=16, AW=16, ACCW=40, OW=16, SHIFT=12;

    logic clk, rst_n, en, clear, result_en;
    logic signed [WW-1:0] w;  logic signed [AW-1:0] a;
    logic signed [OW-1:0] y_r; logic y_valid;

    neuron_syn #(.WW(WW),.AW(AW),.ACCW(ACCW),.OW(OW),.SHIFT(SHIFT)) dut (
        .clk(clk),.rst_n(rst_n),.en(en),.clear(clear),
        .w(w),.a(a),.result_en(result_en),.y_r(y_r),.y_valid(y_valid));

    int errors=0, checks=0;
    initial clk=0; always #5 clk=~clk;

    // golden model: requant(round-half-up + saturate) then ReLU, at fixed SHIFT
    function automatic longint gold(input longint acc_in);
        longint bias, rounded, maxv, minv, xq;
        begin
            bias    = (SHIFT==0) ? 0 : (longint'(1) << (SHIFT-1));
            rounded = (SHIFT==0) ? acc_in : ((acc_in + bias) >>> SHIFT);
            maxv = (longint'(1) << (OW-1)) - 1;
            minv = -(longint'(1) << (OW-1));
            if (rounded > maxv)      xq = maxv;
            else if (rounded < minv) xq = minv;
            else                     xq = rounded;
            gold = (xq < 0) ? 0 : xq;   // ReLU
        end
    endfunction

    // Accumulate L taps, latch, then check y_r. All TB edges are negedges.
    task automatic run_neuron(input int L);
        longint ref_acc, exp_y; int k;
        logic signed [WW-1:0] wv; logic signed [AW-1:0] av;
        begin
            ref_acc = 0;

            // ---- accumulate: change inputs on negedge, DUT latches on posedge
            for (k=0;k<L;k++) begin
                wv=$random; av=$random;
                ref_acc = ref_acc + longint'(wv)*longint'(av);
                @(negedge clk);
                en=1; clear=(k==0); w=wv; a=av;
            end
            @(posedge clk);          // last tap latched into acc on this edge

            // ---- stop accumulating, request the output latch
            @(negedge clk);          // acc settled; safe to change controls
            en=0; clear=0; result_en=1;
            @(posedge clk);          // y_r <= y (= f(acc)); y_valid <= 1
            @(negedge clk);          // sample point: half a cycle after latch
            result_en=0;

            exp_y = gold(ref_acc);
            checks++;
            if (!y_valid) begin errors++; $display("  y_valid low L=%0d",L); end
            if (y_r !== exp_y[OW-1:0]) begin
                errors++;
                $display("  Y MISMATCH L=%0d got=%0d exp=%0d (acc=%0d)",L,y_r,exp_y,ref_acc);
            end
        end
    endtask

    int i, len;
    initial begin
        en=0;clear=0;w=0;a=0;result_en=0; rst_n=0;
        @(negedge clk); @(negedge clk);
        rst_n=1;
        @(negedge clk);

        $display("[directed] 3x3 conv neuron"); run_neuron(9);
        $display("[directed] 7x7 conv neuron"); run_neuron(49);

        // forced negative -> ReLU must give 0
        $display("[directed] forced-negative -> y=0");
        @(negedge clk); en=1; clear=1; w=1000; a=-1000;
        @(posedge clk);                        // acc <= -1,000,000
        @(negedge clk); en=1; clear=0; w=1000; a=-1000;
        @(posedge clk);                        // acc <= -2,000,000
        @(negedge clk); en=0; clear=0; result_en=1;
        @(posedge clk);                        // latch: y_r <= relu(...) = 0
        @(negedge clk); result_en=0;
        checks++;
        if (y_r!==0) begin errors++; $display("  neg FAIL y_r=%0d",y_r); end
        else $display("  neg OK y_r=0");

        $display("[random] 100 neurons ...");
        for (i=0;i<100;i++) begin
            len = ($random % 49); if (len<1) len=1;
            run_neuron(len);
        end

        $display("--------------------------------------------------");
        $display("checks run : %0d", checks);
        $display("errors     : %0d", errors);
        $display("RESULT     : %s", (errors==0)?"PASS":"FAIL");
        $display("--------------------------------------------------");
        $finish;
    end
    initial begin #30_000_000; $display("TIMEOUT"); $finish; end
endmodule