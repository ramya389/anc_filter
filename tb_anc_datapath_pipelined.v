`timescale 1ns/1ps

`include "anc_datapath_pipelined.v"

module tb_anc_datapath_pipelined;

    reg clk;
    reg rst_n;
    reg sample_valid;
    reg [7:0] mu;
    reg signed [15:0] ref_noise_in;
    reg signed [15:0] primary_in;

    wire signed [15:0] y_out;
    wire y_valid;

    // DUT
    anc_datapath_pipelined dut (
        .clk(clk),
        .rst_n(rst_n),
        .sample_valid(sample_valid),
        .mu(mu),
        .ref_noise_in(ref_noise_in),
        .primary_in(primary_in),
        .y_out(y_out),
        .y_valid(y_valid)
    );

    // Clock generation
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;   // 10 ns clock period
    end

    // Task to apply one valid input sample
    task send_sample;
        input signed [15:0] ref_s;
        input signed [15:0] pri_s;
        begin
            @(negedge clk);
            sample_valid = 1'b1;
            ref_noise_in = ref_s;
            primary_in   = pri_s;
        end
    endtask

    // Task to insert idle cycle
    task send_idle;
        begin
            @(negedge clk);
            sample_valid = 1'b0;
            ref_noise_in = 16'sd0;
            primary_in   = 16'sd0;
        end
    endtask

    initial begin
        // dump for waveform
        $dumpfile("tb_anc_datapath_pipelined.vcd");
        $dumpvars(0, tb_anc_datapath_pipelined);

        // initialization
        rst_n         = 1'b0;
        sample_valid  = 1'b0;
        mu            = 8'd4;
        ref_noise_in  = 16'sd0;
        primary_in    = 16'sd0;

        // reset
        repeat(5) @(posedge clk);
        rst_n = 1'b1;

        // -------------------------------------------------
        // Test 1: same first sample as original design
        // Expected initial output after pipeline latency:
        // n_hat = 0, so y_out = primary_in = 200
        // -------------------------------------------------
        send_sample(16'sd100, 16'sd200);
        send_idle();

        // -------------------------------------------------
        // More test samples
        // -------------------------------------------------
        send_sample(16'sd100, 16'sd200);
        send_sample(-16'sd100, 16'sd200);
        send_sample(16'sd50, 16'sd150);
        send_sample(-16'sd75, 16'sd125);
        send_sample(16'sd120, 16'sd220);
        send_sample(-16'sd60, 16'sd180);
        send_sample(16'sd30, 16'sd130);
        send_sample(-16'sd20, 16'sd100);

        // stop driving inputs
        send_idle();
        send_idle();
        send_idle();
        send_idle();
        send_idle();
        send_idle();
        send_idle();
        send_idle();
        send_idle();
        send_idle();

        $finish;
    end

    // Monitor outputs
    always @(posedge clk) begin
        if (y_valid) begin
            $display("TIME=%0t | ref=%0d | primary=%0d | y_out=%0d",
                     $time, $signed(ref_noise_in), $signed(primary_in), $signed(y_out));
        end
    end

endmodule
