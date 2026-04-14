// =============================================================================
// Module: coefficient_memory
// Description: Stores adaptive filter coefficients w_k(n).
//              Verilog-2001 compatible: array port replaced by flat bus.
//
//  Flat bus packing (coeff_out):
//    Coeff k  =>  bits [(k+1)*COEFF_WIDTH-1 : k*COEFF_WIDTH]
// =============================================================================

module coefficient_memory #(
    parameter COEFF_WIDTH  = 16,
    parameter FILTER_ORDER = 8
)(
    input  wire                                     clk,
    input  wire                                     rst_n,
    // Write port (from LMS update unit)
    input  wire                                     wr_en,
    input  wire [2:0]                               wr_addr,   // Log2(8)=3 bits; adjust for other orders
    input  wire [COEFF_WIDTH-1:0]                   wr_data,
    // Read port (to FIR MAC) — all coefficients as flat bus
    output wire [(COEFF_WIDTH*FILTER_ORDER)-1:0]    coeff_out
);

    reg [COEFF_WIDTH-1:0] mem [0:FILTER_ORDER-1];
    integer i;

    always @(posedge clk) begin
        if (!rst_n) begin
            for (i = 0; i < FILTER_ORDER; i = i + 1)
                mem[i] <= {COEFF_WIDTH{1'b0}};
        end else if (wr_en) begin
            mem[wr_addr] <= wr_data;
        end
    end

    genvar k;
    generate
        for (k = 0; k < FILTER_ORDER; k = k + 1) begin : pack_w
            assign coeff_out[(k+1)*COEFF_WIDTH-1 -: COEFF_WIDTH] = mem[k];
        end
    endgenerate

endmodule
