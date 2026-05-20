//=============================================================================
// Testbench: M07_ResetManager
// Cycle-based testbench for Verilator coverage collection
//-----------------------------------------------------------------------------

module tb_M07_ResetManager (
    input logic clk_aon_ext  // External clock from C++
);

    //=========================================================================
    // Signals
    //=========================================================================
    logic clk_aon;

    // Reset Sources
    logic por_in;
    logic sw_reset_req;
    logic wdt_reset_in;

    // Status Inputs
    logic pll_locked;
    logic clk_aon_stable;
    logic clk_sys_stable;
    logic pd_main_ready;

    // Reset Outputs
    logic reset_main_out;
    logic reset_aon_out;
    logic reset_io_out;

    // Status Outputs
    logic [2:0] reset_status;
    logic boot_start;
    logic sequence_done;

    //=========================================================================
    // DUT Instance
    //=========================================================================
    M07_ResetManager dut (
        .clk_aon(clk_aon),
        .por_in(por_in),
        .sw_reset_req(sw_reset_req),
        .wdt_reset_in(wdt_reset_in),
        .pll_locked(pll_locked),
        .clk_aon_stable(clk_aon_stable),
        .clk_sys_stable(clk_sys_stable),
        .pd_main_ready(pd_main_ready),
        .reset_main_out(reset_main_out),
        .reset_aon_out(reset_aon_out),
        .reset_io_out(reset_io_out),
        .reset_status(reset_status),
        .boot_start(boot_start),
        .sequence_done(sequence_done)
    );

    //=========================================================================
    // Clock Assignment
    //=========================================================================
    assign clk_aon = clk_aon_ext;

    //=========================================================================
    // Test FSM States
    //=========================================================================
    typedef enum {
        INIT, RESET,
        TEST_POR_SEQUENCE, TEST_SW_RESET,
        TEST_WDT_RESET, TEST_PLL_WAIT,
        TEST_BOOT_SEQUENCE, TEST_STATUS_CHECK,
        DONE
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
        por_in = 1;  // POR not asserted (active low assumed)
        sw_reset_req = 0;
        wdt_reset_in = 0;
        pll_locked = 0;
        clk_aon_stable = 0;
        clk_sys_stable = 0;
        pd_main_ready = 0;

        state = RESET;
        repeat(10) @(posedge clk_aon);

        // Test POR Sequence
        state = TEST_POR_SEQUENCE;
        por_in = 0;  // Assert POR
        repeat(10) @(posedge clk_aon);
        por_in = 1;  // Deassert POR
        repeat(20) @(posedge clk_aon);

        // Simulate PLL locking
        pll_locked = 1;
        repeat(50) @(posedge clk_aon);

        // Simulate clock stabilization
        clk_aon_stable = 1;
        repeat(20) @(posedge clk_aon);
        clk_sys_stable = 1;
        repeat(20) @(posedge clk_aon);

        // Simulate PD_MAIN ready
        pd_main_ready = 1;
        repeat(100) @(posedge clk_aon);

        // Wait for sequence_done
        wait_counter = 0;
        while (!sequence_done && wait_counter < 200) begin
            @(posedge clk_aon);
            wait_counter++;
        end
        if (sequence_done) test_pass_count++;

        // Test Boot Start
        state = TEST_BOOT_SEQUENCE;
        repeat(50) @(posedge clk_aon);
        if (boot_start) test_pass_count++;

        // Test Software Reset
        state = TEST_SW_RESET;
        sw_reset_req = 1;
        repeat(20) @(posedge clk_aon);
        sw_reset_req = 0;
        repeat(100) @(posedge clk_aon);

        // Re-stabilize
        pll_locked = 1;
        clk_aon_stable = 1;
        clk_sys_stable = 1;
        pd_main_ready = 1;
        repeat(100) @(posedge clk_aon);

        // Test Watchdog Reset
        state = TEST_WDT_RESET;
        wdt_reset_in = 1;
        repeat(20) @(posedge clk_aon);
        wdt_reset_in = 0;
        repeat(100) @(posedge clk_aon);

        // Test PLL Wait
        state = TEST_PLL_WAIT;
        pll_locked = 0;
        por_in = 0;
        repeat(10) @(posedge clk_aon);
        por_in = 1;
        repeat(50) @(posedge clk_aon);
        pll_locked = 1;
        repeat(100) @(posedge clk_aon);

        // Test Status Check
        state = TEST_STATUS_CHECK;
        repeat(50) @(posedge clk_aon);

        state = DONE;
        repeat(10) @(posedge clk_aon);
    end

endmodule