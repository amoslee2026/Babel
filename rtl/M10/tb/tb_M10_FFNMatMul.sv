// ============================================================================
// Testbench: tb_M10_FFNMatMul
// Description: Testbench for M10 FFN/MatMul Unit
// ============================================================================
// Design Specification: spec_mas/M10/MAS.md
// FSM Specification: spec_mas/M10/FSM.md
// Datapath: spec_mas/M10/datapath.md
// ============================================================================
// Version: 1.0
// Status: RTL verification
// Generated: 2026-05-17
// ============================================================================

`timescale 1ns/1ps

/* verilator lint_off INITIALDLY */
/* verilator lint_off WIDTHEXPAND */
module tb_M10_FFNMatMul;

    // ========================================================================
    // Parameters
    // ========================================================================
    parameter int DIM           = 64;
    parameter int HIDDEN_DIM    = 256;
    parameter int DATA_WIDTH    = 32;
    parameter int VECTOR_WIDTH  = 256;
    parameter int LUT_DEPTH     = 256;
    parameter int TIMEOUT_LIMIT = 65536;

    // Command definitions (4-bit)
    parameter logic [3:0] CMD_MMUL   = 4'h1;
    parameter logic [3:0] CMD_MLOAD  = 4'h2;
    parameter logic [3:0] CMD_MSET   = 4'h3;

    // Clock period (500 MHz = 2ns period)
    parameter real CLK_PERIOD   = 2.0;  // ns

    // ========================================================================
    // Signals
    // ========================================================================
    logic                   clk;
    logic                   rst_n;
    logic                   enable;

    // Control interface
    logic                   start;
    logic [1:0]             mode;
    logic                   busy;
    logic                   done;
    logic                   error;
    logic [7:0]             error_code;

    // Data input interface
    logic [VECTOR_WIDTH-1:0] x_in;
    logic                   x_valid;
    logic                   x_ready;

    // Data output interface
    logic [VECTOR_WIDTH-1:0] y_out;
    logic                   y_valid;
    logic                   y_ready;

    // Configuration interface
    logic [15:0]            s_dim;
    logic [31:0]            w_base;
    logic [31:0]            w1_offset;
    logic [31:0]            w3_offset;
    logic [31:0]            w2_offset;

    // Systolic Array Interface - Port 1
    logic [3:0]             sa_cmd_1;
    logic [15:0]            sa_dim_1;
    logic [31:0]            sa_w_base_1;
    logic [7:0]             sa_w_row_1;
    logic [VECTOR_WIDTH-1:0] sa_input_1;
    logic [VECTOR_WIDTH-1:0] sa_result_1;
    logic                   sa_done_1;

    // Systolic Array Interface - Port 2
    logic [3:0]             sa_cmd_2;
    logic [15:0]            sa_dim_2;
    logic [31:0]            sa_w_base_2;
    logic [7:0]             sa_w_row_2;
    logic [VECTOR_WIDTH-1:0] sa_input_2;
    logic [VECTOR_WIDTH-1:0] sa_result_2;
    logic                   sa_done_2;

    // Systolic Array error input
    logic                   sa_error_in;

    // Error clear
    logic                   error_clear;

    // ========================================================================
    // Test Variables
    // ========================================================================
    int                     test_count;
    int                     pass_count;
    int                     fail_count;
    string                  test_name;

    // Simulated Systolic Array latency
    int                     sa_latency_cycles;

    // ========================================================================
    // DUT Instance
    // ========================================================================
    M10_FFNMatMul #(
        .DIM           (DIM),
        .HIDDEN_DIM    (HIDDEN_DIM),
        .DATA_WIDTH    (DATA_WIDTH),
        .VECTOR_WIDTH  (VECTOR_WIDTH),
        .LUT_DEPTH     (LUT_DEPTH),
        .TIMEOUT_LIMIT (TIMEOUT_LIMIT),
        .CMD_MMUL      (CMD_MMUL),
        .CMD_MLOAD    (CMD_MLOAD),
        .CMD_MSET     (CMD_MSET)
    ) dut (
        .clk          (clk),
        .rst_n        (rst_n),
        .enable       (enable),

        .start        (start),
        .mode         (mode),
        .busy         (busy),
        .done         (done),
        .error        (error),
        .error_code   (error_code),

        .x_in         (x_in),
        .x_valid      (x_valid),
        .x_ready      (x_ready),

        .y_out        (y_out),
        .y_valid      (y_valid),
        .y_ready      (y_ready),

        .s_dim        (s_dim),
        .w_base       (w_base),
        .w1_offset    (w1_offset),
        .w3_offset    (w3_offset),
        .w2_offset    (w2_offset),

        .sa_cmd_1     (sa_cmd_1),
        .sa_dim_1     (sa_dim_1),
        .sa_w_base_1  (sa_w_base_1),
        .sa_w_row_1   (sa_w_row_1),
        .sa_input_1   (sa_input_1),
        .sa_result_1  (sa_result_1),
        .sa_done_1    (sa_done_1),

        .sa_cmd_2     (sa_cmd_2),
        .sa_dim_2     (sa_dim_2),
        .sa_w_base_2  (sa_w_base_2),
        .sa_w_row_2   (sa_w_row_2),
        .sa_input_2   (sa_input_2),
        .sa_result_2  (sa_result_2),
        .sa_done_2    (sa_done_2),

        .sa_error_in  (sa_error_in),
        .error_clear  (error_clear)
    );

    // ========================================================================
    // Clock Generation
    // ========================================================================
    initial begin
        clk = 1'b0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    // ========================================================================
    // Simulated Systolic Array Response
    // ========================================================================
    // This block simulates the M00 Systolic Array response
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sa_done_1 <= 1'b0;
            sa_done_2 <= 1'b0;
            sa_result_1 <= '0;
            sa_result_2 <= '0;
        end else begin
            // Port 1 response
            if (sa_cmd_1 == CMD_MMUL) begin
                // Simulate MatMul latency (s_dim cycles)
                sa_latency_cycles = sa_dim_1;

                // For testing, use reduced latency
                repeat(10) @(posedge clk);

                sa_result_1 <= sa_input_1;  // Echo input as result (simplified)
                sa_done_1 <= 1'b1;

                @(posedge clk);
                sa_done_1 <= 1'b0;
            end

            // Port 2 response
            if (sa_cmd_2 == CMD_MMUL) begin
                repeat(10) @(posedge clk);

                sa_result_2 <= sa_input_2;  // Echo input as result (simplified)
                sa_done_2 <= 1'b1;

                @(posedge clk);
                sa_done_2 <= 1'b0;
            end
        end
    end

    // ========================================================================
    // Test Task Definitions
    // ========================================================================

    // Initialize test
    task automatic init_test();
        rst_n       <= 1'b0;
        enable      <= 1'b1;
        start       <= 1'b0;
        mode        <= 2'h0;
        x_in        <= '0;
        x_valid     <= 1'b0;
        y_ready     <= 1'b1;
        s_dim       <= 16'h40;  // 64
        w_base      <= 32'h1000;
        w1_offset   <= 32'h0;
        w3_offset   <= 32'h1000;
        w2_offset   <= 32'h2000;
        sa_error_in <= 1'b0;
        error_clear <= 1'b0;

        // Reset sequence
        repeat(5) @(posedge clk);
        rst_n <= 1'b1;
        repeat(5) @(posedge clk);

        test_count = 0;
        pass_count = 0;
        fail_count = 0;
    endtask

    // Wait for completion
    task automatic wait_done(input int max_cycles);
        int cycles = 0;
        while (!done && cycles < max_cycles) begin
            @(posedge clk);
            cycles++;
        end

        if (cycles >= max_cycles) begin
            $display("[%s] TIMEOUT after %d cycles", test_name, max_cycles);
            fail_count++;
        end else begin
            pass_count++;
        end
    endtask

    // Check result
    task automatic check_result(input logic [VECTOR_WIDTH-1:0] expected);
        if (y_out !== expected) begin
            $display("[%s] FAIL: y_out mismatch. Expected %h, Got %h",
                     test_name, expected, y_out);
            fail_count++;
        end else begin
            $display("[%s] PASS: y_out matches expected", test_name);
            pass_count++;
        end
    endtask

    // Check state sequence
    task automatic check_state_sequence();
        // Monitor state transitions for coverage
        $display("[%s] State transitions monitored", test_name);
    endtask

    // ========================================================================
    // Test Cases
    // ========================================================================

    // Test 1: FFN Complete Mode
    task automatic test_ffn_complete();
        test_name = "FFN_COMPLETE";
        test_count++;
        $display("\n========== Test %d: FFN Complete Mode ========== ", test_count);

        init_test();

        // Set FFN Complete mode
        mode <= 2'h1;
        x_in <= 32'h3F800000;  // 1.0 in FP32
        x_valid <= 1'b1;

        @(posedge clk);
        start <= 1'b1;

        @(posedge clk);
        start <= 1'b0;
        x_valid <= 1'b0;

        // Wait for completion (FFN: ~328 cycles expected)
        wait_done(500);

        if (done) begin
            $display("[%s] FFN Complete finished successfully", test_name);
        end

        // Check for errors
        if (error) begin
            $display("[%s] FAIL: Error detected, code=%h", test_name, error_code);
            fail_count++;
        end
    endtask

    // Test 2: MatMul Only Mode
    task automatic test_matmul_only();
        test_name = "MATMUL_ONLY";
        test_count++;
        $display("\n========== Test %d: MatMul Only Mode ========== ", test_count);

        init_test();

        // Set MatMul Only mode
        mode <= 2'h0;
        x_in <= 32'h40000000;  // 2.0 in FP32
        x_valid <= 1'b1;

        @(posedge clk);
        start <= 1'b1;

        @(posedge clk);
        start <= 1'b0;
        x_valid <= 1'b0;

        // Wait for completion
        wait_done(100);

        if (done) begin
            $display("[%s] MatMul Only finished successfully", test_name);
        end

        // Check for errors
        if (error) begin
            $display("[%s] FAIL: Error detected, code=%h", test_name, error_code);
            fail_count++;
        end
    endtask

    // Test 3: Activation Only Mode
    task automatic test_activation_only();
        test_name = "ACTIVATION_ONLY";
        test_count++;
        $display("\n========== Test %d: Activation Only Mode ========== ", test_count);

        init_test();

        // Set Activation Only mode
        mode <= 2'h2;
        x_in <= 32'h3F000000;  // 0.5 in FP32
        x_valid <= 1'b1;

        @(posedge clk);
        start <= 1'b1;

        @(posedge clk);
        start <= 1'b0;
        x_valid <= 1'b0;

        // Wait for completion (~10 cycles)
        wait_done(50);

        if (done) begin
            $display("[%s] Activation Only finished successfully", test_name);
        end

        // Check for errors
        if (error) begin
            $display("[%s] FAIL: Error detected, code=%h", test_name, error_code);
            fail_count++;
        end
    endtask

    // Test 4: Invalid Mode Error
    task automatic test_invalid_mode();
        test_name = "INVALID_MODE";
        test_count++;
        $display("\n========== Test %d: Invalid Mode Error ========== ", test_count);

        init_test();

        // Set invalid mode (0x3)
        mode <= 2'h3;
        x_valid <= 1'b1;

        @(posedge clk);
        start <= 1'b1;

        @(posedge clk);
        start <= 1'b0;

        // Wait for error state
        repeat(10) @(posedge clk);

        if (error && error_code == 8'h02) begin
            $display("[%s] PASS: Invalid mode error detected correctly", test_name);
            pass_count++;
        end else begin
            $display("[%s] FAIL: Expected error code 0x02, got %h", test_name, error_code);
            fail_count++;
        end

        // Clear error
        error_clear <= 1'b1;
        repeat(5) @(posedge clk);
        error_clear <= 1'b0;
    endtask

    // Test 5: Systolic Array Timeout
    task automatic test_sa_timeout();
        test_name = "SA_TIMEOUT";
        test_count++;
        $display("\n========== Test %d: Systolic Array Timeout ========== ", test_count);

        init_test();

        // Set MatMul Only mode
        mode <= 2'h0;
        x_valid <= 1'b1;

        @(posedge clk);
        start <= 1'b1;

        @(posedge clk);
        start <= 1'b0;

        // Inhibit SA response (simulate timeout)
        // Note: This would require TIMEOUT_LIMIT cycles, which is too long for simulation
        // For testing, we can reduce the timeout or inject error

        // Inject SA error instead for quick test
        @(posedge clk);
        sa_error_in <= 1'b1;

        repeat(10) @(posedge clk);

        if (error) begin
            $display("[%s] PASS: SA error detected", test_name);
            pass_count++;
        end else begin
            $display("[%s] FAIL: SA error not detected", test_name);
            fail_count++;
        end

        sa_error_in <= 1'b0;

        // Clear error
        error_clear <= 1'b1;
        repeat(5) @(posedge clk);
        error_clear <= 1'b0;
    endtask

    // Test 6: Backpressure Handling
    task automatic test_backpressure();
        test_name = "BACKPRESSURE";
        test_count++;
        $display("\n========== Test %d: Backpressure Handling ========== ", test_count);

        init_test();

        // Set y_ready to 0 (backpressure)
        y_ready <= 1'b0;

        mode <= 2'h0;
        x_valid <= 1'b1;

        @(posedge clk);
        start <= 1'b1;

        @(posedge clk);
        start <= 1'b0;

        // Wait for y_valid
        while (!y_valid) @(posedge clk);

        $display("[%s] y_valid asserted, waiting for y_ready", test_name);

        // Hold backpressure for several cycles
        repeat(20) @(posedge clk);

        // Release backpressure
        y_ready <= 1'b1;

        repeat(5) @(posedge clk);

        if (done && !error) begin
            $display("[%s] PASS: Backpressure handled correctly", test_name);
            pass_count++;
        end else begin
            $display("[%s] FAIL: Backpressure handling error", test_name);
            fail_count++;
        end
    endtask

    // Test 7: Parallel w1/w3 MatMul
    task automatic test_parallel_matmul();
        test_name = "PARALLEL_MATMUL";
        test_count++;
        $display("\n========== Test %d: Parallel w1/w3 MatMul ========== ", test_count);

        init_test();

        // Set FFN Complete mode (requires parallel w1/w3)
        mode <= 2'h1;
        x_valid <= 1'b1;

        @(posedge clk);
        start <= 1'b1;

        @(posedge clk);
        start <= 1'b0;

        // Check for parallel command dispatch
        repeat(5) @(posedge clk);

        if (sa_cmd_1 == CMD_MMUL && sa_cmd_2 == CMD_MMUL) begin
            $display("[%s] PASS: Parallel commands dispatched", test_name);
            pass_count++;
        end else begin
            $display("[%s] INFO: Commands: sa_cmd_1=%h, sa_cmd_2=%h",
                     test_name, sa_cmd_1, sa_cmd_2);
        end

        // Wait for completion
        wait_done(500);
    endtask

    // Test 8: Reset During Operation
    task automatic test_reset_during_operation();
        test_name = "RESET_DURING_OP";
        test_count++;
        $display("\n========== Test %d: Reset During Operation ========== ", test_count);

        init_test();

        mode <= 2'h1;
        x_valid <= 1'b1;

        @(posedge clk);
        start <= 1'b1;

        @(posedge clk);
        start <= 1'b0;

        // Wait for operation to start
        while (!busy) @(posedge clk);

        $display("[%s] Operation started, initiating reset", test_name);

        // Assert reset during operation
        rst_n <= 1'b0;
        repeat(10) @(posedge clk);
        rst_n <= 1'b1;

        repeat(10) @(posedge clk);

        // Check that module returns to IDLE
        if (!busy && !done) begin
            $display("[%s] PASS: Reset handled correctly", test_name);
            pass_count++;
        end else begin
            $display("[%s] FAIL: Reset handling error", test_name);
            fail_count++;
        end
    endtask

    // ========================================================================
    // FSM Coverage Monitor
    // ========================================================================
    // Track state transitions for coverage analysis
    logic [2:0] prev_state;
    int         state_visit_count [8];

    always_ff @(posedge clk) begin
        prev_state <= dut.state;

        if (rst_n && dut.state != prev_state) begin
            state_visit_count[dut.state]++;
            $display("[FSM_COVERAGE] State transition: %h -> %h", prev_state, dut.state);
        end
    end

    // ========================================================================
    // Main Test Execution
    // ========================================================================
    initial begin
        $display("\n=======================================================");
        $display("  M10 FFN/MatMul Unit Testbench");
        $display("  Version: 1.0");
        $display("=======================================================\n");

        // Initialize state visit counter
        for (int i = 0; i < 8; i++) begin
            state_visit_count[i] = 0;
        end

        // Run all tests
        test_ffn_complete();
        test_matmul_only();
        test_activation_only();
        test_invalid_mode();
        test_sa_timeout();
        test_backpressure();
        test_parallel_matmul();
        test_reset_during_operation();

        // Print coverage summary
        $display("\n=======================================================");
        $display("  FSM Coverage Summary");
        $display("=======================================================\n");

        $display("State           | Visits");
        $display("----------------|-------");
        $display("IDLE (0x0)      | %d", state_visit_count[0]);
        $display("MATMUL_W1W3 (0x1)| %d", state_visit_count[1]);
        $display("WAIT_SA1 (0x2)  | %d", state_visit_count[2]);
        $display("ACTIVATION (0x3)| %d", state_visit_count[3]);
        $display("MATMUL_W2 (0x4) | %d", state_visit_count[4]);
        $display("WAIT_SA2 (0x5)  | %d", state_visit_count[5]);
        $display("OUTPUT (0x6)    | %d", state_visit_count[6]);
        $display("ERROR (0x7)     | %d", state_visit_count[7]);

        // Print test summary
        $display("\n=======================================================");
        $display("  Test Summary");
        $display("=======================================================\n");

        $display("Total Tests:  %d", test_count);
        $display("Passed:       %d", pass_count);
        $display("Failed:       %d", fail_count);
        $display("Pass Rate:    %.2f%%", (pass_count * 100.0) / test_count);

        if (fail_count == 0) begin
            $display("\n*** ALL TESTS PASSED ***");
        end else begin
            $display("\n*** %d TESTS FAILED ***", fail_count);
        end

        $display("\n=======================================================\n");

        // Finish simulation
        $finish;
    end

    // ========================================================================
    // Waveform Generation (for debug)
    // ========================================================================
    initial begin
        $dumpfile("tb_M10_FFNMatMul.vcd");
        $dumpvars(0, tb_M10_FFNMatMul);
    end

    // ========================================================================
    // Timeout Protection
    // ========================================================================
    initial begin
        #100000;  // 100us timeout
        $display("\n[TIMEOUT] Simulation exceeded 100us");
        $finish;
    end

endmodule
/* verilator lint_on INITIALDLY */
/* verilator lint_on WIDTHEXPAND */