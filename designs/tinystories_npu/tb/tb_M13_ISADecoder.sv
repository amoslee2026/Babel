//=============================================================================
// Testbench: M13_ISADecoder
// Cycle-based testbench for Verilator coverage collection
//-----------------------------------------------------------------------------

module tb_M13_ISADecoder (
    input logic clk_sys_i_ext  // External clock from C++
);

    //=========================================================================
    // Parameters
    //=========================================================================
    localparam PC_WIDTH = 32;
    localparam INST_WIDTH = 32;

    //=========================================================================
    // Signals
    //=========================================================================
    logic clk_sys_i;
    logic rst_sys_n_i;
    logic pg_main_en_i;

    // ISA Interface
    logic isa_inst_valid_i;
    logic [INST_WIDTH-1:0] isa_inst_data_i;
    logic isa_inst_ready_o;
    logic [PC_WIDTH-1:0] isa_pc_i;
    logic isa_pc_update_o;

    // Decoded Output
    logic dec_valid_o;
    logic [5:0] dec_opcode_o;
    logic [1:0] dec_format_o;
    logic [4:0] dec_vd_o;
    logic [4:0] dec_vs1_o;
    logic [4:0] dec_vs2_o;
    logic [4:0] dec_vs3_o;
    logic [15:0] dec_imm16_o;
    logic [20:0] dec_imm21_o;

    // Operator Dispatch
    logic op_valid_o;
    logic [3:0] op_target_o;
    logic op_ready_i;
    logic op_start_o;
    logic op_done_i;

    // Systolic Array
    logic sa_cmd_valid_o;
    logic [1:0] sa_op_o;
    logic sa_ready_i;

    // Memory
    logic [PC_WIDTH-1:0] mem_addr_o;
    logic mem_wen_o;
    logic mem_valid_o;
    logic mem_ready_i;

    // Secure Boot
    logic sec_valid_i;
    logic sec_en_i;

    // Control
    logic sched_start_i;
    logic sched_pause_i;
    logic sched_abort_i;
    logic dec_done_o;
    logic dec_busy_o;

    // Error Status
    logic error_invalid_opcode_o;
    logic error_invalid_format_o;

    //=========================================================================
    // DUT Instance
    //=========================================================================
    M13_ISADecoder dut (
        .clk_sys_i(clk_sys_i),
        .rst_sys_n_i(rst_sys_n_i),
        .pg_main_en_i(pg_main_en_i),
        .isa_inst_valid_i(isa_inst_valid_i),
        .isa_inst_data_i(isa_inst_data_i),
        .isa_inst_ready_o(isa_inst_ready_o),
        .isa_pc_i(isa_pc_i),
        .isa_pc_update_o(isa_pc_update_o),
        .dec_valid_o(dec_valid_o),
        .dec_opcode_o(dec_opcode_o),
        .dec_format_o(dec_format_o),
        .dec_vd_o(dec_vd_o),
        .dec_vs1_o(dec_vs1_o),
        .dec_vs2_o(dec_vs2_o),
        .dec_vs3_o(dec_vs3_o),
        .dec_sd_o(),
        .dec_imm16_o(dec_imm16_o),
        .dec_imm21_o(dec_imm21_o),
        .dec_base_o(),
        .dec_offset_o(),
        .dec_func_o(),
        .op_valid_o(op_valid_o),
        .op_target_o(op_target_o),
        .op_ready_i(op_ready_i),
        .op_start_o(op_start_o),
        .op_done_i(op_done_i),
        .sa_cmd_valid_o(sa_cmd_valid_o),
        .sa_op_o(sa_op_o),
        .sa_ready_i(sa_ready_i),
        .mem_addr_o(mem_addr_o),
        .mem_wen_o(mem_wen_o),
        .mem_valid_o(mem_valid_o),
        .mem_ready_i(mem_ready_i),
        .sec_valid_i(sec_valid_i),
        .sec_en_i(sec_en_i),
        .sched_start_i(sched_start_i),
        .sched_pause_i(sched_pause_i),
        .sched_abort_i(sched_abort_i),
        .dec_done_o(dec_done_o),
        .dec_busy_o(dec_busy_o),
        .error_invalid_opcode_o(error_invalid_opcode_o),
        .error_invalid_format_o(error_invalid_format_o),
        .error_invalid_reg_o(),
        .error_secure_boot_fail_o()
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
        TEST_OPCODE_DECODING, TEST_FORMAT_DECODING,
        TEST_IMM_EXTRACTION, TEST_REG_DECODING,
        TEST_BNZ_BRANCH, TEST_INVALID_OPCODE,
        TEST_OPERATOR_DISPATCH, TEST_SA_CMD,
        TEST_SECURE_BOOT, TEST_PAUSE_ABORT,
        DONE
    } test_state_t;

    test_state_t state;
    int wait_counter;
    int test_pass_count;

    //=========================================================================
    // Instruction Templates
    //=========================================================================
    // R-type: opcode[5:0] | vd[5] | vs1[5] | vs2[5] | func[6]
    // I-type: opcode[5:0] | vd[5] | imm[16]
    // S-type: opcode[5:0] | sd[5] | base[5] | offset[11]

    //=========================================================================
    // Test Stimulus
    //=========================================================================
    initial begin
        state = INIT;
        test_pass_count = 0;

        // Initialize signals
        rst_sys_n_i = 0;
        pg_main_en_i = 1;
        isa_inst_valid_i = 0;
        isa_inst_data_i = 0;
        isa_pc_i = 32'h8000_0000;
        op_ready_i = 1;
        op_done_i = 0;
        sa_ready_i = 1;
        mem_ready_i = 1;
        sec_valid_i = 1;
        sec_en_i = 1;
        sched_start_i = 0;
        sched_pause_i = 0;
        sched_abort_i = 0;

        // Reset phase
        repeat(10) @(posedge clk_sys_i);
        rst_sys_n_i = 1;
        state = RESET;
        repeat(10) @(posedge clk_sys_i);

        // Test Opcode Decoding (32 instructions)
        state = TEST_OPCODE_DECODING;
        for (int opcode = 0; opcode < 32; opcode++) begin
            isa_inst_valid_i = 1;
            isa_inst_data_i = {opcode, 26'b0};
            isa_pc_i = isa_pc_i + 4;
            @(posedge clk_sys_i);
            isa_inst_valid_i = 0;
            repeat(20) @(posedge clk_sys_i);
            if (dec_valid_o) test_pass_count++;
        end

        // Test Format Decoding
        state = TEST_FORMAT_DECODING;
        isa_inst_data_i = 32'h01_00_00_00;  // R-type
        isa_inst_valid_i = 1;
        @(posedge clk_sys_i);
        isa_inst_valid_i = 0;
        repeat(20) @(posedge clk_sys_i);

        isa_inst_data_i = 32'h02_00_FF_FF;  // I-type
        isa_inst_valid_i = 1;
        @(posedge clk_sys_i);
        isa_inst_valid_i = 0;
        repeat(20) @(posedge clk_sys_i);

        // Test Immediate Extraction
        state = TEST_IMM_EXTRACTION;
        for (int imm = 0; imm < 10; imm++) begin
            isa_inst_data_i = {6'h02, 5'h00, imm[15:0], 6'h00};
            isa_inst_valid_i = 1;
            @(posedge clk_sys_i);
            isa_inst_valid_i = 0;
            repeat(20) @(posedge clk_sys_i);
        end

        // Test Register Decoding
        state = TEST_REG_DECODING;
        for (int reg_idx = 0; reg_idx < 32; reg_idx++) begin
            isa_inst_data_i = {6'h01, reg_idx[4:0], reg_idx[4:0], reg_idx[4:0], 6'h00};
            isa_inst_valid_i = 1;
            @(posedge clk_sys_i);
            isa_inst_valid_i = 0;
            repeat(10) @(posedge clk_sys_i);
        end

        // Test BNZ Branch
        state = TEST_BNZ_BRANCH;
        isa_inst_data_i = 32'h10_00_00_04;  // BNZ opcode
        isa_inst_valid_i = 1;
        @(posedge clk_sys_i);
        isa_inst_valid_i = 0;
        repeat(50) @(posedge clk_sys_i);

        // Test Invalid Opcode
        state = TEST_INVALID_OPCODE;
        isa_inst_data_i = 32'hFF_00_00_00;  // Invalid opcode
        isa_inst_valid_i = 1;
        @(posedge clk_sys_i);
        isa_inst_valid_i = 0;
        repeat(20) @(posedge clk_sys_i);
        if (error_invalid_opcode_o) test_pass_count = test_pass_count + 1;

        // Test Operator Dispatch
        state = TEST_OPERATOR_DISPATCH;
        isa_inst_data_i = 32'h01_00_00_00;  // Valid instruction
        isa_inst_valid_i = 1;
        op_ready_i = 1;
        @(posedge clk_sys_i);
        isa_inst_valid_i = 0;
        repeat(100) @(posedge clk_sys_i);
        op_done_i = 1;
        repeat(10) @(posedge clk_sys_i);
        op_done_i = 0;

        // Test Systolic Array Command
        state = TEST_SA_CMD;
        sa_ready_i = 1;
        repeat(50) @(posedge clk_sys_i);

        // Test Secure Boot
        state = TEST_SECURE_BOOT;
        sec_valid_i = 0;
        sec_en_i = 0;
        repeat(20) @(posedge clk_sys_i);
        sec_valid_i = 1;
        sec_en_i = 1;
        repeat(20) @(posedge clk_sys_i);

        // Test Pause and Abort
        state = TEST_PAUSE_ABORT;
        sched_start_i = 1;
        @(posedge clk_sys_i);
        sched_start_i = 0;
        repeat(20) @(posedge clk_sys_i);

        sched_pause_i = 1;
        repeat(20) @(posedge clk_sys_i);
        sched_pause_i = 0;
        repeat(20) @(posedge clk_sys_i);

        sched_abort_i = 1;
        repeat(20) @(posedge clk_sys_i);
        sched_abort_i = 0;
        repeat(20) @(posedge clk_sys_i);

        state = DONE;
        repeat(10) @(posedge clk_sys_i);
    end

endmodule