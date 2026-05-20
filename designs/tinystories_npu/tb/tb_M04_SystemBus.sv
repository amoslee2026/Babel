//=============================================================================
// Testbench: M04_SystemBus
// Cycle-based testbench for Verilator coverage collection
//-----------------------------------------------------------------------------

module tb_M04_SystemBus (
    input logic clk_sys_ext  // External clock from C++
);

    //=========================================================================
    // Parameters
    //=========================================================================
    localparam DATA_WIDTH = 128;
    localparam ADDR_WIDTH = 32;

    //=========================================================================
    // Signals
    //=========================================================================
    logic clk_sys;
    logic clk_io;
    logic clk_aon;
    logic rst_por_n;
    logic rst_sys_n;

    // Control
    logic bus_enable;
    logic bus_busy;
    logic bus_error;
    logic [3:0] arb_winner;
    logic [2:0] route_target;
    logic timeout_irq;
    logic error_irq;

    // TileLink Master M0
    logic tl_m0_a_valid;
    logic tl_m0_a_ready;
    logic [2:0] tl_m0_a_opcode;
    logic [ADDR_WIDTH-1:0] tl_m0_a_address;
    logic [DATA_WIDTH-1:0] tl_m0_a_data;
    logic tl_m0_d_valid;
    logic tl_m0_d_ready;
    logic [DATA_WIDTH-1:0] tl_m0_d_data;

    // TileLink Master M1
    logic tl_m1_a_valid;
    logic tl_m1_a_ready;
    logic [ADDR_WIDTH-1:0] tl_m1_a_address;
    logic tl_m1_d_valid;
    logic tl_m1_d_ready;
    logic [DATA_WIDTH-1:0] tl_m1_d_data;

    // TileLink Slave S0 (DRAM)
    logic tl_s0_a_valid;
    logic tl_s0_a_ready;
    logic [ADDR_WIDTH-1:0] tl_s0_a_address;
    logic tl_s0_d_valid;
    logic tl_s0_d_ready;
    logic [DATA_WIDTH-1:0] tl_s0_d_data;

    // TileLink Slave S1 (SRAM)
    logic tl_s1_a_valid;
    logic tl_s1_a_ready;
    logic [ADDR_WIDTH-1:0] tl_s1_a_address;
    logic tl_s1_d_valid;
    logic tl_s1_d_ready;
    logic [DATA_WIDTH-1:0] tl_s1_d_data;

    // Register Slave S2
    logic reg_s2_req_valid;
    logic reg_s2_req_ready;
    logic [15:0] reg_s2_req_addr;
    logic reg_s2_rsp_valid;
    logic [31:0] reg_s2_rsp_data;

    // Register Slave S3
    logic reg_s3_req_valid;
    logic reg_s3_req_ready;
    logic reg_s3_rsp_valid;
    logic [31:0] reg_s3_rsp_data;

    //=========================================================================
    // DUT Instance
    //=========================================================================
    M04_SystemBus dut (
        .clk_sys(clk_sys),
        .clk_io(clk_io),
        .clk_aon(clk_aon),
        .rst_por_n(rst_por_n),
        .rst_sys_n(rst_sys_n),
        .bus_enable(bus_enable),
        .bus_busy(bus_busy),
        .bus_error(bus_error),
        .arb_winner(arb_winner),
        .route_target(route_target),
        .timeout_irq(timeout_irq),
        .error_irq(error_irq),
        .reg_s2_req_valid(reg_s2_req_valid),
        .reg_s2_req_ready(reg_s2_req_ready),
        .reg_s2_req_addr(reg_s2_req_addr),
        .reg_s2_req_data(32'h0),
        .reg_s2_rsp_valid(reg_s2_rsp_valid),
        .reg_s2_rsp_data(reg_s2_rsp_data),
        .tl_m0_a_valid(tl_m0_a_valid),
        .tl_m0_a_ready(tl_m0_a_ready),
        .tl_m0_a_opcode(tl_m0_a_opcode),
        .tl_m0_a_address(tl_m0_a_address),
        .tl_m0_a_data(tl_m0_a_data),
        .tl_m0_d_valid(tl_m0_d_valid),
        .tl_m0_d_ready(tl_m0_d_ready),
        .tl_m0_d_data(tl_m0_d_data),
        .tl_m1_a_valid(tl_m1_a_valid),
        .tl_m1_a_ready(tl_m1_a_ready),
        .tl_m1_a_address(tl_m1_a_address),
        .tl_m1_d_valid(tl_m1_d_valid),
        .tl_m1_d_ready(tl_m1_d_ready),
        .tl_m1_d_data(tl_m1_d_data),
        .tl_s0_a_valid(tl_s0_a_valid),
        .tl_s0_a_ready(tl_s0_a_ready),
        .tl_s0_a_address(tl_s0_a_address),
        .tl_s0_d_valid(tl_s0_d_valid),
        .tl_s0_d_ready(tl_s0_d_ready),
        .tl_s0_d_data(tl_s0_d_data),
        .tl_s1_a_valid(tl_s1_a_valid),
        .tl_s1_a_ready(tl_s1_a_ready),
        .tl_s1_a_address(tl_s1_a_address),
        .tl_s1_d_valid(tl_s1_d_valid),
        .tl_s1_d_ready(tl_s1_d_ready),
        .tl_s1_d_data(tl_s1_d_data),
        .reg_s3_req_valid(reg_s3_req_valid),
        .reg_s3_req_ready(reg_s3_req_ready),
        .reg_s3_rsp_valid(reg_s3_rsp_valid),
        .reg_s3_rsp_data(reg_s3_rsp_data)
    );

    //=========================================================================
    // Clock Assignment
    //=========================================================================
    assign clk_sys = clk_sys_ext;
    assign clk_io = clk_sys_ext;
    assign clk_aon = clk_sys_ext;

    //=========================================================================
    // Test FSM States
    //=========================================================================
    typedef enum {
        INIT, RESET,
        TEST_TL_M0_READ, TEST_TL_M0_WRITE,
        TEST_TL_M1_READ, TEST_TL_M1_WRITE,
        TEST_AXI_M3_READ, TEST_AXI_M3_WRITE,
        TEST_ADDR_DECODE_DRAM, TEST_ADDR_DECODE_SRAM,
        TEST_ADDR_DECODE_REGS,
        TEST_PRIORITY_ARB, TEST_TIMEOUT_ERROR,
        TEST_MULTI_MASTER,
        DONE
    } test_state_t;

    test_state_t state;
    int wait_counter;
    int test_pass_count;
    int transaction_count;

    //=========================================================================
    // Slave Response Simulation
    //=========================================================================
    always_ff @(posedge clk_sys) begin
        // DRAM Slave Response
        if (tl_s0_a_valid && tl_s0_a_ready) begin
            tl_s0_d_valid <= 1;
            tl_s0_d_data <= 128'h1234_5678_9ABC_DEF0_1234_5678_9ABC_DEF0;
        end else begin
            tl_s0_d_valid <= 0;
        end

        // SRAM Slave Response
        if (tl_s1_a_valid && tl_s1_a_ready) begin
            tl_s1_d_valid <= 1;
            tl_s1_d_data <= 128'hDEAD_BEEF_CAFE_1234_DEAD_BEEF_CAFE_1234;
        end else begin
            tl_s1_d_valid <= 0;
        end

        // Register Slave Response
        if (reg_s2_req_valid) begin
            reg_s2_rsp_valid <= 1;
            reg_s2_rsp_data <= 32'hCAFE_BEEF;
        end else begin
            reg_s2_rsp_valid <= 0;
        end

        if (reg_s3_req_valid) begin
            reg_s3_rsp_valid <= 1;
            reg_s3_rsp_data <= 32'h1234_5678;
        end else begin
            reg_s3_rsp_valid <= 0;
        end
    end

    //=========================================================================
    // Test Stimulus
    //=========================================================================
    initial begin
        state = INIT;
        test_pass_count = 0;
        transaction_count = 0;

        // Initialize signals
        rst_por_n = 0;
        rst_sys_n = 0;
        bus_enable = 0;
        tl_m0_a_valid = 0;
        tl_m0_a_opcode = 0;
        tl_m0_a_address = 0;
        tl_m0_a_data = 0;
        tl_m0_d_ready = 1;
        tl_m1_a_valid = 0;
        tl_m1_a_address = 0;
        tl_m1_d_ready = 1;
        tl_s0_a_ready = 1;
        tl_s0_d_valid = 0;
        tl_s0_d_data = 0;
        tl_s1_a_ready = 1;
        tl_s1_d_valid = 0;
        tl_s1_d_data = 0;
        reg_s2_req_ready = 1;
        reg_s3_req_ready = 1;

        // Reset phase
        repeat(10) @(posedge clk_sys);
        rst_por_n = 1;
        rst_sys_n = 1;
        bus_enable = 1;
        state = RESET;
        repeat(10) @(posedge clk_sys);

        // Test TileLink M0 Read (DRAM)
        state = TEST_TL_M0_READ;
        for (int i = 0; i < 50; i++) begin
            @(posedge clk_sys);
            tl_m0_a_valid = 1;
            tl_m0_a_opcode = 3'b100;  // Get
            tl_m0_a_address = 32'h0000_0000 + i*16;
            tl_m0_a_data = 0;
            wait_counter = 0;
            while (!tl_m0_d_valid && wait_counter < 50) begin
                @(posedge clk_sys);
                wait_counter++;
            end
            if (tl_m0_d_valid) test_pass_count++;
            tl_m0_a_valid = 0;
            transaction_count++;
        end

        // Test TileLink M0 Write (DRAM)
        state = TEST_TL_M0_WRITE;
        for (int i = 0; i < 50; i++) begin
            @(posedge clk_sys);
            tl_m0_a_valid = 1;
            tl_m0_a_opcode = 3'b000;  // PutFullData
            tl_m0_a_address = 32'h0000_1000 + i*16;
            tl_m0_a_data = 128'hDEAD_BEEF_CAFE_1234_DEAD_BEEF_CAFE_1234;
            repeat(10) @(posedge clk_sys);
            tl_m0_a_valid = 0;
        end

        // Test TileLink M1 Read (SRAM)
        state = TEST_TL_M1_READ;
        for (int i = 0; i < 50; i++) begin
            @(posedge clk_sys);
            tl_m1_a_valid = 1;
            tl_m1_a_address = 32'h8000_0000 + i*16;
            wait_counter = 0;
            while (!tl_m1_d_valid && wait_counter < 50) begin
                @(posedge clk_sys);
                wait_counter++;
            end
            tl_m1_a_valid = 0;
        end

        // Test Address Decode
        state = TEST_ADDR_DECODE_DRAM;
        tl_m0_a_valid = 1;
        tl_m0_a_address = 32'h0000_0000;
        repeat(10) @(posedge clk_sys);

        state = TEST_ADDR_DECODE_SRAM;
        tl_m0_a_address = 32'h8000_0000;
        repeat(10) @(posedge clk_sys);

        state = TEST_ADDR_DECODE_REGS;
        tl_m0_a_address = 32'h8008_0000;
        repeat(10) @(posedge clk_sys);
        tl_m0_a_address = 32'h8009_0000;
        repeat(10) @(posedge clk_sys);
        tl_m0_a_address = 32'h800A_0000;
        repeat(10) @(posedge clk_sys);
        tl_m0_a_address = 32'h800C_0000;
        repeat(10) @(posedge clk_sys);
        tl_m0_a_valid = 0;

        // Test Priority Arbitration
        state = TEST_PRIORITY_ARB;
        for (int p = 0; p < 5; p++) begin
            @(posedge clk_sys);
            tl_m0_a_valid = (p == 0);
            tl_m1_a_valid = (p == 1);
            repeat(20) @(posedge clk_sys);
        end
        tl_m0_a_valid = 0;
        tl_m1_a_valid = 0;

        // Test Multi-Master
        state = TEST_MULTI_MASTER;
        tl_m0_a_valid = 1;
        tl_m1_a_valid = 1;
        repeat(100) @(posedge clk_sys);
        tl_m0_a_valid = 0;
        tl_m1_a_valid = 0;

        state = DONE;
        repeat(10) @(posedge clk_sys);
    end

endmodule