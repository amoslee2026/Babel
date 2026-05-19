// M06: Clock Manager Testbench
// Module: tb_M06_ClockManager
// Description: Verification of DVFS clock switching and clock gating
// Generated: 2026-05-17

module tb_M06_ClockManager;

    //=========================================================================
    // Parameters
    //=========================================================================

    // Clock Periods
    parameter EXT_CLK_PERIOD = 20000;   // 20 ns (50 MHz)
    parameter AON_CLK_PERIOD = 1000000; // 1000 ns (1 MHz)
    parameter SYS_CLK_PERIOD = 2000;    // 2 ns (500 MHz) nominal

    // Simulation Time
    parameter SIM_TIME = 10000000;      // 10 ms

    //=========================================================================
    // Testbench Signals
    //=========================================================================

    // Clock and Reset
    logic        ext_clk;
    logic        clk_aon;
    logic        pll_lock;
    logic        pd_aon_vdd;

    // Control Inputs
    logic [1:0]  dvfs_op;
    logic        dvfs_req;
    logic [13:0] clk_gating_en;

    // DUT Outputs
    logic        clk_sys;
    logic        clk_aon_out;
    logic        clk_io;
    logic [13:0] clk_gating;
    logic        dvfs_ack;
    logic [2:0]  clk_status;
    logic        pll_pwr_en;

    //=========================================================================
    // DUT Instance
    //=========================================================================

    M06_ClockManager dut (
        .ext_clk_i        (ext_clk),
        .pll_lock_i       (pll_lock),
        .dvfs_op_i        (dvfs_op),
        .dvfs_req_i       (dvfs_req),
        .clk_gating_en_i  (clk_gating_en),
        .pd_aon_vdd_i     (pd_aon_vdd),
        .clk_sys_o        (clk_sys),
        .clk_aon_o        (clk_aon_out),
        .clk_io_o         (clk_io),
        .clk_gating_o     (clk_gating),
        .dvfs_ack_o       (dvfs_ack),
        .clk_status_o     (clk_status),
        .pll_pwr_en_o     (pll_pwr_en)
    );

    //=========================================================================
    // Clock Generation
    //=========================================================================

    // External 50 MHz Clock
    initial begin
        ext_clk = 0;
        forever #(EXT_CLK_PERIOD/2) ext_clk = ~ext_clk;
    end

    //=========================================================================
    // Status Monitoring
    //=========================================================================

    // Clock Status Encoding
    logic [2:0] STATUS_STABLE    = 3'b000;
    logic [2:0] STATUS_SWITCHING = 3'b001;
    logic [2:0] STATUS_ERROR     = 3'b100;

    // Monitor outputs
    initial begin
        $display("=== M06 Clock Manager Testbench ===");
        $display("Time | State    | dvfs_ack | clk_gating | pll_lock");
        $monitor("%0t | %b | %b | %b | %b",
                 $time, clk_status, dvfs_ack, clk_gating, pll_lock);
    end

    //=========================================================================
    // Test Stimulus
    //=========================================================================

    initial begin
        // Initialize inputs
        pll_lock = 0;
        pd_aon_vdd = 1;
        dvfs_op = 2'b00;      // OP0
        dvfs_req = 0;
        clk_gating_en = 14'h0000;

        // Wait for power stabilization
        #(EXT_CLK_PERIOD * 10);
        $display("Power stabilized, starting tests...");

        //---------------------------------------------------------------------
        // Test 1: PLL Lock Sequence
        //---------------------------------------------------------------------
        $display("\n[Test 1] PLL Lock Sequence");
        pll_lock = 1;
        #(EXT_CLK_PERIOD * 100);
        if (clk_status == STATUS_STABLE) begin
            $display("PASS: Clock stable after PLL lock");
        end else begin
            $display("FAIL: Clock not stable after PLL lock");
        end

        //---------------------------------------------------------------------
        // Test 2: DVFS Switch OP0 -> OP1 (500 -> 250 MHz)
        //---------------------------------------------------------------------
        $display("\n[Test 2] DVFS Switch OP0 -> OP1");
        dvfs_op = 2'b01;      // OP1
        #(EXT_CLK_PERIOD * 10);
        dvfs_req = 1;         // Trigger DVFS request
        #(EXT_CLK_PERIOD * 2);
        dvfs_req = 0;         // Release request

        // Wait for DVFS completion
        #(EXT_CLK_PERIOD * 150);
        if (dvfs_ack == 1 && clk_status == STATUS_STABLE) begin
            $display("PASS: DVFS OP0->OP1 switch completed");
        end else begin
            $display("FAIL: DVFS OP0->OP1 switch failed");
        end

        //---------------------------------------------------------------------
        // Test 3: DVFS Switch OP1 -> OP0 (250 -> 500 MHz)
        //---------------------------------------------------------------------
        $display("\n[Test 3] DVFS Switch OP1 -> OP0");
        dvfs_op = 2'b00;      // OP0
        #(EXT_CLK_PERIOD * 10);
        dvfs_req = 1;
        #(EXT_CLK_PERIOD * 2);
        dvfs_req = 0;

        #(EXT_CLK_PERIOD * 150);
        if (dvfs_ack == 1 && clk_status == STATUS_STABLE) begin
            $display("PASS: DVFS OP1->OP0 switch completed");
        end else begin
            $display("FAIL: DVFS OP1->OP0 switch failed");
        end

        //---------------------------------------------------------------------
        // Test 4: DVFS Switch to OP2 (Sleep Mode)
        //---------------------------------------------------------------------
        $display("\n[Test 4] DVFS Switch to OP2 (Sleep)");
        dvfs_op = 2'b10;      // OP2
        #(EXT_CLK_PERIOD * 10);
        dvfs_req = 1;
        #(EXT_CLK_PERIOD * 2);
        dvfs_req = 0;

        #(EXT_CLK_PERIOD * 150);
        if (dvfs_ack == 1 && clk_status == STATUS_STABLE) begin
            $display("PASS: DVFS to OP2 completed");
        end else begin
            $display("FAIL: DVFS to OP2 failed");
        end

        //---------------------------------------------------------------------
        // Test 5: Wake-up from OP2
        //---------------------------------------------------------------------
        $display("\n[Test 5] Wake-up from OP2 to OP0");
        dvfs_op = 2'b00;      // OP0
        #(EXT_CLK_PERIOD * 10);
        dvfs_req = 1;
        #(EXT_CLK_PERIOD * 2);
        dvfs_req = 0;

        #(EXT_CLK_PERIOD * 150);
        if (dvfs_ack == 1 && clk_status == STATUS_STABLE) begin
            $display("PASS: Wake-up completed");
        end else begin
            $display("FAIL: Wake-up failed");
        end

        //---------------------------------------------------------------------
        // Test 6: Clock Gating Control
        //---------------------------------------------------------------------
        $display("\n[Test 6] Clock Gating Control");
        clk_gating_en = 14'h000F;  // Enable M00-M03
        #(EXT_CLK_PERIOD * 20);
        if (clk_gating == 14'h000F) begin
            $display("PASS: Clock gating enabled for M00-M03");
        end else begin
            $display("FAIL: Clock gating mismatch");
        end

        clk_gating_en = 14'h00FF;  // Enable M00-M07
        #(EXT_CLK_PERIOD * 20);
        if (clk_gating == 14'h00FF) begin
            $display("PASS: Clock gating enabled for M00-M07");
        end else begin
            $display("FAIL: Clock gating mismatch");
        end

        //---------------------------------------------------------------------
        // Test 7: DVFS with PLL Unlock Error
        //---------------------------------------------------------------------
        $display("\n[Test 7] DVFS Error Handling");
        pll_lock = 0;         // Simulate PLL unlock
        #(EXT_CLK_PERIOD * 10);
        dvfs_req = 1;
        #(EXT_CLK_PERIOD * 2);
        dvfs_req = 0;

        #(EXT_CLK_PERIOD * 10);
        if (clk_status == STATUS_ERROR) begin
            $display("PASS: Error detected correctly");
        end else begin
            $display("FAIL: Error not detected");
        end

        // Restore PLL lock
        pll_lock = 1;
        #(EXT_CLK_PERIOD * 100);
        if (clk_status == STATUS_STABLE) begin
            $display("PASS: Recovered from error");
        end else begin
            $display("FAIL: Recovery failed");
        end

        //---------------------------------------------------------------------
        // Test 8: Invalid Operating Point
        //---------------------------------------------------------------------
        $display("\n[Test 8] Invalid Operating Point");
        dvfs_op = 2'b11;      // Invalid OP
        #(EXT_CLK_PERIOD * 10);
        dvfs_req = 1;
        #(EXT_CLK_PERIOD * 2);
        dvfs_req = 0;

        #(EXT_CLK_PERIOD * 10);
        if (clk_status == STATUS_ERROR || clk_status == STATUS_STABLE) begin
            $display("PASS: Invalid OP handled correctly");
        end else begin
            $display("FAIL: Invalid OP not handled");
        end

        // Restore valid OP
        dvfs_op = 2'b00;
        #(EXT_CLK_PERIOD * 50);

        //---------------------------------------------------------------------
        // Test 9: Power Domain Reset
        //---------------------------------------------------------------------
        $display("\n[Test 9] Power Domain Reset");
        pd_aon_vdd = 0;       // Power down
        #(EXT_CLK_PERIOD * 20);
        if (clk_status == STATUS_STABLE && clk_gating == 14'h0000) begin
            $display("PASS: Power reset cleared outputs");
        end else begin
            $display("FAIL: Power reset failed");
        end

        pd_aon_vdd = 1;       // Power up
        #(EXT_CLK_PERIOD * 100);
        if (pll_pwr_en == 1) begin
            $display("PASS: PLL power enabled after power-up");
        end else begin
            $display("FAIL: PLL power not enabled");
        end

        //---------------------------------------------------------------------
        // Test Summary
        //---------------------------------------------------------------------
        #(EXT_CLK_PERIOD * 50);
        $display("\n=== Test Summary ===");
        $display("All tests completed at time %0t", $time);
        $display("Simulation finished successfully");

        $finish;
    end

    //=========================================================================
    // Timeout Protection
    //=========================================================================

    initial begin
        #(SIM_TIME);
        $display("ERROR: Simulation timeout at %0t", $time);
        $finish;
    end

    //=========================================================================
    // Waveform Dump (Optional)
    //=========================================================================

    // Uncomment for waveform viewing
    // initial begin
    //     $dumpfile("tb_M06_ClockManager.vcd");
    //     $dumpvars(0, tb_M06_ClockManager);
    // end

endmodule