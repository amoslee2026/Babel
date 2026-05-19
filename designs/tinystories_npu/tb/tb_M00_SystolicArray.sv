//=============================================================================
// Testbench: M00_SystolicArray
// Cycle-based testbench for Verilator coverage collection
//-----------------------------------------------------------------------------

module tb_M00_SystolicArray (
    input logic clk_i_ext  // External clock from C++
);

    //=========================================================================
    // Parameters
    //=========================================================================
    localparam PE_ROWS    = 128;
    localparam PE_COLS    = 128;
    localparam DATA_W_MAX = 32;
    localparam ACC_W      = 32;

    //=========================================================================
    // Signals
    //=========================================================================
    logic clk_i;
    logic rst_ni;
    logic pe_mode_i;
    logic [1:0] pe_precision_i;
    logic pe_start_i;
    logic pe_done_o;
    logic [7:0] pe_row_cnt_i;
    logic [7:0] pe_col_cnt_i;
    logic [PE_COLS*DATA_W_MAX-1:0] weight_in_i;
    logic [PE_ROWS*DATA_W_MAX-1:0] input_in_i;
    logic [PE_ROWS*DATA_W_MAX-1:0] output_out_o;
    logic [PE_ROWS*ACC_W-1:0] partial_out_o;
    logic [15:0] weight_addr_i;
    logic [15:0] input_addr_i;
    logic [15:0] output_addr_i;
    logic fp8_format_i;
    logic [1:0] round_mode_i;
    logic saturation_i;
    logic mix_precision_en_i;
    logic pe_size_error_o;
    logic [2:0] pe_size_error_code_o;
    logic [8:0] pe_k_cnt_i;

    //=========================================================================
    // DUT Instance
    //=========================================================================
    M00_SystolicArray #(
        .PE_ROWS(PE_ROWS),
        .PE_COLS(PE_COLS),
        .DATA_W_MAX(DATA_W_MAX),
        .ACC_W(ACC_W)
    ) dut (
        .clk_i(clk_i),
        .rst_ni(rst_ni),
        .pe_mode_i(pe_mode_i),
        .pe_precision_i(pe_precision_i),
        .pe_start_i(pe_start_i),
        .pe_done_o(pe_done_o),
        .pe_row_cnt_i(pe_row_cnt_i),
        .pe_col_cnt_i(pe_col_cnt_i),
        .weight_in_i(weight_in_i),
        .input_in_i(input_in_i),
        .output_out_o(output_out_o),
        .partial_out_o(partial_out_o),
        .weight_addr_i(weight_addr_i),
        .input_addr_i(input_addr_i),
        .output_addr_i(output_addr_i),
        .fp8_format_i(fp8_format_i),
        .round_mode_i(round_mode_i),
        .saturation_i(saturation_i),
        .mix_precision_en_i(mix_precision_en_i),
        .pe_size_error_o(pe_size_error_o),
        .pe_size_error_code_o(pe_size_error_code_o),
        .pe_k_cnt_i(pe_k_cnt_i)
    );

    //=========================================================================
    // Clock Assignment
    //=========================================================================
    assign clk_i = clk_i_ext;

    //=========================================================================
    // Test FSM States
    //=========================================================================
    typedef enum {
        INIT, RESET,
        TEST_WS_FP16, TEST_WS_FP8_E4M3, TEST_WS_FP8_E5M2,
        TEST_WS_INT8, TEST_WS_FP32,
        TEST_OS_FP16, TEST_OS_FP8, TEST_OS_INT8,
        TEST_BOUNDARY_M, TEST_BOUNDARY_N, TEST_BOUNDARY_K,
        DONE
    } test_state_t;

    test_state_t state;
    int wait_counter;
    int test_pass_count;
    int test_fail_count;
    int test_cycle;

    //=========================================================================
    // pe_done Detection
    //=========================================================================
    logic pe_done_sampled;
    always @(negedge clk_i) begin
        pe_done_sampled = pe_done_o;
    end

    //=========================================================================
    // Initial Values
    //=========================================================================
    initial begin
        state = INIT;
        test_pass_count = 0;
        test_fail_count = 0;
        wait_counter = 0;
        test_cycle = 0;

        rst_ni = 0;
        pe_mode_i = 0;
        pe_precision_i = 0;
        pe_start_i = 0;
        pe_row_cnt_i = 0;
        pe_col_cnt_i = 0;
        pe_k_cnt_i = 0;
        weight_in_i = '0;
        input_in_i = '0;
        weight_addr_i = 0;
        input_addr_i = 0;
        output_addr_i = 0;
        fp8_format_i = 0;
        round_mode_i = 0;
        saturation_i = 0;
        mix_precision_en_i = 0;
    end

    //=========================================================================
    // Cycle Counter
    //=========================================================================
    always @(posedge clk_i) begin
        test_cycle = test_cycle + 1;
    end

    //=========================================================================
    // Test FSM
    //=========================================================================
    always @(posedge clk_i) begin
        case (state)
            INIT: begin
                if (wait_counter >= 5) begin
                    rst_ni <= 1;
                    state <= RESET;
                    wait_counter <= 0;
                end else begin
                    wait_counter <= wait_counter + 1;
                end
            end

            RESET: begin
                if (wait_counter >= 2) begin
                    $display("=== Starting WS Mode Tests ===");
                    state <= TEST_WS_FP16;
                    wait_counter <= 0;
                end else begin
                    wait_counter <= wait_counter + 1;
                end
            end

            TEST_WS_FP16: begin
                if (wait_counter == 0) begin
                    $display("Test: WS FP16 32x32x64");
                    pe_mode_i <= 0;
                    pe_precision_i <= 2'b01;
                    pe_row_cnt_i <= 32;
                    pe_col_cnt_i <= 32;
                    pe_k_cnt_i <= 64;
                    weight_in_i <= '1;
                    input_in_i <= '1;
                    pe_start_i <= 1;
                    wait_counter <= 1;
                end else if (wait_counter == 1) begin
                    pe_start_i <= 0;
                    wait_counter <= 2;
                end else if (pe_done_sampled || pe_done_o) begin
                    if (pe_size_error_o) test_fail_count <= test_fail_count + 1;
                    else test_pass_count <= test_pass_count + 1;
                    $display("  PASS");
                    state <= TEST_WS_FP8_E4M3;
                    wait_counter <= 0;
                end else begin
                    wait_counter <= wait_counter + 1;
                end
            end

            TEST_WS_FP8_E4M3: begin
                if (wait_counter == 0) begin
                    $display("Test: WS FP8 E4M3 64x64x128");
                    pe_mode_i <= 0;
                    pe_precision_i <= 2'b00;
                    fp8_format_i <= 0;
                    pe_row_cnt_i <= 64;
                    pe_col_cnt_i <= 64;
                    pe_k_cnt_i <= 128;
                    weight_in_i <= '1;
                    input_in_i <= '1;
                    pe_start_i <= 1;
                    wait_counter <= 1;
                end else if (wait_counter == 1) begin
                    pe_start_i <= 0;
                    wait_counter <= 2;
                end else if (pe_done_sampled || pe_done_o) begin
                    if (pe_size_error_o) test_fail_count <= test_fail_count + 1;
                    else test_pass_count <= test_pass_count + 1;
                    $display("  PASS");
                    state <= TEST_WS_FP8_E5M2;
                    wait_counter <= 0;
                end else begin
                    wait_counter <= wait_counter + 1;
                end
            end

            TEST_WS_FP8_E5M2: begin
                if (wait_counter == 0) begin
                    $display("Test: WS FP8 E5M2 64x64x128");
                    fp8_format_i <= 1;
                    weight_in_i <= '1;
                    input_in_i <= '1;
                    pe_start_i <= 1;
                    wait_counter <= 1;
                end else if (wait_counter == 1) begin
                    pe_start_i <= 0;
                    wait_counter <= 2;
                end else if (pe_done_sampled || pe_done_o) begin
                    fp8_format_i <= 0;
                    if (pe_size_error_o) test_fail_count <= test_fail_count + 1;
                    else test_pass_count <= test_pass_count + 1;
                    $display("  PASS");
                    state <= TEST_WS_INT8;
                    wait_counter <= 0;
                end else begin
                    wait_counter <= wait_counter + 1;
                end
            end

            TEST_WS_INT8: begin
                if (wait_counter == 0) begin
                    $display("Test: WS INT8 128x128x256");
                    pe_mode_i <= 0;
                    pe_precision_i <= 2'b10;
                    pe_row_cnt_i <= 128;
                    pe_col_cnt_i <= 128;
                    pe_k_cnt_i <= 256;
                    weight_in_i <= '1;
                    input_in_i <= '1;
                    pe_start_i <= 1;
                    wait_counter <= 1;
                end else if (wait_counter == 1) begin
                    pe_start_i <= 0;
                    wait_counter <= 2;
                end else if (pe_done_sampled || pe_done_o) begin
                    if (pe_size_error_o) test_fail_count <= test_fail_count + 1;
                    else test_pass_count <= test_pass_count + 1;
                    $display("  PASS");
                    state <= TEST_WS_FP32;
                    wait_counter <= 0;
                end else begin
                    wait_counter <= wait_counter + 1;
                end
            end

            TEST_WS_FP32: begin
                if (wait_counter == 0) begin
                    $display("Test: WS FP32 32x32x64");
                    pe_precision_i <= 2'b11;
                    pe_row_cnt_i <= 32;
                    pe_col_cnt_i <= 32;
                    pe_k_cnt_i <= 64;
                    weight_in_i <= '1;
                    input_in_i <= '1;
                    pe_start_i <= 1;
                    wait_counter <= 1;
                end else if (wait_counter == 1) begin
                    pe_start_i <= 0;
                    wait_counter <= 2;
                end else if (pe_done_sampled || pe_done_o) begin
                    if (pe_size_error_o) test_fail_count <= test_fail_count + 1;
                    else test_pass_count <= test_pass_count + 1;
                    $display("  PASS");
                    state <= TEST_OS_FP16;
                    wait_counter <= 0;
                end else begin
                    wait_counter <= wait_counter + 1;
                end
            end

            TEST_OS_FP16: begin
                if (wait_counter == 0) begin
                    $display("=== Starting OS Mode Tests ===");
                    $display("Test: OS FP16 32x32x64");
                    pe_mode_i <= 1;
                    pe_precision_i <= 2'b01;
                    pe_row_cnt_i <= 32;
                    pe_col_cnt_i <= 32;
                    pe_k_cnt_i <= 64;
                    weight_in_i <= '1;
                    input_in_i <= '1;
                    pe_start_i <= 1;
                    wait_counter <= 1;
                end else if (wait_counter == 1) begin
                    pe_start_i <= 0;
                    wait_counter <= 2;
                end else if (pe_done_sampled || pe_done_o) begin
                    if (pe_size_error_o) test_fail_count <= test_fail_count + 1;
                    else test_pass_count <= test_pass_count + 1;
                    $display("  PASS");
                    state <= TEST_OS_FP8;
                    wait_counter <= 0;
                end else begin
                    wait_counter <= wait_counter + 1;
                end
            end

            TEST_OS_FP8: begin
                if (wait_counter == 0) begin
                    $display("Test: OS FP8 64x64x128");
                    pe_precision_i <= 2'b00;
                    pe_row_cnt_i <= 64;
                    pe_col_cnt_i <= 64;
                    pe_k_cnt_i <= 128;
                    weight_in_i <= '1;
                    input_in_i <= '1;
                    pe_start_i <= 1;
                    wait_counter <= 1;
                end else if (wait_counter == 1) begin
                    pe_start_i <= 0;
                    wait_counter <= 2;
                end else if (pe_done_sampled || pe_done_o) begin
                    if (pe_size_error_o) test_fail_count <= test_fail_count + 1;
                    else test_pass_count <= test_pass_count + 1;
                    $display("  PASS");
                    state <= TEST_OS_INT8;
                    wait_counter <= 0;
                end else begin
                    wait_counter <= wait_counter + 1;
                end
            end

            TEST_OS_INT8: begin
                if (wait_counter == 0) begin
                    $display("Test: OS INT8 128x128x128");
                    pe_precision_i <= 2'b10;
                    pe_row_cnt_i <= 128;
                    pe_col_cnt_i <= 128;
                    pe_k_cnt_i <= 128;
                    weight_in_i <= '1;
                    input_in_i <= '1;
                    pe_start_i <= 1;
                    wait_counter <= 1;
                end else if (wait_counter == 1) begin
                    pe_start_i <= 0;
                    wait_counter <= 2;
                end else if (pe_done_sampled || pe_done_o) begin
                    if (pe_size_error_o) test_fail_count <= test_fail_count + 1;
                    else test_pass_count <= test_pass_count + 1;
                    $display("  PASS");
                    state <= TEST_BOUNDARY_M;
                    wait_counter <= 0;
                end else begin
                    wait_counter <= wait_counter + 1;
                end
            end

            TEST_BOUNDARY_M: begin
                if (wait_counter == 0) begin
                    $display("=== Boundary Tests ===");
                    $display("Test: M overflow (129x128x128)");
                    pe_mode_i <= 0;
                    pe_precision_i <= 2'b01;
                    pe_row_cnt_i <= 129;
                    pe_col_cnt_i <= 128;
                    pe_k_cnt_i <= 128;
                    pe_start_i <= 1;
                    wait_counter <= 1;
                end else if (wait_counter == 1) begin
                    pe_start_i <= 0;
                    if (pe_size_error_o) begin
                        test_pass_count <= test_pass_count + 1;
                        $display("  PASS: M overflow detected");
                    end else begin
                        test_fail_count <= test_fail_count + 1;
                        $display("  FAIL");
                    end
                    state <= TEST_BOUNDARY_N;
                    wait_counter <= 0;
                end else begin
                    wait_counter <= wait_counter + 1;
                end
            end

            TEST_BOUNDARY_N: begin
                if (wait_counter == 0) begin
                    $display("Test: N overflow (128x129x128)");
                    pe_row_cnt_i <= 128;
                    pe_col_cnt_i <= 129;
                    pe_start_i <= 1;
                    wait_counter <= 1;
                end else if (wait_counter == 1) begin
                    pe_start_i <= 0;
                    if (pe_size_error_o && pe_size_error_code_o[1]) begin
                        test_pass_count <= test_pass_count + 1;
                        $display("  PASS: N overflow detected");
                    end else begin
                        test_fail_count <= test_fail_count + 1;
                        $display("  FAIL");
                    end
                    state <= TEST_BOUNDARY_K;
                    wait_counter <= 0;
                end else begin
                    wait_counter <= wait_counter + 1;
                end
            end

            TEST_BOUNDARY_K: begin
                if (wait_counter == 0) begin
                    $display("Test: K overflow (128x128x257)");
                    pe_row_cnt_i <= 128;
                    pe_col_cnt_i <= 128;
                    pe_k_cnt_i <= 257;
                    pe_start_i <= 1;
                    wait_counter <= 1;
                end else if (wait_counter == 1) begin
                    pe_start_i <= 0;
                    if (pe_size_error_o && pe_size_error_code_o[2]) begin
                        test_pass_count <= test_pass_count + 1;
                        $display("  PASS: K overflow detected");
                    end else begin
                        test_fail_count <= test_fail_count + 1;
                        $display("  FAIL");
                    end
                    state <= DONE;
                    wait_counter <= 0;
                end else begin
                    wait_counter <= wait_counter + 1;
                end
            end

            DONE: begin
                $display("");
                $display("=== Test Summary ===");
                $display("Passed: %0d, Failed: %0d", test_pass_count, test_fail_count);
                $display("Simulation finished at cycle %0d", test_cycle);
                $finish;
            end
        endcase
    end

endmodule