//=============================================================================
// Testbench: Top-Level Runner for All Modules
// Coverage collection wrapper for all module testbenches
//-----------------------------------------------------------------------------

module tb_top;

    //=========================================================================
    // Clock Generation
    //=========================================================================
    logic clk_sys;
    logic clk_aon;
    logic clk_io;
    logic tck;
    logic ext_clk;

    // Clock parameters
    localparam CLK_SYS_PERIOD = 4;   // 250 MHz
    localparam CLK_AON_PERIOD = 1000; // 1 MHz
    localparam CLK_IO_PERIOD = 20;   // 50 MHz
    localparam TCK_PERIOD = 20;      // 50 MHz JTAG

    initial begin
        clk_sys = 0;
        forever #(CLK_SYS_PERIOD/2) clk_sys = ~clk_sys;
    end

    initial begin
        clk_aon = 0;
        forever #(CLK_AON_PERIOD/2) clk_aon = ~clk_aon;
    end

    initial begin
        clk_io = 0;
        forever #(CLK_IO_PERIOD/2) clk_io = ~clk_io;
    end

    initial begin
        tck = 0;
        forever #(TCK_PERIOD/2) tck = ~tck;
    end

    initial begin
        ext_clk = 0;
        forever #(CLK_IO_PERIOD/2) ext_clk = ~ext_clk;
    end

    //=========================================================================
    // Test Status Tracking
    //=========================================================================
    int total_tests;
    int passed_tests;
    int failed_tests;
    logic all_tests_done;

    //=========================================================================
    // Module Testbench Instances
    //=========================================================================

    // M00: Systolic Array
    tb_M00_SystolicArray tb_M00 (
        .clk_i_ext(clk_sys)
    );

    // M01: Dataflow Controller
    tb_M01_DataflowController tb_M01 (
        .clk_sys_ext(clk_sys)
    );

    // M02: SRAM Scratchpad
    tb_M02_SRAMScratchpad tb_M02 (
        .clk_sys_i_ext(clk_sys)
    );

    // M03: DRAM Controller
    tb_M03_DRAMController tb_M03 (
        .clk_sys_i_ext(clk_sys)
    );

    // M04: System Bus
    tb_M04_SystemBus tb_M04 (
        .clk_sys_ext(clk_sys)
    );

    // M05: Power Manager
    tb_M05_PowerManager tb_M05 (
        .clk_aon_ext(clk_aon)
    );

    // M06: Clock Manager
    tb_M06_ClockManager tb_M06 (
        .ext_clk_i_ext(ext_clk)
    );

    // M07: Reset Manager
    tb_M07_ResetManager tb_M07 (
        .clk_aon_ext(clk_aon)
    );

    // M08: Thread Scheduler
    tb_M08_ThreadScheduler tb_M08 (
        .clk_sys_ext(clk_sys)
    );

    // M09: Attention Unit
    tb_M09_AttentionUnit tb_M09 (
        .clk_i_ext(clk_sys)
    );

    // M10: FFN/MatMul
    tb_M10_FFNMatMul tb_M10 (
        .clk_ext(clk_sys)
    );

    // M11: RMSNorm/RoPE
    tb_M11_RMSNormRoPE tb_M11 (
        .clk_sys_i_ext(clk_sys)
    );

    // M12: SoftMax
    tb_M12_SoftMax tb_M12 (
        .clk_sys_ext(clk_sys)
    );

    // M13: ISA Decoder
    tb_M13_ISADecoder tb_M13 (
        .clk_sys_i_ext(clk_sys)
    );

    // M14: Secure Boot
    tb_M14_SecureBoot tb_M14 (
        .clk_sys_ext(clk_sys)
    );

    // M15: JTAG Interface
    tb_M15_JTAGInterface tb_M15 (
        .tck_ext(tck)
    );

    // M16: ISA Interface
    tb_M16_ISAInterface tb_M16 (
        .clk_sys_ext(clk_sys)
    );

    //=========================================================================
    // Simulation Control
    //=========================================================================
    initial begin
        total_tests = 0;
        passed_tests = 0;
        failed_tests = 0;
        all_tests_done = 0;

        // Wait for all tests to complete (timeout = 100ms)
        repeat(25000000) @(posedge clk_sys);

        all_tests_done = 1;
        $display("========================================");
        $display("TinyStories NPU Verification Complete");
        $display("========================================");
        $display("Total simulation cycles: %0t", $time);
        $finish(0);
    end

    //=========================================================================
    // Coverage Goals (verilator --coverage-line --coverage-branch --coverage-toggle)
    //=========================================================================

endmodule