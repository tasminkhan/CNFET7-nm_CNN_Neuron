// Function:
//   rounded = (acc + 2^(SHIFT-1)) >>> SHIFT        // round-half-up, arith shift
//   q       = clip(rounded, -2^(OW-1), 2^(OW-1)-1) // saturate
//   SHIFT == 0 : no rounding/shift, just saturate.
// -----------------------------------------------------------------------------
module requant_syn #(
    parameter int ACCW  = 40,  // input accumulator width (signed)
    parameter int OW    = 16,  // output width           (signed)
    parameter int SHIFT = 12   // FIXED per-layer right-shift (Q4.12 -> 12)
) (
    input  logic signed [ACCW-1:0] acc,   // from the MAC
    output logic signed [OW-1:0]   q,     // requantized, saturated output
    output logic                   sat    // 1 = output was clipped
);

    // Work a couple of bits wider so the rounding add can't overflow.
    localparam int W = ACCW + 2;

    // Saturation bounds as compile-time signed constants.
    localparam logic signed [W-1:0] MAXV =  (W'(1) <<< (OW-1)) - 1; //  2^(OW-1)-1
    localparam logic signed [W-1:0] MINV = -(W'(1) <<< (OW-1));     // -2^(OW-1)

    // Rounding bias is now a constant: 2^(SHIFT-1), or 0 when SHIFT==0.
    localparam logic signed [W-1:0] BIAS = (SHIFT == 0) ? '0 : (W'(1) <<< (SHIFT-1));

    logic signed [W-1:0] acc_ext;   // sign-extended accumulator
    logic signed [W-1:0] rounded;   // after round + shift
    logic                over, under;
    logic signed [W-1:0] sel;

    assign acc_ext = acc;                          // signed -> signed, sign-extends
    assign rounded = (SHIFT == 0) ? acc_ext
                                  : ((acc_ext + BIAS) >>> SHIFT); // fixed shift

    assign over  = (rounded > MAXV);
    assign under = (rounded < MINV);
    assign sat   = over | under;

    assign sel = over  ? MAXV :
                 under ? MINV : rounded;
    assign q   = sel[OW-1:0];

endmodule