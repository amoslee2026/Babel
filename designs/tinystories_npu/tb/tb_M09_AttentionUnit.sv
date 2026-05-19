//=============================================================================
// Testbench: M09_AttentionUnit
// Testbench for M09 AttentionUnit (Verilator compatible, coverage driven)
//=============================================================================

module tb_M09_AttentionUnit (
    input logic clk_i_ext  // External clock from C++
);

    //=========================================================================
    // Parameters
    //=========================================================================
    localparam N_HEADS    = 8;
    localparam N_KV_HEADS = 4;
    localparam HEAD_SIZE  = 8;
    localparam SEQ_LEN    = 512;

    //=========================================================================
    // Signals
    //=========================================================================
    logic clk_sys_i;
    logic rst_sys_n_i;
    logic pg_main_en_i;

    logic        act_valid_i;
    logic [511:0] act_data_i;
    logic [15:0] act_pos_i;
    logic [7:0]  act_layer_i;
    logic        act_ready_o;

    logic        q_valid_i;
    logic [63:0] q_data_i;
    logic        k_valid_i;
    logic [31:0] k_data_i;
    logic        v_valid_i;
    logic [31:0] v_data_i;
    logic        qkv_ready_o;

    logic [19:0] kv_addr_o;
    logic [63:0] kv_wdata_o;
    logic        kv_wen_o;
    logic [63:0] kv_rdata_i;
    logic        kv_valid_o;
    logic        kv_ready_i;

    logic        sa_cmd_valid_o;
    logic        sa_cmd_ready_i;
    logic [1:0]  sa_op_o;
    logic [7:0]  sa_head_o;
    logic [15:0] sa_pos_o;
    logic        sa_result_valid_i;
    logic [255:0] sa_result_data_i;
    logic        sa_result_ready_o;

    logic        sm_valid_o;
    logic [511:0] sm_data_o;
    logic [7:0]  sm_head_o;
    logic        sm_ready_i;
    logic        sm_result_valid_i;
    logic [511:0] sm_result_data_i;

    logic        out_valid_o;
    logic [63:0] out_data_o;
    logic [7:0]  out_layer_o;
    logic        out_ready_i;

    logic        attn_start_i;
    logic [1:0]  attn_phase_i;
    logic [7:0]  attn_head_sel_i;
    logic        attn_done_o;
    logic        attn_busy_o;

    logic        rope_en_i;
    logic [63:0] rope_q_rotated_i;
    logic [31:0] rope_k_rotated_i;
    logic        rope_valid_i;

    logic        kv_overflow_o;
    logic        error_o;

    //=========================================================================
    // DUT Instance
    //=========================================================================
    M09_AttentionUnit dut (
        .clk_sys_i, .rst_sys_n_i, .pg_main_en_i,
        .act_valid_i, .act_data_i, .act_pos_i, .act_layer_i, .act_ready_o,
        .q_valid_i, .q_data_i, .k_valid_i, .k_data_i, .v_valid_i, .v_data_i, .qkv_ready_o,
        .kv_addr_o, .kv_wdata_o, .kv_wen_o, .kv_rdata_i, .kv_valid_o, .kv_ready_i,
        .sa_cmd_valid_o, .sa_cmd_ready_i, .sa_op_o, .sa_head_o, .sa_pos_o,
        .sa_result_valid_i, .sa_result_data_i, .sa_result_ready_o,
        .sm_valid_o, .sm_data_o, .sm_head_o, .sm_ready_i,
        .sm_result_valid_i, .sm_result_data_i,
        .out_valid_o, .out_data_o, .out_layer_o, .out_ready_i,
        .attn_start_i, .attn_phase_i, .attn_head_sel_i, .attn_done_o, .attn_busy_o,
        .rope_en_i, .rope_q_rotated_i, .rope_k_rotated_i, .rope_valid_i,
        .kv_overflow_o, .error_o
    );

    //=========================================================================
    // Clock
    //=========================================================================
    assign clk_sys_i = clk_i_ext;

    //=========================================================================
    // Test FSM States
    //=========================================================================
    typedef enum {
        INIT, RESET,
        TEST_HEADS_0_TO_7, TEST_LAYERS_0_TO_4,
        TEST_PHASES, TEST_CAUSAL_MASK,
        TEST_KV_OVERFLOW, TEST_ROPE,
        DONE
    } test_state_t;

    test_state_t state;
    int wait_counter;
    int test_pass_count;
    int test_fail_count;
    int test_cycle;
    int sub_head;

    //=========================================================================
    // attn_done edge detection
    //=========================================================================
    logic attn_done_sampled;
    always @(negedge clk_sys_i) begin
        attn_done_sampled = attn_done_o;
    end

    //=========================================================================
    // Mock Responder: KV Cache (always ready)
    //=========================================================================
    assign kv_ready_i = 1;

    // SA responder state
    logic sa_responding;
    int sa_wait_cnt;

    // SM responder state
    logic sm_responding;
    int sm_wait_cnt;

    // Output always ready
    assign out_ready_i = 1;

    //=========================================================================
    // Initial Values
    //=========================================================================
    initial begin
        state = INIT;
        test_pass_count = 0;
        test_fail_count = 0;
        wait_counter = 0;
        test_cycle = 0;
        sub_head = 0;
        sa_responding = 0;
        sa_wait_cnt = 0;
        sm_responding = 0;
        sm_wait_cnt = 0;

        rst_sys_n_i = 0;
        pg_main_en_i = 0;
        act_valid_i = 0;
        act_data_i = 0;
        act_pos_i = 0;
        act_layer_i = 0;
        q_valid_i = 0;
        q_data_i = 0;
        k_valid_i = 0;
        k_data_i = 0;
        v_valid_i = 0;
        v_data_i = 0;
        kv_rdata_i = 0;
        sa_result_valid_i = 0;
        sa_result_data_i = 0;
        sa_cmd_ready_i = 1;
        sm_result_valid_i = 0;
        sm_result_data_i = 0;
        sm_ready_i = 1;
        attn_start_i = 0;
        attn_phase_i = 0;
        attn_head_sel_i = 0;
        rope_en_i = 0;
        rope_q_rotated_i = 0;
        rope_k_rotated_i = 0;
        rope_valid_i = 0;
    end

    //=========================================================================
    // Cycle Counter
    //=========================================================================
    always @(posedge clk_sys_i) begin
        test_cycle = test_cycle + 1;
    end

    //=========================================================================
    // SA Mock Responder
    //=========================================================================
    always @(posedge clk_sys_i) begin
        if (sa_cmd_valid_o && !sa_responding) begin
            sa_responding = 1;
            sa_wait_cnt = 10;
        end

        if (sa_responding) begin
            if (sa_wait_cnt > 0) begin
                sa_wait_cnt = sa_wait_cnt - 1;
            end else begin
                sa_result_valid_i = 1;
                sa_result_data_i = {256{$random}};
                sa_responding = 0;
            end
        end else begin
            sa_result_valid_i = 0;
        end
    end

    //=========================================================================
    // SM Mock Responder
    //=========================================================================
    always @(posedge clk_sys_i) begin
        if (sm_valid_o && !sm_responding) begin
            sm_responding = 1;
            sm_wait_cnt = 5;
        end

        if (sm_responding) begin
            if (sm_wait_cnt > 0) begin
                sm_wait_cnt = sm_wait_cnt - 1;
            end else begin
                sm_result_valid_i = 1;
                sm_result_data_i = {16{$random}};
                sm_responding = 0;
            end
        end else begin
            sm_result_valid_i = 0;
        end
    end

    //=========================================================================
    // Test FSM
    //=========================================================================
    always @(posedge clk_sys_i) begin
        // Timeout protection for each test - prevent infinite waits
        if (state != INIT && state != RESET && state != DONE && wait_counter > 50000) begin
            $display("  TIMEOUT at cycle %0d, DUT fsm=%0d, dut.busy=%0d, dut.qkv_rdy=%0d",
                     test_cycle, dut.debug_state, dut.attn_busy_o, dut.qkv_ready_o);
            test_fail_count <= test_fail_count + 1;
            if (state == TEST_HEADS_0_TO_7) begin
                sub_head <= sub_head + 1;
            end else begin
                sub_head <= sub_head + 1;
            end
            wait_counter <= 0;
        end
        else case (state)
            INIT: begin
                if (wait_counter >= 5) begin
                    rst_sys_n_i <= 1;
                    pg_main_en_i <= 1;
                    state <= RESET;
                    wait_counter <= 0;
                end else begin
                    wait_counter <= wait_counter + 1;
                end
            end

            RESET: begin
                if (wait_counter >= 5) begin
                    $display("=== M09 Attention Unit Tests ===");
                    state <= TEST_HEADS_0_TO_7;
                    wait_counter <= 0;
                    sub_head <= 0;
                end else begin
                    wait_counter <= wait_counter + 1;
                end
            end

            //=================================================================
            // Test heads 0-7
            //=================================================================
            TEST_HEADS_0_TO_7: begin
                if (sub_head >= 8) begin
                    state <= TEST_LAYERS_0_TO_4;
                    sub_head <= 0;
                    wait_counter <= 0;
                end else if (wait_counter == 0) begin
                    $display("Test: Head %0d", sub_head);
                    act_pos_i <= 50;
                    act_layer_i <= 0;
                    attn_head_sel_i <= (1 << sub_head);
                    // Keep all valid high until DUT samples them
                    q_valid_i <= 1;
                    k_valid_i <= 1;
                    v_valid_i <= 1;
                    act_valid_i <= 1;
                    attn_start_i <= 1;
                    wait_counter <= 1;
                end else if (wait_counter == 1) begin
                    attn_start_i <= 0;
                    wait_counter <= 2;
                end else if (qkv_ready_o) begin
                    // DUT has latched Q/K/V, clear valid
                    q_valid_i <= 0;
                    k_valid_i <= 0;
                    v_valid_i <= 0;
                    act_valid_i <= 0;
                    wait_counter <= 3;
                end else if (attn_done_sampled || attn_done_o) begin
                    if (!error_o) begin
                        test_pass_count <= test_pass_count + 1;
                        $display("  PASS");
                    end else begin
                        test_fail_count <= test_fail_count + 1;
                        $display("  FAIL");
                    end
                    sub_head <= sub_head + 1;
                    wait_counter <= 0;
                end else begin
                    wait_counter <= wait_counter + 1;
                end
            end

            //=================================================================
            // Test layers 0-4
            //=================================================================
            TEST_LAYERS_0_TO_4: begin
                if (sub_head >= 5) begin
                    state <= TEST_PHASES;
                    sub_head <= 0;
                    wait_counter <= 0;
                end else if (wait_counter == 0) begin
                    $display("Test: Layer %0d", sub_head);
                    act_pos_i <= 100;
                    act_layer_i <= sub_head;
                    attn_head_sel_i <= 1;
                    q_valid_i <= 1;
                    k_valid_i <= 1;
                    v_valid_i <= 1;
                    act_valid_i <= 1;
                    attn_start_i <= 1;
                    wait_counter <= 1;
                end else if (wait_counter == 1) begin
                    attn_start_i <= 0;
                    wait_counter <= 2;
                end else if (qkv_ready_o) begin
                    q_valid_i <= 0;
                    k_valid_i <= 0;
                    v_valid_i <= 0;
                    act_valid_i <= 0;
                    wait_counter <= 3;
                end else if (attn_done_sampled || attn_done_o) begin
                    if (!error_o) begin
                        test_pass_count <= test_pass_count + 1;
                        $display("  PASS");
                    end else begin
                        test_fail_count <= test_fail_count + 1;
                        $display("  FAIL");
                    end
                    sub_head <= sub_head + 1;
                    wait_counter <= 0;
                end else begin
                    wait_counter <= wait_counter + 1;
                end
            end

            //=================================================================
            // Test phases
            //=================================================================
            TEST_PHASES: begin
                if (sub_head >= 3) begin
                    state <= TEST_CAUSAL_MASK;
                    sub_head <= 0;
                    wait_counter <= 0;
                end else if (wait_counter == 0) begin
                    $display("Test: Phase %0d", sub_head);
                    attn_phase_i <= sub_head;
                    act_pos_i <= 100;
                    act_layer_i <= 0;
                    attn_head_sel_i <= 1;
                    q_valid_i <= 1;
                    k_valid_i <= 1;
                    v_valid_i <= 1;
                    act_valid_i <= 1;
                    attn_start_i <= 1;
                    wait_counter <= 1;
                end else if (wait_counter == 1) begin
                    attn_start_i <= 0;
                    wait_counter <= 2;
                end else if (qkv_ready_o) begin
                    q_valid_i <= 0;
                    k_valid_i <= 0;
                    v_valid_i <= 0;
                    act_valid_i <= 0;
                    wait_counter <= 3;
                end else if (attn_done_sampled || attn_done_o) begin
                    if (!error_o) begin
                        test_pass_count <= test_pass_count + 1;
                        $display("  PASS");
                    end else begin
                        test_fail_count <= test_fail_count + 1;
                        $display("  FAIL");
                    end
                    sub_head <= sub_head + 1;
                    wait_counter <= 0;
                end else begin
                    wait_counter <= wait_counter + 1;
                end
            end

            //=================================================================
            // Causal mask - test position boundaries
            //=================================================================
            TEST_CAUSAL_MASK: begin
                if (sub_head >= 3) begin
                    state <= TEST_KV_OVERFLOW;
                    sub_head <= 1;
                    wait_counter <= 0;
                end else if (wait_counter == 0) begin
                    case (sub_head)
                        0: begin $display("Test: Causal mask pos=0"); act_pos_i <= 0; end
                        1: begin $display("Test: Causal mask pos=255"); act_pos_i <= 255; end
                        2: begin $display("Test: Causal mask pos=511"); act_pos_i <= 511; end
                    endcase
                    act_layer_i <= 0;
                    attn_head_sel_i <= 1;
                    q_valid_i <= 1;
                    k_valid_i <= 1;
                    v_valid_i <= 1;
                    act_valid_i <= 1;
                    attn_start_i <= 1;
                    wait_counter <= 1;
                end else if (wait_counter == 1) begin
                    attn_start_i <= 0;
                    wait_counter <= 2;
                end else if (qkv_ready_o) begin
                    q_valid_i <= 0;
                    k_valid_i <= 0;
                    v_valid_i <= 0;
                    act_valid_i <= 0;
                    wait_counter <= 3;
                end else if (attn_done_sampled || attn_done_o) begin
                    if (!error_o) begin
                        test_pass_count <= test_pass_count + 1;
                        $display("  PASS");
                    end else begin
                        test_fail_count <= test_fail_count + 1;
                        $display("  FAIL");
                    end
                    sub_head <= sub_head + 1;
                    wait_counter <= 0;
                end else begin
                    wait_counter <= wait_counter + 1;
                end
            end

            //=================================================================
            // KV Cache overflow tests
            //=================================================================
            TEST_KV_OVERFLOW: begin
                if (sub_head >= 4) begin
                    state <= TEST_ROPE;
                    sub_head <= 0;
                    wait_counter <= 0;
                end else if (wait_counter == 0) begin
                    case (sub_head)
                        1: begin $display("Test: KV overflow pos=0"); act_pos_i <= 0; end
                        2: begin $display("Test: KV overflow pos=512 (at limit)"); act_pos_i <= 512; end
                        3: begin $display("Test: KV overflow pos=600 (over)"); act_pos_i <= 600; end
                    endcase
                    act_layer_i <= 0;
                    attn_head_sel_i <= 1;
                    q_valid_i <= 1;
                    k_valid_i <= 1;
                    v_valid_i <= 1;
                    act_valid_i <= 1;
                    attn_start_i <= 1;
                    wait_counter <= 1;
                end else if (wait_counter == 1) begin
                    attn_start_i <= 0;
                    wait_counter <= 2;
                end else if (qkv_ready_o) begin
                    q_valid_i <= 0;
                    k_valid_i <= 0;
                    v_valid_i <= 0;
                    act_valid_i <= 0;
                    wait_counter <= 3;
                end else if (attn_done_sampled || attn_done_o) begin
                    if (!error_o) begin
                        test_pass_count <= test_pass_count + 1;
                        $display("  PASS");
                    end else begin
                        test_fail_count <= test_fail_count + 1;
                        $display("  FAIL");
                    end
                    sub_head <= sub_head + 1;
                    wait_counter <= 0;
                end else begin
                    wait_counter <= wait_counter + 1;
                end
            end

            //=================================================================
            // RoPE tests
            //=================================================================
            TEST_ROPE: begin
                if (sub_head >= 2) begin
                    state <= DONE;
                    wait_counter <= 0;
                end else if (wait_counter == 0) begin
                    if (sub_head == 0)
                        $display("Test: RoPE disabled");
                    else begin
                        $display("Test: RoPE enabled");
                        rope_en_i <= 1;
                        rope_q_rotated_i <= {64{$random}};
                        rope_k_rotated_i <= {32{$random}};
                        rope_valid_i <= 1;
                    end
                    act_pos_i <= 100;
                    act_layer_i <= 0;
                    attn_head_sel_i <= 1;
                    q_valid_i <= 1;
                    k_valid_i <= 1;
                    v_valid_i <= 1;
                    act_valid_i <= 1;
                    attn_start_i <= 1;
                    wait_counter <= 1;
                end else if (wait_counter == 1) begin
                    attn_start_i <= 0;
                    wait_counter <= 2;
                end else if (qkv_ready_o) begin
                    q_valid_i <= 0;
                    k_valid_i <= 0;
                    v_valid_i <= 0;
                    act_valid_i <= 0;
                    rope_en_i <= 0;
                    rope_valid_i <= 0;
                    wait_counter <= 3;
                end else if (attn_done_sampled || attn_done_o) begin
                    if (!error_o) begin
                        test_pass_count <= test_pass_count + 1;
                        $display("  PASS");
                    end else begin
                        test_fail_count <= test_fail_count + 1;
                        $display("  FAIL");
                    end
                    sub_head <= sub_head + 1;
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
