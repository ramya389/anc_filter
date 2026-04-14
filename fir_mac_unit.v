// =============================================================================
// Module: fir_mac_unit
// Description: FIR Multiply-Accumulate Unit.
//   Computes: n_hat_signal = (sum_{k=0}^{N-1} w_k * x_k) >>> Q_SHIFT
//
// Scaling rationale:
//   Coefficients are stored as scaled integers (not unit-range fractions).
//   The product w_k * x_k has magnitude up to ~32767 * 32767 = ~10^9,
//   far exceeding the 16-bit signal range.  Right-shifting the accumulator
//   by Q_SHIFT=10 maps the coefficient scale back to signal scale so that
//   the error subtractor produces a meaningful e(n).
//
//   n_hat_out is DATA_WIDTH bits (signal-scale), ready for subtraction.
//
// Flat bus layout: Tap k => bits [(k+1)*WIDTH-1 : k*WIDTH]
// =============================================================================

module fir_mac_unit #(
    parameter DATA_WIDTH   = 16,
    parameter COEFF_WIDTH  = 16,
    parameter ACC_WIDTH    = 40,
    parameter FILTER_ORDER = 8,
    parameter Q_SHIFT      = 10   // Arithmetic right-shift applied to accumulator
)(
    input  wire                                      clk,
    input  wire                                      rst_n,
    input  wire                                      start,
    input  wire [(DATA_WIDTH  * FILTER_ORDER)-1:0]   x_in,
    input  wire [(COEFF_WIDTH * FILTER_ORDER)-1:0]   w_in,
    output reg  signed [DATA_WIDTH-1:0]              n_hat,    // Signal-scale estimate
    output reg                                       mac_done
);

    localparam IDLE    = 2'd0;
    localparam COMPUTE = 2'd1;
    localparam DONE    = 2'd2;

    reg [1:0]  state;
    reg [3:0]  tap_cnt;
    reg signed [ACC_WIDTH-1:0] accumulator;

    // Combinational tap extraction
    wire signed [DATA_WIDTH-1:0]  x_k;
    wire signed [COEFF_WIDTH-1:0] w_k;
    assign x_k = $signed(x_in[(tap_cnt * DATA_WIDTH)  +: DATA_WIDTH]);
    assign w_k = $signed(w_in[(tap_cnt * COEFF_WIDTH) +: COEFF_WIDTH]);

    // Full-precision signed product, sign-extended to ACC_WIDTH
    wire signed [DATA_WIDTH+COEFF_WIDTH-1:0] product;
    assign product = $signed(w_k) * $signed(x_k);

    wire signed [ACC_WIDTH-1:0] product_ext;
    assign product_ext = {{(ACC_WIDTH - DATA_WIDTH - COEFF_WIDTH){product[DATA_WIDTH+COEFF_WIDTH-1]}},
                           product};

    // Arithmetic right-shift of accumulator by Q_SHIFT → signal-scale result
    wire signed [ACC_WIDTH-1:0] acc_shifted;
    assign acc_shifted = $signed(accumulator) >>> Q_SHIFT;

    always @(posedge clk) begin
        if (!rst_n) begin
            state       <= IDLE;
            tap_cnt     <= 4'd0;
            accumulator <= {ACC_WIDTH{1'b0}};
            n_hat       <= {DATA_WIDTH{1'b0}};
            mac_done    <= 1'b0;
        end else begin
            mac_done <= 1'b0;

            case (state)
                IDLE: begin
                    if (start) begin
                        accumulator <= {ACC_WIDTH{1'b0}};
                        tap_cnt     <= 4'd0;
                        state       <= COMPUTE;
                    end
                end

                COMPUTE: begin
                    accumulator <= accumulator + product_ext;
                    if (tap_cnt == FILTER_ORDER - 1)
                        state <= DONE;
                    else
                        tap_cnt <= tap_cnt + 1;
                end

                DONE: begin
                    // Arithmetic right-shift then truncate to DATA_WIDTH
                    n_hat    <= acc_shifted[DATA_WIDTH-1:0];
                    mac_done <= 1'b1;
                    state    <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule
