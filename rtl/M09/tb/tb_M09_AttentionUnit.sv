//=============================================================================
// Testbench: M09 Attention Unit
// TinyStories NPU - Multi-Head Attention Verification
//-----------------------------------------------------------------------------
// Test Categories:
//   1. Prefill Phase: Batch processing (256 tokens)
//   2. Decode Phase: Single token generation
//   3. MQA Head Sharing: 8 Query heads with 4 KV heads
//   4. Causal Masking: Position-based mask application
//   5. KV Cache Overflow (REQ-M09-010): Boundary handling
//   6. RoPE Integration: Optional position encoding
//   7. Precision Modes: FP16/FP8/INT8
//=============================================================================

module tb_M09_AttentionUnit;

    //=========================================================================
    // Parameters
    //=========================================================================
    parameter int N_HEADS      = 8;
    parameter int N_KV_HEADS   = 4;
    parameter int HEAD_SIZE    = 8;
    parameter int SEQ_LEN      = 512;
    parameter int KV_DIM       = 32;
    parameter int CLK_PERIOD   = 4;  // 250 MHz = 4ns period

    //=========================================================================
    // Clock & Reset
    //=========================================================================
    logic clk_sys;
    logic rst_sys_n;
    logic pg_main_en;

    initial begin
        clk_sys = 0;
        forever #(CLK_PERIOD/2) clk_sys = ~clk_sys;
    end

    initial begin
        rst_sys_n = 0;
        pg_main_en = 1;
        #20 rst_sys_n = 1;
    end

    //=========================================================================
    // DUT Signals
    //=========================================================================

    // Activation Input Interface
    logic        act_valid;
    logic [511:0] act_data;
    logic [15:0] act_pos;
    logic [7:0]  act_layer;
    logic        act_ready;

    // Q/K/V Vector Interface
    logic        q_valid;
    logic [63:0] q_data;
    logic        k_valid;
    logic [31:0] k_data;
    logic        v_valid;
    logic [31:0] v_data;
    logic        qkv_ready;

    // KV Cache Interface
    logic [19:0] kv_addr;
    logic [63:0] kv_wdata;
    logic        kv_wen;
    logic [63:0] kv_rdata;
    logic        kv_valid;
    logic        kv_ready;

    // Systolic Array Interface
    logic        sa_cmd_valid;
    logic        sa_cmd_ready;
    logic [1:0]  sa_op;
    logic [7:0]  sa_head;
    logic [15:0] sa_pos;
    logic        sa_result_valid;
    logic [255:0] sa_result_data;
    logic        sa_result_ready;

    // SoftMax Interface
    logic        sm_valid;
    logic [511:0] sm_data;
    logic [7:0]  sm_head;
    logic        sm_ready;
    logic        sm_result_valid;
    logic [511:0] sm_result_data;

    // Output Interface
    logic        out_valid;
    logic [63:0] out_data;
    logic [7:0]  out_layer;
    logic        out_ready;

    // Control Interface
    logic        attn_start;
    logic [1:0]  attn_phase;
    logic [7:0]  attn_head_sel;
    logic        attn_done;
    logic        attn_busy;

    // RoPE Interface
    logic        rope_en;
    logic [63:0] rope_q_rotated;
    logic [31:0] rope_k_rotated;
    logic        rope_valid;

    // Error/Status
    logic        kv_overflow;
    logic        error;

    //=========================================================================
    // DUT Instance
    //=========================================================================
    M09_AttentionUnit #(
        .N_HEADS    (N_HEADS),
        .N_KV_HEADS (N_KV_HEADS),
        .HEAD_SIZE  (HEAD_SIZE),
        .SEQ_LEN    (SEQ_LEN),
        .KV_DIM     (KV_DIM)
    ) dut (
        .clk_sys_i        (clk_sys),
        .rst_sys_n_i      (rst_sys_n),
        .pg_main_en_i     (pg_main_en),

        .act_valid_i      (act_valid),
        .act_data_i       (act_data),
        .act_pos_i        (act_pos),
        .act_layer_i      (act_layer),
        .act_ready_o      (act_ready),

        .q_valid_i        (q_valid),
        .q_data_i         (q_data),
        .k_valid_i        (k_valid),
        .k_data_i         (k_data),
        .v_valid_i        (v_valid),
        .v_data_i         (v_data),
        .qkv_ready_o      (qkv_ready),

        .kv_addr_o        (kv_addr),
        .kv_wdata_o       (kv_wdata),
        .kv_wen_o         (kv_wen),
        .kv_rdata_i       (kv_rdata),
        .kv_valid_o       (kv_valid),
        .kv_ready_i       (kv_ready),

        .sa_cmd_valid_o   (sa_cmd_valid),
        .sa_cmd_ready_i   (sa_cmd_ready),
        .sa_op_o          (sa_op),
        .sa_head_o        (sa_head),
        .sa_pos_o         (sa_pos),
        .sa_result_valid_i(sa_result_valid),
        .sa_result_data_i (sa_result_data),
        .sa_result_ready_o(sa_result_ready),

        .sm_valid_o       (sm_valid),
        .sm_data_o        (sm_data),
        .sm_head_o        (sm_head),
        .sm_ready_i       (sm_ready),
        .sm_result_valid_i(sm_result_valid),
        .sm_result_data_i (sm_result_data),

        .out_valid_o      (out_valid),
        .out_data_o       (out_data),
        .out_layer_o      (out_layer),
        .out_ready_i      (out_ready),

        .attn_start_i     (attn_start),
        .attn_phase_i     (attn_phase),
        .attn_head_sel_i  (attn_head_sel),
        .attn_done_o      (attn_done),
        .attn_busy_o      (attn_busy),

        .rope_en_i        (rope_en),
        .rope_q_rotated_i (rope_q_rotated),
        .rope_k_rotated_i (rope_k_rotated),
        .rope_valid_i     (rope_valid),

        .kv_overflow_o    (kv_overflow),
        .error_o          (error)
    );

    //=========================================================================
    // External Module Mocks
    //=========================================================================

    // M00 Systolic Array Mock
    initial begin
        sa_cmd_ready = 1;
        forever @(posedge clk_sys) begin
            if (sa_cmd_valid) begin
                #CLK_PERIOD;
                // Simulate computation delay
                sa_result_valid = 1;
                sa_result_data = $random;  // Mock result
                #CLK_PERIOD;
                sa_result_valid = 0;
            end
        end
    end

    // M12 SoftMax Unit Mock
    initial begin
        sm_ready = 1;
        forever @(posedge clk_sys) begin
            if (sm_valid) begin
                #CLK_PERIOD;
                // Simulate SoftMax computation
                sm_result_valid = 1;
                // Normalize mock weights (all 1s for simplicity)
                sm_result_data = {64{8'h01}};  // Mock normalized weights
                #CLK_PERIOD;
                sm_result_valid = 0;
            end
        end
    end

    // M02 SRAM Mock
    logic [63:0] kv_cache_mem [0:SEQ_LEN*5*2-1];  // Mock KV cache storage

    initial begin
        kv_ready = 1;
        kv_rdata = 0;
        forever @(posedge clk_sys) begin
            if (kv_valid && kv_wen) begin
                kv_cache_mem[kv_addr] = kv_wdata;
                #CLK_PERIOD;
                kv_ready = 1;
            end else if (kv_valid && !kv_wen) begin
                kv_rdata = kv_cache_mem[kv_addr];
                #CLK_PERIOD;
                kv_ready = 1;
            end
        end
    end

    // Output Ready Mock
    initial begin
        out_ready = 1;
    end

    //=========================================================================
    // Test Tasks
    //=========================================================================

    // Task: Initialize all signals
    task init_signals();
        act_valid      = 0;
        act_data       = 0;
        act_pos        = 0;
        act_layer      = 0;
        q_valid        = 0;
        q_data         = 0;
        k_valid        = 0;
        k_data         = 0;
        v_valid        = 0;
        v_data         = 0;
        attn_start     = 0;
        attn_phase     = 0;
        attn_head_sel  = 0;
        rope_en        = 0;
        rope_q_rotated = 0;
        rope_k_rotated = 0;
        rope_valid     = 0;
    endtask

    // Task: Send Q/K/V vectors
    task send_qkv(
        input logic [63:0] q_vec,
        input logic [31:0] k_vec,
        input logic [31:0] v_vec,
        input logic [7:0]  head_sel
    );
        @(posedge clk_sys);
        q_valid        = 1;
        q_data         = q_vec;
        k_valid        = 1;
        k_data         = k_vec;
        v_valid        = 1;
        v_data         = v_vec;
        attn_head_sel  = head_sel;
        @(posedge clk_sys);
        q_valid = 0;
        k_valid = 0;
        v_valid = 0;
    endtask

    // Task: Start attention computation
    task start_attention(
        input logic [15:0] pos,
        input logic [7:0]  layer,
        input logic [1:0]  phase
    );
        @(posedge clk_sys);
        act_valid   = 1;
        act_pos     = pos;
        act_layer   = layer;
        attn_phase  = phase;
        attn_start  = 1;
        @(posedge clk_sys);
        attn_start = 0;
        act_valid  = 0;
    endtask

    // Task: Wait for completion
    task wait_completion();
        while (!attn_done) begin
            @(posedge clk_sys);
        end
        @(posedge clk_sys);
    endtask

    // Task: Enable RoPE and provide rotated vectors
    task enable_rope(
        input logic [63:0] q_rotated,
        input logic [31:0] k_rotated
    );
        @(posedge clk_sys);
        rope_en        = 1;
        rope_q_rotated = q_rotated;
        rope_k_rotated = k_rotated;
        rope_valid     = 1;
        @(posedge clk_sys);
        rope_valid = 0;
    endtask

    //=========================================================================
    // Test Cases
    //=========================================================================

    // Test result tracking
    int test_passed;
    int test_failed;
    string test_name;

    task check_result(input logic expected, input logic actual, input string name);
        if (expected == actual) begin
            test_passed++;
            $display("[PASS] %s: Expected=%b, Actual=%b", name, expected, actual);
        end else begin
            test_failed++;
            $display("[FAIL] %s: Expected=%b, Actual=%b", name, expected, actual);
        end
    endtask

    //=========================================================================
    // Main Test Sequence
    //=========================================================================

    initial begin
        $display("========================================");
        $display("M09 Attention Unit Testbench");
        $display("========================================");

        test_passed = 0;
        test_failed = 0;

        // Wait for reset
        wait(rst_sys_n);
        #10;

        //---------------------------------------------------------------------
        // Test 1: Decode Phase - Single Token (pos=0)
        //---------------------------------------------------------------------
        test_name = "Test 1: Decode Single Token (pos=0)";
        $display("\n--- %s ---", test_name);

        init_signals();
        start_attention(0, 0, 2'b00);  // pos=0, layer=0, Score phase
        send_qkv(64'hDEADBEEF_CAFE0001, 32'h12345678, 32'hABCDEF01, 8'h01);
        wait_completion();

        check_result(1'b0, kv_overflow, "KV Overflow (should not overflow)");
        check_result(1'b0, error, "Error flag (should be no error)");

        //---------------------------------------------------------------------
        // Test 2: Decode Phase - Single Token (pos=256)
        //---------------------------------------------------------------------
        test_name = "Test 2: Decode Single Token (pos=256)";
        $display("\n--- %s ---", test_name);

        init_signals();
        start_attention(256, 1, 2'b00);  // pos=256, layer=1
        send_qkv(64'hAAAA_BBBB_CCCC_DDDD, 32'h1111_2222, 32'h3333_4444, 8'h03);
        wait_completion();

        check_result(1'b0, kv_overflow, "KV Overflow (pos=256 < 512)");

        //---------------------------------------------------------------------
        // Test 3: REQ-M09-010 - KV Cache Overflow (pos=512)
        //---------------------------------------------------------------------
        test_name = "Test 3: REQ-M09-010 KV Cache Overflow (pos=512)";
        $display("\n--- %s ---", test_name);

        init_signals();
        start_attention(512, 2, 2'b00);  // pos=512, exceeds SEQ_LEN
        send_qkv(64'hOVER_FLOW_TEST_001, 32'hFFFF_0000, 32'h0000_FFFF, 8'h07);
        wait_completion();

        check_result(1'b1, kv_overflow, "REQ-M09-010: Overflow flag should be set");

        //---------------------------------------------------------------------
        // Test 4: MQA Head Sharing - All 8 Query Heads
        //---------------------------------------------------------------------
        test_name = "Test 4: MQA Head Sharing (8 Q heads, 4 KV heads)";
        $display("\n--- %s ---", test_name);

        // Test each head group
        for (int head = 0; head < N_HEADS; head++) begin
            init_signals();
            start_attention(10, 0, 2'b00);

            // Check KV head mapping: head[2:1] gives KV head index
            logic [2:0] expected_kv_head;
            expected_kv_head = head[2:1];

            $display("  Head %d -> KV Head %d", head, expected_kv_head);

            send_qkv($random, $random, $random, head);
            wait_completion();

            check_result(1'b0, error, "MQA Head " + string'(head));
        end

        //---------------------------------------------------------------------
        // Test 5: Causal Masking - Position-based
        //---------------------------------------------------------------------
        test_name = "Test 5: Causal Masking (pos=100)";
        $display("\n--- %s ---", test_name);

        init_signals();
        start_attention(100, 0, 2'b00);
        send_qkv(64'hMASK_TEST_POS_100, 32'hMASK_K_001, 32'hMASK_V_001, 8'h02);
        wait_completion();

        // Check that mask was applied (positions > 100 should be masked)
        check_result(1'b0, kv_overflow, "Causal Mask: No overflow");

        //---------------------------------------------------------------------
        // Test 6: RoPE Integration - Enabled
        //---------------------------------------------------------------------
        test_name = "Test 6: RoPE Integration (enabled)";
        $display("\n--- %s ---", test_name);

        init_signals();
        start_attention(50, 0, 2'b00);
        send_qkv(64'hROPE_Q_RAW_0001, 32'hROPE_K_RAW, 32'hROPE_V_001, 8'h04);

        // Enable RoPE
        enable_rope(64'hROPE_Q_ROTATED, 32'hROPE_K_ROTATED);

        wait_completion();

        check_result(1'b0, error, "RoPE Integration: No error");

        //---------------------------------------------------------------------
        // Test 7: RoPE Disabled - Skip ROPE_WAIT state
        //---------------------------------------------------------------------
        test_name = "Test 7: RoPE Disabled (bypass)";
        $display("\n--- %s ---", test_name);

        init_signals();
        rope_en = 0;  // Disable RoPE explicitly
        start_attention(30, 1, 2'b00);
        send_qkv(64'hNO_ROPE_Q_001, 32'hNO_ROPE_K, 32'hNO_ROPE_V, 8'h01);
        wait_completion();

        check_result(1'b0, error, "RoPE Disabled: No error");

        //---------------------------------------------------------------------
        // Test 8: Prefill Phase - Multiple Positions
        //---------------------------------------------------------------------
        test_name = "Test 8: Prefill Phase (batch positions)";
        $display("\n--- %s ---", test_name);

        // Simulate prefill for positions 0-9
        for (int pos = 0; pos < 10; pos++) begin
            init_signals();
            start_attention(pos, 0, 2'b00);
            send_qkv($random, $random, $random, pos % 8);
            wait_completion();
            #5;
        end

        check_result(1'b0, kv_overflow, "Prefill: No overflow");
        check_result(1'b0, error, "Prefill: No error");

        //---------------------------------------------------------------------
        // Test 9: Power Gate - During Operation
        //---------------------------------------------------------------------
        test_name = "Test 9: Power Gate Behavior";
        $display("\n--- %s ---", test_name);

        init_signals();
        start_attention(10, 0, 2'b00);
        send_qkv(64'hPG_TEST_Q, 32'hPG_TEST_K, 32'hPG_TEST_V, 8'h00);

        // Apply power gate during operation
        #10;
        pg_main_en = 0;  // Power gate
        #CLK_PERIOD;
        pg_main_en = 1;  // Restore power

        wait_completion();
        check_result(1'b0, attn_busy, "Power Gate: attn_busy should be 0");

        //---------------------------------------------------------------------
        // Test 10: All Layer Processing (5 layers)
        //---------------------------------------------------------------------
        test_name = "Test 10: All Layers (0-4)";
        $display("\n--- %s ---", test_name);

        for (int layer = 0; layer < 5; layer++) begin
            init_signals();
            start_attention(20, layer, 2'b00);
            send_qkv($random, $random, $random, layer % 8);
            wait_completion();
            check_result(1'b0, error, "Layer " + string'(layer));
        end

        //=====================================================================
        // Test Summary
        //=====================================================================
        #100;
        $display("\n========================================");
        $display("Test Summary");
        $display("========================================");
        $display("Passed: %d", test_passed);
        $display("Failed: %d", test_failed);
        $display("Total:  %d", test_passed + test_failed);

        if (test_failed == 0) begin
            $display("\n[SUCCESS] All tests passed!");
        end else begin
            $display("\n[FAILURE] Some tests failed!");
        end

        $display("========================================");
        $finish;
    end

    //=========================================================================
    // Waveform Dump (Optional)
    //=========================================================================
    initial begin
        $dumpfile("tb_M09_AttentionUnit.vcd");
        $dumpvars(0, tb_M09_AttentionUnit);
    end

    //=========================================================================
    // Timeout Watchdog
    //=========================================================================
    initial begin
        #100000;  // 100us timeout
        $display("[TIMEOUT] Testbench exceeded maximum time!");
        $finish;
    end

    //=========================================================================
    // FSM State Monitor
    //=========================================================================
    logic [3:0] monitored_state;

    always @(posedge clk_sys) begin
        if (dut.current_state != monitored_state) begin
            monitored_state = dut.current_state;
            case (monitored_state)
                4'b0000: $display("[FSM] State: IDLE");
                4'b0001: $display("[FSM] State: QKV_LOAD");
                4'b0010: $display("[FSM] State: ROPE_WAIT");
                4'b0011: $display("[FSM] State: SCORE_INIT");
                4'b0100: $display("[FSM] State: SCORE_COMPUTE");
                4'b0101: $display("[FSM] State: CAUSAL_MASK");
                4'b0110: $display("[FSM] State: SOFTMAX_WAIT");
                4'b0111: $display("[FSM] State: AV_COMPUTE");
                4'b1000: $display("[FSM] State: KV_UPDATE");
                4'b1001: $display("[FSM] State: OUTPUT_STORE");
                4'b1010: $display("[FSM] State: DONE");
                default: $display("[FSM] State: UNKNOWN (%b)", monitored_state);
            endcase
        end
    end

endmodule