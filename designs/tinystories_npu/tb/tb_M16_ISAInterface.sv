//=============================================================================
// Testbench: M16_ISAInterface
// Cycle-based testbench for Verilator coverage collection
//-----------------------------------------------------------------------------

module tb_M16_ISAInterface (
    input logic clk_sys_ext  // External clock from C++
);

    //=========================================================================
    // Parameters
    //=========================================================================
    localparam DATA_WIDTH = 16;
    localparam INST_WIDTH = 32;
    localparam PC_WIDTH = 32;

    //=========================================================================
    // Signals
    //=========================================================================
    logic clk_sys_i;
    logic rst_sys_n_i;

    // ISA_IF External Interface
    logic [DATA_WIDTH-1:0] ISA_IF;
    logic ISA_CLK;
    logic ISA_VALID;
    logic ISA_DIR;
    logic ISA_READY;

    // CDC Bridge Interface
    logic [INST_WIDTH-1:0] isa_data_sys_o;
    logic isa_valid_sys_o;
    logic isa_ready_sys_i;
    logic isa_req_sys_o;
    logic [PC_WIDTH-1:0] isa_pc_o;

    // Control Interface
    logic m16_reset_n_i;
    logic m16_enable_i;
    logic [1:0] m16_mode_i;

    // Security Interface
    logic sec_boot_done_i;
    logic sec_status_pass_i;
    logic sec_status_fail_i;
    logic sec_lockdown_i;
    logic isa_access_grant_o;
    logic isa_access_denied_o;
    logic isa_crc_error_o;

    // Error Status
    logic error_cdc_timeout_o;
    logic error_invalid_opcode_o;
    logic error_security_o;
    logic error_crc_o;

    //=========================================================================
    // DUT Instance
    //=========================================================================
    M16_ISAInterface dut (
        .ISA_IF(ISA_IF),
        .ISA_CLK(ISA_CLK),
        .ISA_VALID(ISA_VALID),
        .ISA_DIR(ISA_DIR),
        .ISA_READY(ISA_READY),
        .isa_data_sys_o(isa_data_sys_o),
        .isa_valid_sys_o(isa_valid_sys_o),
        .isa_ready_sys_i(isa_ready_sys_i),
        .isa_req_sys_o(isa_req_sys_o),
        .isa_pc_o(isa_pc_o),
        .m16_reset_n_i(m16_reset_n_i),
        .m16_enable_i(m16_enable_i),
        .m16_mode_i(m16_mode_i),
        .sec_boot_done_i(sec_boot_done_i),
        .sec_status_pass_i(sec_status_pass_i),
        .sec_status_fail_i(sec_status_fail_i),
        .sec_lockdown_i(sec_lockdown_i),
        .isa_access_grant_o(isa_access_grant_o),
        .isa_access_denied_o(isa_access_denied_o),
        .isa_crc_error_o(isa_crc_error_o),
        .isa_auth_token_i(128'h0),
        .clk_sys_i(clk_sys_i),
        .rst_sys_n_i(rst_sys_n_i),
        .error_cdc_timeout_o(error_cdc_timeout_o),
        .error_invalid_opcode_o(error_invalid_opcode_o),
        .error_security_o(error_security_o),
        .error_crc_o(error_crc_o)
    );

    //=========================================================================
    // Clock Assignment
    //=========================================================================
    assign clk_sys_i = clk_sys_ext;
    assign ISA_CLK = clk_sys_ext;  // Simplified: same clock

    //=========================================================================
    // Bidirectional Bus Simulation
    //=========================================================================
    logic [DATA_WIDTH-1:0] isa_if_data;

    always_ff @(posedge clk_sys_i) begin
        if (ISA_DIR == 1) begin  // TX mode
            ISA_IF <= isa_if_data;
        end else begin  // RX mode
            ISA_IF <= 16'hFFFF;  // Simulated external data
        end
        ISA_READY <= 1;  // Always ready for simplicity
    end

    //=========================================================================
    // Test FSM States
    //=========================================================================
    typedef enum {
        INIT, RESET,
        TEST_RX_MODE, TEST_TX_MODE,
        TEST_BIDIR_MODE, TEST_CDC_HANDSHAKE,
        TEST_32BIT_INSTRUCTION, TEST_SECURITY_CHECK,
        TEST_CRC_CHECK, TEST_TIMEOUT,
        TEST_INVALID_OPCODE, TEST_LOCKDOWN,
        DONE
    } test_state_t;

    test_state_t state;
    int wait_counter;
    int test_pass_count;
    int instruction_count;

    //=========================================================================
    // Test Stimulus
    //=========================================================================
    initial begin
        state = INIT;
        test_pass_count = 0;
        instruction_count = 0;

        // Initialize signals
        rst_sys_n_i = 0;
        m16_reset_n_i = 0;
        m16_enable_i = 1;
        m16_mode_i = 2;  // Bidirectional
        isa_ready_sys_i = 1;
        sec_boot_done_i = 1;
        sec_status_pass_i = 1;
        sec_status_fail_i = 0;
        sec_lockdown_i = 0;
        isa_if_data = 0;

        // Reset phase
        repeat(10) @(posedge clk_sys_i);
        rst_sys_n_i = 1;
        m16_reset_n_i = 1;
        state = RESET;
        repeat(10) @(posedge clk_sys_i);

        // Test RX Mode (Receive Instructions)
        state = TEST_RX_MODE;
        m16_mode_i = 0;  // RX mode
        for (int i = 0; i < 100; i++) begin
            isa_if_data = i;
            @(posedge clk_sys_i);
            if (isa_valid_sys_o) test_pass_count++;
        end

        // Test TX Mode (Transmit Data)
        state = TEST_TX_MODE;
        m16_mode_i = 1;  // TX mode
        ISA_DIR = 1;
        for (int i = 0; i < 50; i++) begin
            isa_if_data = 16'h1234 + i;
            @(posedge clk_sys_i);
        end

        // Test Bidirectional Mode
        state = TEST_BIDIR_MODE;
        m16_mode_i = 2;  // Bidir mode
        for (int i = 0; i < 100; i++) begin
            ISA_DIR = i % 2;  // Alternate direction
            isa_if_data = i;
            @(posedge clk_sys_i);
        end

        // Test CDC Handshake
        state = TEST_CDC_HANDSHAKE;
        isa_ready_sys_i = 1;
        for (int i = 0; i < 50; i++) begin
            @(posedge clk_sys_i);
            if (isa_req_sys_o) begin
                isa_ready_sys_i = 1;
                @(posedge clk_sys_i);
                isa_ready_sys_i = 0;
            end
        end

        // Test 32-bit Instruction Assembly
        state = TEST_32BIT_INSTRUCTION;
        m16_mode_i = 0;
        for (int i = 0; i < 50; i++) begin
            // Send two 16-bit halves
            isa_if_data = 16'h1234;  // Lower half
            @(posedge clk_sys_i);
            isa_if_data = 16'h5678;  // Upper half
            @(posedge clk_sys_i);
            instruction_count++;
        end

        // Test Security Check
        state = TEST_SECURITY_CHECK;
        sec_boot_done_i = 1;
        sec_status_pass_i = 1;
        sec_lockdown_i = 0;
        repeat(100) @(posedge clk_sys_i);
        if (isa_access_grant_o) test_pass_count++;

        // Test Security Lockdown
        state = TEST_LOCKDOWN;
        sec_lockdown_i = 1;
        repeat(50) @(posedge clk_sys_i);
        sec_lockdown_i = 0;
        repeat(50) @(posedge clk_sys_i);

        // Test CRC Check
        state = TEST_CRC_CHECK;
        // Valid data
        isa_if_data = 16'h1234;
        repeat(20) @(posedge clk_sys_i);
        // Invalid data (would trigger CRC error)
        isa_if_data = 16'hFFFF;
        repeat(20) @(posedge clk_sys_i);

        // Test Timeout
        state = TEST_TIMEOUT;
        ISA_READY = 0;  // Simulate timeout
        repeat(300) @(posedge clk_sys_i);
        ISA_READY = 1;
        repeat(20) @(posedge clk_sys_i);

        // Test Invalid Opcode
        state = TEST_INVALID_OPCODE;
        isa_if_data = 16'h00FF;  // Invalid opcode pattern
        repeat(50) @(posedge clk_sys_i);

        state = DONE;
        repeat(10) @(posedge clk_sys_i);
    end

endmodule