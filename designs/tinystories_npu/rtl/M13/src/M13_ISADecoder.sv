//-----------------------------------------------------------------------------
// Module: M13_ISADecoder
// Description: TinyStories NPU ISA Decoder - 32 instruction decode, register file,
//              immediate extraction, BNZ branch handling, invalid opcode detection
// Reference: spec_mas/M13/MAS.md, FSM.md, datapath.md
// REQ: REQ-SW-001, REQ-M13-010
//-----------------------------------------------------------------------------
module M13_ISADecoder #(
    parameter PC_WIDTH       = 32,
    parameter INST_WIDTH     = 32,
    parameter OPCODE_WIDTH   = 6,
    parameter FORMAT_WIDTH   = 2,
    parameter REG_IDX_WIDTH  = 5,
    parameter IMM16_WIDTH    = 16,
    parameter IMM21_WIDTH    = 21,
    parameter OFFSET_WIDTH   = 11,
    parameter FUNC_WIDTH     = 6,
    parameter TARGET_WIDTH   = 4
)(
    // Clock & Reset
    input  logic                    clk_sys_i,
    input  logic                    rst_sys_n_i,
    input  logic                    pg_main_en_i,

    // ISA Interface (from M16)
    input  logic                    isa_inst_valid_i,
    input  logic [INST_WIDTH-1:0]   isa_inst_data_i,
    output logic                    isa_inst_ready_o,
    input  logic [PC_WIDTH-1:0]     isa_pc_i,
    output logic                    isa_pc_update_o,

    // Decoded Output Interface
    output logic                    dec_valid_o,
    output logic [OPCODE_WIDTH-1:0] dec_opcode_o,
    output logic [FORMAT_WIDTH-1:0] dec_format_o,
    output logic [REG_IDX_WIDTH-1:0] dec_vd_o,
    output logic [REG_IDX_WIDTH-1:0] dec_vs1_o,
    output logic [REG_IDX_WIDTH-1:0] dec_vs2_o,
    output logic [REG_IDX_WIDTH-1:0] dec_vs3_o,
    output logic [REG_IDX_WIDTH-1:0] dec_sd_o,
    output logic [IMM16_WIDTH-1:0]  dec_imm16_o,
    output logic [IMM21_WIDTH-1:0]  dec_imm21_o,
    output logic [REG_IDX_WIDTH-1:0] dec_base_o,
    output logic [OFFSET_WIDTH-1:0] dec_offset_o,
    output logic [FUNC_WIDTH-1:0]   dec_func_o,

    // Operator Dispatch Interface (to M09-M12)
    output logic                    op_valid_o,
    output logic [TARGET_WIDTH-1:0] op_target_o,
    input  logic                    op_ready_i,
    output logic                    op_start_o,
    input  logic                    op_done_i,

    // Systolic Array Interface (to M00)
    output logic                    sa_cmd_valid_o,
    output logic [1:0]              sa_op_o,
    input  logic                    sa_ready_i,

    // Memory Interface (to M02/M03)
    output logic [PC_WIDTH-1:0]     mem_addr_o,
    output logic                    mem_wen_o,
    output logic                    mem_valid_o,
    input  logic                    mem_ready_i,

    // Secure Boot Interface (from M14)
    input  logic                    sec_valid_i,
    input  logic                    sec_en_i,

    // Control Interface (from M08 Scheduler)
    input  logic                    sched_start_i,
    input  logic                    sched_pause_i,
    input  logic                    sched_abort_i,
    output logic                    dec_done_o,
    output logic                    dec_busy_o,

    // Error Status Output
    output logic                    error_invalid_opcode_o,
    output logic                    error_invalid_format_o,
    output logic                    error_invalid_reg_o,
    output logic                    error_secure_boot_fail_o
);

    //=========================================================================
    // FSM State Definition
    //=========================================================================
    typedef enum logic [2:0] {
        S0_IDLE           = 3'b000,
        S1_FETCH          = 3'b001,
        S2_OPCODE_DECODE  = 3'b010,
        S3_OPERAND_EXTRACT = 3'b011,
        S4_DISPATCH       = 3'b100,
        S5_EXECUTE_WAIT   = 3'b101,
        S6_BRANCH_TAKEN   = 3'b110,
        S7_ERROR          = 3'b111
    } fsm_state_t;

    //=========================================================================
    // Internal Registers
    //=========================================================================
    fsm_state_t                     fsm_state, fsm_next_state;
    logic [INST_WIDTH-1:0]          inst_buf_reg;
    logic [PC_WIDTH-1:0]            pc_reg;
    logic [OPCODE_WIDTH-1:0]        opcode_reg;
    logic [FORMAT_WIDTH-1:0]        format_reg;
    logic [REG_IDX_WIDTH-1:0]       vd_reg, vs1_reg, vs2_reg, vs3_reg, sd_reg, base_reg;
    logic [IMM16_WIDTH-1:0]         imm16_reg;
    logic [IMM21_WIDTH-1:0]         imm21_reg;
    logic [OFFSET_WIDTH-1:0]        offset_reg;
    logic [FUNC_WIDTH-1:0]          func_reg;
    logic [TARGET_WIDTH-1:0]        target_reg;
    logic [1:0]                     branch_counter;
    logic [PC_WIDTH-1:0]            branch_target_reg;
    logic                           branch_taken_flag;

    // Decode valid pipeline registers
    logic                           s1_valid, s2_valid, s3_valid, s4_valid;

    //=========================================================================
    // Format Encoding Constants
    //=========================================================================
    localparam FORMAT_V     = 2'b00;  // V-Type: Vector Triple Operand
    localparam FORMAT_VI    = 2'b01;  // VI-Type: Vector + Immediate
    localparam FORMAT_M     = 2'b10;  // M-Type: Memory Access
    localparam FORMAT_S     = 2'b11;  // S-Type: Scalar/Control

    //=========================================================================
    // Target Module Encoding
    //=========================================================================
    localparam TARGET_M00   = 4'd0;   // Systolic Array
    localparam TARGET_M09   = 4'd1;   // Attention Unit
    localparam TARGET_M10   = 4'd2;   // FFN/MatMul Unit
    localparam TARGET_M11   = 4'd3;   // RMSNorm/RoPE Unit
    localparam TARGET_M12   = 4'd4;   // SoftMax Unit
    localparam TARGET_M02   = 4'd5;   // Memory (SRAM)
    localparam TARGET_M13   = 4'd6;   // Internal Scalar/Control

    //=========================================================================
    // OPCODE Validity Check
    //=========================================================================
    logic opcode_valid;
    logic format_valid;
    logic reg_valid;

    // Valid opcode ranges (REQ-M13-010)
    function automatic logic check_opcode_valid(input logic [5:0] opcode);
        case (opcode)
            // Vector Arithmetic (0x00-0x05)
            6'h00, 6'h01, 6'h02, 6'h03, 6'h04, 6'h05: check_opcode_valid = 1'b1;
            // Matrix Multiply (0x08-0x0A)
            6'h08, 6'h09, 6'h0A: check_opcode_valid = 1'b1;
            // Special Function (0x10-0x14)
            6'h10, 6'h11, 6'h12, 6'h13, 6'h14: check_opcode_valid = 1'b1;
            // Reduction (0x18-0x1B)
            6'h18, 6'h19, 6'h1A, 6'h1B: check_opcode_valid = 1'b1;
            // Memory Access (0x20-0x25)
            6'h20, 6'h21, 6'h22, 6'h23, 6'h24, 6'h25: check_opcode_valid = 1'b1;
            // KV Cache (0x28-0x2A)
            6'h28, 6'h29, 6'h2A: check_opcode_valid = 1'b1;
            // Scalar/Control (0x30-0x34)
            6'h30, 6'h31, 6'h32, 6'h33, 6'h34: check_opcode_valid = 1'b1;
            default: check_opcode_valid = 1'b0;  // Reserved opcodes invalid
        endcase
    endfunction

    assign opcode_valid = check_opcode_valid(opcode_reg);

    //=========================================================================
    // Format Detection Logic
    //=========================================================================
    function automatic logic [FORMAT_WIDTH-1:0] detect_format(input logic [5:0] opcode);
        case (opcode)
            // V-Type: 0x00-0x05 (except 0x02=VI), 0x09, 0x10-0x14, 0x18-0x1B, 0x28
            6'h00, 6'h01, 6'h03, 6'h04, 6'h05,
            6'h09,
            6'h10, 6'h11, 6'h12, 6'h13, 6'h14,
            6'h18, 6'h19, 6'h1A, 6'h1B,
            6'h28: detect_format = FORMAT_V;

            // VI-Type: 0x02 (VSMUL)
            6'h02: detect_format = FORMAT_VI;

            // M-Type: 0x08, 0x20-0x21, 0x25, 0x29
            6'h08, 6'h20, 6'h21, 6'h25, 6'h29: detect_format = FORMAT_M;

            // S-Type: 0x0A, 0x22-0x24, 0x2A, 0x30-0x34
            6'h0A, 6'h22, 6'h23, 6'h24, 6'h2A,
            6'h30, 6'h31, 6'h32, 6'h33, 6'h34: detect_format = FORMAT_S;

            default: detect_format = FORMAT_V;  // Default
        endcase
    endfunction

    //=========================================================================
    // Target Selector Logic
    //=========================================================================
    function automatic logic [TARGET_WIDTH-1:0] select_target(input logic [5:0] opcode);
        case (opcode)
            // M00 Systolic Array (0x08-0x0A)
            6'h08, 6'h09, 6'h0A: select_target = TARGET_M00;

            // M09 Attention Unit (0x28-0x2A, 0x1A VDOT)
            6'h1A, 6'h28, 6'h29, 6'h2A: select_target = TARGET_M09;

            // M10 FFN/MatMul Unit (0x00-0x05)
            6'h00, 6'h01, 6'h02, 6'h03, 6'h04, 6'h05: select_target = TARGET_M10;

            // M11 RMSNorm/RoPE Unit (0x11-0x13)
            6'h11, 6'h12, 6'h13: select_target = TARGET_M11;

            // M12 SoftMax Unit (0x10, 0x14, 0x18-0x1B)
            6'h10, 6'h14, 6'h18, 6'h19, 6'h1B: select_target = TARGET_M12;

            // M02 Memory (0x20-0x25)
            6'h20, 6'h21, 6'h22, 6'h23, 6'h24, 6'h25: select_target = TARGET_M02;

            // M13 Internal (0x30-0x34)
            6'h30, 6'h31, 6'h32, 6'h33, 6'h34: select_target = TARGET_M13;

            default: select_target = TARGET_M00;
        endcase
    endfunction

    //=========================================================================
    // Register File: 32 Vector Registers (v0-v31) and 16 Scalar Registers (s0-s15)
    //=========================================================================
    // Note: Register file is conceptual - actual storage is in operator units
    // This decoder extracts indices for register access

    logic [REG_IDX_WIDTH-1:0] vector_reg_idx [0:31];
    logic [REG_IDX_WIDTH-1:0] scalar_reg_idx [0:15];

    // Register validity check
    function automatic logic check_reg_valid(
        input logic [REG_IDX_WIDTH-1:0] vd,
        input logic [REG_IDX_WIDTH-1:0] vs1,
        input logic [REG_IDX_WIDTH-1:0] vs2,
        input logic [REG_IDX_WIDTH-1:0] vs3,
        input logic [REG_IDX_WIDTH-1:0] sd,
        input logic [FORMAT_WIDTH-1:0] format
    );
        logic v_valid, s_valid;
        // Vector registers: v0-v31 valid
        v_valid = (vd <= 5'd31) && (vs1 <= 5'd31) && (vs2 <= 5'd31) && (vs3 <= 5'd31);
        // Scalar registers: s0-s15 valid (sd <= 15)
        s_valid = (sd <= 5'd15);
        // Format-specific validation
        case (format)
            FORMAT_V:  check_reg_valid = v_valid;
            FORMAT_VI: check_reg_valid = v_valid && s_valid;
            FORMAT_M:  check_reg_valid = v_valid && s_valid;
            FORMAT_S:  check_reg_valid = s_valid;
            default:   check_reg_valid = 1'b0;
        endcase
    endfunction

    //=========================================================================
    // Operand Extraction Logic
    //=========================================================================
    logic [INST_WIDTH-1:0] inst;
    assign inst = inst_buf_reg;

    // V-Type: OPCODE(6) | VD(5) | VS1(5) | VS2(5) | VS3(5) | FUNC(6)
    logic [REG_IDX_WIDTH-1:0] v_vd, v_vs1, v_vs2, v_vs3;
    logic [FUNC_WIDTH-1:0]    v_func;
    assign v_vd    = inst[25:21];
    assign v_vs1   = inst[20:16];
    assign v_vs2   = inst[15:11];
    assign v_vs3   = inst[10:6];
    assign v_func  = inst[5:0];

    // VI-Type: OPCODE(6) | VD(5) | VS1(5) | IMM16(16)
    logic [REG_IDX_WIDTH-1:0] vi_vd, vi_vs1;
    logic [IMM16_WIDTH-1:0]   vi_imm16;
    assign vi_vd    = inst[25:21];
    assign vi_vs1   = inst[20:16];
    assign vi_imm16 = inst[15:0];

    // M-Type: OPCODE(6) | VD(5) | BASE(5) | SD(5) | OFFSET11(11)
    logic [REG_IDX_WIDTH-1:0] m_vd, m_base, m_sd;
    logic [OFFSET_WIDTH-1:0]  m_offset;
    assign m_vd     = inst[25:21];
    assign m_base   = inst[20:16];
    assign m_sd     = inst[15:11];
    assign m_offset = inst[10:0];

    // S-Type: OPCODE(6) | SD(5) | IMM21(21)
    logic [REG_IDX_WIDTH-1:0] s_sd;
    logic [IMM21_WIDTH-1:0]   s_imm21;
    assign s_sd     = inst[25:21];
    assign s_imm21  = inst[20:0];

    //=========================================================================
    // BNZ Branch Handling
    //=========================================================================
    logic is_bnz;
    logic bnz_condition;
    logic signed [IMM21_WIDTH-1:0] bnz_offset_signed;

    assign is_bnz = (opcode_reg == 6'h33);
    assign bnz_offset_signed = $signed(imm21_reg);
    // BNZ condition: ss != 0 (check scalar register value - simulated)
    assign bnz_condition = (sd_reg != 5'd0);  // Simplified: check if sd index is non-zero

    //=========================================================================
    // FSM State Transition Logic
    //=========================================================================
    always_comb begin
        fsm_next_state = fsm_state;

        case (fsm_state)
            // S0: IDLE - Wait for start
            S0_IDLE: begin
                if (sched_start_i && sec_en_i)
                    fsm_next_state = S1_FETCH;
                else if (!sec_en_i && sched_start_i)
                    fsm_next_state = S7_ERROR;
            end

            // S1: FETCH - Instruction fetch from M16
            S1_FETCH: begin
                if (isa_inst_valid_i)
                    fsm_next_state = S2_OPCODE_DECODE;
                // else wait for valid
            end

            // S2: OPCODE_DECODE - Opcode decode and format detection
            S2_OPCODE_DECODE: begin
                if (opcode_valid)
                    fsm_next_state = S3_OPERAND_EXTRACT;
                else
                    fsm_next_state = S7_ERROR;
            end

            // S3: OPERAND_EXTRACT - Operand extraction and validation
            S3_OPERAND_EXTRACT: begin
                if (is_bnz && bnz_condition)
                    fsm_next_state = S6_BRANCH_TAKEN;
                else if (reg_valid && format_valid)
                    fsm_next_state = S4_DISPATCH;
                else
                    fsm_next_state = S7_ERROR;
            end

            // S4: DISPATCH - Dispatch to target module
            S4_DISPATCH: begin
                if (op_ready_i || (target_reg == TARGET_M13))
                    fsm_next_state = S5_EXECUTE_WAIT;
                // else wait for ready
            end

            // S5: EXECUTE_WAIT - Wait for execution complete
            S5_EXECUTE_WAIT: begin
                if (op_done_i || (target_reg == TARGET_M13)) begin
                    if (opcode_reg == 6'h34)  // HALT
                        fsm_next_state = S0_IDLE;
                    else if (sched_pause_i || sched_abort_i)
                        fsm_next_state = S0_IDLE;
                    else
                        fsm_next_state = S1_FETCH;
                end
            end

            // S6: BRANCH_TAKEN - Pipeline flush (2 cycles)
            S6_BRANCH_TAKEN: begin
                if (branch_counter == 2'd2)
                    fsm_next_state = S1_FETCH;
            end

            // S7: ERROR - Wait for abort/reset
            S7_ERROR: begin
                if (sched_abort_i || !rst_sys_n_i)
                    fsm_next_state = S0_IDLE;
            end

            default: fsm_next_state = S0_IDLE;
        endcase
    end

    //=========================================================================
    // FSM State Register Update
    //=========================================================================
    always_ff @(posedge clk_sys_i or negedge rst_sys_n_i) begin
        if (!rst_sys_n_i) begin
            fsm_state <= S0_IDLE;
            inst_buf_reg <= '0;
            pc_reg <= '0;
            opcode_reg <= '0;
            format_reg <= FORMAT_V;
            vd_reg <= '0;
            vs1_reg <= '0;
            vs2_reg <= '0;
            vs3_reg <= '0;
            sd_reg <= '0;
            base_reg <= '0;
            imm16_reg <= '0;
            imm21_reg <= '0;
            offset_reg <= '0;
            func_reg <= '0;
            target_reg <= '0;
            branch_counter <= '0;
            branch_target_reg <= '0;
            branch_taken_flag <= '0;
            s1_valid <= '0;
            s2_valid <= '0;
            s3_valid <= '0;
            s4_valid <= '0;
        end else if (pg_main_en_i) begin
            fsm_state <= fsm_next_state;

            // State-specific register updates
            case (fsm_state)
                S0_IDLE: begin
                    s1_valid <= '0;
                    s2_valid <= '0;
                    s3_valid <= '0;
                    s4_valid <= '0;
                    branch_taken_flag <= '0;
                end

                S1_FETCH: begin
                    if (isa_inst_valid_i) begin
                        inst_buf_reg <= isa_inst_data_i;
                        pc_reg <= isa_pc_i;
                        s1_valid <= 1'b1;
                    end
                end

                S2_OPCODE_DECODE: begin
                    if (s1_valid) begin
                        opcode_reg <= inst[31:26];
                        format_reg <= detect_format(inst[31:26]);
                        s2_valid <= 1'b1;
                    end
                end

                S3_OPERAND_EXTRACT: begin
                    if (s2_valid) begin
                        // Extract operands based on format
                        case (format_reg)
                            FORMAT_V: begin
                                vd_reg <= v_vd;
                                vs1_reg <= v_vs1;
                                vs2_reg <= v_vs2;
                                vs3_reg <= v_vs3;
                                func_reg <= v_func;
                                sd_reg <= '0;
                                imm16_reg <= '0;
                                imm21_reg <= '0;
                                offset_reg <= '0;
                                base_reg <= '0;
                            end
                            FORMAT_VI: begin
                                vd_reg <= vi_vd;
                                vs1_reg <= vi_vs1;
                                imm16_reg <= vi_imm16;
                                vs2_reg <= '0;
                                vs3_reg <= '0;
                                func_reg <= '0;
                                sd_reg <= '0;
                                imm21_reg <= '0;
                                offset_reg <= '0;
                                base_reg <= '0;
                            end
                            FORMAT_M: begin
                                vd_reg <= m_vd;
                                base_reg <= m_base;
                                sd_reg <= m_sd;
                                offset_reg <= m_offset;
                                vs1_reg <= '0;
                                vs2_reg <= '0;
                                vs3_reg <= '0;
                                imm16_reg <= '0;
                                imm21_reg <= '0;
                                func_reg <= '0;
                            end
                            FORMAT_S: begin
                                sd_reg <= s_sd;
                                imm21_reg <= s_imm21;
                                vd_reg <= '0;
                                vs1_reg <= '0;
                                vs2_reg <= '0;
                                vs3_reg <= '0;
                                base_reg <= '0;
                                imm16_reg <= '0;
                                offset_reg <= '0;
                                func_reg <= '0;
                            end
                        endcase
                        s3_valid <= 1'b1;
                    end
                end

                S4_DISPATCH: begin
                    if (s3_valid) begin
                        target_reg <= select_target(opcode_reg);
                        s4_valid <= 1'b1;
                    end
                end

                S5_EXECUTE_WAIT: begin
                    // Execution complete
                    if (op_done_i || (target_reg == TARGET_M13)) begin
                        s4_valid <= '0;
                        s3_valid <= '0;
                        s2_valid <= '0;
                        s1_valid <= '0;
                    end
                end

                S6_BRANCH_TAKEN: begin
                    branch_counter <= branch_counter + 1;
                    if (branch_counter == 2'd0) begin
                        // Calculate branch target
                        branch_target_reg <= pc_reg + PC_WIDTH'(bnz_offset_signed);
                        // Pipeline flush - clear registers
                        inst_buf_reg <= '0;
                        opcode_reg <= '0;
                        s1_valid <= '0;
                        s2_valid <= '0;
                        s3_valid <= '0;
                        s4_valid <= '0;
                    end
                    if (branch_counter == 2'd1) begin
                        // Update PC
                        pc_reg <= branch_target_reg;
                        branch_taken_flag <= 1'b1;
                    end
                end

                S7_ERROR: begin
                    // Clear all pipeline registers
                    inst_buf_reg <= '0;
                    s1_valid <= '0;
                    s2_valid <= '0;
                    s3_valid <= '0;
                    s4_valid <= '0;
                end
            endcase
        end
    end

    //=========================================================================
    // Validity Checks
    //=========================================================================
    assign format_valid = (opcode_valid);  // Format is valid if opcode is valid
    assign reg_valid = check_reg_valid(vd_reg, vs1_reg, vs2_reg, vs3_reg, sd_reg, format_reg);

    //=========================================================================
    // Error Detection (REQ-M13-010)
    //=========================================================================
    always_ff @(posedge clk_sys_i or negedge rst_sys_n_i) begin
        if (!rst_sys_n_i) begin
            error_invalid_opcode_o <= '0;
            error_invalid_format_o <= '0;
            error_invalid_reg_o <= '0;
            error_secure_boot_fail_o <= '0;
        end else begin
            // Invalid opcode detection
            if (fsm_state == S2_OPCODE_DECODE && !opcode_valid)
                error_invalid_opcode_o <= 1'b1;
            else if (fsm_state == S0_IDLE)
                error_invalid_opcode_o <= '0;

            // Invalid format detection
            if (fsm_state == S3_OPERAND_EXTRACT && !format_valid)
                error_invalid_format_o <= 1'b1;
            else if (fsm_state == S0_IDLE)
                error_invalid_format_o <= '0;

            // Invalid register detection
            if (fsm_state == S3_OPERAND_EXTRACT && !reg_valid)
                error_invalid_reg_o <= 1'b1;
            else if (fsm_state == S0_IDLE)
                error_invalid_reg_o <= '0;

            // Secure boot failure (REQ-SEC-001)
            if (fsm_state == S0_IDLE && sched_start_i && !sec_en_i)
                error_secure_boot_fail_o <= 1'b1;
            else if (fsm_state == S0_IDLE)
                error_secure_boot_fail_o <= '0;
        end
    end

    //=========================================================================
    // Output Assignments
    //=========================================================================
    // ISA Interface
    assign isa_inst_ready_o = (fsm_state == S1_FETCH);
    assign isa_pc_update_o = (fsm_state == S6_BRANCH_TAKEN && branch_counter == 2'd1);

    // Decoded Output
    assign dec_valid_o = s4_valid;
    assign dec_opcode_o = opcode_reg;
    assign dec_format_o = format_reg;
    assign dec_vd_o = vd_reg;
    assign dec_vs1_o = vs1_reg;
    assign dec_vs2_o = vs2_reg;
    assign dec_vs3_o = vs3_reg;
    assign dec_sd_o = sd_reg;
    assign dec_imm16_o = imm16_reg;
    assign dec_imm21_o = imm21_reg;
    assign dec_base_o = base_reg;
    assign dec_offset_o = offset_reg;
    assign dec_func_o = func_reg;

    // Operator Dispatch Interface
    assign op_valid_o = (fsm_state == S4_DISPATCH);
    assign op_target_o = target_reg;
    assign op_start_o = (fsm_state == S4_DISPATCH && op_ready_i);

    // Systolic Array Interface
    assign sa_cmd_valid_o = (fsm_state == S4_DISPATCH && target_reg == TARGET_M00);
    assign sa_op_o = (opcode_reg == 6'h08) ? 2'b00 :  // MLOAD
                     (opcode_reg == 6'h09) ? 2'b01 :  // MMUL
                     (opcode_reg == 6'h0A) ? 2'b10 :  // MSET_DIM
                     2'b00;

    // Memory Interface
    assign mem_addr_o = {base_reg, offset_reg};  // Simplified address calculation
    assign mem_wen_o = (opcode_reg == 6'h21 || opcode_reg == 6'h23);  // VST, SST
    assign mem_valid_o = (fsm_state == S4_DISPATCH && target_reg == TARGET_M02);

    // Control Interface
    assign dec_busy_o = (fsm_state != S0_IDLE && fsm_state != S7_ERROR);
    assign dec_done_o = (opcode_reg == 6'h34 && fsm_state == S0_IDLE);

endmodule