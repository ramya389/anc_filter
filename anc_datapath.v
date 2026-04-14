// =============================================================================
// Module: anc_datapath  (Top-Level)
// Description: Adaptive Noise Canceller Datapath — Verilog-2001 compatible.
//
// Pipeline timing (with S_LMS_WAIT to ensure e_n is registered before LMS):
//
//   State      | Cycle | Activity
//   -----------|-------|------------------------------------------------------
//   S_IDLE     |   0   | sample_valid → latch d_n
//   S_SHIFT    |   1   | ref sample shifts into SR; mac_start_r = 1
//   S_MAC      |  2-10 | FIR MAC accumulates 8 taps; mac_done fires
//   S_SUBTR    |  11   | sub_valid_r = 1 → error_subtractor registers e_n
//   S_LMS_WAIT |  12   | e_n now stable; lms_start_r = 1
//   S_LMS      | 13-21 | LMS updates 8 coefficients; lms_done fires
//   S_IDLE     |  22   | Ready for next sample
//
// Q_SHIFT=10 parameter must be consistent across fir_mac_unit and
// lms_update_unit — passed as parameter to both.
// =============================================================================

`include "sample_shift_register.v"
`include "coefficient_memory.v"
`include "fir_mac_unit.v"
`include "error_subtractor.v"
`include "lms_update_unit.v"

module anc_datapath #(
    parameter DATA_WIDTH   = 16,
    parameter COEFF_WIDTH  = 16,
    parameter ACC_WIDTH    = 40,
    parameter MU_WIDTH     = 8,
    parameter FILTER_ORDER = 8,
    parameter Q_SHIFT      = 10   // Scaling shift — must match in MAC and LMS
)(
    input  wire                          clk,
    input  wire                          rst_n,
    input  wire                          sample_valid,
    input  wire [MU_WIDTH-1:0]           mu,
    input  wire signed [DATA_WIDTH-1:0]  ref_noise_in,
    input  wire signed [DATA_WIDTH-1:0]  primary_in,
    output wire signed [DATA_WIDTH-1:0]  y_out,
    output wire                          y_valid,
    output wire                          busy
);

    // -------------------------------------------------------------------------
    // Interconnects
    // -------------------------------------------------------------------------
    wire [(DATA_WIDTH  * FILTER_ORDER)-1:0] x_bus;
    wire [(COEFF_WIDTH * FILTER_ORDER)-1:0] w_bus;

    wire signed [DATA_WIDTH-1:0] n_hat;      // Signal-scale from MAC (post Q_SHIFT)
    wire                         mac_done;

    wire signed [DATA_WIDTH-1:0] e_n;
    wire                         e_valid;

    wire                         lms_wr_en;
    wire [2:0]                   lms_wr_addr;
    wire [COEFF_WIDTH-1:0]       lms_wr_data;
    wire                         lms_done;

    // -------------------------------------------------------------------------
    // Control FSM
    // -------------------------------------------------------------------------
    localparam S_IDLE     = 3'd0;
    localparam S_SHIFT    = 3'd1;
    localparam S_MAC      = 3'd2;
    localparam S_SUBTR    = 3'd3;
    localparam S_LMS_WAIT = 3'd4;  // Wait one cycle for e_n to be registered
    localparam S_LMS      = 3'd5;

    reg [2:0] ctrl_state;
    reg       mac_start_r;
    reg       sub_valid_r;
    reg       lms_start_r;
    reg signed [DATA_WIDTH-1:0] d_n_reg;

    always @(posedge clk) begin
        if (!rst_n) begin
            ctrl_state  <= S_IDLE;
            mac_start_r <= 1'b0;
            sub_valid_r <= 1'b0;
            lms_start_r <= 1'b0;
            d_n_reg     <= {DATA_WIDTH{1'b0}};
        end else begin
            mac_start_r <= 1'b0;
            sub_valid_r <= 1'b0;
            lms_start_r <= 1'b0;

            case (ctrl_state)
                S_IDLE: begin
                    if (sample_valid) begin
                        d_n_reg    <= primary_in;
                        ctrl_state <= S_SHIFT;
                    end
                end
                S_SHIFT: begin
                    mac_start_r <= 1'b1;
                    ctrl_state  <= S_MAC;
                end
                S_MAC: begin
                    if (mac_done) begin
                        sub_valid_r <= 1'b1;
                        ctrl_state  <= S_SUBTR;
                    end
                end
                S_SUBTR: begin
                    // error_subtractor registers e_n this cycle
                    ctrl_state <= S_LMS_WAIT;
                end
                S_LMS_WAIT: begin
                    // e_n now valid and stable
                    lms_start_r <= 1'b1;
                    ctrl_state  <= S_LMS;
                end
                S_LMS: begin
                    if (lms_done)
                        ctrl_state <= S_IDLE;
                end
                default: ctrl_state <= S_IDLE;
            endcase
        end
    end

    assign busy = (ctrl_state != S_IDLE);

    // -------------------------------------------------------------------------
    // Sub-module Instantiations
    // -------------------------------------------------------------------------

    sample_shift_register #(
        .DATA_WIDTH   (DATA_WIDTH),
        .FILTER_ORDER (FILTER_ORDER)
    ) u_shift_reg (
        .clk      (clk),
        .rst_n    (rst_n),
        .shift_en (ctrl_state == S_SHIFT),
        .x_in     (ref_noise_in),
        .x_out    (x_bus)
    );

    coefficient_memory #(
        .COEFF_WIDTH  (COEFF_WIDTH),
        .FILTER_ORDER (FILTER_ORDER)
    ) u_coeff_mem (
        .clk       (clk),
        .rst_n     (rst_n),
        .wr_en     (lms_wr_en),
        .wr_addr   (lms_wr_addr),
        .wr_data   (lms_wr_data),
        .coeff_out (w_bus)
    );

    fir_mac_unit #(
        .DATA_WIDTH   (DATA_WIDTH),
        .COEFF_WIDTH  (COEFF_WIDTH),
        .ACC_WIDTH    (ACC_WIDTH),
        .FILTER_ORDER (FILTER_ORDER),
        .Q_SHIFT      (Q_SHIFT)
    ) u_mac (
        .clk      (clk),
        .rst_n    (rst_n),
        .start    (mac_start_r),
        .x_in     (x_bus),
        .w_in     (w_bus),
        .n_hat    (n_hat),
        .mac_done (mac_done)
    );

    error_subtractor #(
        .DATA_WIDTH (DATA_WIDTH),
        .OUT_WIDTH  (DATA_WIDTH)
    ) u_subtr (
        .clk       (clk),
        .rst_n     (rst_n),
        .valid_in  (sub_valid_r),
        .d_n       (d_n_reg),
        .n_hat     (n_hat),
        .e_n       (e_n),
        .valid_out (e_valid)
    );

    lms_update_unit #(
        .DATA_WIDTH   (DATA_WIDTH),
        .COEFF_WIDTH  (COEFF_WIDTH),
        .MU_WIDTH     (MU_WIDTH),
        .FILTER_ORDER (FILTER_ORDER),
        .Q_SHIFT      (Q_SHIFT)
    ) u_lms (
        .clk      (clk),
        .rst_n    (rst_n),
        .start    (lms_start_r),
        .e_n      (e_n),
        .x_in     (x_bus),
        .w_in     (w_bus),
        .mu       (mu),
        .wr_en    (lms_wr_en),
        .wr_addr  (lms_wr_addr),
        .wr_data  (lms_wr_data),
        .lms_done (lms_done)
    );

    assign y_out   = e_n;
    assign y_valid = e_valid;

endmodule
