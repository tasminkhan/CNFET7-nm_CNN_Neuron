// The fundamental compute primitive of the inference engine. One MAC does:
//     acc <- acc + (w * a)          (accumulate a term of a dot-product)
//     acc <- (w * a)                (start a fresh dot-product, via `clear`)
//     acc <- acc                    (hold, when not enabled)
//
//   ACCW sizing rule (so acc can never overflow):
//   ACCW >= WW + AW + ceil(log2(N_max))
//   where N_max is the largest number of terms summed in any single
//   dot-product in your network (e.g. the widest LSTM gate reduction).
// -----------------------------------------------------------------------------
module mac #(
    parameter int WW   = 16,   // weight width      (signed, two's complement)
    parameter int AW   = 16,   // activation width  (signed, two's complement)
    parameter int ACCW = 40    // accumulator width (signed) 
) (
    input  logic                    clk,
    input  logic                    rst_n,   // asynchronous, active-low reset
    input  logic                    en,      // 1 = act this cycle; 0 = hold acc
    input  logic                    clear,   // with en: acc <= product (new sum)
                                             // without: acc <= acc + product
    input  logic signed [WW-1:0]    w,       // weight   operand
    input  logic signed [AW-1:0]    a,       // activation operand
    output logic signed [ACCW-1:0]  acc      // running accumulator
);

    // Full-precision product. w and a are signed, so this multiply is signed
    // and is (WW+AW) bits wide - no precision is lost here.
    logic signed [WW+AW-1:0] prod;
    assign prod = w * a;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            acc <= '0;
        end else if (en) begin
            if (clear)
                acc <= prod;          // first term of a new dot-product
            else
                acc <= acc + prod;    // signed context -> prod sign-extends to ACCW
        end
    end

endmodule
