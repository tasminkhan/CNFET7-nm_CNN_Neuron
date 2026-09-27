// if the input is negative, output zero; otherwise pass it
// through. That is a multiplexer deciding on the sign bit
// -----------------------------------------------------------------------------
module relu #(
    parameter int DATAW = 16
) (
    input  logic signed [DATAW-1:0] x,
    output logic signed [DATAW-1:0] y
);

    // x[DATAW-1] is the sign bit: 1 => negative => clamp to 0.
    assign y = x[DATAW-1] ? '0 : x;

endmodule
