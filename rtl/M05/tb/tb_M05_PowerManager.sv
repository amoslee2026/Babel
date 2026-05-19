//-----------------------------------------------------------------------------
// Testbench: tb_M05_PowerManager
// Description: Testbench for M05 Power Manager
//              Tests Power Mode FSM, DVFS Controller, Wakeup Controller,
//              Power Gate Controller, and Power Estimator
//
// Specification: spec_mas/M05/MAS.md, FSM.md, datapath.md
//-----------------------------------------------------------------------------

`timescale 1us / 1ns

module tb_M05_PowerManager;

    //========================================================================
    // Parameters
    //========================================================================
    parameter CLK_PERIOD = 1;  // 1 MHz clock -> 1 us period
    parameter SIM_TIME = 100000;  // 100 ms simulation time

    //========================================================================
    // DUT Signals
    //========================================================================

    // Clock & Reset
    logic        clk_aon;
    logic        rst_aon_n;
    logic        rst_por_n;

    // System Bus Interface
    logic        bus_cmd_valid;
    logic        bus_cmd_ready;
    logic [15:0] bus_cmd_addr;
    logic        bus_cmd_rw;
    logic [31:0] bus_cmd_data;
    logic        bus_rsp_valid;
    logic [31:0] bus_rsp_data;
    logic        bus_rsp_error;

    // DVFS Control Interface
    logic [1:0]  dvfs_op_req;
    logic        dvfs_op_ack;
    logic [2:0]  dvfs_vdd_req;
    logic [31:0] dvfs_freq_req;
    logic        dvfs_busy;

    // Voltage Regulator Interface
    logic [7:0]  vdd_main_set;
    logic        vdd_main_ack;
    logic        vdd_main_ready;
    logic        vdd_main_error;

    // Power Gate Control
    logic        pg_main_en;
    logic        pg_main_status;
    logic        pg_main_switch;
    logic        pg_iso_en;

    // Power Mode Interface
    logic [1:0]  pmode_state;
    logic [1:0]  pmode_req;
    logic        pmode_ack;
    logic        pmode_error;

    // Wakeup Interface
    logic [7:0]  wakeup_ext;
    logic [7:0]  wakeup_en;
    logic [7:0]  wakeup_status;
    logic        wakeup_pending;
    logic        wakeup_clear;

    // Power Estimator Interface
    logic [15:0] pwr_estimate;
    logic [15:0] pwr_budget;
    logic        pwr_alert;
    logic [31:0] pwr_counters;

    // Activity Monitoring
    logic        activity_main;
    logic        activity_io;
    logic        activity_dram;
    logic [15:0] idle_timeout;
    logic        idle_detected;

    // Status & Interrupt
    logic [7:0]  pm_status;
    logic        pm_irq;
    logic [2:0]  pm_irq_type;

    //========================================================================
    // State Encoding (for testbench assertions)
    //========================================================================
    localparam logic [1:0]
        STATE_RESET      = 2'b11,
        STATE_ACTIVE     = 2'b00,
        STATE_SLEEP      = 2'b01,
        STATE_DEEP_SLEEP = 2'b10;

    localparam logic [1:0]
        OP0 = 2'b00,
        OP1 = 2'b01,
        OP2 = 2'b10;

    //========================================================================
    // DUT Instance
    //========================================================================
    M05_PowerManager #(
        .MAX_POWER_OP0 (1700),
        .MAX_POWER_IO  (15),
        .MAX_POWER_DRAM (80)
    ) dut (
        .clk_aon           (clk_aon),
        .rst_aon_n         (rst_aon_n),
        .rst_por_n         (rst_por_n),

        .bus_cmd_valid     (bus_cmd_valid),
        .bus_cmd_ready     (bus_cmd_ready),
        .bus_cmd_addr      (bus_cmd_addr),
        .bus_cmd_rw        (bus_cmd_rw),
        .bus_cmd_data      (bus_cmd_data),
        .bus_rsp_valid     (bus_rsp_valid),
        .bus_rsp_data      (bus_rsp_data),
        .bus_rsp_error     (bus_rsp_error),

        .dvfs_op_req       (dvfs_op_req),
        .dvfs_op_ack       (dvfs_op_ack),
        .dvfs_vdd_req      (dvfs_vdd_req),
        .dvfs_freq_req     (dvfs_freq_req),
        .dvfs_busy         (dvfs_busy),

        .vdd_main_set      (vdd_main_set),
        .vdd_main_ack      (vdd_main_ack),
        .vdd_main_ready    (vdd_main_ready),
        .vdd_main_error    (vdd_main_error),

        .pg_main_en        (pg_main_en),
        .pg_main_status    (pg_main_status),
        .pg_main_switch    (pg_main_switch),
        .pg_iso_en         (pg_iso_en),

        .pmode_state       (pmode_state),
        .pmode_req         (pmode_req),
        .pmode_ack         (pmode_ack),
        .pmode_error       (pmode_error),

        .wakeup_ext        (wakeup_ext),
        .wakeup_en         (wakeup_en),
        .wakeup_status     (wakeup_status),
        .wakeup_pending    (wakeup_pending),
        .wakeup_clear      (wakeup_clear),

        .pwr_estimate      (pwr_estimate),
        .pwr_budget        (pwr_budget),
        .pwr_alert         (pwr_alert),
        .pwr_counters      (pwr_counters),

        .activity_main     (activity_main),
        .activity_io       (activity_io),
        .activity_dram     (activity_dram),
        .idle_timeout      (idle_timeout),
        .idle_detected     (idle_detected),

        .pm_status         (pm_status),
        .pm_irq            (pm_irq),
        .pm_irq_type       (pm_irq_type)
    );

    //========================================================================
    // Clock Generation
    //========================================================================
    initial begin
        clk_aon = 1'b0;
        forever begin
            #(CLK_PERIOD/2) clk_aon = ~clk_aon;
        end
    end

    //========================================================================
    // Test Variables
    //========================================================================
    integer test_count;
    integer pass_count;
    integer fail_count;
    logic [255:0] test_name;

    //========================================================================
    // Test Tasks
    //========================================================================

    // Task: Initialize all signals
    task automatic init_signals;
        rst_aon_n = 1'b1;
        rst_por_n = 1'b0;  // POR active
        bus_cmd_valid = 1'b0;
        bus_cmd_addr = 16'b0;
        bus_cmd_rw = 1'b0;
        bus_cmd_data = 32'b0;
        dvfs_op_ack = 1'b0;
        dvfs_busy = 1'b0;
        vdd_main_ack = 1'b0;
        vdd_main_ready = 1'b1;
        vdd_main_error = 1'b0;
        pg_main_status = 1'b0;  // PG status: powered off initially
        pmode_req = 2'b0;
        wakeup_ext = 8'b0;
        wakeup_clear = 1'b0;
        pwr_budget = 16'h700;
        activity_main = 1'b0;
        activity_io = 1'b0;
        activity_dram = 1'b0;
        idle_timeout = 16'h64;  // 100 cycles timeout
    endtask

    // Task: Apply POR reset sequence
    task automatic apply_por_reset;
        rst_por_n = 1'b0;
        #(10 * CLK_PERIOD);
        rst_por_n = 1'b1;  // Release POR
        #(10 * CLK_PERIOD);
    endtask

    // Task: Write register via bus
    task automatic write_register;
        input logic [15:0] addr;
        input logic [31:0] data;
        begin
            @(posedge clk_aon);
            bus_cmd_valid = 1'b1;
            bus_cmd_rw = 1'b1;
            bus_cmd_addr = addr;
            bus_cmd_data = data;
            @(posedge clk_aon);
            bus_cmd_valid = 1'b0;
            @(posedge clk_aon);
        end
    endtask

    // Task: Read register via bus
    task automatic read_register;
        input logic [15:0] addr;
        output logic [31:0] data;
        begin
            @(posedge clk_aon);
            bus_cmd_valid = 1'b1;
            bus_cmd_rw = 1'b0;
            bus_cmd_addr = addr;
            @(posedge clk_aon);
            @(posedge clk_aon);
            data = bus_rsp_data;
            bus_cmd_valid = 1'b0;
        end
    endtask

    // Task: Simulate voltage regulator ACK
    task automatic simulate_vdd_ack;
        #(5 * CLK_PERIOD);
        vdd_main_ack = 1'b1;
        #(CLK_PERIOD);
        vdd_main_ack = 1'b0;
    endtask

    // Task: Simulate DVFS ACK from M06
    task automatic simulate_dvfs_ack;
        #(10 * CLK_PERIOD);
        dvfs_op_ack = 1'b1;
        #(CLK_PERIOD);
        dvfs_op_ack = 1'b0;
    endtask

    // Task: Simulate power gate status change
    task automatic simulate_pg_status;
        input logic status;
        begin
            #(10 * CLK_PERIOD);
            pg_main_status = status;
        end
    endtask

    // Task: Simulate wakeup signal
    task automatic simulate_wakeup;
        input logic [7:0] wakeup_source;
        begin
            @(posedge clk_aon);
            wakeup_ext = wakeup_source;
            #(3 * CLK_PERIOD);
            wakeup_ext = 8'b0;
        end
    endtask

    // Task: Check expected state
    task automatic check_state;
        input logic [1:0] expected_state;
        input logic [255:0] desc;
        begin
            test_count = test_count + 1;
            if (pmode_state == expected_state) begin
                pass_count = pass_count + 1;
                $display("[%0t] PASS: %s - State = %b (expected %b)",
                    $time, desc, pmode_state, expected_state);
            end else begin
                fail_count = fail_count + 1;
                $display("[%0t] FAIL: %s - State = %b (expected %b)",
                    $time, desc, pmode_state, expected_state);
            end
        end
    endtask

    // Task: Check DVFS OP
    task automatic check_dvfs_op;
        input logic [1:0] expected_op;
        input logic [255:0] desc;
        begin
            test_count = test_count + 1;
            if (dvfs_op_req == expected_op) begin
                pass_count = pass_count + 1;
                $display("[%0t] PASS: %s - DVFS OP = %b (expected %b)",
                    $time, desc, dvfs_op_req, expected_op);
            end else begin
                fail_count = fail_count + 1;
                $display("[%0t] FAIL: %s - DVFS OP = %b (expected %b)",
                    $time, desc, dvfs_op_req, expected_op);
            end
        end
    endtask

    // Task: Check power gate status
    task automatic check_pg_status;
        input logic expected_pg_en;
        input logic expected_iso_en;
        input logic [255:0] desc;
        begin
            test_count = test_count + 1;
            if (pg_main_en == expected_pg_en && pg_iso_en == expected_iso_en) begin
                pass_count = pass_count + 1;
                $display("[%0t] PASS: %s - PG_EN=%b ISO_EN=%b",
                    $time, desc, pg_main_en, pg_iso_en);
            end else begin
                fail_count = fail_count + 1;
                $display("[%0t] FAIL: %s - PG_EN=%b ISO_EN=%b (expected PG=%b ISO=%b)",
                    $time, desc, pg_main_en, pg_iso_en, expected_pg_en, expected_iso_en);
            end
        end
    endtask

    //========================================================================
    // Main Test Sequence
    //========================================================================
    initial begin
        $display("==========================================");
        $display("M05 Power Manager Testbench");
        $display("==========================================");

        test_count = 0;
        pass_count = 0;
        fail_count = 0;

        // Initialize
        init_signals();

        //========================================
        // Test 1: POR Reset to ACTIVE State
        //========================================
        $display("\n--- Test 1: POR Reset Sequence ---");
        test_name = "POR Reset Sequence";

        apply_por_reset();

        // Enable Power Manager
        write_register(16'h0000, 32'h00000001);  // PM_CTRL enable

        #(20 * CLK_PERIOD);

        check_state(STATE_ACTIVE, "After POR release");
        check_pg_status(1'b0, 1'b0, "Active state PG/ISO");
        check_dvfs_op(OP0, "Active state DVFS OP");

        //========================================
        // Test 2: ACTIVE to SLEEP Transition
        //========================================
        $display("\n--- Test 2: ACTIVE to SLEEP ---");
        test_name = "ACTIVE to SLEEP";

        pmode_req = 2'b01;  // Request SLEEP

        #(5 * CLK_PERIOD);

        // Simulate DVFS ACK
        simulate_vdd_ack();
        simulate_dvfs_ack();

        #(20 * CLK_PERIOD);

        check_state(STATE_SLEEP, "After SLEEP request");
        check_dvfs_op(OP1, "SLEEP state DVFS OP");
        check_pg_status(1'b0, 1'b0, "SLEEP state PG/ISO");

        pmode_req = 2'b00;

        //========================================
        // Test 3: SLEEP Wakeup to ACTIVE
        //========================================
        $display("\n--- Test 3: SLEEP Wakeup ---");
        test_name = "SLEEP Wakeup";

        // Trigger wakeup from Timer (source 2)
        simulate_wakeup(8'b00000100);

        #(5 * CLK_PERIOD);

        // Simulate DVFS ACK for OP0
        simulate_vdd_ack();
        simulate_dvfs_ack();

        #(20 * CLK_PERIOD);

        check_state(STATE_ACTIVE, "After wakeup from SLEEP");
        check_dvfs_op(OP0, "ACTIVE state DVFS OP");

        // Clear wakeup status
        wakeup_clear = 1'b1;
        #(CLK_PERIOD);
        wakeup_clear = 1'b0;

        //========================================
        // Test 4: ACTIVE to DEEP_SLEEP Transition
        //========================================
        $display("\n--- Test 4: ACTIVE to DEEP_SLEEP ---");
        test_name = "ACTIVE to DEEP_SLEEP";

        pmode_req = 2'b10;  // Request DEEP_SLEEP

        #(5 * CLK_PERIOD);

        // Simulate DVFS ACK for OP2
        simulate_vdd_ack();
        simulate_dvfs_ack();

        // Simulate PG enter sequence
        simulate_pg_status(1'b0);  // PG status: powered off

        #(30 * CLK_PERIOD);

        check_state(STATE_DEEP_SLEEP, "After DEEP_SLEEP request");
        check_dvfs_op(OP2, "DEEP_SLEEP state DVFS OP");
        check_pg_status(1'b1, 1'b1, "DEEP_SLEEP state PG/ISO");

        pmode_req = 2'b00;

        //========================================
        // Test 5: DEEP_SLEEP Wakeup to ACTIVE
        //========================================
        $display("\n--- Test 5: DEEP_SLEEP Wakeup ---");
        test_name = "DEEP_SLEEP Wakeup";

        // Trigger wakeup from JTAG (source 0)
        simulate_wakeup(8'b00000001);

        #(5 * CLK_PERIOD);

        // Simulate PG exit sequence
        simulate_pg_status(1'b1);  // PG status: powered on

        // Simulate DVFS ACK for OP0
        simulate_vdd_ack();
        simulate_dvfs_ack();

        #(50 * CLK_PERIOD);

        check_state(STATE_ACTIVE, "After wakeup from DEEP_SLEEP");
        check_dvfs_op(OP0, "ACTIVE state DVFS OP");
        check_pg_status(1'b0, 1'b0, "ACTIVE state PG/ISO after wakeup");

        //========================================
        // Test 6: DVFS Switching OP0 to OP1
        //========================================
        $display("\n--- Test 6: DVFS Switching ---");
        test_name = "DVFS Switching";

        // Request DVFS to OP1
        write_register(16'h000C, 32'h00000005);  // DVFS_CTRL: op_target=1, op_switch_req=1

        #(5 * CLK_PERIOD);

        // Simulate ACK sequence
        simulate_vdd_ack();
        simulate_dvfs_ack();

        #(20 * CLK_PERIOD);

        check_dvfs_op(OP1, "After DVFS switch to OP1");

        //========================================
        // Test 7: Idle Detection
        //========================================
        $display("\n--- Test 7: Idle Detection ---");
        test_name = "Idle Detection";

        // Enable idle detection
        write_register(16'h0000, 32'h00000041);  // PM_CTRL: enable + idle_det_en
        write_register(16'h0048, 32'h00000050);  // IDLE_CTRL: timeout = 80

        // Set all activity to idle
        activity_main = 1'b0;
        activity_io = 1'b0;
        activity_dram = 1'b0;

        // Wait for idle timeout
        #(100 * CLK_PERIOD);

        test_count = test_count + 1;
        if (idle_detected == 1'b1) begin
            pass_count = pass_count + 1;
            $display("[%0t] PASS: Idle detected after timeout", $time);
        end else begin
            fail_count = fail_count + 1;
            $display("[%0t] FAIL: Idle not detected", $time);
        end

        // Set activity active
        activity_main = 1'b1;

        #(CLK_PERIOD);

        test_count = test_count + 1;
        if (idle_detected == 1'b0) begin
            pass_count = pass_count + 1;
            $display("[%0t] PASS: Idle cleared on activity", $time);
        end else begin
            fail_count = fail_count + 1;
            $display("[%0t] FAIL: Idle not cleared", $time);
        end

        activity_main = 1'b0;

        //========================================
        // Test 8: Power Estimator
        //========================================
        $display("\n--- Test 8: Power Estimator ---");
        test_name = "Power Estimator";

        // Enable power estimator
        write_register(16'h0000, 32'h00000011);  // PM_CTRL: enable + pwr_est_en

        // Set activity
        activity_main = 1'b1;
        activity_io = 1'b1;
        activity_dram = 1'b1;

        #(10 * CLK_PERIOD);

        // Check power estimate is non-zero
        test_count = test_count + 1;
        if (pwr_estimate > 16'b0) begin
            pass_count = pass_count + 1;
            $display("[%0t] PASS: Power estimate = %d mW", $time, pwr_estimate);
        end else begin
            fail_count = fail_count + 1;
            $display("[%0t] FAIL: Power estimate is zero", $time);
        end

        // Set low budget to trigger alert
        pwr_budget = 16'h10;  // 10 mW budget

        #(10 * CLK_PERIOD);

        test_count = test_count + 1;
        if (pwr_alert == 1'b1) begin
            pass_count = pass_count + 1;
            $display("[%0t] PASS: Power alert triggered", $time);
        end else begin
            fail_count = fail_count + 1;
            $display("[%0t] FAIL: Power alert not triggered", $time);
        end

        activity_main = 1'b0;
        activity_io = 1'b0;
        activity_dram = 1'b0;

        //========================================
        // Test 9: Register Read/Write
        //========================================
        $display("\n--- Test 9: Register Access ---");
        test_name = "Register Access";

        // Read PM_STATUS
        logic [31:0] read_data;
        read_register(16'h0004, read_data);

        test_count = test_count + 1;
        if (bus_rsp_error == 1'b0) begin
            pass_count = pass_count + 1;
            $display("[%0t] PASS: PM_STATUS read = 0x%h", $time, read_data);
        end else begin
            fail_count = fail_count + 1;
            $display("[%0t] FAIL: PM_STATUS read error", $time);
        end

        //========================================
        // Test 10: Error Timeout Handling
        //========================================
        $display("\n--- Test 10: Error Timeout Handling ---");
        test_name = "Error Timeout Handling";

        // Ensure we're in ACTIVE state
        pmode_req = 2'b00;  // Request ACTIVE
        #(10 * CLK_PERIOD);

        // Test voltage regulator error response
        vdd_main_error = 1'b1;  // Simulate voltage error
        #(5 * CLK_PERIOD);

        test_count = test_count + 1;
        if (pm_status[2] == 1'b1) begin  // pm_error bit
            pass_count = pass_count + 1;
            $display("[%0t] PASS: Voltage error detected in pm_status", $time);
        end else begin
            fail_count = fail_count + 1;
            $display("[%0t] FAIL: Voltage error not reflected in pm_status", $time);
        end

        // Clear error
        vdd_main_error = 1'b0;
        #(10 * CLK_PERIOD);

        // Test DVFS timeout (by not providing ACK)
        // Request DVFS to OP2 but don't acknowledge
        write_register(16'h000C, 32'h00000006);  // DVFS_CTRL: op_target=2, op_switch_req=1

        // Don't provide ACK - wait for timeout handling
        dvfs_busy = 1'b1;  // Force busy state
        dvfs_op_ack = 1'b0;
        vdd_main_ack = 1'b0;
        vdd_main_ready = 1'b1;

        // Wait for timeout (RTL uses 100 cycles timeout)
        #(110 * CLK_PERIOD);

        test_count = test_count + 1;
        // Check that timeout was handled (error bit or completion)
        if (pm_status[2] == 1'b1 || dvfs_busy == 1'b0) begin
            pass_count = pass_count + 1;
            $display("[%0t] PASS: DVFS timeout handled gracefully", $time);
        end else begin
            fail_count = fail_count + 1;
            $display("[%0t] FAIL: DVFS timeout not handled", $time);
        end

        // Release stuck state
        dvfs_busy = 1'b0;
        dvfs_op_ack = 1'b1;
        #(CLK_PERIOD);
        dvfs_op_ack = 1'b0;
        #(20 * CLK_PERIOD);

        //========================================
        // Test 11: Wakeup Multi-Source
        //========================================
        $display("\n--- Test 11: Multiple Wakeup Sources ---");
        test_name = "Multiple Wakeup Sources";

        // Enter DEEP_SLEEP
        pmode_req = 2'b10;
        simulate_vdd_ack();
        simulate_dvfs_ack();
        simulate_pg_status(1'b0);
        #(30 * CLK_PERIOD);

        check_state(STATE_DEEP_SLEEP, "Before multi-source wakeup");

        // Trigger multiple wakeup sources simultaneously (Timer + GPIO + Software)
        simulate_wakeup(8'b00001110);  // sources 1, 2, 3

        #(10 * CLK_PERIOD);

        test_count = test_count + 1;
        if (wakeup_pending == 1'b1) begin
            pass_count = pass_count + 1;
            $display("[%0t] PASS: Wakeup pending set for multiple sources", $time);
        end else begin
            fail_count = fail_count + 1;
            $display("[%0t] FAIL: Wakeup pending not set", $time);
        end

        test_count = test_count + 1;
        if ((wakeup_status & 8'b00001110) != 0) begin
            pass_count = pass_count + 1;
            $display("[%0t] PASS: Wakeup status captured sources: 0x%h", $time, wakeup_status);
        end else begin
            fail_count = fail_count + 1;
            $display("[%0t] FAIL: Wakeup status not captured", $time);
        end

        // Simulate PG exit and wake to ACTIVE
        simulate_pg_status(1'b1);
        simulate_vdd_ack();
        simulate_dvfs_ack();
        #(50 * CLK_PERIOD);

        check_state(STATE_ACTIVE, "After multi-source wakeup");

        // Clear wakeup
        wakeup_clear = 1'b1;
        #(CLK_PERIOD);
        wakeup_clear = 1'b0;

        pmode_req = 2'b00;

        //========================================
        // Test Summary
        //========================================
        #(100 * CLK_PERIOD);

        $display("\n==========================================");
        $display("Test Summary");
        $display("==========================================");
        $display("Total Tests: %0d", test_count);
        $display("Passed:      %0d", pass_count);
        $display("Failed:      %0d", fail_count);
        $display("Pass Rate:   %.2f%%", (pass_count * 100.0) / test_count);
        $display("==========================================");

        if (fail_count == 0) begin
            $display("ALL TESTS PASSED");
        end else begin
            $display("SOME TESTS FAILED");
        end

        $finish;
    end

    //========================================================================
    // Timeout Watchdog
    //========================================================================
    initial begin
        #(SIM_TIME * CLK_PERIOD);
        $display("\n[%0t] TIMEOUT: Simulation exceeded maximum time", $time);
        $finish;
    end

    //========================================================================
    // Wave Dump (for debugging)
    //========================================================================
    initial begin
        $dumpfile("tb_M05_PowerManager.vcd");
        $dumpvars(0, tb_M05_PowerManager);
    end

    //========================================================================
    // Assertions (SystemVerilog SVA)
    //========================================================================

    // State encoding validity check
    assert property (@(posedge clk_aon)
        pmode_state inside {STATE_RESET, STATE_ACTIVE, STATE_SLEEP, STATE_DEEP_SLEEP})
        else $display("ASSERT FAIL: Invalid state encoding at time %0t, state=%b", $time, pmode_state);

    // POR reset behavior - state must be RESET when POR is active
    assert property (@(posedge clk_aon)
        !rst_por_n |-> pmode_state == STATE_RESET)
        else $display("ASSERT FAIL: State not RESET during POR at time %0t", $time);

    // DVFS OP request validity
    assert property (@(posedge clk_aon)
        dvfs_op_req inside {OP0, OP1, OP2})
        else $display("ASSERT FAIL: Invalid DVFS OP request at time %0t, op=%b", $time, dvfs_op_req);

    // Power gate sequence: isolation must be enabled before switch is turned off
    assert property (@(posedge clk_aon)
        (!pg_main_switch |-> pg_iso_en) or !rst_por_n)
        else $display("ASSERT FAIL: Switch OFF without isolation at time %0t", $time);

    // Wakeup pending implies status is non-zero
    assert property (@(posedge clk_aon)
        wakeup_pending |-> (wakeup_status != 8'b0))
        else $display("ASSERT FAIL: Wakeup pending without status at time %0t", $time);

    // Power alert implies estimate exceeds budget (when estimator enabled)
    assert property (@(posedge clk_aon)
        pwr_alert |-> (pwr_estimate > pwr_budget) or !rst_por_n)
        else $display("ASSERT FAIL: Power alert without over-budget at time %0t", $time);

    // DEEP_SLEEP state must have power gating enabled
    assert property (@(posedge clk_aon)
        (pmode_state == STATE_DEEP_SLEEP && rst_por_n) |-> (pg_main_en == 1'b1 && pg_iso_en == 1'b1))
        else $display("ASSERT FAIL: DEEP_SLEEP without PG enabled at time %0t", $time);

    // ACTIVE state must not have power gating
    assert property (@(posedge clk_aon)
        (pmode_state == STATE_ACTIVE && rst_por_n) |-> (pg_main_en == 1'b0 && pg_iso_en == 1'b0))
        else $display("ASSERT FAIL: ACTIVE state with PG enabled at time %0t", $time);

    // SLEEP state DVFS must be OP1
    assert property (@(posedge clk_aon)
        (pmode_state == STATE_SLEEP && rst_por_n && !dut.dvfs_switching_reg) |-> dvfs_op_req == OP1)
        else $display("ASSERT FAIL: SLEEP state with wrong DVFS OP at time %0t", $time);

    // DEEP_SLEEP state DVFS must be OP2
    assert property (@(posedge clk_aon)
        (pmode_state == STATE_DEEP_SLEEP && rst_por_n && !dut.dvfs_switching_reg) |-> dvfs_op_req == OP2)
        else $display("ASSERT FAIL: DEEP_SLEEP state with wrong DVFS OP at time %0t", $time);

    // Bus response valid within 2 cycles after command
    assert property (@(posedge clk_aon)
        bus_cmd_valid |-> ##[1:2] bus_rsp_valid)
        else $display("ASSERT FAIL: Bus response timeout at time %0t", $time);

    // Cover points for state transitions
    cover property (@(posedge clk_aon)
        pmode_state == STATE_RESET |-> ##[1:100] pmode_state == STATE_ACTIVE)
        $display("COVER: RESET to ACTIVE transition at time %0t", $time);

    cover property (@(posedge clk_aon)
        pmode_state == STATE_ACTIVE |-> ##[1:50] pmode_state == STATE_SLEEP)
        $display("COVER: ACTIVE to SLEEP transition at time %0t", $time);

    cover property (@(posedge clk_aon)
        pmode_state == STATE_ACTIVE |-> ##[1:50] pmode_state == STATE_DEEP_SLEEP)
        $display("COVER: ACTIVE to DEEP_SLEEP transition at time %0t", $time);

    cover property (@(posedge clk_aon)
        pmode_state == STATE_SLEEP |-> ##[1:50] pmode_state == STATE_ACTIVE)
        $display("COVER: SLEEP to ACTIVE wakeup at time %0t", $time);

    cover property (@(posedge clk_aon)
        pmode_state == STATE_DEEP_SLEEP |-> ##[1:100] pmode_state == STATE_ACTIVE)
        $display("COVER: DEEP_SLEEP to ACTIVE wakeup at time %0t", $time);

endmodule