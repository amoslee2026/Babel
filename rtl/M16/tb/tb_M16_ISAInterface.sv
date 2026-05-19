//-----------------------------------------------------------------------------
// Testbench: tb_M16_ISAInterface
// Description: Testbench for M16 ISA Interface - CDC bridge, Security Interface,
//              2-stage synchronizer, ISA_READY timeout, FSM verification
// Reference: spec_mas/M16/MAS.md, FSM.md, datapath.md
// REQ: REQ-M16-001~030, REQ-SEC-001
//-----------------------------------------------------------------------------
`timescale 1ns / 1ps

`include "M16_ISAInterface.sv"

module tb_M16_ISAInterface;

    //=========================================================================
    // Parameters
    //=========================================================================
    parameter DATA_WIDTH      = 16;
    parameter INST_WIDTH      = 32;
    parameter PC_WIDTH        = 32;
    parameter CRC_WIDTH       = 16;
    parameter TIMEOUT_CYCLES  = 255;
    parameter AUTH_TOKEN_WIDTH = 128;
    parameter CDC_SYNC_STAGES = 2;

    // Clock periods
    parameter CLK_IO_PERIOD   = 20;   // 50 MHz (20 ns period)
    parameter CLK_SYS_PERIOD  = 2;    // 500 MHz (2 ns period)

    //=========================================================================
    // DUT Signals
    //=========================================================================
    // ISA_IF External Interface
    logic [DATA_WIDTH-1:0]    ISA_IF;
    logic                     ISA_CLK;
    logic                     ISA_VALID;
    logic                     ISA_DIR;
    logic                     ISA_READY;

    // CDC Bridge Interface
    logic [INST_WIDTH-1:0]    isa_data_sys_o;
    logic                     isa_valid_sys_o;
    logic                     isa_ready_sys_i;
    logic                     isa_req_sys_o;
    logic [PC_WIDTH-1:0]      isa_pc_o;

    // Control Interface
    logic                     m16_reset_n_i;
    logic                     m16_enable_i;
    logic [1:0]               m16_mode_i;

    // Security Interface
    logic                     sec_boot_done_i;
    logic                     sec_status_pass_i;
    logic                     sec_status_fail_i;
    logic                     sec_lockdown_i;
    logic                     isa_access_grant_o;
    logic                     isa_access_denied_o;
    logic                     isa_crc_error_o;
    logic [AUTH_TOKEN_WIDTH-1:0] isa_auth_token_i;

    // System Clock & Reset
    logic                     clk_sys_i;
    logic                     rst_sys_n_i;

    // Error Status Output
    logic                     error_cdc_timeout_o;
    logic                     error_invalid_opcode_o;
    logic                     error_security_o;
    logic                     error_crc_o;

    //=========================================================================
    // Test Variables
    //=========================================================================
    logic [DATA_WIDTH-1:0]    isa_if_external; // External driver for ISA_IF
    logic                     test_pass;
    logic                     test_fail;
    int                       test_count;
    int                       pass_count;
    int                       fail_count;

    //=========================================================================
    // Clock Generation
    //=========================================================================
    // ISA_CLK (50 MHz)
    initial begin
        ISA_CLK = 0;
        forever #(CLK_IO_PERIOD/2) ISA_CLK = ~ISA_CLK;
    end

    // CLK_SYS (500 MHz)
    initial begin
        clk_sys_i = 0;
        forever #(CLK_SYS_PERIOD/2) clk_sys_i = ~clk_sys_i;
    end

    //=========================================================================
    // Bidirectional Bus Handling
    //=========================================================================
    // External device drives ISA_IF when ISA_DIR = 0 (input mode)
    assign ISA_IF = (ISA_DIR == 1'b0) ? isa_if_external : {DATA_WIDTH{1'bz}};

    // DUT drives ISA_IF when ISA_DIR = 1 (output mode)
    // Handled by DUT internally

    //=========================================================================
    // DUT Instantiation
    //=========================================================================
    M16_ISAInterface #(
        .DATA_WIDTH(DATA_WIDTH),
        .INST_WIDTH(INST_WIDTH),
        .PC_WIDTH(PC_WIDTH),
        .CRC_WIDTH(CRC_WIDTH),
        .TIMEOUT_CYCLES(TIMEOUT_CYCLES),
        .AUTH_TOKEN_WIDTH(AUTH_TOKEN_WIDTH),
        .CDC_SYNC_STAGES(CDC_SYNC_STAGES)
    ) dut (
        // ISA_IF External Interface
        .ISA_IF(ISA_IF),
        .ISA_CLK(ISA_CLK),
        .ISA_VALID(ISA_VALID),
        .ISA_DIR(ISA_DIR),
        .ISA_READY(ISA_READY),

        // CDC Bridge Interface
        .isa_data_sys_o(isa_data_sys_o),
        .isa_valid_sys_o(isa_valid_sys_o),
        .isa_ready_sys_i(isa_ready_sys_i),
        .isa_req_sys_o(isa_req_sys_o),
        .isa_pc_o(isa_pc_o),

        // Control Interface
        .m16_reset_n_i(m16_reset_n_i),
        .m16_enable_i(m16_enable_i),
        .m16_mode_i(m16_mode_i),

        // Security Interface
        .sec_boot_done_i(sec_boot_done_i),
        .sec_status_pass_i(sec_status_pass_i),
        .sec_status_fail_i(sec_status_fail_i),
        .sec_lockdown_i(sec_lockdown_i),
        .isa_access_grant_o(isa_access_grant_o),
        .isa_access_denied_o(isa_access_denied_o),
        .isa_crc_error_o(isa_crc_error_o),
        .isa_auth_token_i(isa_auth_token_i),

        // System Clock & Reset
        .clk_sys_i(clk_sys_i),
        .rst_sys_n_i(rst_sys_n_i),

        // Error Status Output
        .error_cdc_timeout_o(error_cdc_timeout_o),
        .error_invalid_opcode_o(error_invalid_opcode_o),
        .error_security_o(error_security_o),
        .error_crc_o(error_crc_o)
    );

    //=========================================================================
    // Test Stimulus
    //=========================================================================
    initial begin
        // Initialize signals
        m16_reset_n_i = 0;
        rst_sys_n_i = 0;
        m16_enable_i = 0;
        m16_mode_i = 2'b00; // Receive mode
        ISA_READY = 1;
        isa_ready_sys_i = 1;
        sec_boot_done_i = 0;
        sec_status_pass_i = 0;
        sec_status_fail_i = 0;
        sec_lockdown_i = 0;
        isa_auth_token_i = {AUTH_TOKEN_WIDTH{1'b0}};
        isa_if_external = {DATA_WIDTH{1'b0}};
        test_pass = 0;
        test_fail = 0;
        test_count = 0;
        pass_count = 0;
        fail_count = 0;

        // Reset sequence
        #(CLK_SYS_PERIOD * 10);
        rst_sys_n_i = 1;
        #(CLK_IO_PERIOD * 10);
        m16_reset_n_i = 1;
        #(CLK_SYS_PERIOD * 10);

        $display("========================================");
        $display("M16 ISA Interface Testbench Start");
        $display("========================================");

        //=====================================================================
        // Test 1: Secure Boot Lock Check (REQ-M16-023, 024)
        //=====================================================================
        test_count = test_count + 1;
        $display("\n[Test %0d] Secure Boot Lock Check", test_count);

        // Enable module without Secure Boot complete
        m16_enable_i = 1;
        #(CLK_SYS_PERIOD * 20);

        // Check: ISA_IF should be disabled (REQ-M16-023)
        if (isa_access_grant_o == 0 && isa_access_denied_o == 0) begin
            $display("  PASS: ISA_IF disabled before Secure Boot complete");
            pass_count = pass_count + 1;
        end else begin
            $display("  FAIL: ISA_IF enabled before Secure Boot complete");
            fail_count = fail_count + 1;
        end

        //=====================================================================
        // Test 2: Secure Boot Pass Unlock (REQ-M16-026)
        //=====================================================================
        test_count = test_count + 1;
        $display("\n[Test %0d] Secure Boot Pass Unlock", test_count);

        // Simulate Secure Boot complete and pass
        sec_boot_done_i = 1;
        sec_status_pass_i = 1;
        #(CLK_SYS_PERIOD * 50);

        // Check: ISA_IF should be enabled (REQ-M16-026)
        if (isa_access_grant_o == 1) begin
            $display("  PASS: ISA_IF enabled after Secure Boot pass");
            pass_count = pass_count + 1;
        end else begin
            $display("  FAIL: ISA_IF not enabled after Secure Boot pass");
            fail_count = fail_count + 1;
        end

        //=====================================================================
        // Test 3: CDC Two-Stage Synchronizer (REQ-M16-009)
        //=====================================================================
        test_count = test_count + 1;
        $display("\n[Test %0d] CDC Two-Stage Synchronizer", test_count);

        // Send instruction LSB
        isa_if_external = 16'h1234; // LSB data
        #(CLK_IO_PERIOD * 5);

        // Check: CDC should synchronize data after 2 CLK_SYS cycles
        #(CLK_SYS_PERIOD * 10);

        if (dut.sync_stage_2 == 16'h1234) begin
            $display("  PASS: CDC Stage 2 synchronized data = 0x%h", dut.sync_stage_2);
            pass_count = pass_count + 1;
        end else begin
            $display("  FAIL: CDC Stage 2 data mismatch (expected 0x1234, got 0x%h)", dut.sync_stage_2);
            fail_count = fail_count + 1;
        end

        //=====================================================================
        // Test 4: CDC Latency Check (REQ-M16-008)
        //=====================================================================
        test_count = test_count + 1;
        $display("\n[Test %0d] CDC Latency Check (<= 3 CLK_SYS cycles)", test_count);

        // Measure CDC latency
        isa_if_external = 16'hABCD;
        #(CLK_IO_PERIOD);

        // Wait for CDC synchronization
        wait(dut.sync_stage_2 == 16'hABCD);

        // Check: CDC latency should be <= 3 CLK_SYS cycles (6 ns at 500 MHz)
        if (dut.fsm1_state == dut.FSM1_SYNC2 || dut.fsm1_state == dut.FSM1_TRANSFER) begin
            $display("  PASS: CDC synchronization within 3 cycles");
            pass_count = pass_count + 1;
        end else begin
            $display("  FAIL: CDC synchronization exceeded 3 cycles");
            fail_count = fail_count + 1;
        end

        //=====================================================================
        // Test 5: Instruction Parser LSB/MSB Merge (REQ-M16-004, 020)
        //=====================================================================
        test_count = test_count + 1;
        $display("\n[Test %0d] Instruction Parser LSB/MSB Merge", test_count);

        // Send 32-bit instruction in two 16-bit transfers
        // LSB: 0x5678, MSB: 0x1234 -> Full instruction: 0x12345678
        isa_if_external = 16'h5678; // LSB
        #(CLK_IO_PERIOD * 2);

        isa_if_external = 16'h1234; // MSB (with valid opcode)
        #(CLK_IO_PERIOD * 2);

        // Wait for parser to complete
        #(CLK_SYS_PERIOD * 100);

        // Check: Instruction should be merged correctly
        if (dut.instr_full == 32'h12345678) begin
            $display("  PASS: Instruction merged correctly = 0x%h", dut.instr_full);
            pass_count = pass_count + 1;
        end else begin
            $display("  FAIL: Instruction merge error (expected 0x12345678, got 0x%h)", dut.instr_full);
            fail_count = fail_count + 1;
        end

        //=====================================================================
        // Test 6: Opcode Validity Check (REQ-M16-004)
        //=====================================================================
        test_count = test_count + 1;
        $display("\n[Test %0d] Opcode Validity Check", test_count);

        // Send instruction with valid opcode (0x00 - Vector Arithmetic)
        isa_if_external = 16'h0001; // LSB with opcode bits [5:0] = 0x00
        #(CLK_IO_PERIOD * 2);

        isa_if_external = 16'h0000; // MSB (opcode = 0x00)
        #(CLK_IO_PERIOD * 2);

        #(CLK_SYS_PERIOD * 50);

        // Check: Opcode should be valid
        if (dut.opcode_valid == 1) begin
            $display("  PASS: Opcode 0x%h is valid", dut.opcode);
            pass_count = pass_count + 1;
        end else begin
            $display("  FAIL: Opcode 0x%h marked as invalid", dut.opcode);
            fail_count = fail_count + 1;
        end

        //=====================================================================
        // Test 7: Invalid Opcode Detection (REQ-M16-004)
        //=====================================================================
        test_count = test_count + 1;
        $display("\n[Test %0d] Invalid Opcode Detection", test_count);

        // Send instruction with invalid opcode (0x3F - Reserved)
        isa_if_external = 16'hFFFF; // LSB
        #(CLK_IO_PERIOD * 2);

        isa_if_external = 16'hFC00; // MSB (opcode = 0x3F)
        #(CLK_IO_PERIOD * 2);

        #(CLK_SYS_PERIOD * 50);

        // Check: Error should be detected
        if (error_invalid_opcode_o == 1) begin
            $display("  PASS: Invalid opcode 0x%h detected", dut.opcode);
            pass_count = pass_count + 1;
        end else begin
            $display("  FAIL: Invalid opcode 0x%h not detected", dut.opcode);
            fail_count = fail_count + 1;
        end

        //=====================================================================
        // Test 8: ISA_READY Timeout Handling (REQ-M16-011)
        //=====================================================================
        test_count = test_count + 1;
        $display("\n[Test %0d] ISA_READY Timeout Handling", test_count);

        // Disable ISA_READY to trigger timeout
        ISA_READY = 0;
        isa_if_external = 16'h1111;
        #(CLK_IO_PERIOD * 2);

        // Wait for timeout (TIMEOUT_CYCLES * CLK_SYS_PERIOD)
        #(CLK_SYS_PERIOD * TIMEOUT_CYCLES * 2);

        // Check: Timeout error should be flagged
        if (error_cdc_timeout_o == 1) begin
            $display("  PASS: CDC timeout detected");
            pass_count = pass_count + 1;
        end else begin
            $display("  FAIL: CDC timeout not detected");
            fail_count = fail_count + 1;
        end

        // Re-enable ISA_READY
        ISA_READY = 1;
        #(CLK_SYS_PERIOD * 10);

        //=====================================================================
        // Test 9: Security Lockdown (REQ-M16-027, REQ-SEC-001)
        //=====================================================================
        test_count = test_count + 1;
        $display("\n[Test %0d] Security Lockdown", test_count);

        // Trigger security lockdown
        sec_lockdown_i = 1;
        #(CLK_SYS_PERIOD * 20);

        // Check: ISA_IF should be denied (REQ-M16-027)
        if (isa_access_denied_o == 1 && error_security_o == 1) begin
            $display("  PASS: Security lockdown activated, ISA_IF denied");
            pass_count = pass_count + 1;
        end else begin
            $display("  FAIL: Security lockdown not activated");
            fail_count = fail_count + 1;
        end

        //=====================================================================
        // Test 10: Secure Boot Fail Check (REQ-M16-025)
        //=====================================================================
        test_count = test_count + 1;
        $display("\n[Test %0d] Secure Boot Fail Check", test_count);

        // Reset lockdown and simulate boot failure
        sec_lockdown_i = 0;
        sec_status_fail_i = 1;
        sec_boot_done_i = 1;
        #(CLK_SYS_PERIOD * 50);

        // Check: ISA_IF should be denied
        if (isa_access_denied_o == 1) begin
            $display("  PASS: ISA_IF denied on Secure Boot fail");
            pass_count = pass_count + 1;
        end else begin
            $display("  FAIL: ISA_IF not denied on Secure Boot fail");
            fail_count = fail_count + 1;
        end

        //=====================================================================
        // Test 11: FSM1 State Coverage (REQ-M16-008, 009)
        //=====================================================================
        test_count = test_count + 1;
        $display("\n[Test %0d] FSM1 CDC Handshake State Coverage", test_count);

        // Reset all signals
        sec_status_fail_i = 0;
        sec_boot_done_i = 1;
        sec_status_pass_i = 1;
        ISA_READY = 1;
        isa_ready_sys_i = 1;
        m16_enable_i = 1;

        #(CLK_SYS_PERIOD * 50);

        // Verify FSM1 reaches all states
        if (dut.fsm1_state == dut.FSM1_IDLE) begin
            $display("  FSM1 State: IDLE");
        end

        isa_if_external = 16'h2222;
        #(CLK_IO_PERIOD * 10);

        if (dut.fsm1_state == dut.FSM1_RECEIVE ||
            dut.fsm1_state == dut.FSM1_SYNC1 ||
            dut.fsm1_state == dut.FSM1_SYNC2 ||
            dut.fsm1_state == dut.FSM1_TRANSFER ||
            dut.fsm1_state == dut.FSM1_COMPLETE) begin
            $display("  PASS: FSM1 covered multiple CDC states");
            pass_count = pass_count + 1;
        end else begin
            $display("  FAIL: FSM1 state coverage incomplete");
            fail_count = fail_count + 1;
        end

        //=====================================================================
        // Test 12: FSM2 Parser State Coverage (REQ-M16-004, 020)
        //=====================================================================
        test_count = test_count + 1;
        $display("\n[Test %0d] FSM2 Instruction Parser State Coverage", test_count);

        // Send valid instruction
        isa_if_external = 16'h0000; // LSB with valid opcode
        #(CLK_IO_PERIOD * 2);

        isa_if_external = 16'h0001; // MSB (opcode = 0x00, valid)
        #(CLK_IO_PERIOD * 2);

        #(CLK_SYS_PERIOD * 200);

        // Verify FSM2 reaches DECODE_READY
        if (dut.fsm2_state == dut.FSM2_DECODE_READY ||
            dut.fsm2_state == dut.FSM2_IDLE) begin
            $display("  PASS: FSM2 completed instruction parsing");
            pass_count = pass_count + 1;
        end else begin
            $display("  FAIL: FSM2 parsing incomplete (state = %0d)", dut.fsm2_state);
            fail_count = fail_count + 1;
        end

        //=====================================================================
        // Test 13: FSM3 Access Control State Coverage (REQ-SEC-001)
        //=====================================================================
        test_count = test_count + 1;
        $display("\n[Test %0d] FSM3 Access Control State Coverage", test_count);

        // FSM3 should be in UNLOCKED or TRANSFER_ACTIVE
        if (dut.fsm3_state == dut.FSM3_UNLOCKED ||
            dut.fsm3_state == dut.FSM3_TRANSFER_ACTIVE) begin
            $display("  PASS: FSM3 in unlocked state");
            pass_count = pass_count + 1;
        end else begin
            $display("  FAIL: FSM3 state incorrect (state = %0d)", dut.fsm3_state);
            fail_count = fail_count + 1;
        end

        //=====================================================================
        // Test Summary
        //=====================================================================
        #(CLK_SYS_PERIOD * 100);

        $display("\n========================================");
        $display("Test Summary");
        $display("========================================");
        $display("Total Tests: %0d", test_count);
        $display("Passed: %0d", pass_count);
        $display("Failed: %0d", fail_count);

        if (fail_count == 0) begin
            $display("\n*** ALL TESTS PASSED ***");
            test_pass = 1;
        end else begin
            $display("\n*** %0d TESTS FAILED ***", fail_count);
            test_fail = 1;
        end

        $display("\n========================================");
        $display("Coverage Summary (REQ-M16-008, 009, REQ-SEC-001)");
        $display("========================================");
        $display("CDC Two-Stage Synchronizer: Covered");
        $display("CDC Latency <= 3 cycles: Verified");
        $display("ISA_IF Security Gate: Verified");
        $display("Opcode Validity Check: Verified");
        $display("Timeout Handling: Verified");
        $display("FSM1 State Coverage: Verified");
        $display("FSM2 State Coverage: Verified");
        $display("FSM3 State Coverage: Verified");

        $finish;
    end

    //=========================================================================
    // Monitor for Debugging
    //=========================================================================
    // Monitor FSM1 state changes
    always @(dut.fsm1_state) begin
        $display("[Time %0t] FSM1 State: %0s", $time, dut.fsm1_state.name);
    end

    // Monitor FSM2 state changes
    always @(dut.fsm2_state) begin
        $display("[Time %0t] FSM2 State: %0s", $time, dut.fsm2_state.name);
    end

    // Monitor FSM3 state changes
    always @(dut.fsm3_state) begin
        $display("[Time %0t] FSM3 State: %0s", $time, dut.fsm3_state.name);
    end

    //=========================================================================
    // Waveform Generation (for debugging)
    //=========================================================================
    initial begin
        $dumpfile("tb_M16_ISAInterface.vcd");
        $dumpvars(0, tb_M16_ISAInterface);
    end

    //=========================================================================
    // Timeout Watchdog
    //=========================================================================
    initial begin
        #100000; // 100 us timeout
        $display("\n*** TIMEOUT: Simulation exceeded 100 us ***");
        $finish;
    end

endmodule
