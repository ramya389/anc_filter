// =============================================================================
// Module: lms_update_unit
// Description: LMS weight update: w_k(n+1) = w_k(n) + delta_w_k
//   where delta_w_k = (mu * e(n) * x(n-k)) >>> Q_SHIFT
//
// Scaling rationale:
//   Without the right-shift, delta_w = mu * e * x has magnitude
//   ~4 * 512 * 512 = 1,048,576 >> 32767 (max coeff value), so coefficients
//   saturate immediately and never converge.
//   Dividing by 2^Q_SHIFT = 1024 gives delta_w ~ 1024, which grows
//   coefficients smoothly toward the optimal value.
//
//   Q_SHIFT must match the Q_SHIFT in fir_mac_unit.
//
// e_n is captured into e_n_reg on the start pulse for stability.
// Flat bus layout: Tap k => bits [(k+1)*WIDTH-1 : k*WIDTH]
// =============================================================================

module lms_update_unit #(
    parameter DATA_WIDTH   = 16,
    parameter COEFF_WIDTH  = 16,
    parameter MU_WIDTH     = 8,
    parameter FILTER_ORDER = 8,
    parameter Q_SHIFT      = 10   // Must match fir_mac_unit Q_SHIFT
)(
    input  wire                                      clk,
    input  wire                                      rst_n,
    input  wire                                      start,
    input  wire signed [DATA_WIDTH-1:0]              e_n,
    input  wire [(DATA_WIDTH  * FILTER_ORDER)-1:0]   x_in,
    input  wire [(COEFF_WIDTH * FILTER_ORDER)-1:0]   w_in,
    input  wire [MU_WIDTH-1:0]                       mu,
    output reg                                       wr_en,
    output reg  [2:0]                                wr_addr,
    output reg  [COEFF_WIDTH-1:0]                    wr_data,
    output reg                                       lms_done
);

    localparam IDLE    = 2'd0;
    localparam COMPUTE = 2'd1;
    localparam FINISH  = 2'd2;

    reg [1:0]  state;
    reg [3:0]  tap_idx;
    reg signed [DATA_WIDTH-1:0] e_n_reg;  // Frozen error for entire update pass

    // Combinational tap extraction
    wire signed [DATA_WIDTH-1:0]  x_k;
    wire signed [COEFF_WIDTH-1:0] w_k;
    assign x_k = $signed(x_in[(tap_idx * DATA_WIDTH)  +: COEFF_WIDTH]);
    assign w_k = $signed(w_in[(tap_idx * COEFF_WIDTH) +: COEFF_WIDTH]);

    // delta_w = (mu * e_n_reg * x_k) >>> Q_SHIFT
    // Product width: MU_WIDTH + DATA_WIDTH + DATA_WIDTH bits
    localparam PROD_W = MU_WIDTH + DATA_WIDTH + DATA_WIDTH;
    wire signed [PROD_W-1:0]    raw_product;
    wire signed [PROD_W-1:0]    delta_w;
    wire signed [COEFF_WIDTH:0] w_new_full;   // One extra guard bit
    wire signed [COEFF_WIDTH-1:0] w_new_sat;

    assign raw_product = $signed({1'b0, mu}) * e_n_reg * $signed(x_k);
    assign delta_w     = $signed(raw_product) >>> Q_SHIFT;  // Arithmetic right-shift

    // w_new = w_k + delta_w (truncated to COEFF_WIDTH guard bits)
    assign w_new_full = {w_k[COEFF_WIDTH-1], w_k} + delta_w[COEFF_WIDTH:0];

    // Saturate to COEFF_WIDTH signed range
    assign w_new_sat =
        (w_new_full > $signed({{1'b0}, {(COEFF_WIDTH-1){1'b1}}})) ? {1'b0, {(COEFF_WIDTH-1){1'b1}}} :
        (w_new_full < $signed({{1'b1}, {(COEFF_WIDTH-1){1'b0}}})) ? {1'b1, {(COEFF_WIDTH-1){1'b0}}} :
                                                                      w_new_full[COEFF_WIDTH-1:0];

    always @(posedge clk) begin
        if (!rst_n) begin
            state    <= IDLE;
            tap_idx  <= 4'd0;
            wr_en    <= 1'b0;
            wr_addr  <= 3'd0;
            wr_data  <= {COEFF_WIDTH{1'b0}};
            lms_done <= 1'b0;
            e_n_reg  <= {DATA_WIDTH{1'b0}};
        end else begin
            wr_en    <= 1'b0;
            lms_done <= 1'b0;

            case (state)
                IDLE: begin
                    if (start) begin
                        e_n_reg <= e_n;    // Capture stable e_n
                        tap_idx <= 4'd0;
                        state   <= COMPUTE;
                    end
                end

                COMPUTE: begin
                    wr_en   <= 1'b1;
                    wr_addr <= tap_idx[2:0];
                    wr_data <= w_new_sat;  // Combinational, valid for current tap_idx

                    if (tap_idx == FILTER_ORDER - 1)
                        state <= FINISH;
                    else
                        tap_idx <= tap_idx + 1;
                end

                FINISH: begin
                    lms_done <= 1'b1;
                    state    <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule
