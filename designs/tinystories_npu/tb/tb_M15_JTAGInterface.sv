//=============================================================================
// Testbench: M15_JTAGInterface
// Cycle-based testbench for Verilator coverage collection
//-----------------------------------------------------------------------------

module tb_M15_JTAGInterface (
    input logic tck_ext  // External JTAG clock from C++
);

    //=========================================================================
    // Signals
    //=========================================================================
    logic tck;
    logic tms;
    logic tdi;
    logic tdo;
    logic trst_n;
    logic tdo_en;

    // TEST_MODE Security
    logic test_mode_en;
    logic test_mode_valid;
    logic sec_boot_en;
    logic test_access_grant;
    logic test_access_denied;

    // Scan Chain
    logic [3:0] scan_select;
    logic scan_enable;
    logic scan_in;
    logic scan_out;
    logic scan_capture;
    logic scan_update;

    // Boundary Scan
    logic bsr_select;
    logic bsr_capture;
    logic bsr_update;
    logic [23:0] bsr_data_in;
    logic [23:0] bsr_data_out;

    // Debug Interface
    logic [15:0] debug_addr;
    logic [31:0] debug_data_in;
    logic [31:0] debug_data_out;
    logic debug_rw;
    logic debug_valid;
    logic debug_ack;

    // MBIST
    logic mbist_start;
    logic mbist_stop;
    logic [1:0] mbist_target;
    logic [3:0] mbist_algorithm;
    logic [23:0] mbist_status;

    // System Reset
    logic rst_io_n;

    //=========================================================================
    // DUT Instance
    //=========================================================================
    M15_JTAGInterface dut (
        .tck(tck),
        .tms(tms),
        .tdi(tdi),
        .tdo(tdo),
        .trst_n(trst_n),
        .tdo_en(tdo_en),
        .test_mode_en(test_mode_en),
        .test_mode_valid(test_mode_valid),
        .sec_boot_en(sec_boot_en),
        .test_access_grant(test_access_grant),
        .test_access_denied(test_access_denied),
        .scan_select(scan_select),
        .scan_enable(scan_enable),
        .scan_in(scan_in),
        .scan_out(scan_out),
        .scan_capture(scan_capture),
        .scan_update(scan_update),
        .bsr_select(bsr_select),
        .bsr_capture(bsr_capture),
        .bsr_update(bsr_update),
        .bsr_data_in(bsr_data_in),
        .bsr_data_out(bsr_data_out),
        .debug_addr(debug_addr),
        .debug_data_in(debug_data_in),
        .debug_data_out(debug_data_out),
        .debug_rw(debug_rw),
        .debug_valid(debug_valid),
        .debug_ack(debug_ack),
        .mbist_start(mbist_start),
        .mbist_stop(mbist_stop),
        .mbist_target(mbist_target),
        .mbist_algorithm(mbist_algorithm),
        .mbist_status(mbist_status),
        .rst_io_n(rst_io_n)
    );

    //=========================================================================
    // Clock Assignment
    //=========================================================================
    assign tck = tck_ext;

    //=========================================================================
    // Response Simulation
    //=========================================================================
    always_ff @(posedge tck) begin
        // Debug response
        if (debug_valid) begin
            debug_ack <= 1;
            debug_data_out <= 32'hCAFE_BEEF;
        end else begin
            debug_ack <= 0;
        end

        // MBIST status
        mbist_status <= 24'h000080;
    end

    //=========================================================================
    // Test FSM States
    //=========================================================================
    typedef enum {
        INIT, RESET,
        TEST_TAP_STATES, TEST_INSTRUCTION_SCAN,
        TEST_DATA_SCAN, TEST_DEBUG_ACCESS,
        TEST_MBIST, TEST_BOUNDARY_SCAN,
        TEST_TEST_MODE_SECURITY, TEST_RESET_SEQUENCE,
        DONE
    } test_state_t;

    test_state_t state;
    int test_pass_count;
    int tms_sequence_idx;

    //=========================================================================
    // Test Stimulus
    //=========================================================================
    initial begin
        state = INIT;
        test_pass_count = 0;
        tms_sequence_idx = 0;

        // Initialize signals
        trst_n = 0;
        tms = 0;
        tdi = 0;
        rst_io_n = 1;
        test_mode_en = 0;
        test_mode_valid = 0;
        sec_boot_en = 1;
        scan_out = 0;
        bsr_data_in = 24'h000000;
        debug_ack = 0;
        debug_data_out = 0;

        // Reset phase
        repeat(10) @(posedge tck);
        trst_n = 1;
        state = RESET;
        repeat(10) @(posedge tck);

        // Test TAP State Machine (walk through all states)
        state = TEST_TAP_STATES;
        // Test-Logic-Reset -> Run-Test/Idle
        tms = 0;
        repeat(5) @(posedge tck);
        // Run-Test/Idle -> Select-DR-Scan
        tms = 1;
        repeat(2) @(posedge tck);
        // Select-DR-Scan -> Capture-DR
        tms = 0;
        repeat(2) @(posedge tck);
        // Capture-DR -> Shift-DR
        tms = 0;
        repeat(5) @(posedge tck);
        // Shift-DR -> Exit1-DR
        tms = 1;
        repeat(2) @(posedge tck);
        // Exit1-DR -> Update-DR
        tms = 1;
        repeat(2) @(posedge tck);
        // Update-DR -> Run-Test/Idle
        tms = 0;
        repeat(5) @(posedge tck);

        // Test Instruction Scan
        state = TEST_INSTRUCTION_SCAN;
        // Go to Select-IR-Scan
        tms = 1;
        repeat(2) @(posedge tck);
        tms = 1;
        repeat(2) @(posedge tck);
        // Capture-IR
        tms = 0;
        repeat(2) @(posedge tck);
        // Shift-IR
        tms = 0;
        tdi = 1;
        repeat(10) @(posedge tck);
        // Exit1-IR
        tms = 1;
        repeat(2) @(posedge tck);
        // Update-IR
        tms = 1;
        repeat(2) @(posedge tck);
        // Return to Run-Test/Idle
        tms = 0;
        tdi = 0;
        repeat(5) @(posedge tck);

        // Test Data Scan
        state = TEST_DATA_SCAN;
        // Select-DR-Scan
        tms = 1;
        repeat(2) @(posedge tck);
        tms = 0;
        repeat(2) @(posedge tck);
        // Shift-DR
        tms = 0;
        for (int i = 0; i < 32; i++) begin
            tdi = i[0];
            repeat(1) @(posedge tck);
        end
        // Exit and Update
        tms = 1;
        repeat(2) @(posedge tck);
        tms = 1;
        repeat(2) @(posedge tck);
        tms = 0;
        repeat(5) @(posedge tck);

        // Test Debug Access
        state = TEST_DEBUG_ACCESS;
        repeat(100) @(posedge tck);

        // Test MBIST
        state = TEST_MBIST;
        repeat(100) @(posedge tck);

        // Test Boundary Scan
        state = TEST_BOUNDARY_SCAN;
        bsr_data_in = 24'hFFFFFF;
        repeat(50) @(posedge tck);

        // Test TEST_MODE Security
        state = TEST_TEST_MODE_SECURITY;
        test_mode_en = 1;
        test_mode_valid = 1;
        repeat(50) @(posedge tck);
        test_mode_en = 0;
        repeat(50) @(posedge tck);

        // Test Reset Sequence
        state = TEST_RESET_SEQUENCE;
        trst_n = 0;
        repeat(10) @(posedge tck);
        trst_n = 1;
        repeat(20) @(posedge tck);

        state = DONE;
        repeat(10) @(posedge tck);
    end

endmodule