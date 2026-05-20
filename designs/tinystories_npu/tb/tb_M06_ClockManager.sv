//=============================================================================
// Testbench: M06_ClockManager
// Cycle-based testbench for Verilator coverage collection
//-----------------------------------------------------------------------------

module tb_M06_ClockManager (
    input logic ext_clk_i_ext  // External clock from C++
);

    //=========================================================================
    // Signals
    //=========================================================================
    logic ext_clk_i;
    logic pll_lock_i;
    logic [1:0] dvfs_op_i;
    logic dvfs_req_i;
    logic [13:0] clk_gating_en_i;
    logic pd_aon_vdd_i;

    logic clk_sys_o;
    logic clk_aon_o;
    logic clk_io_o;
    logic [13:0] clk_gating_o;

    logic dvfs_ack_o;
    logic [2:0] clk_status_o;
    logic pll_pwr_en_o;

    //=========================================================================
    // DUT Instance
    //=========================================================================
    M06_ClockManager dut (
        .ext_clk_i(ext_clk_i),
        .pll_lock_i(pll_lock_i),
        .dvfs_op_i(dvfs_op_i),
        .dvfs_req_i(dvfs_req_i),
        .clk_gating_en_i(clk_gating_en_i),
        .pd_aon_vdd_i(pd_aon_vdd_i),
        .clk_sys_o(clk_sys_o),
        .clk_aon_o(clk_aon_o),
        .clk_io_o(clk_io_o),
        .clk_gating_o(clk_gating_o),
        .dvfs_ack_o(dvfs_ack_o),
        .clk_status_o(clk_status_o),
        .pll_pwr_en_o(pll_pwr_en_o)
    );

    //=========================================================================
    // Clock Assignment
    //=========================================================================
    assign ext_clk_i = ext_clk_i_ext;

    //=========================================================================
    // Test FSM States
    //=========================================================================
    typedef enum {
        INIT, RESET,
        TEST_CLK_GENERATION_OP0, TEST_CLK_GENERATION_OP1,
        TEST_CLK_GENERATION_OP2,
        TEST_CLK_GATING, TEST_DVFS_TRANSITION,
        TEST_PLL_LOCK_WAIT, TEST_STATUS_CHECK,
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
        pll_lock_i = 1;
        dvfs_op_i = 0;
        dvfs_req_i = 0;
        clk_gating_en_i = 14'h3FFF;
        pd_aon_vdd_i = 1;

        state = RESET;
        repeat(10) @(posedge ext_clk_i);

        // Test Clock Generation OP0 (500 MHz)
        state = TEST_CLK_GENERATION_OP0;
        dvfs_op_i = 0;  // OP0
        dvfs_req_i = 1;
        repeat(20) @(posedge ext_clk_i);
        dvfs_req_i = 0;
        wait_counter = 0;
        while (!dvfs_ack_o && wait_counter < 100) begin
            @(posedge ext_clk_i);
            wait_counter++;
        end
        test_pass_count++;

        // Test Clock Generation OP1 (250 MHz)
        state = TEST_CLK_GENERATION_OP1;
        dvfs_op_i = 1;  // OP1
        dvfs_req_i = 1;
        repeat(20) @(posedge ext_clk_i);
        dvfs_req_i = 0;
        repeat(100) @(posedge ext_clk_i);

        // Test Clock Generation OP2 (1 MHz AON)
        state = TEST_CLK_GENERATION_OP2;
        dvfs_op_i = 2;  // OP2
        dvfs_req_i = 1;
        pll_lock_i = 1;
        repeat(20) @(posedge ext_clk_i);
        dvfs_req_i = 0;
        repeat(100) @(posedge ext_clk_i);

        // Test Clock Gating
        state = TEST_CLK_GATING;
        for (int i = 0; i < 14; i++) begin
            clk_gating_en_i = (1 << i);
            repeat(20) @(posedge ext_clk_i);
        end
        clk_gating_en_i = 14'h0000;
        repeat(20) @(posedge ext_clk_i);
        clk_gating_en_i = 14'h3FFF;

        // Test DVFS Transition
        state = TEST_DVFS_TRANSITION;
        dvfs_op_i = 0;
        dvfs_req_i = 1;
        repeat(20) @(posedge ext_clk_i);
        dvfs_req_i = 0;
        repeat(100) @(posedge ext_clk_i);
        dvfs_op_i = 1;
        dvfs_req_i = 1;
        repeat(20) @(posedge ext_clk_i);
        dvfs_req_i = 0;
        repeat(100) @(posedge ext_clk_i);

        // Test PLL Lock Wait
        state = TEST_PLL_LOCK_WAIT;
        pll_lock_i = 0;
        dvfs_req_i = 1;
        repeat(100) @(posedge ext_clk_i);
        pll_lock_i = 1;
        repeat(100) @(posedge ext_clk_i);

        // Test Status Check
        state = TEST_STATUS_CHECK;
        repeat(50) @(posedge ext_clk_i);

        state = DONE;
        repeat(10) @(posedge ext_clk_i);
    end

endmodule