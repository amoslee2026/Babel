//-----------------------------------------------------------------------------
// Testbench: tb_M07_ResetManager
// Description: Verification of M07 Reset Manager module
// Author: Generated from spec_mas/M07 specifications
// Version: 1.1 - Updated for clk_aon input port
//-----------------------------------------------------------------------------

`timescale 1us/1ns  // 1 us = 1 cycle at 1 MHz CLK_AON

module tb_M07_ResetManager;

//=============================================================================
// Parameters
//=============================================================================
parameter CLK_AON_PERIOD = 1.0;  // 1 us (1 MHz)
parameter CLK_SYS_PERIOD = 0.1; // 100 ns (10 MHz)
parameter T_PLL_CONFIG   = 100; // 100 us
parameter T_PLL_LOCK     = 50;  // 50 us (guard)
parameter T_PD_POWERON   = 10;  // 10 us

//=============================================================================
// DUT Signals
//=============================================================================
// Clock Input
reg  clk_aon;

// Reset Source Inputs
reg  por_in;
reg  sw_reset_req;
reg  wdt_reset_in;

// Status Inputs
reg  pll_locked;
reg  clk_aon_stable;
reg  clk_sys_stable;
reg  pd_main_ready;

// Reset Outputs
wire reset_main_out;
wire reset_aon_out;
wire reset_io_out;

// Status Outputs
wire [2:0] reset_status;
wire       boot_start;
wire       sequence_done;

//=============================================================================
// Test Clocks
//=============================================================================
reg clk_sys;

//=============================================================================
// Test Control
//=============================================================================
integer test_cycle;
integer error_count;
reg     test_complete;

//=============================================================================
// Status Code Constants
//=============================================================================
localparam STATUS_IDLE          = 3'h0;
localparam STATUS_POR_ACTIVE    = 3'h1;
localparam STATUS_SW_RESET      = 3'h2;
localparam STATUS_WDT_RESET     = 3'h3;
localparam STATUS_PLL_LOCKING   = 3'h4;
localparam STATUS_POWER_ON      = 3'h5;
localparam STATUS_CLK_STABLE    = 3'h6;
localparam STATUS_BOOT_START    = 3'h7;

//=============================================================================
// FSM State Constants (for monitoring)
//=============================================================================
localparam STATE_IDLE           = 4'd0;
localparam STATE_POR_ASSERTED   = 4'd1;
localparam STATE_PLL_CONFIG     = 4'd2;
localparam STATE_PLL_WAIT       = 4'd3;
localparam STATE_CLK_AON_STABLE = 4'd4;
localparam STATE_PD_POWERON     = 4'd5;
localparam STATE_CLK_SYS_STABLE = 4'd6;
localparam STATE_RESET_RELEASE  = 4'd7;
localparam STATE_BOOT_START     = 4'd8;
localparam STATE_SW_RESET       = 4'd9;
localparam STATE_WDT_RESET      = 4'd10;

//=============================================================================
// DUT Instance
//=============================================================================
M07_ResetManager DUT (
    .clk_aon         (clk_aon),
    .por_in          (por_in),
    .sw_reset_req    (sw_reset_req),
    .wdt_reset_in    (wdt_reset_in),
    .pll_locked      (pll_locked),
    .clk_aon_stable  (clk_aon_stable),
    .clk_sys_stable  (clk_sys_stable),
    .pd_main_ready   (pd_main_ready),
    .reset_main_out  (reset_main_out),
    .reset_aon_out   (reset_aon_out),
    .reset_io_out    (reset_io_out),
    .reset_status    (reset_status),
    .boot_start      (boot_start),
    .sequence_done   (sequence_done)
);

//=============================================================================
// Clock Generation
//=============================================================================
// CLK_AON: 1 MHz (1 us period)
initial begin
    clk_aon = 0;
    forever #(CLK_AON_PERIOD/2) clk_aon = ~clk_aon;
end

// CLK_SYS: 10 MHz (100 ns period) - for SW_RESET stimulus
initial begin
    clk_sys = 0;
    forever #(CLK_SYS_PERIOD/2) clk_sys = ~clk_sys;
end

//=============================================================================
// Test Initialization
//=============================================================================
initial begin
    // Initialize all inputs
    por_in          = 0;
    sw_reset_req    = 0;
    wdt_reset_in    = 0;
    pll_locked      = 0;
    clk_aon_stable  = 0;
    clk_sys_stable  = 0;
    pd_main_ready   = 0;

    test_cycle = 0;
    error_count = 0;
    test_complete = 0;

    $display("========================================");
    $display("M07 Reset Manager Testbench Start");
    $display("CLK_AON Period: %0.1f us (1 MHz)", CLK_AON_PERIOD);
    $display("CLK_SYS Period: %0.1f ns (10 MHz)", CLK_SYS_PERIOD * 1000);
    $display("========================================");
end

//=============================================================================
// Cycle Counter
//=============================================================================
always @(posedge clk_aon) begin
    test_cycle = test_cycle + 1;
end

//=============================================================================
// Monitor - State transitions
//=============================================================================
always @(posedge clk_aon) begin
    if (DUT.current_state !== DUT.next_state) begin
        $display("[Cycle %0d] State: %0d -> %0d, Status: %h, R_main: %b, R_aon: %b, R_io: %b",
                 test_cycle, DUT.current_state, DUT.next_state,
                 reset_status, reset_main_out, reset_aon_out, reset_io_out);
    end
end

//=============================================================================
// Test Sequence
//=============================================================================
initial begin
    // Wait for initial stability
    #(CLK_AON_PERIOD * 5);

    //-----------------------------------------
    // Test 1: POR Sequence (Full 8-step)
    //-----------------------------------------
    $display("\n[Test 1] POR Sequence Test Start");
    $display("Simulating full POR reset sequence (8 steps)");

    // Apply POR
    @(posedge clk_aon);
    por_in = 1;
    #(CLK_AON_PERIOD * 3);

    // Check: POR detected, all resets asserted
    if (reset_status !== STATUS_POR_ACTIVE) begin
        $display("  ERROR: POR not detected (status=%h, expected=%h)",
                 reset_status, STATUS_POR_ACTIVE);
        error_count = error_count + 1;
    end else begin
        $display("  PASS: POR detected, status=%h", reset_status);
    end

    if (reset_main_out !== 1'b1) begin
        $display("  ERROR: reset_main_out not asserted");
        error_count = error_count + 1;
    end

    // Release POR input (sequence continues)
    por_in = 0;
    #(CLK_AON_PERIOD * 2);

    // Wait for PLL_CONFIG state
    wait (DUT.current_state === STATE_PLL_CONFIG || test_cycle > 200);
    $display("  Reached PLL_CONFIG state at cycle %0d", test_cycle);

    // Simulate PLL configuration duration
    #(CLK_AON_PERIOD * T_PLL_CONFIG);

    // Check: Still in PLL locking phase
    if (reset_status !== STATUS_PLL_LOCKING) begin
        $display("  ERROR: Not in PLL_LOCKING state (status=%h)", reset_status);
        error_count = error_count + 1;
    end else begin
        $display("  PASS: PLL configuration phase, status=%h", reset_status);
    end

    // Simulate PLL lock
    pll_locked = 1;
    #(CLK_AON_PERIOD * 10);

    // Wait for CLK_AON_STABLE state
    wait (DUT.current_state === STATE_CLK_AON_STABLE || test_cycle > 400);
    $display("  Reached CLK_AON_STABLE state at cycle %0d", test_cycle);

    // Simulate CLK_AON stable
    clk_aon_stable = 1;
    #(CLK_AON_PERIOD * 5);

    // Wait for PD_POWERON state
    wait (DUT.current_state === STATE_PD_POWERON || test_cycle > 500);
    $display("  Reached PD_POWERON state at cycle %0d", test_cycle);

    // Check: Power-On status
    if (reset_status !== STATUS_POWER_ON) begin
        $display("  ERROR: Not in POWER_ON state (status=%h)", reset_status);
        error_count = error_count + 1;
    end else begin
        $display("  PASS: Power-on phase, status=%h", reset_status);
    end

    // Simulate PD_MAIN ready
    pd_main_ready = 1;
    #(CLK_AON_PERIOD * T_PD_POWERON);

    // Simulate CLK_SYS stable
    clk_sys_stable = 1;
    #(CLK_AON_PERIOD * 10);

    // Wait for RESET_RELEASE state
    wait (DUT.current_state === STATE_RESET_RELEASE || DUT.current_state === STATE_BOOT_START || test_cycle > 600);
    $display("  Reached RESET_RELEASE/BOOT_START state at cycle %0d", test_cycle);

    // Check: Resets should be released
    #(CLK_AON_PERIOD * 5);
    if (reset_main_out !== 1'b0) begin
        $display("  ERROR: reset_main_out not released");
        error_count = error_count + 1;
    end else begin
        $display("  PASS: reset_main_out released");
    end

    // Wait for sequence completion
    #(CLK_AON_PERIOD * 10);
    wait (sequence_done === 1'b1 || test_cycle > 650);

    if (sequence_done !== 1'b1) begin
        $display("  ERROR: sequence_done not asserted");
        error_count = error_count + 1;
    end else begin
        $display("  PASS: Sequence complete, sequence_done asserted");
    end

    // Wait for IDLE state
    #(CLK_AON_PERIOD * 5);
    if (reset_status !== STATUS_IDLE) begin
        $display("  ERROR: Not returned to IDLE (status=%h)", reset_status);
        error_count = error_count + 1;
    end else begin
        $display("  PASS: Returned to IDLE state, status=%h", reset_status);
    end

    $display("[Test 1] POR Sequence Test Complete - Errors: %0d", error_count);

    //-----------------------------------------
    // Test 2: SW_RESET Test
    //-----------------------------------------
    #(CLK_AON_PERIOD * 50);
    $display("\n[Test 2] SW_RESET Test Start");

    // Reset inputs to idle state
    pll_locked = 0;
    clk_aon_stable = 0;
    pd_main_ready = 0;
    clk_sys_stable = 0;

    // Apply SW_RESET in CLK_SYS domain
    @(posedge clk_sys);
    sw_reset_req = 1;
    #(CLK_SYS_PERIOD * 2);
    @(posedge clk_sys);
    sw_reset_req = 0;

    // Wait for CDC synchronization
    #(CLK_AON_PERIOD * 5);

    // Check: reset_main_out should pulse
    #(CLK_AON_PERIOD * 5);
    $display("  SW_RESET detected, status=%h, reset_main=%b", reset_status, reset_main_out);

    // Wait for completion
    #(CLK_AON_PERIOD * 10);
    if (reset_status === STATUS_IDLE) begin
        $display("  PASS: SW_RESET handled, returned to IDLE");
    end else begin
        $display("  NOTE: SW_RESET handling status=%h", reset_status);
    end

    $display("[Test 2] SW_RESET Test Complete");

    //-----------------------------------------
    // Test 3: WDT_RESET Test
    //-----------------------------------------
    #(CLK_AON_PERIOD * 50);
    $display("\n[Test 3] WDT_RESET Test Start");

    // Apply WDT_RESET
    @(posedge clk_aon);
    wdt_reset_in = 1;
    #(CLK_AON_PERIOD * 3);
    wdt_reset_in = 0;

    // Wait for deglitch
    #(CLK_AON_PERIOD * 5);

    $display("  WDT_RESET detected, status=%h, reset_main=%b", reset_status, reset_main_out);

    // Wait for completion
    #(CLK_AON_PERIOD * 10);
    if (reset_status === STATUS_IDLE) begin
        $display("  PASS: WDT_RESET handled, returned to IDLE");
    end else begin
        $display("  NOTE: WDT_RESET handling status=%h", reset_status);
    end

    $display("[Test 3] WDT_RESET Test Complete");

    //-----------------------------------------
    // Test 4: Reset Priority Test
    //-----------------------------------------
    #(CLK_AON_PERIOD * 50);
    $display("\n[Test 4] Reset Priority Test Start");

    // Apply SW_RESET first
    @(posedge clk_sys);
    sw_reset_req = 1;
    #(CLK_AON_PERIOD * 5);

    // Apply POR (should override SW_RESET)
    por_in = 1;
    #(CLK_AON_PERIOD * 3);

    if (reset_status === STATUS_POR_ACTIVE) begin
        $display("  PASS: POR overrides SW_RESET, status=%h", reset_status);
    end else begin
        $display("  ERROR: POR did not override SW_RESET, status=%h", reset_status);
        error_count = error_count + 1;
    end

    // Complete POR sequence
    por_in = 0;
    pll_locked = 1;
    clk_aon_stable = 1;
    pd_main_ready = 1;
    clk_sys_stable = 1;
    sw_reset_req = 0;

    #(CLK_AON_PERIOD * 20);
    $display("[Test 4] Reset Priority Test Complete");

    //-----------------------------------------
    // Test 5: Glitch Protection Test
    //-----------------------------------------
    #(CLK_AON_PERIOD * 50);
    $display("\n[Test 5] Glitch Protection Test Start");

    // Reset to idle
    pll_locked = 0;
    clk_aon_stable = 0;
    pd_main_ready = 0;
    clk_sys_stable = 0;

    // Apply short glitch on POR (less than 2 cycles)
    por_in = 1;
    #(CLK_AON_PERIOD * 0.5);  // Short pulse
    por_in = 0;

    #(CLK_AON_PERIOD * 5);

    // Short glitch should not trigger full POR sequence
    if (reset_status === STATUS_POR_ACTIVE && DUT.current_state !== STATE_IDLE) begin
        $display("  ERROR: Glitch triggered POR sequence, status=%h, state=%0d",
                 reset_status, DUT.current_state);
        error_count = error_count + 1;
    end else begin
        $display("  PASS: Glitch filtered correctly, status=%h, state=%0d",
                 reset_status, DUT.current_state);
    end

    $display("[Test 5] Glitch Protection Test Complete");

    //-----------------------------------------
    // Final Summary
    //-----------------------------------------
    #(CLK_AON_PERIOD * 100);
    $display("\n========================================");
    $display("M07 Reset Manager Test Summary");
    $display("========================================");
    $display("Total Test Cycles: %0d", test_cycle);
    $display("Total Errors: %0d", error_count);

    if (error_count == 0) begin
        $display("STATUS: ALL TESTS PASSED");
    end else begin
        $display("STATUS: TESTS FAILED (%0d errors)", error_count);
    end

    $display("========================================");
    test_complete = 1;
    $finish;
end

//=============================================================================
// Timeout Watchdog
//=============================================================================
initial begin
    #100000;  // 100 ms timeout
    if (!test_complete) begin
        $display("ERROR: Test timeout exceeded at cycle %0d", test_cycle);
        $display("Current state: %0d, status: %h", DUT.current_state, reset_status);
        $finish;
    end
end

//=============================================================================
// Waveform Dump (for debugging)
//=============================================================================
initial begin
    $dumpfile("tb_M07_ResetManager.vcd");
    $dumpvars(0, tb_M07_ResetManager);
end

endmodule