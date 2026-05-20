//=============================================================================
// Testbench: M05_PowerManager
// Cycle-based testbench for Verilator coverage collection
//-----------------------------------------------------------------------------

module tb_M05_PowerManager (
    input logic clk_aon_ext  // External clock from C++
);

    //=========================================================================
    // Signals
    //=========================================================================
    logic clk_aon;
    logic rst_aon_n;
    logic rst_por_n;

    // Bus Interface
    logic bus_cmd_valid;
    logic bus_cmd_ready;
    logic [15:0] bus_cmd_addr;
    logic bus_cmd_rw;
    logic [31:0] bus_cmd_data;
    logic bus_rsp_valid;
    logic [31:0] bus_rsp_data;
    logic bus_rsp_error;

    // DVFS Control
    logic [1:0] dvfs_op_req;
    logic dvfs_op_ack;
    logic dvfs_busy;

    // Power Gate Control
    logic pg_main_en;
    logic pg_main_status;
    logic pg_main_switch;
    logic pg_iso_en;

    // Power Mode
    logic [1:0] pmode_state;
    logic [1:0] pmode_req;
    logic pmode_ack;
    logic pmode_error;

    // Wakeup
    logic [7:0] wakeup_ext;
    logic [7:0] wakeup_en;
    logic [7:0] wakeup_status;
    logic wakeup_pending;
    logic wakeup_clear;

    // Power Estimator
    logic [15:0] pwr_estimate;
    logic [15:0] pwr_budget;
    logic pwr_alert;

    // Activity Monitoring
    logic activity_main;
    logic activity_io;
    logic activity_dram;
    logic [15:0] idle_timeout;
    logic idle_detected;

    // Status
    logic [7:0] pm_status;

    //=========================================================================
    // DUT Instance
    //=========================================================================
    M05_PowerManager dut (
        .clk_aon(clk_aon),
        .rst_aon_n(rst_aon_n),
        .rst_por_n(rst_por_n),
        .bus_cmd_valid(bus_cmd_valid),
        .bus_cmd_ready(bus_cmd_ready),
        .bus_cmd_addr(bus_cmd_addr),
        .bus_cmd_rw(bus_cmd_rw),
        .bus_cmd_data(bus_cmd_data),
        .bus_rsp_valid(bus_rsp_valid),
        .bus_rsp_data(bus_rsp_data),
        .bus_rsp_error(bus_rsp_error),
        .dvfs_op_req(dvfs_op_req),
        .dvfs_op_ack(dvfs_op_ack),
        .dvfs_vdd_req(),
        .dvfs_freq_req(),
        .dvfs_busy(dvfs_busy),
        .vdd_main_set(),
        .vdd_main_ack(1),
        .vdd_main_ready(1),
        .vdd_main_error(0),
        .pg_main_en(pg_main_en),
        .pg_main_status(pg_main_status),
        .pg_main_switch(pg_main_switch),
        .pg_iso_en(pg_iso_en),
        .pmode_state(pmode_state),
        .pmode_req(pmode_req),
        .pmode_ack(pmode_ack),
        .pmode_error(pmode_error),
        .wakeup_ext(wakeup_ext),
        .wakeup_en(wakeup_en),
        .wakeup_status(wakeup_status),
        .wakeup_pending(wakeup_pending),
        .wakeup_clear(wakeup_clear),
        .pwr_estimate(pwr_estimate),
        .pwr_budget(pwr_budget),
        .pwr_alert(pwr_alert),
        .pwr_counters(),
        .activity_main(activity_main),
        .activity_io(activity_io),
        .activity_dram(activity_dram),
        .idle_timeout(idle_timeout),
        .idle_detected(idle_detected),
        .pm_status(pm_status),
        .pm_irq(),
        .pm_irq_type()
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
        TEST_DVFS_OP0, TEST_DVFS_OP1, TEST_DVFS_OP2,
        TEST_POWER_GATE, TEST_POWER_MODE_ACTIVE,
        TEST_POWER_MODE_SLEEP, TEST_WAKEUP,
        TEST_POWER_ESTIMATOR, TEST_IDLE_DETECT,
        TEST_BUS_READ, TEST_BUS_WRITE,
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
        rst_aon_n = 0;
        rst_por_n = 0;
        bus_cmd_valid = 0;
        bus_cmd_addr = 0;
        bus_cmd_rw = 0;
        bus_cmd_data = 0;
        dvfs_op_ack = 1;
        dvfs_busy = 0;
        pg_main_status = 1;
        pmode_req = 0;
        wakeup_ext = 0;
        wakeup_clear = 0;
        pwr_budget = 1000;
        activity_main = 1;
        activity_io = 0;
        activity_dram = 0;
        idle_timeout = 100;

        // Reset phase
        repeat(10) @(posedge clk_aon);
        rst_por_n = 1;
        rst_aon_n = 1;
        state = RESET;
        repeat(10) @(posedge clk_aon);

        // Test DVFS OP0 (High performance)
        state = TEST_DVFS_OP0;
        bus_cmd_valid = 1;
        bus_cmd_addr = 16'h0000;
        bus_cmd_rw = 1;
        bus_cmd_data = 32'h0000_0000;  // OP0
        repeat(50) @(posedge clk_aon);
        bus_cmd_valid = 0;

        // Test DVFS OP1 (Medium)
        state = TEST_DVFS_OP1;
        bus_cmd_valid = 1;
        bus_cmd_data = 32'h0000_0001;  // OP1
        repeat(50) @(posedge clk_aon);
        bus_cmd_valid = 0;

        // Test DVFS OP2 (Low power)
        state = TEST_DVFS_OP2;
        bus_cmd_valid = 1;
        bus_cmd_data = 32'h0000_0002;  // OP2
        repeat(50) @(posedge clk_aon);
        bus_cmd_valid = 0;

        // Test Power Gate
        state = TEST_POWER_GATE;
        pg_main_status = 0;
        bus_cmd_valid = 1;
        bus_cmd_addr = 16'h0010;
        bus_cmd_data = 32'h0000_0001;  // Enable power gate
        repeat(100) @(posedge clk_aon);
        pg_main_status = 1;
        bus_cmd_valid = 0;

        // Test Power Mode Active
        state = TEST_POWER_MODE_ACTIVE;
        pmode_req = 0;  // Active
        repeat(50) @(posedge clk_aon);

        // Test Power Mode Sleep
        state = TEST_POWER_MODE_SLEEP;
        pmode_req = 1;  // Sleep
        repeat(50) @(posedge clk_aon);
        pmode_req = 0;

        // Test Wakeup
        state = TEST_WAKEUP;
        wakeup_ext = 8'h01;
        repeat(50) @(posedge clk_aon);
        wakeup_clear = 1;
        repeat(10) @(posedge clk_aon);
        wakeup_ext = 0;
        wakeup_clear = 0;

        // Test Power Estimator
        state = TEST_POWER_ESTIMATOR;
        pwr_budget = 500;
        activity_main = 1;
        activity_io = 1;
        activity_dram = 1;
        repeat(100) @(posedge clk_aon);

        // Test Idle Detection
        state = TEST_IDLE_DETECT;
        activity_main = 0;
        activity_io = 0;
        activity_dram = 0;
        repeat(200) @(posedge clk_aon);

        // Test Bus Read
        state = TEST_BUS_READ;
        bus_cmd_valid = 1;
        bus_cmd_rw = 0;
        bus_cmd_addr = 16'h0000;
        repeat(20) @(posedge clk_aon);
        bus_cmd_valid = 0;

        state = DONE;
        repeat(10) @(posedge clk_aon);
    end

endmodule