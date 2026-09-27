`timescale 1ns/1ps

module relu_tb;

    localparam int DATAW = 16;

    logic signed [DATAW-1:0] x, y;

    relu #(.DATAW(DATAW)) dut (.x(x), .y(y));

    int errors = 0;
    int checks = 0;

    task automatic check(input logic signed [DATAW-1:0] xin, input string tag);
        logic signed [DATAW-1:0] exp;
        begin
            x = xin;
            #1;
            exp = (xin < 0) ? '0 : xin;     // reference: max(x,0)
            checks++;
            if (y !== exp) begin
                errors++;
                $display("  MISMATCH [%s] x=%0d | got=%0d exp=%0d", tag, xin, y, exp);
            end
        end
    endtask

    int i;
    logic signed [DATAW-1:0] rx;

    initial begin
        // directed
        check(0,       "zero");
        check(1,       "small pos");
        check(-1,      "small neg");
        check(32767,   "max pos");
        check(-32768,  "max neg");
        check(12345,   "pos");
        check(-12345,  "neg");

        $display("--------------------------------------------------");
        $display("checks run : %0d", checks);
        $display("errors     : %0d", errors);
        $display("RESULT     : %s", (errors==0) ? "PASS" : "FAIL");
        $display("--------------------------------------------------");
        $finish;
    end

endmodule
