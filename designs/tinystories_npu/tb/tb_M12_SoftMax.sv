//=============================================================================
// Testbench: M12_SoftMax
// Cycle-based testbench for Verilator coverage collection
//-----------------------------------------------------------------------------

module tb_M12_SoftMax (
    input logic clk_sys_ext  // External clock from C++
);

    //=========================================================================
    // Signals
    //=========================================================================
    logic clk_sys;
    logic rst_sys_n;

    // Score Input
    logic score_valid;
    logic score_ready;
    logic [511:0] score_data;
    logic [7:0] score_len;

    // Probability Output
    logic prob_valid;
    logic prob_ready;
    logic [511:0] prob_data;
    logic [7:0] prob_len;

    // Control
    logic softmax_start;
    logic softmax_busy;
    logic softmax_done;
    logic softmax_error;

    //=========================================================================
    // DUT Instance
    //=========================================================================
    M12_SoftMax dut (
        .clk_sys(clk_sys),
        .rst_sys_n(rst_sys_n),
        .score_valid(score_valid),
        .score_ready(score_ready),
        .score_data(score_data),
        .score_len(score_len),
        .prob_valid(prob_valid),
        .prob_ready(prob_ready),
        .prob_data(prob_data),
        .prob_len(prob_len),
        .softmax_start(softmax_start),
        .softmax_busy(softmax_busy),
        .softmax_done(softmax_done),
        .softmax_error(softmax_error)
    );

    //=========================================================================
    // Clock Assignment
    //=========================================================================
    assign clk_sys = clk_sys_ext;

    //=========================================================================
    // Test FSM States
    //=========================================================================
    typedef enum {
        INIT, RESET,
        TEST_BASIC_SOFTMAX, TEST_MAX_SUBTRACT,
        TEST_EXP_APPROX, TEST_SUM_NORM,
        TEST_FULL_PIPE, TEST_LENGTH_VAR,
        TEST_CAUSAL_MASK, TEST_NEGATIVE_SCORES,
        TEST_ERROR_CASES, DONE
    } test_state_t;

    test_state_t state;
    int wait_counter;
    int test_pass_count;

    //=========================================================================
    // Test Stimulus
    //=========================================================================
    initial begin
        state = INIT;
        test_pass_count = 0;

        // Initialize signals
        rst_sys_n = 0;
        score_valid = 0;
        score_data = 0;
        score_len = 32;
        prob_ready = 1;
        softmax_start = 0;

        // Reset phase
        repeat(10) @(posedge clk_sys);
        rst_sys_n = 1;
        state = RESET;
        repeat(10) @(posedge clk_sys);

        // Test Basic SoftMax
        state = TEST_BASIC_SOFTMAX;
        for (int i = 0; i < 50; i++) begin
            score_valid = 1;
            score_data = {32{i[15:0], 16'h0000}};  // 32 x FP16 values
            score_len = 32;
            softmax_start = 1;
            @(posedge clk_sys);
            score_valid = 0;
            softmax_start = 0;
            wait_counter = 0;
            while (!prob_valid && wait_counter < 200) begin
                @(posedge clk_sys);
                wait_counter++;
            end
            if (prob_valid) test_pass_count++;
            prob_ready = 1;
        end

        // Test Max Subtraction
        state = TEST_MAX_SUBTRACT;
        score_data[15:0] = 16'h7BFF;  // Max value
        score_data[31:16] = 16'h0000;  // Min value
        score_valid = 1;
        softmax_start = 1;
        @(posedge clk_sys);
        score_valid = 0;
        softmax_start = 0;
        repeat(100) @(posedge clk_sys);

        // Test Exp Approximation
        state = TEST_EXP_APPROX;
        for (int e = 0; e < 10; e++) begin
            score_data = {32{e[3:0], 12'h000}};
            score_valid = 1;
            softmax_start = 1;
            @(posedge clk_sys);
            score_valid = 0;
            softmax_start = 0;
            repeat(100) @(posedge clk_sys);
        end

        // Test Sum and Normalize
        state = TEST_SUM_NORM;
        score_data = {32{16'h3C00}};  // All ones
        score_valid = 1;
        softmax_start = 1;
        @(posedge clk_sys);
        score_valid = 0;
        softmax_start = 0;
        repeat(100) @(posedge clk_sys);

        // Test Full Pipeline
        state = TEST_FULL_PIPE;
        for (int i = 0; i < 100; i++) begin
            score_valid = 1;
            score_data = i;
            softmax_start = 1;
            @(posedge clk_sys);
            softmax_start = 0;
            repeat(50) @(posedge clk_sys);
        end
        score_valid = 0;

        // Test Length Variation
        state = TEST_LENGTH_VAR;
        for (int len = 8; len <= 32; len += 8) begin
            score_len = len;
            score_valid = 1;
            softmax_start = 1;
            @(posedge clk_sys);
            score_valid = 0;
            softmax_start = 0;
            repeat(100) @(posedge clk_sys);
        end

        // Test Causal Mask (-inf scores)
        state = TEST_CAUSAL_MASK;
        score_data[15:0] = 16'hFC00;  // -inf
        score_data[31:16] = 16'h3C00;  // 1.0
        score_valid = 1;
        softmax_start = 1;
        @(posedge clk_sys);
        score_valid = 0;
        softmax_start = 0;
        repeat(100) @(posedge clk_sys);

        // Test Negative Scores
        state = TEST_NEGATIVE_SCORES;
        score_data = {32{16'hBC00}};  // -1.0
        score_valid = 1;
        softmax_start = 1;
        @(posedge clk_sys);
        score_valid = 0;
        softmax_start = 0;
        repeat(100) @(posedge clk_sys);

        // Test Error Cases
        state = TEST_ERROR_CASES;
        score_len = 0;  // Invalid length
        score_valid = 1;
        softmax_start = 1;
        @(posedge clk_sys);
        score_valid = 0;
        softmax_start = 0;
        repeat(50) @(posedge clk_sys);
        score_len = 32;

        state = DONE;
        repeat(10) @(posedge clk_sys);
    end

endmodule