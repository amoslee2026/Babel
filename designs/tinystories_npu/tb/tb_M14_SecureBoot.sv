//=============================================================================
// Testbench: M14_SecureBoot
// Cycle-based testbench for Verilator coverage collection
//-----------------------------------------------------------------------------

module tb_M14_SecureBoot (
    input logic clk_sys_ext  // External clock from C++
);

    //=========================================================================
    // Signals
    //=========================================================================
    logic clk_sys;
    logic rst_sys_n;
    logic rst_por_n;

    // Firmware Interface
    logic [31:0] fw_addr;
    logic [31:0] fw_size;
    logic fw_data_req;
    logic [31:0] fw_data_addr;
    logic fw_data_valid;
    logic [255:0] fw_data;
    logic fw_data_last;

    // Signature Interface
    logic [255:0] sig_r;
    logic [255:0] sig_s;
    logic sig_valid;

    // OTP Interface
    logic [7:0] otp_key_addr;
    logic [511:0] otp_key_data;
    logic otp_key_valid;
    logic otp_read_ack;
    logic otp_read_req;
    logic otp_locked;

    // Security Control
    logic sec_boot_en;
    logic sec_status;
    logic sec_lock;
    logic sec_unlock_req;

    // TEST_MODE
    logic test_mode_en;
    logic [255:0] test_mode_key;
    logic test_mode_valid;
    logic test_bypass;

    // Boot Control
    logic boot_start;
    logic boot_done;
    logic boot_status;
    logic [7:0] boot_error_code;

    //=========================================================================
    // DUT Instance
    //=========================================================================
    M14_SecureBoot dut (
        .clk_sys(clk_sys),
        .rst_sys_n(rst_sys_n),
        .rst_por_n(rst_por_n),
        .fw_addr(fw_addr),
        .fw_size(fw_size),
        .fw_data_req(fw_data_req),
        .fw_data_addr(fw_data_addr),
        .fw_data_valid(fw_data_valid),
        .fw_data(fw_data),
        .fw_data_last(fw_data_last),
        .sig_r(sig_r),
        .sig_s(sig_s),
        .sig_valid(sig_valid),
        .otp_key_addr(otp_key_addr),
        .otp_key_data(otp_key_data),
        .otp_key_valid(otp_key_valid),
        .otp_read_ack(otp_read_ack),
        .otp_read_req(otp_read_req),
        .otp_locked(otp_locked),
        .sec_boot_en(sec_boot_en),
        .sec_status(sec_status),
        .sec_lock(sec_lock),
        .sec_unlock_req(sec_unlock_req),
        .test_mode_en(test_mode_en),
        .test_mode_key(test_mode_key),
        .test_mode_valid(test_mode_valid),
        .test_bypass(test_bypass),
        .boot_start(boot_start),
        .boot_done(boot_done),
        .boot_status(boot_status),
        .boot_error_code(boot_error_code)
    );

    //=========================================================================
    // Clock Assignment
    //=========================================================================
    assign clk_sys = clk_sys_ext;

    //=========================================================================
    // OTP and Firmware Response Simulation
    //=========================================================================
    always_ff @(posedge clk_sys) begin
        // OTP Response
        if (otp_read_req) begin
            otp_read_ack <= 1;
            otp_key_valid <= 1;
            otp_key_data <= {512{1'b1}};
        end else begin
            otp_read_ack <= 0;
            otp_key_valid <= 0;
        end

        // Firmware Response
        if (fw_data_req) begin
            fw_data_valid <= 1;
            fw_data <= {256{1'b1}};
            fw_data_last <= (fw_data_addr >= fw_size - 32);
        end else begin
            fw_data_valid <= 0;
            fw_data_last <= 0;
        end
    end

    //=========================================================================
    // Test FSM States
    //=========================================================================
    typedef enum {
        INIT, RESET,
        TEST_BOOT_SEQUENCE, TEST_SIGNATURE_VERIFY,
        TEST_OTP_READ, TEST_SHA256_HASH,
        TEST_TEST_MODE, TEST_RETRY_MECHANISM,
        TEST_LOCKOUT, TEST_UNLOCK,
        TEST_ERROR_CASES, DONE
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
        rst_sys_n = 0;
        rst_por_n = 0;
        fw_addr = 32'h8000_0000;
        fw_size = 32'h0000_1000;
        fw_data_valid = 0;
        fw_data = 0;
        fw_data_last = 0;
        sig_r = {256{1'b1}};
        sig_s = {256{1'b0}};
        sig_valid = 1;
        otp_locked = 1;
        sec_boot_en = 1;
        sec_unlock_req = 0;
        test_mode_en = 0;
        test_mode_key = 0;
        test_mode_valid = 0;
        boot_start = 0;

        // Reset phase
        repeat(10) @(posedge clk_sys);
        rst_por_n = 1;
        rst_sys_n = 1;
        state = RESET;
        repeat(10) @(posedge clk_sys);

        // Test Boot Sequence
        state = TEST_BOOT_SEQUENCE;
        boot_start = 1;
        @(posedge clk_sys);
        boot_start = 0;
        wait_counter = 0;
        while (!boot_done && wait_counter < 5000) begin
            @(posedge clk_sys);
            wait_counter++;
        end
        if (boot_done) test_pass_count++;

        // Test Signature Verification
        state = TEST_SIGNATURE_VERIFY;
        sig_valid = 1;
        sig_r = 256'h1234_5678_9ABC_DEF0;
        sig_s = 256'hDEAD_BEEF_CAFE_1234;
        boot_start = 1;
        @(posedge clk_sys);
        boot_start = 0;
        repeat(500) @(posedge clk_sys);

        // Test OTP Read
        state = TEST_OTP_READ;
        otp_locked = 1;
        otp_key_data = {512{1'b1}};
        repeat(200) @(posedge clk_sys);

        // Test SHA-256 Hash
        state = TEST_SHA256_HASH;
        fw_data_valid = 1;
        fw_data = {256{1'b1}};
        repeat(100) @(posedge clk_sys);
        fw_data_last = 1;
        repeat(100) @(posedge clk_sys);
        fw_data_last = 0;
        fw_data_valid = 0;

        // Test TEST_MODE Bypass
        state = TEST_TEST_MODE;
        test_mode_en = 1;
        test_mode_valid = 1;
        test_mode_key = {256{1'b1}};
        boot_start = 1;
        @(posedge clk_sys);
        boot_start = 0;
        repeat(200) @(posedge clk_sys);
        test_mode_en = 0;

        // Test Retry Mechanism
        state = TEST_RETRY_MECHANISM;
        sig_valid = 0;  // Invalid signature
        boot_start = 1;
        @(posedge clk_sys);
        boot_start = 0;
        repeat(100) @(posedge clk_sys);
        sig_valid = 1;  // Valid signature again
        boot_start = 1;
        @(posedge clk_sys);
        boot_start = 0;
        repeat(200) @(posedge clk_sys);

        // Test Lockout
        state = TEST_LOCKOUT;
        sig_valid = 0;
        for (int retry = 0; retry < 5; retry++) begin
            boot_start = 1;
            @(posedge clk_sys);
            boot_start = 0;
            repeat(200) @(posedge clk_sys);
        end
        sig_valid = 1;

        // Test Unlock
        state = TEST_UNLOCK;
        if (sec_lock) begin
            sec_unlock_req = 1;
            repeat(50) @(posedge clk_sys);
            sec_unlock_req = 0;
        end

        // Test Error Cases
        state = TEST_ERROR_CASES;
        fw_size = 0;  // Invalid firmware size
        boot_start = 1;
        @(posedge clk_sys);
        boot_start = 0;
        repeat(100) @(posedge clk_sys);
        fw_size = 32'h0000_1000;

        otp_locked = 0;  // OTP not locked
        boot_start = 1;
        @(posedge clk_sys);
        boot_start = 0;
        repeat(100) @(posedge clk_sys);
        otp_locked = 1;

        state = DONE;
        repeat(10) @(posedge clk_sys);
    end

endmodule