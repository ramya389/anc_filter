// =============================================================================
// Module: error_subtractor
// Description: Computes e(n) = d(n) - n_hat(n)
//
//   n_hat is now DATA_WIDTH signal-scale output from fir_mac_unit
//   (the Q_SHIFT scaling has already been applied by the MAC unit).
//   Simple registered subtraction — no truncation needed.
// =============================================================================

module error_subtractor #(
    parameter DATA_WIDTH = 16,
    parameter OUT_WIDTH  = 16
)(
    input  wire                          clk,
    input  wire                          rst_n,
    input  wire                          valid_in,
    input  wire signed [DATA_WIDTH-1:0]  d_n,
    input  wire signed [DATA_WIDTH-1:0]  n_hat,   // Already signal-scale
    output reg  signed [OUT_WIDTH-1:0]   e_n,
    output reg                           valid_out
);

    always @(posedge clk) begin
        if (!rst_n) begin
            e_n       <= {OUT_WIDTH{1'b0}};
            valid_out <= 1'b0;
        end else begin
            valid_out <= valid_in;
            if (valid_in)
                e_n <= d_n - n_hat;
        end
    end

endmodule
