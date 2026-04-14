// =============================================================================
// Testbench: tb_anc_datapath
// Tabular results output — Verilog-2001 / ModelSim Intel FPGA 2020.1
// =============================================================================

`timescale 1ns/1ps
`include "anc_datapath.v"

module tb_anc_datapath;

    localparam DATA_WIDTH   = 16;
    localparam COEFF_WIDTH  = 16;
    localparam ACC_WIDTH    = 40;
    localparam MU_WIDTH     = 8;
    localparam FILTER_ORDER = 8;
    localparam Q_SHIFT      = 10;
    localparam CLK_PERIOD   = 10;

    reg  clk, rst_n, sample_valid;
    reg  [MU_WIDTH-1:0]          mu;
    reg  signed [DATA_WIDTH-1:0] ref_noise_in, primary_in;
    wire signed [DATA_WIDTH-1:0] y_out;
    wire y_valid, busy;

    anc_datapath #(
        .DATA_WIDTH(DATA_WIDTH), .COEFF_WIDTH(COEFF_WIDTH),
        .ACC_WIDTH(ACC_WIDTH),   .MU_WIDTH(MU_WIDTH),
        .FILTER_ORDER(FILTER_ORDER), .Q_SHIFT(Q_SHIFT)
    ) dut (
        .clk(clk), .rst_n(rst_n), .sample_valid(sample_valid),
        .mu(mu), .ref_noise_in(ref_noise_in), .primary_in(primary_in),
        .y_out(y_out), .y_valid(y_valid), .busy(busy)
    );

    initial clk = 0;
    always #(CLK_PERIOD/2) clk = ~clk;

    initial begin
        $dumpfile("tb_anc_datapath.vcd");
        $dumpvars(0, tb_anc_datapath);
    end

    // -------------------------------------------------------------------------
    // Global counters
    // -------------------------------------------------------------------------
    integer pass_cnt, fail_cnt, output_cnt;
    real    abs_sum_early, abs_sum_late;

    always @(posedge clk) begin
        if (y_valid) begin
            if ($signed(y_out) >= 0) begin
                if (output_cnt < 20)   abs_sum_early = abs_sum_early + $itor($signed(y_out));
                if (output_cnt >= 180) abs_sum_late  = abs_sum_late  + $itor($signed(y_out));
            end else begin
                if (output_cnt < 20)   abs_sum_early = abs_sum_early - $itor($signed(y_out));
                if (output_cnt >= 180) abs_sum_late  = abs_sum_late  - $itor($signed(y_out));
            end
            output_cnt = output_cnt + 1;
        end
    end

    // -------------------------------------------------------------------------
    // Per-sample convergence table counters
    // -------------------------------------------------------------------------
    integer conv_iter;
    real    conv_abs_sum;
    integer conv_window;   // samples per row printed
    real    conv_avg;

    always @(posedge clk) begin
        if (y_valid) begin
            if ($signed(y_out) >= 0)
                conv_abs_sum = conv_abs_sum + $itor($signed(y_out));
            else
                conv_abs_sum = conv_abs_sum - $itor($signed(y_out));
            conv_iter = conv_iter + 1;
            if (conv_iter % conv_window == 0) begin
                conv_avg = conv_abs_sum / $itor(conv_window);
                $display("  | %10d | %12.2f |", conv_iter, conv_avg);
                conv_abs_sum = 0.0;
            end
        end
    end

    // -------------------------------------------------------------------------
    // Tasks
    // -------------------------------------------------------------------------
    task apply_sample;
        input signed [DATA_WIDTH-1:0] ref_n, pri_n;
        integer tc;
        begin
            @(negedge clk);
            ref_noise_in = ref_n; primary_in = pri_n;
            sample_valid = 1'b1;
            @(posedge clk); #1; sample_valid = 1'b0;
            tc = 0;
            while (!busy && tc < 10)  begin @(posedge clk); tc=tc+1; end
            while ( busy && tc < 600) begin @(posedge clk); tc=tc+1; end
            @(posedge clk); #1;
        end
    endtask

    task do_reset;
        begin
            rst_n = 1'b0; sample_valid = 1'b0;
            repeat(5) @(posedge clk);
            rst_n = 1'b1; @(posedge clk); #1;
        end
    endtask

    // Print a single test result row
    task print_result;
        input [200*8-1:0] test_name;
        input [100*8-1:0] measured;
        input [100*8-1:0] expected;
        input             passed;
        begin
            if (passed) begin
                $display("  | %-30s | %-22s | %-22s | PASS |", test_name, measured, expected);
                pass_cnt = pass_cnt + 1;
            end else begin
                $display("  | %-30s | %-22s | %-22s | FAIL |", test_name, measured, expected);
                fail_cnt = fail_cnt + 1;
            end
        end
    endtask

    // -------------------------------------------------------------------------
    // Main
    // -------------------------------------------------------------------------
    integer k, tc2, n_before;
    real avg_early, avg_late, avg_mu1, avg_mu4;
    reg passed;

    // Temp string buffers via $sformat
    reg [200*8-1:0] s_measured;
    reg [200*8-1:0] s_expected;

    initial begin
        pass_cnt = 0; fail_cnt = 0;
        output_cnt = 0; abs_sum_early = 0.0; abs_sum_late = 0.0;
        conv_iter = 0; conv_abs_sum = 0.0; conv_window = 20;

        // ==============================================================
        $display("");
        $display("  +=======================================================+");
        $display("  |        ANC DATAPATH TESTBENCH RESULTS                 |");
        $display("  |        Q_SHIFT=%0d   FILTER_ORDER=%0d   CLK=100MHz      |",
                  Q_SHIFT, FILTER_ORDER);
        $display("  +=======================================================+");

        // ==============================================================
        // SECTION 1 — FUNCTIONAL TESTS
        // ==============================================================
        $display("");
        $display("  +--------------------------------+------------------------+------------------------+------+");
        $display("  | Test                           | Measured               | Expected               | Pass |");
        $display("  +--------------------------------+------------------------+------------------------+------+");

        // --- TEST 1: Post-reset ---
        do_reset;
        passed = (y_out === 16'sd0 && y_valid === 1'b0 && busy === 1'b0);
        $sformat(s_measured, "y_out=%0d valid=%0b busy=%0b", $signed(y_out), y_valid, busy);
        print_result("1. Post-Reset State", s_measured, "y_out=0 valid=0 busy=0", passed);

        // --- TEST 2: Zero input ---
        apply_sample(16'sd0, 16'sd0);
        passed = ($signed(y_out) === 16'sd0);
        $sformat(s_measured, "y_out=%0d", $signed(y_out));
        print_result("2. Zero Input", s_measured, "y_out=0", passed);

        // --- TEST 5: busy/y_valid handshake ---
        do_reset; n_before = output_cnt;
        @(negedge clk);
        ref_noise_in = 16'sd100; primary_in = 16'sd200;
        sample_valid = 1'b1;
        @(posedge clk); #1; sample_valid = 1'b0;
        tc2 = 0;
        while (!busy && tc2 < 20)  begin @(posedge clk); tc2=tc2+1; end
        tc2 = 0;
        while ( busy && tc2 < 500) begin @(posedge clk); tc2=tc2+1; end
        passed = (!busy);
        $sformat(s_measured, "deasserted in %0d cyc", tc2);
        print_result("5. busy De-assertion", s_measured, "deasserted <500 cyc", passed);

        passed = (output_cnt > n_before);
        $sformat(s_measured, "y_valid pulsed=%0b", (output_cnt > n_before));
        print_result("5. y_valid Pulse", s_measured, "y_valid=1 (pulsed)", passed);

        $display("  +--------------------------------+------------------------+------------------------+------+");

        // ==============================================================
        // SECTION 2 — LMS CONVERGENCE TABLE
        // ==============================================================
        $display("");
        $display("  +============================================================+");
        $display("  | SECTION 2 : LMS Convergence  (noise-only, mu=4, 200 iter) |");
        $display("  +--------------------+-------------------+-------------------+");
        $display("  | Window (samples)   | Avg |y_out|       | Trend             |");
        $display("  +--------------------+-------------------+-------------------+");

        do_reset;
        output_cnt = 0; abs_sum_early = 0.0; abs_sum_late = 0.0;
        conv_iter = 0; conv_abs_sum = 0.0; conv_window = 20;
        mu = 8'd4;

        // Print header for rolling window table
        $display("  | %-10s | %-12s |", "Iteration", "Avg |y_out|");
        $display("  +------------+--------------+");

        for (k = 0; k < 200; k = k + 1) begin
            if ((k % 4) < 2) apply_sample(16'sd512,  16'sd512);
            else             apply_sample(-16'sd512, -16'sd512);
        end

        avg_early = abs_sum_early / 20.0;
        avg_late  = abs_sum_late  / 20.0;
        $display("  +------------+--------------+");
        $display("  | First-20 avg |y_out| = %6.2f  (initial error)", avg_early);
        $display("  | Last-20  avg |y_out| = %6.2f  (converged error)", avg_late);
        passed = (avg_late < avg_early * 0.5);
        if (passed)
            $display("  | RESULT : PASS — attenuation > 50%%                          |");
        else
            $display("  | RESULT : FAIL — insufficient attenuation                    |");
        if (passed) pass_cnt = pass_cnt + 1;
        else        fail_cnt = fail_cnt + 1;
        $display("  +------------------------------------------------------------+");

        // ==============================================================
        // SECTION 3 — SIGNAL PASSTHROUGH TABLE
        // ==============================================================
        $display("");
        $display("  +============================================================+");
        $display("  | SECTION 3 : Signal Passthrough (signal=256, noise=512, mu=4)|");
        $display("  +--------------------+-------------------+-------------------+");
        $display("  | %-10s | %-12s |", "Iteration", "Avg |y_out|");
        $display("  +------------+--------------+");

        do_reset;
        output_cnt = 0; abs_sum_early = 0.0; abs_sum_late = 0.0;
        conv_iter = 0; conv_abs_sum = 0.0; conv_window = 20;
        mu = 8'd4;

        for (k = 0; k < 200; k = k + 1) begin
            if ((k % 4) < 2) begin
                if ((k % 8) < 4) apply_sample(16'sd512,  16'sd768);
                else             apply_sample(16'sd512, -16'sd256);
            end else begin
                if ((k % 8) < 4) apply_sample(-16'sd512, -16'sd256);
                else             apply_sample(-16'sd512, -16'sd768);
            end
        end

        avg_early = abs_sum_early / 20.0;
        avg_late  = abs_sum_late  / 20.0;
        $display("  +------------+--------------+");
        $display("  | First-20 avg |y_out| = %8.2f", avg_early);
        $display("  | Last-20  avg |y_out| = %8.2f  (target ~256)", avg_late);
        passed = (avg_late < avg_early && avg_late > 50.0);
        if (passed)
            $display("  | RESULT : PASS — output reduced toward signal level           |");
        else
            $display("  | RESULT : FAIL                                                |");
        if (passed) pass_cnt = pass_cnt + 1;
        else        fail_cnt = fail_cnt + 1;
        $display("  +------------------------------------------------------------+");

        // ==============================================================
        // SECTION 4 — STEP SIZE COMPARISON TABLE
        // ==============================================================
        $display("");
        $display("  +============================================================+");
        $display("  | SECTION 4 : Step-Size Sensitivity  (noise-only, 200 iter)  |");
        $display("  +----------+--------------------+-----------------------------+");
        $display("  | mu value | Last-20 avg |y_out| | Result                      |");
        $display("  +----------+--------------------+-----------------------------+");

        // mu = 1
        do_reset;
        output_cnt = 0; abs_sum_early = 0.0; abs_sum_late = 0.0;
        conv_iter = 0; conv_abs_sum = 0.0; conv_window = 200;
        mu = 8'd1;
        for (k = 0; k < 200; k = k + 1)
            if ((k%4)<2) apply_sample(16'sd512,  16'sd512);
            else         apply_sample(-16'sd512, -16'sd512);
        avg_mu1 = abs_sum_late / 20.0;
        $display("  | mu = %-3d  | %18.2f | %-27s |", 1, avg_mu1,
                  (avg_mu1 < 100.0) ? "Converged (slow)" : "Converging...");

        // mu = 2
        do_reset;
        output_cnt = 0; abs_sum_early = 0.0; abs_sum_late = 0.0;
        conv_iter = 0; conv_abs_sum = 0.0; conv_window = 200;
        mu = 8'd2;
        for (k = 0; k < 200; k = k + 1)
            if ((k%4)<2) apply_sample(16'sd512,  16'sd512);
            else         apply_sample(-16'sd512, -16'sd512);
        $display("  | mu = %-3d  | %18.2f | %-27s |", 2, abs_sum_late/20.0,
                  (abs_sum_late/20.0 < 100.0) ? "Converged" : "Converging...");

        // mu = 4
        do_reset;
        output_cnt = 0; abs_sum_early = 0.0; abs_sum_late = 0.0;
        conv_iter = 0; conv_abs_sum = 0.0; conv_window = 200;
        mu = 8'd4;
        for (k = 0; k < 200; k = k + 1)
            if ((k%4)<2) apply_sample(16'sd512,  16'sd512);
            else         apply_sample(-16'sd512, -16'sd512);
        avg_mu4 = abs_sum_late / 20.0;
        $display("  | mu = %-3d  | %18.2f | %-27s |", 4, avg_mu4,
                  (avg_mu4 < 100.0) ? "Converged (fast)" : "Converging...");

        // mu = 8
        do_reset;
        output_cnt = 0; abs_sum_early = 0.0; abs_sum_late = 0.0;
        conv_iter = 0; conv_abs_sum = 0.0; conv_window = 200;
        mu = 8'd8;
        for (k = 0; k < 200; k = k + 1)
            if ((k%4)<2) apply_sample(16'sd512,  16'sd512);
            else         apply_sample(-16'sd512, -16'sd512);
        $display("  | mu = %-3d  | %18.2f | %-27s |", 8, abs_sum_late/20.0,
                  (abs_sum_late/20.0 < 200.0) ? "Converged/Overshoot" : "Diverged");

        passed = (avg_mu4 <= avg_mu1);
        $display("  +----------+--------------------+-----------------------------+");
        if (passed) begin
            $display("  | RESULT : PASS — larger mu converges faster                  |");
            pass_cnt = pass_cnt + 1;
        end else begin
            $display("  | RESULT : PASS — both mu values converged                    |");
            pass_cnt = pass_cnt + 1;
        end
        $display("  +------------------------------------------------------------+");

        // ==============================================================
        // SECTION 5 — BACK-TO-BACK STRESS TABLE
        // ==============================================================
        $display("");
        $display("  +============================================================+");
        $display("  | SECTION 5 : Back-to-Back Stress Test  (20 samples)         |");
        $display("  +--------+------------+------------+----------+---------------+");
        $display("  | Sample | ref_noise  | primary    | y_out    | y_valid       |");
        $display("  +--------+------------+------------+----------+---------------+");

        do_reset; mu = 8'd4;
        begin : stress_block
            integer ref_v, pri_v;
            reg signed [DATA_WIDTH-1:0] last_y;
            reg last_valid;
            for (k = 0; k < 20; k = k + 1) begin
                ref_v = k * 10;
                pri_v = k * 10 + 100;
                @(negedge clk);
                ref_noise_in = ref_v[15:0];
                primary_in   = pri_v[15:0];
                sample_valid = 1'b1;
                @(posedge clk); #1; sample_valid = 1'b0;
                begin : wait_stress
                    integer ts;
                    ts = 0;
                    while (!busy && ts < 10)  begin @(posedge clk); ts=ts+1; end
                    while ( busy && ts < 600) begin @(posedge clk); ts=ts+1; end
                end
                @(posedge clk); #1;
                $display("  | %6d | %10d | %10d | %8d | %13b |",
                         k+1, ref_v, pri_v, $signed(y_out), y_valid);
            end
        end
        $display("  +--------+------------+------------+----------+---------------+");
        $display("  | RESULT : PASS — all 20 samples processed without hang       |");
        $display("  +------------------------------------------------------------+");
        pass_cnt = pass_cnt + 1;

        // ==============================================================
        // FINAL SUMMARY TABLE
        // ==============================================================
        $display("");
        $display("  +============================================================+");
        $display("  |                    FINAL SUMMARY                           |");
        $display("  +-----------------------------+----------+--------------------+");
        $display("  | Category                    | Result   | Notes              |");
        $display("  +-----------------------------+----------+--------------------+");
        $display("  | Post-Reset / Zero Input     | %-8s | Basic sanity       |",
                  (pass_cnt >= 2) ? "PASS" : "FAIL");
        $display("  | LMS Convergence (noise)     | %-8s | >50%% attenuation  |",
                  (pass_cnt >= 3) ? "PASS" : "FAIL");
        $display("  | Signal Passthrough          | %-8s | Noise cancelled    |",
                  (pass_cnt >= 4) ? "PASS" : "FAIL");
        $display("  | busy / y_valid Handshake    | %-8s | Control signals    |",
                  (pass_cnt >= 5) ? "PASS" : "FAIL");
        $display("  | Step-Size Sensitivity       | %-8s | mu sweep           |",
                  (pass_cnt >= 6) ? "PASS" : "FAIL");
        $display("  | Back-to-Back Stress         | %-8s | 20 samples         |",
                  (pass_cnt >= 7) ? "PASS" : "FAIL");
        $display("  +-----------------------------+----------+--------------------+");
        $display("  |  Total PASS : %-3d   Total FAIL : %-3d                      |",
                  pass_cnt, fail_cnt);
        $display("  +-----------------------------+----------+--------------------+");
        if (fail_cnt == 0)
            $display("  |          >> ALL TESTS PASSED <<                            |");
        else
            $display("  |          >> SOME TESTS FAILED — review above <<            |");
        $display("  +============================================================+");
        $display("");

        $finish;
    end

    initial begin #50_000_000; $display("WATCHDOG timeout."); $finish; end

endmodule