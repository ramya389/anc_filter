`include "fir_pipeline_unit.v"
`include "lms_pipeline_update.v"

module anc_datapath_pipelined #(
    parameter DATA_WIDTH  = 16,
    parameter COEFF_WIDTH = 16,
    parameter ACC_WIDTH   = 40,
    parameter MU_WIDTH    = 8,
    parameter Q_SHIFT     = 10
)(
    input  wire                          clk,
    input  wire                          rst_n,
    input  wire                          sample_valid,
    input  wire [MU_WIDTH-1:0]           mu,
    input  wire signed [DATA_WIDTH-1:0]  ref_noise_in,
    input  wire signed [DATA_WIDTH-1:0]  primary_in,
    output reg  signed [DATA_WIDTH-1:0]  y_out,
    output reg                           y_valid
);

    reg signed [DATA_WIDTH-1:0] x0, x1, x2, x3;
    reg signed [DATA_WIDTH-1:0] d0, d1, d2, d3, d4;
    reg signed [COEFF_WIDTH-1:0] w0, w1, w2, w3;

    wire signed [DATA_WIDTH-1:0] n_hat;
    wire                         n_hat_valid;
    wire signed [DATA_WIDTH-1:0] x0_lms, x1_lms, x2_lms, x3_lms;
    wire signed [COEFF_WIDTH-1:0] w0_next, w1_next, w2_next, w3_next;
    wire signed [DATA_WIDTH-1:0] e_now;

    assign e_now = d4 - n_hat;

    // Input shift registers and desired-signal delay line
    always @(posedge clk) begin
        if (!rst_n) begin
            x0 <= 0; x1 <= 0; x2 <= 0; x3 <= 0;
            d0 <= 0; d1 <= 0; d2 <= 0; d3 <= 0; d4 <= 0;
        end else begin
            if (sample_valid) begin
                x3 <= x2;
                x2 <= x1;
                x1 <= x0;
                x0 <= ref_noise_in;

                d0 <= primary_in;
            end

            d1 <= d0;
            d2 <= d1;
            d3 <= d2;
            d4 <= d3;
        end
    end

    fir_pipeline_unit #(
        .DATA_WIDTH (DATA_WIDTH),
        .COEFF_WIDTH(COEFF_WIDTH),
        .ACC_WIDTH  (ACC_WIDTH),
        .Q_SHIFT    (Q_SHIFT)
    ) u_fir_pipeline (
        .clk      (clk),
        .rst_n    (rst_n),
        .valid_in (sample_valid),
        .x0       (x0),
        .x1       (x1),
        .x2       (x2),
        .x3       (x3),
        .w0       (w0),
        .w1       (w1),
        .w2       (w2),
        .w3       (w3),
        .n_hat    (n_hat),
        .valid_out(n_hat_valid),
        .x0_lms   (x0_lms),
        .x1_lms   (x1_lms),
        .x2_lms   (x2_lms),
        .x3_lms   (x3_lms)
    );

    lms_pipeline_update #(
        .DATA_WIDTH (DATA_WIDTH),
        .COEFF_WIDTH(COEFF_WIDTH),
        .MU_WIDTH   (MU_WIDTH),
        .PROD_WIDTH (ACC_WIDTH),
        .Q_SHIFT    (Q_SHIFT)
    ) u_lms_pipeline (
        .e_n   (e_now),
        .mu    (mu),
        .x0    (x0_lms),
        .x1    (x1_lms),
        .x2    (x2_lms),
        .x3    (x3_lms),
        .w0_in (w0),
        .w1_in (w1),
        .w2_in (w2),
        .w3_in (w3),
        .w0_out(w0_next),
        .w1_out(w1_next),
        .w2_out(w2_next),
        .w3_out(w3_next)
    );

    always @(posedge clk) begin
        if (!rst_n) begin
            y_out   <= 0;
            y_valid <= 1'b0;
            w0 <= 0; w1 <= 0; w2 <= 0; w3 <= 0;
        end else begin
            y_valid <= n_hat_valid;

            if (n_hat_valid) begin
                y_out <= e_now;

                w0 <= w0_next;
                w1 <= w1_next;
                w2 <= w2_next;
                w3 <= w3_next;
            end
        end
    end

endmodule
