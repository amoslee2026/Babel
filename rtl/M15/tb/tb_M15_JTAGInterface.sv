//-----------------------------------------------------------------------------
// Testbench: tb_M15_JTAGInterface
// Module:    M15_JTAGInterface
// Purpose:   Verify IEEE 1149.1 JTAG TAP Controller functionality
//-----------------------------------------------------------------------------
// Coverage Targets:
//   - TAP FSM 16-state transitions
//   - Instruction Register operations
//   - Data Register operations (BYPASS, IDCODE, BSR, DEBUG, SCAN)
//   - TEST_MODE Security Gating
//   - Scan Chain selection and control
//   - Debug Access interface
//-----------------------------------------------------------------------------

/* verilator lint_off WIDTHEXPAND */
/* verilator lint_off WIDTHTRUNC */

module tb_M15_JTAGInterface;

    //=========================================================================
    // Parameters
    //=========================================================================

    parameter TCK_PERIOD = 20;  // 50 MHz TCK
    parameter IDCODE_VALUE = 32'h1234_5AB9;

    //=========================================================================
    // DUT Signals
    //=========================================================================

    // JTAG Standard Interface
    logic        tck;
    logic        tms;
    logic        tdi;
    logic        tdo;
    logic        trst_n;
    logic        tdo_en;

    // TEST_MODE Security Interface
    logic        test_mode_en;
    logic        test_mode_valid;
    logic        sec_boot_en;
    logic        test_access_grant;
    logic        test_access_denied;

    // Scan Chain Interface
    logic [3:0]  scan_select;
    logic        scan_enable;
    logic        scan_in;
    logic        scan_out;
    logic        scan_capture;
    logic        scan_update;

    // Boundary Scan Interface
    logic        bsr_select;
    logic        bsr_capture;
    logic        bsr_update;
    logic [23:0] bsr_data_in;
    logic [23:0] bsr_data_out;

    // Debug Interface
    logic [15:0] debug_addr;
    logic [31:0] debug_data_in;
    logic [31:0] debug_data_out;
    logic        debug_rw;
    logic        debug_valid;
    logic        debug_ack;

    // MBIST Interface
    logic        mbist_start;
    logic        mbist_stop;
    logic [1:0]  mbist_target;
    logic [3:0]  mbist_algorithm;
    logic [23:0] mbist_status;

    // System Reset
    logic        rst_io_n;

    //=========================================================================
    // DUT Instance
    //=========================================================================

    M15_JTAGInterface dut (
        .tck                (tck),
        .tms                (tms),
        .tdi                (tdi),
        .tdo                (tdo),
        .trst_n             (trst_n),
        .tdo_en             (tdo_en),

        .test_mode_en       (test_mode_en),
        .test_mode_valid    (test_mode_valid),
        .sec_boot_en        (sec_boot_en),
        .test_access_grant  (test_access_grant),
        .test_access_denied (test_access_denied),

        .scan_select        (scan_select),
        .scan_enable        (scan_enable),
        .scan_in            (scan_in),
        .scan_out           (scan_out),
        .scan_capture       (scan_capture),
        .scan_update        (scan_update),

        .bsr_select         (bsr_select),
        .bsr_capture        (bsr_capture),
        .bsr_update         (bsr_update),
        .bsr_data_in        (bsr_data_in),
        .bsr_data_out       (bsr_data_out),

        .debug_addr         (debug_addr),
        .debug_data_in      (debug_data_in),
        .debug_data_out     (debug_data_out),
        .debug_rw           (debug_rw),
        .debug_valid        (debug_valid),
        .debug_ack          (debug_ack),

        .mbist_start        (mbist_start),
        .mbist_stop         (mbist_stop),
        .mbist_target       (mbist_target),
        .mbist_algorithm    (mbist_algorithm),
        .mbist_status       (mbist_status),

        .rst_io_n           (rst_io_n)
    );

    //=========================================================================
    // Clock Generation
    //=========================================================================

    initial begin
        tck = 1'b0;
        forever #(TCK_PERIOD/2) tck = ~tck;
    end

    //=========================================================================
    // Test Variables
    //=========================================================================

    integer test_count;
    integer pass_count;
    integer fail_count;
    logic [63:0] captured_data;
    logic [4:0]  captured_ir;

    //=========================================================================
    // Helper Tasks
    //=========================================================================

    // Reset sequence
    task reset_dut();
        begin
            trst_n = 1'b0;
            rst_io_n = 1'b0;
            tms = 1'b1;
            tdi = 1'b0;
            test_mode_en = 1'b0;
            test_mode_valid = 1'b0;
            sec_boot_en = 1'b0;
            scan_out = 1'b0;
            bsr_data_in = 24'b0;
            debug_data_out = 32'b0;
            debug_ack = 1'b0;
            mbist_status = 24'b0;
            @(posedge tck);
            @(posedge tck);
            rst_io_n = 1'b1;
            trst_n = 1'b1;
            @(posedge tck);
            $display("[%0t] DUT Reset Complete", $time);
        end
    endtask

    // Go to Test-Logic-Reset state (TMS=1 for 5+ cycles)
    task goto_reset_state();
        begin
            tms = 1'b1;
            repeat(6) @(posedge tck);
            $display("[%0t] In Test-Logic-Reset state", $time);
        end
    endtask

    // Go to Run-Test/Idle state
    task goto_idle_state();
        begin
            // From Test-Logic-Reset: TMS=0
            tms = 1'b0;
            @(posedge tck);
            $display("[%0t] In Run-Test/Idle state", $time);
        end
    endtask

    // Shift IR instruction
    task shift_ir(input logic [4:0] ir_value, output logic [4:0] captured_ir_out);
        logic [4:0] shift_data;
        integer i;
        begin
            shift_data = ir_value;

            // Select-DR-Scan -> Select-IR-Scan (TMS=1)
            tms = 1'b1;
            @(posedge tck);

            // Select-IR-Scan -> Capture-IR (TMS=0)
            tms = 1'b0;
            @(posedge tck);

            // Capture-IR -> Shift-IR (TMS=0)
            tms = 1'b0;
            @(posedge tck);

            $display("[%0t] In Shift-IR state, shifting IR=%h", $time, ir_value);

            // Shift 5 bits of IR
            captured_ir_out = 5'b0;
            for (i = 0; i < 4; i = i + 1) begin
                tdi = shift_data[i];
                @(negedge tck);
                captured_ir_out[4-i] = tdo;
                @(posedge tck);
            end

            // Last bit with TMS=1 to exit
            tdi = shift_data[4];
            @(negedge tck);
            captured_ir_out[0] = tdo;
            tms = 1'b1;
            @(posedge tck);

            // Exit1-IR -> Update-IR (TMS=1)
            @(posedge tck);

            // Update-IR -> Run-Test/Idle (TMS=0)
            tms = 1'b0;
            @(posedge tck);

            $display("[%0t] IR Update complete, captured IR=%h", $time, captured_ir_out);
        end
    endtask

    // Shift DR data
    task shift_dr(input integer length, input logic [63:0] data_in, output logic [63:0] data_out);
        logic [63:0] shift_data;
        integer i;
        begin
            shift_data = data_in;

            // Run-Test/Idle -> Select-DR-Scan (TMS=1)
            tms = 1'b1;
            @(posedge tck);

            // Select-DR-Scan -> Capture-DR (TMS=0)
            tms = 1'b0;
            @(posedge tck);

            // Capture-DR -> Shift-DR (TMS=0)
            tms = 1'b0;
            @(posedge tck);

            $display("[%0t] In Shift-DR state, length=%0d, data_in=%h", $time, length, data_in);

            // Shift data bits
            data_out = 64'b0;
            for (i = 0; i < length-1; i = i + 1) begin
                tdi = shift_data[i];
                @(negedge tck);
                data_out[length-1-i] = tdo;
                @(posedge tck);
            end

            // Last bit with TMS=1 to exit
            tdi = shift_data[length-1];
            @(negedge tck);
            data_out[0] = tdo;
            tms = 1'b1;
            @(posedge tck);

            // Exit1-DR -> Update-DR (TMS=1)
            @(posedge tck);

            // Update-DR -> Run-Test/Idle (TMS=0)
            tms = 1'b0;
            @(posedge tck);

            $display("[%0t] DR Update complete, captured data=%h", $time, data_out);
        end
    endtask

    // Enable TEST_MODE access
    task enable_test_mode();
        begin
            test_mode_en = 1'b1;
            test_mode_valid = 1'b1;
            @(posedge tck);
            @(posedge tck);
            $display("[%0t] TEST_MODE enabled, access_grant=%b", $time, test_access_grant);
        end
    endtask

    // Disable TEST_MODE access
    task disable_test_mode();
        begin
            test_mode_en = 1'b0;
            test_mode_valid = 1'b0;
            @(posedge tck);
            @(posedge tck);
            $display("[%0t] TEST_MODE disabled", $time);
        end
    endtask

    //=========================================================================
    // Test Cases
    //=========================================================================

    initial begin
        $display("========================================");
        $display("M15 JTAG Interface Testbench Start");
        $display("========================================");

        test_count = 0;
        pass_count = 0;
        fail_count = 0;

        // Initialize
        reset_dut();

        //---------------------------------------------------------------------
        // Test 1: Reset State Verification
        //---------------------------------------------------------------------
        test_count = test_count + 1;
        $display("\n--- Test %0d: Reset State Verification ---", test_count);

        goto_reset_state();

        // Verify TDO is disabled in reset state
        @(posedge tck);
        if (tdo_en === 1'b0) begin
            pass_count = pass_count + 1;
            $display("PASS: TDO disabled in reset state");
        end else begin
            fail_count = fail_count + 1;
            $display("FAIL: TDO enabled in reset state");
        end

        //---------------------------------------------------------------------
        // Test 2: BYPASS Instruction Test
        //---------------------------------------------------------------------
        test_count = test_count + 1;
        $display("\n--- Test %0d: BYPASS Instruction Test ---", test_count);

        goto_idle_state();
        shift_ir(5'h00, captured_ir);  // BYPASS instruction

        // Shift single bit through BYPASS register
        shift_dr(1, 32'h1, captured_data);

        if (captured_data[0] === 1'b1) begin
            pass_count = pass_count + 1;
            $display("PASS: BYPASS register shifts correctly");
        end else begin
            fail_count = fail_count + 1;
            $display("FAIL: BYPASS register shift mismatch");
        end

        //---------------------------------------------------------------------
        // Test 3: IDCODE Instruction Test
        //---------------------------------------------------------------------
        test_count = test_count + 1;
        $display("\n--- Test %0d: IDCODE Instruction Test ---", test_count);

        goto_idle_state();
        shift_ir(5'h01, captured_ir);  // IDCODE instruction

        // Shift and capture IDCODE
        shift_dr(32, 32'h0, captured_data);

        if (captured_data === IDCODE_VALUE) begin
            pass_count = pass_count + 1;
            $display("PASS: IDCODE correct: %h (expected: %h)", captured_data, IDCODE_VALUE);
        end else begin
            fail_count = fail_count + 1;
            $display("FAIL: IDCODE mismatch: %h (expected: %h)", captured_data, IDCODE_VALUE);
        end

        //---------------------------------------------------------------------
        // Test 4: TEST_MODE Security Gating (Without Auth)
        //---------------------------------------------------------------------
        test_count = test_count + 1;
        $display("\n--- Test %0d: TEST_MODE Security Gating (No Auth) ---", test_count);

        // TEST_MODE disabled - sensitive instructions should be blocked
        disable_test_mode();

        goto_idle_state();
        shift_ir(5'h07, captured_ir);  // DEBUG instruction (should be blocked)

        // Should behave like BYPASS
        shift_dr(1, 32'h1, captured_data);

        if (captured_data[0] === 1'b1 && test_access_denied === 1'b1) begin
            pass_count = pass_count + 1;
            $display("PASS: DEBUG instruction blocked without TEST_MODE");
        end else begin
            fail_count = fail_count + 1;
            $display("FAIL: DEBUG instruction not blocked properly");
        end

        //---------------------------------------------------------------------
        // Test 5: TEST_MODE Security Gating (With Auth)
        //---------------------------------------------------------------------
        test_count = test_count + 1;
        $display("\n--- Test %0d: TEST_MODE Security Gating (With Auth) ---", test_count);

        // TEST_MODE enabled with authentication
        enable_test_mode();

        goto_idle_state();
        shift_ir(5'h07, captured_ir);  // DEBUG instruction (should be allowed)

        if (test_access_grant === 1'b1) begin
            pass_count = pass_count + 1;
            $display("PASS: DEBUG instruction allowed with TEST_MODE");
        end else begin
            fail_count = fail_count + 1;
            $display("FAIL: DEBUG instruction not allowed with TEST_MODE");
        end

        //---------------------------------------------------------------------
        // Test 6: Scan Chain Selection Test
        //---------------------------------------------------------------------
        test_count = test_count + 1;
        $display("\n--- Test %0d: Scan Chain Selection Test ---", test_count);

        enable_test_mode();

        goto_idle_state();
        shift_ir(5'h04, captured_ir);  // SCAN_IN instruction

        // Provide scan data: chain_select=SC2 (0x2), enable=1
        shift_dr(16, {4'h2, 1'b1, 11'b0}, captured_data);

        // Wait for update
        @(posedge tck);

        if (scan_select === 4'h2 && scan_enable === 1'b1) begin
            pass_count = pass_count + 1;
            $display("PASS: Scan chain SC2 selected correctly");
        end else begin
            fail_count = fail_count + 1;
            $display("FAIL: Scan chain selection mismatch: select=%h, enable=%b", scan_select, scan_enable);
        end

        //---------------------------------------------------------------------
        // Test 7: Boundary Scan Register Test
        //---------------------------------------------------------------------
        test_count = test_count + 1;
        $display("\n--- Test %0d: Boundary Scan Register Test ---", test_count);

        enable_test_mode();

        // Set boundary scan input data
        bsr_data_in = 24'hABCDEF;

        goto_idle_state();
        shift_ir(5'h02, captured_ir);  // EXTEST instruction

        // Capture and shift BSR
        shift_dr(24, 24'h0, captured_data);

        if (captured_data[23:0] === 24'hABCDEF) begin
            pass_count = pass_count + 1;
            $display("PASS: BSR capture correct: %h", captured_data[23:0]);
        end else begin
            fail_count = fail_count + 1;
            $display("FAIL: BSR capture mismatch: %h (expected: %h)", captured_data[23:0], 24'hABCDEF);
        end

        //---------------------------------------------------------------------
        // Test 8: Debug Access Test
        //---------------------------------------------------------------------
        test_count = test_count + 1;
        $display("\n--- Test %0d: Debug Access Test ---", test_count);

        enable_test_mode();

        // Set debug read data
        debug_data_out = 32'hDEADBEEF;
        debug_ack = 1'b1;

        goto_idle_state();
        shift_ir(5'h07, captured_ir);  // DEBUG instruction

        // Shift debug data: addr=0x1234, data (read)
        shift_dr(48, {16'h1234, 32'h0}, captured_data);

        if (captured_data[31:0] === 32'hDEADBEEF) begin
            pass_count = pass_count + 1;
            $display("PASS: Debug read data correct: %h", captured_data[31:0]);
        end else begin
            fail_count = fail_count + 1;
            $display("FAIL: Debug read data mismatch: %h (expected: %h)", captured_data[31:0], 32'hDEADBEEF);
        end

        //---------------------------------------------------------------------
        // Test 9: MBIST Control Test
        //---------------------------------------------------------------------
        test_count = test_count + 1;
        $display("\n--- Test %0d: MBIST Control Test ---", test_count);

        enable_test_mode();

        goto_idle_state();
        shift_ir(5'h08, captured_ir);  // MBIST_CTRL instruction

        // Shift MBIST control: start=1, stop=0, target=SRAM(0x0), algorithm=0x5
        shift_dr(32, {24'b0, 4'h5, 2'b00, 1'b0, 1'b1}, captured_data);

        if (mbist_start === 1'b1 && mbist_target === 2'b00 && mbist_algorithm === 4'h5) begin
            pass_count = pass_count + 1;
            $display("PASS: MBIST control correct: start=%b, target=%h, algorithm=%h", mbist_start, mbist_target, mbist_algorithm);
        end else begin
            fail_count = fail_count + 1;
            $display("FAIL: MBIST control mismatch");
        end

        //---------------------------------------------------------------------
        // Test 10: Secure Boot Authentication Test
        //---------------------------------------------------------------------
        test_count = test_count + 1;
        $display("\n--- Test %0d: Secure Boot Authentication Test ---", test_count);

        // Secure Boot enabled, need authentication
        sec_boot_en = 1'b1;
        test_mode_en = 1'b1;
        test_mode_valid = 1'b0;  // Not authenticated yet

        @(posedge tck);
        @(posedge tck);

        if (test_access_grant === 1'b0) begin
            pass_count = pass_count + 1;
            $display("PASS: Access blocked without authentication");
        end else begin
            fail_count = fail_count + 1;
            $display("FAIL: Access granted without authentication");
        end

        // Now authenticate
        test_mode_valid = 1'b1;
        @(posedge tck);
        @(posedge tck);

        if (test_access_grant === 1'b1) begin
            pass_count = pass_count + 1;
            $display("PASS: Access granted after authentication");
        end else begin
            fail_count = fail_count + 1;
            $display("FAIL: Access not granted after authentication");
        end

        //---------------------------------------------------------------------
        // Test Summary
        //---------------------------------------------------------------------

        $display("\n========================================");
        $display("Test Summary");
        $display("========================================");
        $display("Total Tests:  %0d", test_count);
        $display("Passed:       %0d", pass_count);
        $display("Failed:       %0d", fail_count);
        $display("Pass Rate:    %0.1f%%", (pass_count * 100.0) / test_count);
        $display("========================================");

        if (fail_count == 0)
            $display("All tests PASSED!");
        else
            $display("Some tests FAILED!");

        $finish;
    end

    //=========================================================================
    // Waveform Dump (for debugging)
    //=========================================================================

    initial begin
        $dumpfile("tb_M15_JTAGInterface.vcd");
        $dumpvars(0, tb_M15_JTAGInterface);
    end

    //=========================================================================
    // Timeout
    //=========================================================================

    initial begin
        #100000;
        $display("ERROR: Simulation timeout");
        $finish;
    end

endmodule