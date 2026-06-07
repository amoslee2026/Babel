//-----------------------------------------------------------------------------
// Module: M16_ISAInterface
// Description: TinyStories NPU ISA Interface - 16-bit ISA bus, CDC bridge,
//              Security Interface, 2-stage synchronizer, ISA_READY timeout
// Reference: spec_mas/M16/MAS.md, FSM.md, datapath.md
// REQ: REQ-M16-001~030, REQ-SEC-001
//-----------------------------------------------------------------------------
/* verilator lint_off UNUSEDPARAM */  // CDC_SYNC_STAGES reserved for future config
/* verilator lint_off UNUSEDSIGNAL */ // isa_auth_token_i reserved for future auth
module M16_ISAInterface #(
    parameter DATA_WIDTH      = 16,
    parameter INST_WIDTH      = 32,
    parameter PC_WIDTH        = 32,
    parameter CRC_WIDTH       = 16,
    parameter TIMEOUT_CYCLES  = 255,
    parameter AUTH_TOKEN_WIDTH = 128,
    parameter CDC_SYNC_STAGES = 2
)(
    //=========================================================================
    // ISA_IF External Interface (REQ-IO-002, REQ-M16-004)
    //=========================================================================
    inout  logic [DATA_WIDTH-1:0]   ISA_IF,          // Bidirectional data bus
    input  logic                    ISA_CLK,         // ISA clock (50 MHz)
    output logic                    ISA_VALID,       // Data valid flag
    output logic                    ISA_DIR,         // Direction control (0=RX, 1=TX)
    input  logic                    ISA_READY,       // External ready signal

    //=========================================================================
    // CDC Bridge Interface (to M13 ISA Decoder) (REQ-M16-012~015)
    //=========================================================================
    output logic [INST_WIDTH-1:0]   isa_data_sys_o,  // Synchronized instruction data
    output logic                    isa_valid_sys_o, // Synchronized valid flag
    input  logic                    isa_ready_sys_i, // System domain ready
    output logic                    isa_req_sys_o,   // Transfer request
    output logic [PC_WIDTH-1:0]     isa_pc_o,        // Program counter output

    //=========================================================================
    // Control Interface (REQ-M16-016~018)
    //=========================================================================
    input  logic                    m16_reset_n_i,   // Module reset (CLK_IO domain)
    input  logic                    m16_enable_i,    // Module enable
    input  logic [1:0]              m16_mode_i,      // Mode: 00=RX, 01=TX, 10=Bidir

    //=========================================================================
    // Security Interface (REQ-M16-023~030)
    //=========================================================================
    input  logic                    sec_boot_done_i,     // Secure Boot complete (from M14)
    input  logic                    sec_status_pass_i,   // Secure Boot status PASS
    input  logic                    sec_status_fail_i,   // Secure Boot status FAIL
    input  logic                    sec_lockdown_i,      // Security lockdown trigger
    output logic                    isa_access_grant_o,  // ISA_IF access granted
    output logic                    isa_access_denied_o, // ISA_IF access denied
    output logic                    isa_crc_error_o,     // CRC check error
    input  logic [AUTH_TOKEN_WIDTH-1:0] isa_auth_token_i, // Authentication token (optional)

    //=========================================================================
    // System Clock & Reset (CLK_SYS domain)
    //=========================================================================
    input  logic                    clk_sys_i,       // System clock (500 MHz)
    input  logic                    rst_sys_n_i,     // System reset

    //=========================================================================
    // Error Status Output
    //=========================================================================
    output logic                    error_cdc_timeout_o,   // CDC timeout error
    output logic                    error_invalid_opcode_o,// Invalid opcode error
    output logic                    error_security_o,      // Security violation error
    output logic                    error_crc_o            // CRC error flag
);

    //=========================================================================
    // FSM1: CDC Handshake Controller States (REQ-M16-008, 009)
    //=========================================================================
    typedef enum logic [2:0] {
        FSM1_IDLE      = 3'b000,
        FSM1_RECEIVE   = 3'b001,
        FSM1_SYNC1     = 3'b010,
        FSM1_SYNC2     = 3'b011,
        FSM1_TRANSFER  = 3'b100,
        FSM1_COMPLETE  = 3'b101,
        FSM1_ERROR     = 3'b110
    } fsm1_state_t;

    //=========================================================================
    // FSM2: Instruction Parser States (REQ-M16-004, 020)
    //=========================================================================
    typedef enum logic [3:0] {
        FSM2_IDLE          = 4'b0000,
        FSM2_FETCH_LSB     = 4'b0001,
        FSM2_FETCH_MSB     = 4'b0010,
        FSM2_PARSE_OPCODE  = 4'b0011,
        FSM2_PARSE_TYPE    = 4'b0100,
        FSM2_PARSE_FIELDS  = 4'b0101,
        FSM2_VALIDATE      = 4'b0110,
        FSM2_DECODE_READY  = 4'b0111,
        FSM2_ERROR_INVALID = 4'b1000,
        FSM2_ERROR_TIMEOUT = 4'b1001,
        FSM2_ERROR_CRC     = 4'b1010
    } fsm2_state_t;

    //=========================================================================
    // FSM3: Access Control States (REQ-SEC-001)
    //=========================================================================
    typedef enum logic [2:0] {
        FSM3_LOCKED         = 3'b000,
        FSM3_WAIT_BOOT      = 3'b001,
        FSM3_CHECK_STATUS   = 3'b010,
        FSM3_UNLOCKED       = 3'b011,
        FSM3_TRANSFER_ACTIVE = 3'b100,
        FSM3_LOCKDOWN       = 3'b101,
        FSM3_ERROR_BOOT_FAIL = 3'b110
    } fsm3_state_t;

    //=========================================================================
    // Internal Registers - FSM1 CDC Handshake
    //=========================================================================
    fsm1_state_t                    fsm1_state, fsm1_next_state;
    logic [DATA_WIDTH-1:0]          isa_data_io;         // CLK_IO domain sampled data
    logic [DATA_WIDTH-1:0]          sync_stage_1;        // CDC Stage 1 (REQ-M16-009)
    logic [DATA_WIDTH-1:0]          sync_stage_2;        // CDC Stage 2
    logic [DATA_WIDTH-1:0]          isa_data_sys_reg;    // CLK_SYS domain output
    logic                           isa_valid_io_sync1;  // Valid signal CDC Stage 1
    logic                           isa_valid_io_sync2;  // Valid signal CDC Stage 2
    logic                           isa_valid_sys_reg;   // Synchronized valid
    logic                           isa_ready_sync1;     // Ready signal CDC Stage 1
    logic                           isa_ready_sync2;     // Ready signal CDC Stage 2
    logic [7:0]                     cdc_timeout_cnt;     // CDC timeout counter
    logic                           cdc_timeout_flag;    // Timeout flag
    logic                           cdc_sync_done;       // CDC sync complete flag

    //=========================================================================
    // Internal Registers - FSM2 Instruction Parser
    //=========================================================================
    fsm2_state_t                    fsm2_state, fsm2_next_state;
    logic [DATA_WIDTH-1:0]          lsb_buffer;          // LSB instruction buffer
    logic [DATA_WIDTH-1:0]          msb_buffer;          // MSB instruction buffer
    logic [INST_WIDTH-1:0]          instr_full;          // Full 32-bit instruction
    logic [5:0]                     opcode;              // Opcode field [31:26]
    logic [1:0]                     fetch_count;         // Fetch count (LSB/MSB)
    logic [7:0]                     parse_timeout_cnt;   // Parse timeout counter
    logic                           opcode_valid;        // Opcode validity flag
    logic                           instr_valid_reg;     // Instruction validity flag
    logic [CRC_WIDTH-1:0]           instr_crc;           // CRC checksum
    logic [CRC_WIDTH-1:0]           crc_computed;        // Computed CRC

    //=========================================================================
    // Internal Registers - FSM3 Access Control
    //=========================================================================
    fsm3_state_t                    fsm3_state, fsm3_next_state;
    logic                           isa_if_enable;       // ISA_IF enable flag
    logic                           access_grant_reg;    // Access grant register
    logic                           access_denied_reg;   // Access denied register
    logic [7:0]                     boot_timeout_cnt;    // Boot timeout counter

    //=========================================================================
    // Bidirectional Bus Control (REQ-M16-010)
    //=========================================================================
    /* verilator lint_off UNDRIVEN */ // isa_data_out driven in TX mode (future extension)
    logic [DATA_WIDTH-1:0]          isa_data_out;        // Output data (TX mode)
    /* verilator lint_on UNDRIVEN */
    logic [DATA_WIDTH-1:0]          isa_data_in;         // Input data (RX mode)
    logic                           isa_dir_reg;         // Direction register

    // Tri-state buffer for bidirectional bus
    assign ISA_IF = (isa_dir_reg == 1'b1 && m16_enable_i && isa_if_enable)
                    ? isa_data_out : {DATA_WIDTH{1'bz}};
    assign isa_data_in = ISA_IF;

    //=========================================================================
    // Reset Synchronization (CLK_IO and CLK_SYS domains)
    //=========================================================================
    logic                           rst_sys_n_sync1;     // Reset CDC Stage 1 (CLK_SYS domain)
    logic                           rst_sys_n_sync2;     // Reset CDC Stage 2 (CLK_SYS domain)
    logic                           rst_io_n_sync1;      // Reset CDC Stage 1 (CLK_IO domain)
    logic                           rst_io_n_sync2;      // Reset CDC Stage 2 (CLK_IO domain)

    // Reset synchronization: m16_reset_n_i (CLK_IO domain) -> CLK_SYS domain
    always_ff @(posedge clk_sys_i or negedge m16_reset_n_i) begin
        if (!m16_reset_n_i) begin
            rst_sys_n_sync1 <= 1'b0;
            rst_sys_n_sync2 <= 1'b0;
        end else begin
            rst_sys_n_sync1 <= 1'b1;
            rst_sys_n_sync2 <= rst_sys_n_sync1;
        end
    end

    // Reset synchronization: rst_sys_n_i (CLK_SYS domain) -> CLK_IO domain
    always_ff @(posedge ISA_CLK or negedge rst_sys_n_i) begin
        if (!rst_sys_n_i) begin
            rst_io_n_sync1 <= 1'b0;
            rst_io_n_sync2 <= 1'b0;
        end else begin
            rst_io_n_sync1 <= 1'b1;
            rst_io_n_sync2 <= rst_io_n_sync1;
        end
    end

    //=========================================================================
    // FSM3: Access Control FSM (REQ-SEC-001, REQ-M16-023~030)
    //=========================================================================
    // State Transition Logic
    always_comb begin
        fsm3_next_state = FSM3_LOCKED;

        case (fsm3_state)
            FSM3_LOCKED: begin
                if (sec_lockdown_i)
                    fsm3_next_state = FSM3_LOCKDOWN;
                else if (sec_boot_done_i)
                    fsm3_next_state = FSM3_WAIT_BOOT;
                else
                    fsm3_next_state = FSM3_LOCKED;
            end

            FSM3_WAIT_BOOT: begin
                if (sec_lockdown_i)
                    fsm3_next_state = FSM3_LOCKDOWN;
                else if (boot_timeout_cnt >= TIMEOUT_CYCLES)
                    fsm3_next_state = FSM3_ERROR_BOOT_FAIL;
                else
                    fsm3_next_state = FSM3_CHECK_STATUS;
            end

            FSM3_CHECK_STATUS: begin
                if (sec_lockdown_i)
                    fsm3_next_state = FSM3_LOCKDOWN;
                else if (sec_status_fail_i)
                    fsm3_next_state = FSM3_ERROR_BOOT_FAIL;
                else if (sec_status_pass_i)
                    fsm3_next_state = FSM3_UNLOCKED;
                else
                    fsm3_next_state = FSM3_CHECK_STATUS;
            end

            FSM3_UNLOCKED: begin
                if (sec_lockdown_i)
                    fsm3_next_state = FSM3_LOCKDOWN;
                else if (m16_enable_i)
                    fsm3_next_state = FSM3_TRANSFER_ACTIVE;
                else
                    fsm3_next_state = FSM3_UNLOCKED;
            end

            FSM3_TRANSFER_ACTIVE: begin
                if (sec_lockdown_i)
                    fsm3_next_state = FSM3_LOCKDOWN;
                else if (!m16_enable_i)
                    fsm3_next_state = FSM3_UNLOCKED;
                else
                    fsm3_next_state = FSM3_TRANSFER_ACTIVE;
            end

            FSM3_ERROR_BOOT_FAIL: begin
                fsm3_next_state = FSM3_ERROR_BOOT_FAIL; // Hold error state
            end

            FSM3_LOCKDOWN: begin
                fsm3_next_state = FSM3_LOCKDOWN; // Secure lockdown
            end

            default: fsm3_next_state = FSM3_LOCKED;
        endcase
    end

    // FSM3 State Register (CLK_SYS domain)
    always_ff @(posedge clk_sys_i or negedge rst_sys_n_sync2) begin
        if (!rst_sys_n_sync2) begin
            fsm3_state <= FSM3_LOCKED;
            boot_timeout_cnt <= 8'b0;
        end else begin
            fsm3_state <= fsm3_next_state;

            // Boot timeout counter
            if (fsm3_state == FSM3_WAIT_BOOT || fsm3_state == FSM3_CHECK_STATUS) begin
                if (boot_timeout_cnt < TIMEOUT_CYCLES)
                    boot_timeout_cnt <= boot_timeout_cnt + 1'b1;
            end else begin
                boot_timeout_cnt <= 8'b0;
            end
        end
    end

    // FSM3 Output Logic (REQ-M16-026, 027)
    always_comb begin
        isa_if_enable = 1'b0;
        access_grant_reg = 1'b0;
        access_denied_reg = 1'b0;

        case (fsm3_state)
            FSM3_UNLOCKED: begin
                isa_if_enable = 1'b1;
                access_grant_reg = 1'b1;
            end

            FSM3_TRANSFER_ACTIVE: begin
                isa_if_enable = 1'b1;
                access_grant_reg = 1'b1;
            end

            FSM3_LOCKDOWN, FSM3_ERROR_BOOT_FAIL: begin
                isa_if_enable = 1'b0;
                access_denied_reg = 1'b1;
            end

            default: begin
                isa_if_enable = 1'b0;
            end
        endcase
    end

    //=========================================================================
    // FSM1: CDC Handshake Controller (REQ-M16-008, 009)
    //=========================================================================
    // ISA_DIR Control (REQ-M16-010)
    always_comb begin
        if (!m16_enable_i || !isa_if_enable) begin
            isa_dir_reg = 1'b0;  // Default to input (safe state)
        end else begin
            case (m16_mode_i)
                2'b00: isa_dir_reg = 1'b0;  // Receive mode
                2'b01: isa_dir_reg = 1'b1;  // Transmit mode
                2'b10: isa_dir_reg = (fsm1_state == FSM1_RECEIVE) ? 1'b0 : 1'b1; // Bidir
                default: isa_dir_reg = 1'b0;
            endcase
        end
    end

    // CLK_IO Domain: Sample ISA_IF data
    always_ff @(posedge ISA_CLK or negedge rst_io_n_sync2) begin
        if (!rst_io_n_sync2) begin
            isa_data_io <= {DATA_WIDTH{1'b0}};
        end else if (m16_enable_i && isa_if_enable && ISA_READY && fsm1_state == FSM1_RECEIVE) begin
            isa_data_io <= isa_data_in;
        end
    end

    // CDC Two-Stage Synchronizer for Data (REQ-M16-009)
    always_ff @(posedge clk_sys_i or negedge rst_sys_n_sync2) begin
        if (!rst_sys_n_sync2) begin
            sync_stage_1 <= {DATA_WIDTH{1'b0}};
            sync_stage_2 <= {DATA_WIDTH{1'b0}};
            isa_data_sys_reg <= {DATA_WIDTH{1'b0}};
        end else begin
            sync_stage_1 <= isa_data_io;
            sync_stage_2 <= sync_stage_1;
            isa_data_sys_reg <= sync_stage_2;
        end
    end

    // CDC Two-Stage Synchronizer for Valid Signal
    always_ff @(posedge clk_sys_i or negedge rst_sys_n_sync2) begin
        if (!rst_sys_n_sync2) begin
            isa_valid_io_sync1 <= 1'b0;
            isa_valid_io_sync2 <= 1'b0;
        end else begin
            isa_valid_io_sync1 <= ISA_VALID;
            isa_valid_io_sync2 <= isa_valid_io_sync1;
        end
    end

    // CDC Two-Stage Synchronizer for Ready Signal
    always_ff @(posedge ISA_CLK or negedge rst_io_n_sync2) begin
        if (!rst_io_n_sync2) begin
            isa_ready_sync1 <= 1'b0;
            isa_ready_sync2 <= 1'b0;
        end else begin
            isa_ready_sync1 <= isa_ready_sys_i;
            isa_ready_sync2 <= isa_ready_sync1;
        end
    end

    // CDC Sync Done Flag
    assign cdc_sync_done = (sync_stage_2 != {DATA_WIDTH{1'b0}}) && isa_valid_io_sync2;

    // FSM1 State Transition Logic
    always_comb begin
        fsm1_next_state = FSM1_IDLE;

        case (fsm1_state)
            FSM1_IDLE: begin
                if (cdc_timeout_flag)
                    fsm1_next_state = FSM1_ERROR;
                else if (ISA_VALID && m16_enable_i && isa_if_enable)
                    fsm1_next_state = FSM1_RECEIVE;
                else
                    fsm1_next_state = FSM1_IDLE;
            end

            FSM1_RECEIVE: begin
                if (cdc_timeout_flag)
                    fsm1_next_state = FSM1_ERROR;
                else if (ISA_READY && isa_data_io != {DATA_WIDTH{1'b0}})
                    fsm1_next_state = FSM1_SYNC1;
                else
                    fsm1_next_state = FSM1_RECEIVE;
            end

            FSM1_SYNC1: begin
                if (cdc_timeout_flag)
                    fsm1_next_state = FSM1_ERROR;
                else
                    fsm1_next_state = FSM1_SYNC2;
            end

            FSM1_SYNC2: begin
                if (cdc_timeout_flag)
                    fsm1_next_state = FSM1_ERROR;
                else if (cdc_sync_done && !isa_ready_sys_i)
                    fsm1_next_state = FSM1_TRANSFER;
                else if (cdc_sync_done && isa_ready_sys_i)
                    fsm1_next_state = FSM1_TRANSFER;
                else
                    fsm1_next_state = FSM1_SYNC2;
            end

            FSM1_TRANSFER: begin
                if (cdc_timeout_flag)
                    fsm1_next_state = FSM1_ERROR;
                else if (isa_ready_sys_i)
                    fsm1_next_state = FSM1_COMPLETE;
                else
                    fsm1_next_state = FSM1_TRANSFER;
            end

            FSM1_COMPLETE: begin
                fsm1_next_state = FSM1_IDLE;
            end

            FSM1_ERROR: begin
                fsm1_next_state = FSM1_IDLE;  // Recovery: return to IDLE
            end

            default: fsm1_next_state = FSM1_IDLE;
        endcase
    end

    // FSM1 State Register (CLK_SYS domain)
    always_ff @(posedge clk_sys_i or negedge rst_sys_n_sync2) begin
        if (!rst_sys_n_sync2) begin
            fsm1_state <= FSM1_IDLE;
            cdc_timeout_cnt <= 8'b0;
            cdc_timeout_flag <= 1'b0;
        end else begin
            fsm1_state <= fsm1_next_state;

            // Timeout counter (REQ-M16-008)
            if (fsm1_state != FSM1_IDLE && fsm1_state != FSM1_COMPLETE) begin
                if (cdc_timeout_cnt < TIMEOUT_CYCLES)
                    cdc_timeout_cnt <= cdc_timeout_cnt + 1'b1;
                else
                    cdc_timeout_flag <= 1'b1;
            end else begin
                cdc_timeout_cnt <= 8'b0;
                cdc_timeout_flag <= 1'b0;
            end
        end
    end

    // FSM1 Output Logic
    always_comb begin
        isa_valid_sys_reg = 1'b0;
        isa_req_sys_o = 1'b0;

        case (fsm1_state)
            FSM1_TRANSFER: begin
                isa_valid_sys_reg = 1'b1;
                isa_req_sys_o = 1'b1;
            end

            FSM1_COMPLETE: begin
                isa_req_sys_o = 1'b0;
            end

            default: begin
                isa_valid_sys_reg = 1'b0;
            end
        endcase
    end

    //=========================================================================
    // FSM2: Instruction Parser (REQ-M16-004, 020)
    //=========================================================================
    // Opcode Validity Check
    always_comb begin
        opcode_valid = 1'b0;
        opcode = instr_full[31:26];

        // Valid opcode ranges (REQ-M16-004)
        if ((opcode <= 6'h05) ||                    // Vector Arithmetic (0x00-0x05)
            (opcode >= 6'h08 && opcode <= 6'h0A) ||   // Matrix Multiplication
            (opcode >= 6'h10 && opcode <= 6'h14) ||   // Special Functions
            (opcode >= 6'h18 && opcode <= 6'h1B) ||   // Reduction
            (opcode >= 6'h20 && opcode <= 6'h25) ||   // Memory Access
            (opcode >= 6'h28 && opcode <= 6'h2A) ||   // KV Cache
            (opcode >= 6'h30 && opcode <= 6'h34))     // Scalar/Control
            opcode_valid = 1'b1;
    end

    // CRC Computation (REQ-M16-028)
    // Simple 16-bit CRC using polynomial 0x8005
    function automatic [CRC_WIDTH-1:0] compute_crc16;
        input [INST_WIDTH-1:0] data;
        logic [CRC_WIDTH-1:0] crc;
        logic [INST_WIDTH-1:0] temp;
        begin
            crc = 16'hFFFF;
            temp = data;
            for (int i = 0; i < INST_WIDTH; i++) begin
                if ((crc[15] ^ temp[i]) == 1'b1) begin
                    crc = {crc[14:0], 1'b0} ^ 16'h8005;
                end else begin
                    crc = {crc[14:0], 1'b0};
                end
            end
            compute_crc16 = crc;
        end
    endfunction

    // FSM2 State Transition Logic
    always_comb begin
        fsm2_next_state = FSM2_IDLE;
        crc_computed = {CRC_WIDTH{1'b0}}; // Initialize to prevent latch

        case (fsm2_state)
            FSM2_IDLE: begin
                if (isa_valid_sys_reg)
                    fsm2_next_state = FSM2_FETCH_LSB;
                else
                    fsm2_next_state = FSM2_IDLE;
            end

            FSM2_FETCH_LSB: begin
                if (parse_timeout_cnt >= TIMEOUT_CYCLES)
                    fsm2_next_state = FSM2_ERROR_TIMEOUT;
                else if (isa_valid_sys_reg && fetch_count == 2'b0)
                    fsm2_next_state = FSM2_FETCH_MSB;
                else
                    fsm2_next_state = FSM2_FETCH_LSB;
            end

            FSM2_FETCH_MSB: begin
                if (isa_valid_sys_reg && fetch_count == 2'b1)
                    fsm2_next_state = FSM2_PARSE_OPCODE;
                else
                    fsm2_next_state = FSM2_FETCH_MSB;
            end

            FSM2_PARSE_OPCODE: begin
                if (!opcode_valid)
                    fsm2_next_state = FSM2_ERROR_INVALID;
                else
                    fsm2_next_state = FSM2_PARSE_TYPE;
            end

            FSM2_PARSE_TYPE: begin
                fsm2_next_state = FSM2_PARSE_FIELDS;
            end

            FSM2_PARSE_FIELDS: begin
                fsm2_next_state = FSM2_VALIDATE;
            end

            FSM2_VALIDATE: begin
                // CRC check (REQ-M16-028)
                crc_computed = compute_crc16(instr_full);
                if (instr_crc != crc_computed)
                    fsm2_next_state = FSM2_ERROR_CRC;
                else
                    fsm2_next_state = FSM2_DECODE_READY;
            end

            FSM2_DECODE_READY: begin
                fsm2_next_state = FSM2_IDLE;
            end

            FSM2_ERROR_INVALID: begin
                fsm2_next_state = FSM2_IDLE;
            end

            FSM2_ERROR_TIMEOUT: begin
                fsm2_next_state = FSM2_IDLE;
            end

            FSM2_ERROR_CRC: begin
                fsm2_next_state = FSM2_IDLE;
            end

            default: fsm2_next_state = FSM2_IDLE;
        endcase
    end

    // FSM2 State Register (CLK_SYS domain)
    always_ff @(posedge clk_sys_i or negedge rst_sys_n_sync2) begin
        if (!rst_sys_n_sync2) begin
            fsm2_state <= FSM2_IDLE;
            lsb_buffer <= {DATA_WIDTH{1'b0}};
            msb_buffer <= {DATA_WIDTH{1'b0}};
            instr_full <= {INST_WIDTH{1'b0}};
            fetch_count <= 2'b0;
            parse_timeout_cnt <= 8'b0;
            instr_valid_reg <= 1'b0;
            instr_crc <= {CRC_WIDTH{1'b0}};
        end else begin
            fsm2_state <= fsm2_next_state;

            // LSB/MSB Buffer Logic
            case (fsm2_state)
                FSM2_FETCH_LSB: begin
                    if (isa_valid_sys_reg) begin
                        lsb_buffer <= isa_data_sys_reg;
                        fetch_count <= fetch_count + 1'b1;
                        parse_timeout_cnt <= 8'b0;
                    end else if (fetch_count == 2'b0 && parse_timeout_cnt < TIMEOUT_CYCLES) begin
                        parse_timeout_cnt <= parse_timeout_cnt + 1'b1;
                    end
                end

                FSM2_FETCH_MSB: begin
                    if (isa_valid_sys_reg) begin
                        msb_buffer <= isa_data_sys_reg;
                        fetch_count <= fetch_count + 1'b1;
                        instr_full <= {msb_buffer, lsb_buffer};
                    end
                end

                FSM2_VALIDATE: begin
                    // Extract CRC from instruction (last 16 bits of metadata)
                    instr_crc <= instr_full[15:0]; // Simplified CRC extraction
                end

                FSM2_DECODE_READY: begin
                    instr_valid_reg <= 1'b1;
                    fetch_count <= 2'b0;
                end

                FSM2_IDLE: begin
                    instr_valid_reg <= 1'b0;
                    fetch_count <= 2'b0;
                    parse_timeout_cnt <= 8'b0;
                end

                default: begin
                    instr_valid_reg <= 1'b0;
                end
            endcase
        end
    end

    //=========================================================================
    // Output Assignments
    //=========================================================================
    // ISA_IF External Interface
    assign ISA_VALID = (fsm1_state == FSM1_TRANSFER) ? 1'b1 : 1'b0;
    assign ISA_DIR = isa_dir_reg;

    // CDC Bridge Interface (to M13)
    assign isa_data_sys_o = instr_full;
    assign isa_valid_sys_o = instr_valid_reg;
    assign isa_pc_o = {PC_WIDTH{1'b0}}; // PC from external source (future extension)

    // Security Interface Output
    assign isa_access_grant_o = access_grant_reg;
    assign isa_access_denied_o = access_denied_reg;
    assign isa_crc_error_o = (fsm2_state == FSM2_ERROR_CRC) ? 1'b1 : 1'b0;

    // Error Status Output
    assign error_cdc_timeout_o = (fsm1_state == FSM1_ERROR) ? 1'b1 : 1'b0;
    assign error_invalid_opcode_o = (fsm2_state == FSM2_ERROR_INVALID) ? 1'b1 : 1'b0;
    assign error_security_o = (fsm3_state == FSM3_LOCKDOWN || fsm3_state == FSM3_ERROR_BOOT_FAIL)
                               ? 1'b1 : 1'b0;
    assign error_crc_o = (fsm2_state == FSM2_ERROR_CRC) ? 1'b1 : 1'b0;

    //=========================================================================
    // Assertions for Verification
    //=========================================================================
    // REQ-M16-008: CDC latency <= 3 CLK_SYS cycles
    // Formal verification should check:
    // - sync_stage_1 and sync_stage_2 capture data within 2 cycles
    // - isa_data_sys_reg stable after SYNC2

    // REQ-M16-023: ISA_IF disabled before Secure Boot complete
    // Formal verification should check:
    // - isa_if_enable = 0 when sec_boot_done_i = 0

    // REQ-M16-024: ISA_IF enabled only when sec_status_pass_i = 1
    // Formal verification should check:
    // - isa_if_enable = 1 only when sec_status_pass_i = 1 && sec_boot_done_i = 1

endmodule
