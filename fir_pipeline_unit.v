module fir_pipeline_unit #(
    parameter DATA_WIDTH   = 16,
    parameter COEFF_WIDTH  = 16,
    parameter ACC_WIDTH    = 40,
    parameter Q_SHIFT      = 10
)(
    input  wire                          clk,
    input  wire                          rst_n,
    input  wire                          valid_in,
    input  wire signed [DATA_WIDTH-1:0]  x0,
    input  wire signed [DATA_WIDTH-1:0]  x1,
    input  wire signed [DATA_WIDTH-1:0]  x2,
    input  wire signed [DATA_WIDTH-1:0]  x3,
    input  wire signed [COEFF_WIDTH-1:0] w0,
    input  wire signed [COEFF_WIDTH-1:0] w1,
    input  wire signed [COEFF_WIDTH-1:0] w2,
    input  wire signed [COEFF_WIDTH-1:0] w3,
    output reg  signed [DATA_WIDTH-1:0]  n_hat,
    output reg                           valid_out,
    output reg  signed [DATA_WIDTH-1:0]  x0_lms,
    output reg  signed [DATA_WIDTH-1:0]  x1_lms,
    output reg  signed [DATA_WIDTH-1:0]  x2_lms,
    output reg  signed [DATA_WIDTH-1:0]  x3_lms
);

    reg signed [DATA_WIDTH+COEFF_WIDTH-1:0] p0_r, p1_r, p2_r, p3_r;
    reg signed [ACC_WIDTH-1:0] s1_r, s2_r, s3_r;
    reg [3:0] vpipe;

    reg signed [DATA_WIDTH-1:0] x0_d1, x1_d1, x2_d1, x3_d1;
    reg signed [DATA_WIDTH-1:0] x0_d2, x1_d2, x2_d2, x3_d2;
    reg signed [DATA_WIDTH-1:0] x0_d3, x1_d3, x2_d3, x3_d3;
    reg signed [DATA_WIDTH-1:0] x0_d4, x1_d4, x2_d4, x3_d4;

    always @(posedge clk) begin
        if (!rst_n) begin
            p0_r <= 0; p1_r <= 0; p2_r <= 0; p3_r <= 0;
            s1_r <= 0; s2_r <= 0; s3_r <= 0;
            n_hat <= 0;
            valid_out <= 1'b0;
            vpipe <= 4'b0;

            x0_d1 <= 0; x1_d1 <= 0; x2_d1 <= 0; x3_d1 <= 0;
            x0_d2 <= 0; x1_d2 <= 0; x2_d2 <= 0; x3_d2 <= 0;
            x0_d3 <= 0; x1_d3 <= 0; x2_d3 <= 0; x3_d3 <= 0;
            x0_d4 <= 0; x1_d4 <= 0; x2_d4 <= 0; x3_d4 <= 0;

            x0_lms <= 0; x1_lms <= 0; x2_lms <= 0; x3_lms <= 0;
        end else begin
            vpipe <= {vpipe[2:0], valid_in};
            valid_out <= vpipe[3];

            // Delay x-vector to align with FIR output
            x0_d1 <= x0;    x1_d1 <= x1;    x2_d1 <= x2;    x3_d1 <= x3;
            x0_d2 <= x0_d1; x1_d2 <= x1_d1; x2_d2 <= x2_d1; x3_d2 <= x3_d1;
            x0_d3 <= x0_d2; x1_d3 <= x1_d2; x2_d3 <= x2_d2; x3_d3 <= x3_d2;
            x0_d4 <= x0_d3; x1_d4 <= x1_d3; x2_d4 <= x2_d3; x3_d4 <= x3_d3;

            x0_lms <= x0_d4;
            x1_lms <= x1_d4;
            x2_lms <= x2_d4;
            x3_lms <= x3_d4;

            // Stage 1: multiply
            p0_r <= $signed(w0) * $signed(x0);
            p1_r <= $signed(w1) * $signed(x1);
            p2_r <= $signed(w2) * $signed(x2);
            p3_r <= $signed(w3) * $signed(x3);

            // Stage 2/3/4: pipelined accumulation
            s1_r <= {{(ACC_WIDTH-(DATA_WIDTH+COEFF_WIDTH)){p0_r[DATA_WIDTH+COEFF_WIDTH-1]}}, p0_r} +
                    {{(ACC_WIDTH-(DATA_WIDTH+COEFF_WIDTH)){p1_r[DATA_WIDTH+COEFF_WIDTH-1]}}, p1_r};

            s2_r <= s1_r +
                    {{(ACC_WIDTH-(DATA_WIDTH+COEFF_WIDTH)){p2_r[DATA_WIDTH+COEFF_WIDTH-1]}}, p2_r};

            s3_r <= s2_r +
                    {{(ACC_WIDTH-(DATA_WIDTH+COEFF_WIDTH)){p3_r[DATA_WIDTH+COEFF_WIDTH-1]}}, p3_r};

            // Output stage
            n_hat <= ($signed(s3_r) >>> Q_SHIFT);
        end
    end

endmodule
