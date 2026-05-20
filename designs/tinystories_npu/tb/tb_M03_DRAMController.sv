//=============================================================================
// Testbench: M03_DRAMController
// Cycle-based testbench for Verilator coverage collection
//-----------------------------------------------------------------------------

module tb_M03_DRAMController (
    input logic clk_sys_i_ext  // External clock from C++
);

    //=========================================================================
    // Parameters
    //=========================================================================
    localparam DATA_WIDTH = 64;
    localparam ECC_WIDTH = 8;
    localparam ADDR_WIDTH = 32;

    //=========================================================================
    // Signals
    //=========================================================================
    logic clk_sys_i;
    logic rst_sys_n_i;
    logic clk_d2d_i;
    logic clk_d2d_pll_i;

    // Bus Interface
    logic        bus_cmd_valid_i;
    logic        bus_cmd_ready_o;
    logic [ADDR_WIDTH-1:0] bus_cmd_addr_i;
    logic        bus_cmd_rw_i;
    logic [DATA_WIDTH+ECC_WIDTH-1:0] bus_cmd_data_i;
    logic [7:0]  bus_cmd_mask_i;
    logic        bus_rsp_valid_o;
    logic [DATA_WIDTH+ECC_WIDTH-1:0] bus_rsp_data_o;
    logic        bus_rsp_error_o;
    logic [7:0]  bus_rsp_latency_o;

    // D2D Interface
    logic        d2d_cmd_valid_o;
    logic        d2d_cmd_ready_i;
    logic [ADDR_WIDTH-1:0] d2d_cmd_addr_o;
    logic        d2d_cmd_rw_o;
    logic [7:0]  d2d_cmd_burst_o;
    logic        d2d_wdata_valid_o;
    logic [DATA_WIDTH+ECC_WIDTH-1:0] d2d_wdata_o;
    logic        d2d_wdata_last_o;
    logic        d2d_rdata_valid_i;
    logic [DATA_WIDTH+ECC_WIDTH-1:0] d2d_rdata_i;
    logic        d2d_rdata_last_i;
    logic        d2d_rdata_error_i;
    logic [15:0] d2d_tx_data_o;
    logic        d2d_tx_clk_o;
    logic [15:0] d2d_rx_data_i;
    logic        d2d_rx_clk_i;
    logic        d2d_pll_lock_i;

    // ECC Interface
    logic [ADDR_WIDTH-1:0] ecc_err_addr_o;
    logic [1:0]  ecc_err_type_o;
    logic        ecc_err_valid_o;
    logic        ecc_err_clear_i;
    logic        ecc_corrected_o;

    // Bandwidth
    logic [15:0] bw_request_i;
    logic [15:0] bw_grant_o;
    logic [3:0]  bw_priority_i;
    logic [7:0]  bw_status_o;

    // Power Management
    logic        dram_active_o;
    logic        dram_idle_o;
    logic [1:0]  dram_power_mode_i;
    logic        dram_self_refresh_req_i;
    logic        dram_self_refresh_ack_o;

    // Status
    logic [7:0]  dram_status_o;
    logic        dram_irq_o;
    logic [3:0]  dram_irq_type_o;

    //=========================================================================
    // DUT Instance
    //=========================================================================
    M03_DRAMController dut (
        .clk_sys_i(clk_sys_i),
        .rst_sys_n_i(rst_sys_n_i),
        .clk_d2d_i(clk_d2d_i),
        .clk_d2d_pll_i(clk_d2d_pll_i),
        .bus_cmd_valid_i(bus_cmd_valid_i),
        .bus_cmd_ready_o(bus_cmd_ready_o),
        .bus_cmd_addr_i(bus_cmd_addr_i),
        .bus_cmd_rw_i(bus_cmd_rw_i),
        .bus_cmd_data_i(bus_cmd_data_i),
        .bus_cmd_mask_i(bus_cmd_mask_i),
        .bus_rsp_valid_o(bus_rsp_valid_o),
        .bus_rsp_data_o(bus_rsp_data_o),
        .bus_rsp_error_o(bus_rsp_error_o),
        .bus_rsp_latency_o(bus_rsp_latency_o),
        .d2d_cmd_valid_o(d2d_cmd_valid_o),
        .d2d_cmd_ready_i(d2d_cmd_ready_i),
        .d2d_cmd_addr_o(d2d_cmd_addr_o),
        .d2d_cmd_rw_o(d2d_cmd_rw_o),
        .d2d_cmd_burst_o(d2d_cmd_burst_o),
        .d2d_wdata_valid_o(d2d_wdata_valid_o),
        .d2d_wdata_o(d2d_wdata_o),
        .d2d_wdata_last_o(d2d_wdata_last_o),
        .d2d_rdata_valid_i(d2d_rdata_valid_i),
        .d2d_rdata_i(d2d_rdata_i),
        .d2d_rdata_last_i(d2d_rdata_last_i),
        .d2d_rdata_error_i(d2d_rdata_error_i),
        .d2d_tx_data_o(d2d_tx_data_o),
        .d2d_tx_clk_o(d2d_tx_clk_o),
        .d2d_rx_data_i(d2d_rx_data_i),
        .d2d_rx_clk_i(d2d_rx_clk_i),
        .d2d_pll_lock_i(d2d_pll_lock_i),
        .ecc_err_addr_o(ecc_err_addr_o),
        .ecc_err_type_o(ecc_err_type_o),
        .ecc_err_valid_o(ecc_err_valid_o),
        .ecc_err_clear_i(ecc_err_clear_i),
        .ecc_corrected_o(ecc_corrected_o),
        .bw_request_i(bw_request_i),
        .bw_grant_o(bw_grant_o),
        .bw_priority_i(bw_priority_i),
        .bw_status_o(bw_status_o),
        .dram_active_o(dram_active_o),
        .dram_idle_o(dram_idle_o),
        .dram_power_mode_i(dram_power_mode_i),
        .dram_self_refresh_req_i(dram_self_refresh_req_i),
        .dram_self_refresh_ack_o(dram_self_refresh_ack_o),
        .dram_status_o(dram_status_o),
        .dram_irq_o(dram_irq_o),
        .dram_irq_type_o(dram_irq_type_o)
    );

    //=========================================================================
    // Clock Assignment
    //=========================================================================
    assign clk_sys_i = clk_sys_i_ext;
    assign clk_d2d_i = clk_sys_i_ext;  // Simplified: same clock
    assign clk_d2d_pll_i = clk_sys_i_ext;

    //=========================================================================
    // Test FSM States
    //=========================================================================
    typedef enum {
        INIT, RESET,
        TEST_DRAM_READ, TEST_DRAM_WRITE,
       _TEST_DRAM_BURST_READ, TEST_DRAM_BURST_WRITE,
        TEST_ROW_HIT, TEST_ROW_MISS,
        TEST_REFRESH, TEST_SELF_REFRESH,
        TEST_ECC_CORRECTION, TEST_BANDWIDTH_ARB,
        DONE
    } test_state_t;

    test_state_t state;
    int wait_counter;
    int test_pass_count;
    int access_count;

    //=========================================================================
    // Test Stimulus
    //=========================================================================
    initial begin
        state = INIT;
        test_pass_count = 0;
        access_count = 0;

        // Initialize signals
        rst_sys_n_i = 0;
        bus_cmd_valid_i = 0;
        bus_cmd_addr_i = 0;
        bus_cmd_rw_i = 0;
        bus_cmd_data_i = 0;
        bus_cmd_mask_i = 8'hFF;
        d2d_cmd_ready_i = 1;
        d2d_rdata_valid_i = 0;
        d2d_rdata_i = 0;
        d2d_rdata_last_i = 0;
        d2d_rdata_error_i = 0;
        d2d_pll_lock_i = 1;
        ecc_err_clear_i = 0;
        bw_request_i = 16'h0001;
        bw_priority_i = 4'h0;
        dram_power_mode_i = 2'b00;
        dram_self_refresh_req_i = 0;

        // Reset phase
        repeat(10) @(posedge clk_sys_i);
        rst_sys_n_i = 1;
        state = RESET;
        repeat(5) @(posedge clk_sys_i);

        // Test DRAM Read
        state = TEST_DRAM_READ;
        for (int i = 0; i < 50; i++) begin
            @(posedge clk_sys_i);
            bus_cmd_valid_i = 1;
            bus_cmd_addr_i = 32'h0000_0000 + i*8;
            bus_cmd_rw_i = 0;
            wait_counter = 0;
            while (!bus_rsp_valid_o && wait_counter < 200) begin
                @(posedge clk_sys_i);
                // Simulate D2D response
                if (d2d_cmd_valid_o && d2d_cmd_ready_i) begin
                    d2d_rdata_valid_i = 1;
                    d2d_rdata_i = 72'h1234_5678_9ABC_DEF0_12;
                    d2d_rdata_last_i = 1;
                end
                wait_counter++;
            end
            bus_cmd_valid_i = 0;
            d2d_rdata_valid_i = 0;
        end

        // Test DRAM Write
        state = TEST_DRAM_WRITE;
        for (int i = 0; i < 50; i++) begin
            @(posedge clk_sys_i);
            bus_cmd_valid_i = 1;
            bus_cmd_addr_i = 32'h0000_1000 + i*8;
            bus_cmd_rw_i = 1;
            bus_cmd_data_i = 72'hDEAD_BEEF_CAFE_1234_56;
            repeat(20) @(posedge clk_sys_i);
            bus_cmd_valid_i = 0;
        end

        // Test Row Hit/Miss scenarios
        state = TEST_ROW_HIT;
        bus_cmd_addr_i = 32'h0000_0000;  // Same row
        repeat(20) @(posedge clk_sys_i);

        state = TEST_ROW_MISS;
        bus_cmd_addr_i = 32'h0001_0000;  // Different row
        repeat(20) @(posedge clk_sys_i);

        // Test Refresh
        state = TEST_REFRESH;
        repeat(100) @(posedge clk_sys_i);

        // Test Self Refresh
        state = TEST_SELF_REFRESH;
        dram_self_refresh_req_i = 1;
        repeat(50) @(posedge clk_sys_i);
        dram_self_refresh_req_i = 0;
        repeat(50) @(posedge clk_sys_i);

        // Test Bandwidth Arbitration
        state = TEST_BANDWIDTH_ARB;
        for (int p = 0; p < 4; p++) begin
            bw_priority_i = p;
            bw_request_i = 16'h0001 << p;
            repeat(20) @(posedge clk_sys_i);
        end

        state = DONE;
        repeat(10) @(posedge clk_sys_i);
    end

endmodule