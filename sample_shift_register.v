// =============================================================================
// Module: sample_shift_register
// Description: Tap delay line for reference noise samples.
//              Verilog-2001 compatible: array port replaced by flat bus.
//
//  Flat bus packing (x_out):
//    Tap k  =>  bits [(k+1)*DATA_WIDTH-1 : k*DATA_WIDTH]
//    k=0 = most recent sample, k=N-1 = oldest sample
// =============================================================================

module sample_shift_register #(
    parameter DATA_WIDTH   = 16,
    parameter FILTER_ORDER = 8
)(
    input  wire                                   clk,
    input  wire                                   rst_n,      // Active-low sync reset
    input  wire                                   shift_en,   // Shift on new sample
    input  wire [DATA_WIDTH-1:0]                  x_in,       // New reference noise sample
    output wire [(DATA_WIDTH*FILTER_ORDER)-1:0]   x_out       // All taps, flat bus
);

    reg [DATA_WIDTH-1:0] sr [0:FILTER_ORDER-1];
    integer i;

    always @(posedge clk) begin
        if (!rst_n) begin
            for (i = 0; i < FILTER_ORDER; i = i + 1)
                sr[i] <= {DATA_WIDTH{1'b0}};
        end else if (shift_en) begin
            sr[0] <= x_in;
            for (i = 1; i < FILTER_ORDER; i = i + 1)
                sr[i] <= sr[i-1];
        end
    end

    // Pack array into flat bus
    genvar k;
    generate
        for (k = 0; k < FILTER_ORDER; k = k + 1) begin : pack_x
            assign x_out[(k+1)*DATA_WIDTH-1 -: DATA_WIDTH] = sr[k];
        end
    endgenerate

endmodule
