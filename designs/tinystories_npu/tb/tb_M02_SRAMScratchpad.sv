//=============================================================================
// Testbench: M02_SRAMScratchpad
// Cycle-based testbench for Verilator coverage collection
//-----------------------------------------------------------------------------

module tb_M02_SRAMScratchpad (
    input logic clk_sys_i_ext  // External clock from C++
);

    //=========================================================================
    // Parameters
    //=========================================================================
    localparam SRAM_DEPTH = 131072;
    localparam ADDR_WIDTH = 20;
    localparam DATA_WIDTH = 32;

    //=========================================================================
    // Signals
    //=========================================================================
    logic clk_sys_i;
    logic rst_sys_n_i;
    logic pg_main_en_i;

    // Bus Interface
    logic        bus_cmd_valid_i;
    logic        bus_cmd_ready_o;
    logic [31:0] bus_cmd_addr_i;
    logic        bus_cmd_rw_i;
    logic [1:0]  bus_cmd_width_i;
    logic [63:0] bus_cmd_wdata_i;
    logic [7:0]  bus_cmd_wstrb_i;
    logic        bus_rsp_valid_o;
    logic [63:0] bus_rsp_rdata_o;
    logic        bus_rsp_error_o;

    // Direct Interface
    logic        sram_req_valid_i;
    logic [ADDR_WIDTH-1:0] sram_req_addr_i;
    logic        sram_req_rw_i;
    logic [63:0] sram_req_wdata_i;
    logic [7:0]  sram_req_wstrb_i;
    logic        sram_rsp_valid_o;
    logic [63:0] sram_rsp_rdata_o;
    logic        sram_rsp_error_o;

    // Arbitration
    logic [3:0]  arb_master_id_i;
    logic [2:0]  arb_priority_i;
    logic [3:0]  arb_grant_o;
    logic        arb_busy_o;

    // ECC Status
    logic [31:0] ecc_err_addr_o;
    logic        ecc_err_type_o;
    logic        ecc_err_valid_o;
    logic        ecc_irq_o;

    // Power Management
    logic        sram_retention_i;
    logic        sram_power_gate_i;
    logic        sram_power_status_o;

    //=========================================================================
    // DUT Instance
    //=========================================================================
    M02_SRAMScratchpad dut (
        .clk_sys_i(clk_sys_i),
        .rst_sys_n_i(rst_sys_n_i),
        .pg_main_en_i(pg_main_en_i),
        .bus_cmd_valid_i(bus_cmd_valid_i),
        .bus_cmd_ready_o(bus_cmd_ready_o),
        .bus_cmd_addr_i(bus_cmd_addr_i),
        .bus_cmd_rw_i(bus_cmd_rw_i),
        .bus_cmd_width_i(bus_cmd_width_i),
        .bus_cmd_wdata_i(bus_cmd_wdata_i),
        .bus_cmd_wstrb_i(bus_cmd_wstrb_i),
        .bus_rsp_valid_o(bus_rsp_valid_o),
        .bus_rsp_rdata_o(bus_rsp_rdata_o),
        .bus_rsp_error_o(bus_rsp_error_o),
        .sram_req_valid_i(sram_req_valid_i),
        .sram_req_addr_i(sram_req_addr_i),
        .sram_req_rw_i(sram_req_rw_i),
        .sram_req_wdata_i(sram_req_wdata_i),
        .sram_req_wstrb_i(sram_req_wstrb_i),
        .sram_rsp_valid_o(sram_rsp_valid_o),
        .sram_rsp_rdata_o(sram_rsp_rdata_o),
        .sram_rsp_error_o(sram_rsp_error_o),
        .arb_master_id_i(arb_master_id_i),
        .arb_priority_i(arb_priority_i),
        .arb_grant_o(arb_grant_o),
        .arb_busy_o(arb_busy_o),
        .ecc_err_addr_o(ecc_err_addr_o),
        .ecc_err_type_o(ecc_err_type_o),
        .ecc_err_valid_o(ecc_err_valid_o),
        .ecc_irq_o(ecc_irq_o),
        .sram_retention_i(sram_retention_i),
        .sram_power_gate_i(sram_power_gate_i),
        .sram_power_status_o(sram_power_status_o)
    );

    //=========================================================================
    // Clock Assignment
    //=========================================================================
    assign clk_sys_i = clk_sys_i_ext;

    //=========================================================================
    // Test FSM States
    //=========================================================================
    typedef enum {
        INIT, RESET,
        TEST_READ_32BIT, TEST_READ_64BIT,
        TEST_WRITE_32BIT, TEST_WRITE_64BIT,
        TEST_BANK_ARBITRATION, TEST_BURST_ACCESS,
        TEST_ECC_SINGLE_ERR, TEST_ECC_DOUBLE_ERR,
        TEST_ADDR_BOUNDARY, TEST_POWER_GATE,
        DONE
    } test_state_t;

    test_state_t state;
    int wait_counter;
    int test_pass_count;
    int test_fail_count;
    int access_count;

    //=========================================================================
    // Test Stimulus
    //=========================================================================
    initial begin
        state = INIT;
        test_pass_count = 0;
        test_fail_count = 0;
        access_count = 0;

        // Initialize signals
        rst_sys_n_i = 0;
        pg_main_en_i = 1;
        bus_cmd_valid_i = 0;
        bus_cmd_addr_i = 0;
        bus_cmd_rw_i = 0;
        bus_cmd_width_i = 0;
        bus_cmd_wdata_i = 0;
        bus_cmd_wstrb_i = 0;
        sram_req_valid_i = 0;
        sram_req_addr_i = 0;
        sram_req_rw_i = 0;
        sram_req_wdata_i = 0;
        sram_req_wstrb_i = 0;
        arb_master_id_i = 0;
        arb_priority_i = 0;
        sram_retention_i = 0;
        sram_power_gate_i = 0;

        // Reset phase
        repeat(10) @(posedge clk_sys_i);
        rst_sys_n_i = 1;
        state = RESET;
        repeat(5) @(posedge clk_sys_i);

        // Test 32-bit Read
        state = TEST_READ_32BIT;
        for (int i = 0; i < 100; i++) begin
            @(posedge clk_sys_i);
            bus_cmd_valid_i = 1;
            bus_cmd_addr_i = 32'h8000_0000 + i*4;
            bus_cmd_rw_i = 0;
            bus_cmd_width_i = 0;
            bus_cmd_wstrb_i = 8'hFF;
            arb_master_id_i = 4'h0;
            arb_priority_i = 3'b000;
            wait_counter = 0;
            while (!bus_rsp_valid_o && wait_counter < 100) begin
                @(posedge clk_sys_i);
                wait_counter++;
            end
            if (bus_rsp_valid_o) test_pass_count++;
            bus_cmd_valid_i = 0;
        end

        // Test 32-bit Write
        state = TEST_WRITE_32BIT;
        for (int i = 0; i < 100; i++) begin
            @(posedge clk_sys_i);
            bus_cmd_valid_i = 1;
            bus_cmd_addr_i = 32'h8000_1000 + i*4;
            bus_cmd_rw_i = 1;
            bus_cmd_width_i = 0;
            bus_cmd_wdata_i = 64'hDEAD_BEEF_CAFE_1234 + i;
            bus_cmd_wstrb_i = 8'hFF;
            wait_counter = 0;
            while (!bus_rsp_valid_o && wait_counter < 100) begin
                @(posedge clk_sys_i);
                wait_counter++;
            end
            if (bus_rsp_valid_o) test_pass_count++;
            bus_cmd_valid_i = 0;
        end

        // Test 64-bit Read
        state = TEST_READ_64BIT;
        for (int i = 0; i < 50; i++) begin
            @(posedge clk_sys_i);
            bus_cmd_valid_i = 1;
            bus_cmd_addr_i = 32'h8000_2000 + i*8;
            bus_cmd_rw_i = 0;
            bus_cmd_width_i = 1;
            arb_priority_i = 3'b001;
            wait_counter = 0;
            while (!bus_rsp_valid_o && wait_counter < 100) begin
                @(posedge clk_sys_i);
                wait_counter++;
            end
            bus_cmd_valid_i = 0;
        end

        // Test Bank Arbitration (different masters)
        state = TEST_BANK_ARBITRATION;
        for (int p = 0; p < 4; p++) begin
            arb_priority_i = p;
            arb_master_id_i = p;
            repeat(20) @(posedge clk_sys_i);
            bus_cmd_valid_i = 1;
            bus_cmd_addr_i = 32'h8000_0000 + p*256;
            bus_cmd_rw_i = 0;
            repeat(20) @(posedge clk_sys_i);
            bus_cmd_valid_i = 0;
        end

        // Test Burst Access
        state = TEST_BURST_ACCESS;
        for (int i = 0; i < 16; i++) begin
            @(posedge clk_sys_i);
            sram_req_valid_i = 1;
            sram_req_addr_i = i*32;
            sram_req_rw_i = 0;
            repeat(2) @(posedge clk_sys_i);
        end
        sram_req_valid_i = 0;

        // Test ECC Single Error
        state = TEST_ECC_SINGLE_ERR;
        repeat(50) @(posedge clk_sys_i);

        // Test Address Boundary
        state = TEST_ADDR_BOUNDARY;
        bus_cmd_valid_i = 1;
        bus_cmd_addr_i = 32'h8007_FFFC;  // Last valid address
        bus_cmd_rw_i = 0;
        repeat(20) @(posedge clk_sys_i);
        bus_cmd_addr_i = 32'h8008_0000;  // Invalid address
        repeat(20) @(posedge clk_sys_i);
        bus_cmd_valid_i = 0;

        // Test Power Gate
        state = TEST_POWER_GATE;
        sram_power_gate_i = 1;
        repeat(20) @(posedge clk_sys_i);
        sram_power_gate_i = 0;
        pg_main_en_i = 1;
        repeat(20) @(posedge clk_sys_i);

        state = DONE;
        repeat(10) @(posedge clk_sys_i);
    end

endmodule