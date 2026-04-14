module lms_pipeline_update #(
    parameter DATA_WIDTH  = 16,
    parameter COEFF_WIDTH = 16,
    parameter MU_WIDTH    = 8,
    parameter PROD_WIDTH  = 40,
    parameter Q_SHIFT     = 10
)(
    input  wire signed [DATA_WIDTH-1:0]  e_n,
    input  wire [MU_WIDTH-1:0]           mu,
    input  wire signed [DATA_WIDTH-1:0]  x0,
    input  wire signed [DATA_WIDTH-1:0]  x1,
    input  wire signed [DATA_WIDTH-1:0]  x2,
    input  wire signed [DATA_WIDTH-1:0]  x3,
    input  wire signed [COEFF_WIDTH-1:0] w0_in,
    input  wire signed [COEFF_WIDTH-1:0] w1_in,
    input  wire signed [COEFF_WIDTH-1:0] w2_in,
    input  wire signed [COEFF_WIDTH-1:0] w3_in,
    output wire signed [COEFF_WIDTH-1:0] w0_out,
    output wire signed [COEFF_WIDTH-1:0] w1_out,
    output wire signed [COEFF_WIDTH-1:0] w2_out,
    output wire signed [COEFF_WIDTH-1:0] w3_out
);

    localparam MU_E_W = MU_WIDTH + DATA_WIDTH;

    wire signed [MU_E_W-1:0]   mu_e;
    wire signed [PROD_WIDTH-1:0] delta0, delta1, delta2, delta3;

    assign mu_e   = $signed({1'b0, mu}) * $signed(e_n);

    assign delta0 = $signed(mu_e) * $signed(x0);
    assign delta1 = $signed(mu_e) * $signed(x1);
    assign delta2 = $signed(mu_e) * $signed(x2);
    assign delta3 = $signed(mu_e) * $signed(x3);

    function [COEFF_WIDTH-1:0] sat_add;
        input signed [COEFF_WIDTH-1:0] a;
        input signed [PROD_WIDTH-1:0]  b;
        reg   signed [PROD_WIDTH-1:0]  sum;
        begin
            sum = $signed(a) + ($signed(b) >>> Q_SHIFT);

            if (sum > $signed({1'b0, {(COEFF_WIDTH-1){1'b1}}}))
                sat_add = {1'b0, {(COEFF_WIDTH-1){1'b1}}};
            else if (sum < $signed({1'b1, {(COEFF_WIDTH-1){1'b0}}}))
                sat_add = {1'b1, {(COEFF_WIDTH-1){1'b0}}};
            else
                sat_add = sum[COEFF_WIDTH-1:0];
        end
    endfunction

    assign w0_out = sat_add(w0_in, delta0);
    assign w1_out = sat_add(w1_in, delta1);
    assign w2_out = sat_add(w2_in, delta2);
    assign w3_out = sat_add(w3_in, delta3);

endmodule
