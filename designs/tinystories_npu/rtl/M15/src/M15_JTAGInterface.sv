//-----------------------------------------------------------------------------
// Module: M15_JTAGInterface
// Type:   IO Module (IEEE 1149.1 JTAG TAP Controller)
// Version: Simplified for synthesis compatibility
//-----------------------------------------------------------------------------
// Description:
//   Simplified JTAG Test Access Port Controller for TinyStories NPU.
//-----------------------------------------------------------------------------

module M15_JTAGInterface (
    // JTAG Standard Interface (IEEE 1149.1)
    input  logic        tck,            // Test Clock (up to 50 MHz)
    input  logic        tms,            // Test Mode Select
    input  logic        tdi,            // Test Data In
    output logic        tdo,            // Test Data Out
    input  logic        trst_n,         // Test Reset (active low)
    output logic        tdo_en,         // TDO Output Enable

    // TEST_MODE Security Interface (from M14)
    input  logic        test_mode_en,
    input  logic        test_mode_valid,
    input  logic        sec_boot_en,
    output logic        test_access_grant,
    output logic        test_access_denied,

    // Scan Chain Interface
    output logic [3:0]  scan_select,
    output logic        scan_enable,
    output logic        scan_in,
    input  logic        scan_out,
    output logic        scan_capture,
    output logic        scan_update,

    // Boundary Scan Interface
    output logic        bsr_select,
    output logic        bsr_capture,
    output logic        bsr_update,
    input  logic [23:0] bsr_data_in,
    output logic [23:0] bsr_data_out,

    // Debug Interface
    output logic [15:0] debug_addr,
    output logic [31:0] debug_data_in,
    input  logic [31:0] debug_data_out,
    output logic        debug_rw,
    output logic        debug_valid,
    input  logic        debug_ack,

    // MBIST Interface
    output logic        mbist_start,
    output logic        mbist_stop,
    output logic [1:0]  mbist_target,
    output logic [3:0]  mbist_algorithm,
    input  logic [23:0] mbist_status,

    // System Reset (from M07)
    input  logic        rst_io_n
);

    //=========================================================================
    // Parameters and Constants
    //=========================================================================

    // TAP State Encoding (IEEE 1149.1)
    localparam TEST_LOGIC_RESET = 4'h0;
    localparam RUN_TEST_IDLE    = 4'h1;
    localparam SELECT_DR_SCAN   = 4'h2;
    localparam CAPTURE_DR       = 4'h3;
    localparam SHIFT_DR         = 4'h4;
    localparam EXIT1_DR         = 4'h5;
    localparam PAUSE_DR         = 4'h6;
    localparam EXIT2_DR         = 4'h7;
    localparam UPDATE_DR        = 4'h8;
    localparam SELECT_IR_SCAN   = 4'h9;
    localparam CAPTURE_IR       = 4'hA;
    localparam SHIFT_IR         = 4'hB;
    localparam EXIT1_IR         = 4'hC;
    localparam PAUSE_IR         = 4'hD;
    localparam EXIT2_IR         = 4'hE;
    localparam UPDATE_IR        = 4'hF;

    // IDCODE Value
    localparam IDCODE_VALUE     = 32'h1234_5AB9;

    //=========================================================================
    // Internal Signals
    //=========================================================================

    // TAP FSM State
    logic [3:0]  tap_state;
    logic [3:0]  tap_state_next;
    logic        dr_scan_active;
    logic        ir_scan_active;

    // Instruction Register
    logic [4:0]  ir_shift_reg;
    logic [4:0]  ir_update_reg;

    // Data Registers
    logic        dr_bypass_reg;
    logic [31:0] dr_idcode_reg;
    logic [23:0] dr_bsr_reg;

    // TDO Output
    logic        tdo_selected;

    //=========================================================================
    // TAP State Machine (Simplified)
    //=========================================================================

    // State transition logic
    always_comb begin
        tap_state_next = tap_state;
        case (tap_state)
            TEST_LOGIC_RESET: tap_state_next = (tms) ? TEST_LOGIC_RESET : RUN_TEST_IDLE;
            RUN_TEST_IDLE:    tap_state_next = (tms) ? SELECT_DR_SCAN : RUN_TEST_IDLE;
            SELECT_DR_SCAN:   tap_state_next = (tms) ? SELECT_IR_SCAN : CAPTURE_DR;
            CAPTURE_DR:       tap_state_next = (tms) ? EXIT1_DR : SHIFT_DR;
            SHIFT_DR:         tap_state_next = (tms) ? EXIT1_DR : SHIFT_DR;
            EXIT1_DR:         tap_state_next = (tms) ? UPDATE_DR : PAUSE_DR;
            PAUSE_DR:         tap_state_next = (tms) ? EXIT2_DR : PAUSE_DR;
            EXIT2_DR:         tap_state_next = (tms) ? UPDATE_DR : SHIFT_DR;
            UPDATE_DR:        tap_state_next = (tms) ? SELECT_DR_SCAN : RUN_TEST_IDLE;
            SELECT_IR_SCAN:   tap_state_next = (tms) ? TEST_LOGIC_RESET : CAPTURE_IR;
            CAPTURE_IR:       tap_state_next = (tms) ? EXIT1_IR : SHIFT_IR;
            SHIFT_IR:         tap_state_next = (tms) ? EXIT1_IR : SHIFT_IR;
            EXIT1_IR:         tap_state_next = (tms) ? UPDATE_IR : PAUSE_IR;
            PAUSE_IR:         tap_state_next = (tms) ? EXIT2_IR : PAUSE_IR;
            EXIT2_IR:         tap_state_next = (tms) ? UPDATE_IR : SHIFT_IR;
            UPDATE_IR:        tap_state_next = (tms) ? TEST_LOGIC_RESET : RUN_TEST_IDLE;
            default:          tap_state_next = TEST_LOGIC_RESET;
        endcase
    end

    // State Register (Single async reset for synthesis compatibility)
    always_ff @(posedge tck or negedge trst_n) begin
        if (!trst_n) begin
            tap_state <= TEST_LOGIC_RESET;
        end else begin
            if (!rst_io_n) begin
                tap_state <= TEST_LOGIC_RESET;
            end else begin
                tap_state <= tap_state_next;
            end
        end
    end

    //=========================================================================
    // Instruction Register
    //=========================================================================

    always_ff @(posedge tck or negedge trst_n) begin
        if (!trst_n) begin
            ir_shift_reg <= 5'b00001;  // Default: BYPASS
            ir_update_reg <= 5'b00001;
        end else begin
            if (!rst_io_n) begin
                ir_shift_reg <= 5'b00001;
                ir_update_reg <= 5'b00001;
            end else begin
                // Capture IR
                if (tap_state == CAPTURE_IR) begin
                    ir_shift_reg <= {ir_update_reg[3:0], 1'b1};
                end
                // Shift IR
                else if (tap_state == SHIFT_IR) begin
                    ir_shift_reg <= {tdi, ir_shift_reg[4:1]};
                end
                // Update IR
                else if (tap_state == UPDATE_IR) begin
                    ir_update_reg <= ir_shift_reg;
                end
            end
        end
    end

    //=========================================================================
    // Data Registers
    //=========================================================================

    // BYPASS Register (1-bit)
    always_ff @(posedge tck or negedge trst_n) begin
        if (!trst_n) begin
            dr_bypass_reg <= 1'b0;
        end else begin
            if (!rst_io_n) begin
                dr_bypass_reg <= 1'b0;
            end else begin
                if (tap_state == CAPTURE_DR && ir_update_reg == 5'b00000) begin
                    dr_bypass_reg <= 1'b0;
                end else if (tap_state == SHIFT_DR && ir_update_reg == 5'b00000) begin
                    dr_bypass_reg <= tdi;
                end
            end
        end
    end

    // IDCODE Register (32-bit)
    always_ff @(posedge tck or negedge trst_n) begin
        if (!trst_n) begin
            dr_idcode_reg <= IDCODE_VALUE;
        end else begin
            if (!rst_io_n) begin
                dr_idcode_reg <= IDCODE_VALUE;
            end else begin
                if (tap_state == CAPTURE_DR && ir_update_reg == 5'b00001) begin
                    dr_idcode_reg <= IDCODE_VALUE;
                end else if (tap_state == SHIFT_DR && ir_update_reg == 5'b00001) begin
                    dr_idcode_reg <= {tdi, dr_idcode_reg[31:1]};
                end
            end
        end
    end

    // BSR Register (24-bit)
    always_ff @(posedge tck or negedge trst_n) begin
        if (!trst_n) begin
            dr_bsr_reg <= 24'b0;
        end else begin
            if (!rst_io_n) begin
                dr_bsr_reg <= 24'b0;
            end else begin
                if (tap_state == CAPTURE_DR && ir_update_reg == 5'b00010) begin
                    dr_bsr_reg <= bsr_data_in;
                end else if (tap_state == SHIFT_DR && ir_update_reg == 5'b00010) begin
                    dr_bsr_reg <= {tdi, dr_bsr_reg[23:1]};
                end else if (tap_state == UPDATE_DR && ir_update_reg == 5'b00010) begin
                    bsr_data_out <= dr_bsr_reg;
                end
            end
        end
    end

    //=========================================================================
    // TDO Output Selection
    //=========================================================================

    always_comb begin
        dr_scan_active = (tap_state >= CAPTURE_DR && tap_state <= UPDATE_DR);
        ir_scan_active = (tap_state >= CAPTURE_IR && tap_state <= UPDATE_IR);
        
        tdo_selected = 1'b0;
        if (tap_state == SHIFT_DR) begin
            if (ir_update_reg == 5'b00000) begin
                tdo_selected = dr_bypass_reg;
            end else if (ir_update_reg == 5'b00001) begin
                tdo_selected = dr_idcode_reg[0];
            end else if (ir_update_reg == 5'b00010) begin
                tdo_selected = dr_bsr_reg[0];
            end else begin
                tdo_selected = dr_bypass_reg;
            end
        end else if (tap_state == SHIFT_IR) begin
            tdo_selected = ir_shift_reg[0];
        end
    end

    assign tdo = tdo_selected;
    assign tdo_en = (tap_state == SHIFT_DR || tap_state == SHIFT_IR);

    //=========================================================================
    // Control Signal Generation
    //=========================================================================

    assign scan_capture  = (tap_state == CAPTURE_DR);
    assign scan_enable   = (tap_state == SHIFT_DR);
    assign scan_update   = (tap_state == UPDATE_DR);
    assign scan_select   = 4'b0001;  // Default scan chain
    assign scan_in       = tdi;

    assign bsr_select    = (ir_update_reg == 5'b00010);
    assign bsr_capture   = (tap_state == CAPTURE_DR && ir_update_reg == 5'b00010);
    assign bsr_update    = (tap_state == UPDATE_DR && ir_update_reg == 5'b00010);

    //=========================================================================
    // TEST_MODE Security Gating
    //=========================================================================

    always_comb begin
        test_access_grant  = test_mode_en && test_mode_valid && sec_boot_en;
        test_access_denied = test_mode_en && !test_mode_valid;
    end

    //=========================================================================
    // Debug Interface (Simplified)
    //=========================================================================

    assign debug_addr    = 16'b0;
    assign debug_data_in = 32'b0;
    assign debug_rw      = 1'b0;
    assign debug_valid   = 1'b0;

    //=========================================================================
    // MBIST Interface (Simplified)
    //=========================================================================

    assign mbist_start     = 1'b0;
    assign mbist_stop      = 1'b0;
    assign mbist_target    = 2'b0;
    assign mbist_algorithm = 4'b0;

endmodule
