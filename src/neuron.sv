//  w,a --[ mac ]--acc-->[ requant_syn ]--x_q-->[ relu ]--> y --(reg)--> y_r
//
// Differences from the simulation neuron.sv:
//   - observation ports (acc, x_q, q_sat, y) are internal nets, not ports
//   - the requant shift is a COMPILE-TIME CONSTANT (SHIFT)
// -----------------------------------------------------------------------------
module neuron_syn #(
    parameter int WW    = 16,   // weight width
    parameter int AW    = 16,   // activation width
    parameter int ACCW  = 40,   // accumulator width
    parameter int OW    = 16,   // requant / activation width
    parameter int SHIFT = 12    // FIXED requant shift (Q4.12 weights -> 12)
) (
    input  logic                  clk,
    input  logic                  rst_n,
    input  logic                  en,        // MAC enable (accumulate this tap)
    input  logic                  clear,     // MAC start-new-dot-product
    input  logic signed [WW-1:0]  w,         // weight  tap
    input  logic signed [AW-1:0]  a,         // activation tap
    input  logic                  result_en, // latch the neuron output
    output logic signed [OW-1:0]  y_r,       // registered neuron output
    output logic                  y_valid    // 1 for one cycle after result_en
);

    // ---- internal nets ------------------------------------------------------
    logic signed [ACCW-1:0] acc;    // raw accumulator
    logic signed [OW-1:0]   x_q;    // requantized pre-ReLU
    logic                   q_sat;  // requant saturated (unused externally)
    logic signed [OW-1:0]   y;      // combinational neuron output

    // ---- multiply-accumulate ------------------------------------------------
    mac #(.WW(WW), .AW(AW), .ACCW(ACCW)) u_mac (
        .clk   (clk),
        .rst_n (rst_n),
        .en    (en),
        .clear (clear),
        .w     (w),
        .a     (a),
        .acc   (acc)
    );

    // ---- requantize (fixed shift, combinational) ----------------------------
    requant #(.ACCW(ACCW), .OW(OW), .SHIFT(SHIFT)) u_rq (
        .acc (acc),
        .q   (x_q),
        .sat (q_sat)
    );

    // ---- ReLU activation (combinational) ------------------------------------
    relu #(.DATAW(OW)) u_relu (
        .x (x_q),
        .y (y)
    );

    // ---- registered output --------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            y_r     <= '0;
            y_valid <= 1'b0;
        end else if (result_en) begin
            y_r     <= y;
            y_valid <= 1'b1;
        end else begin
            y_valid <= 1'b0;
        end
    end

endmodule