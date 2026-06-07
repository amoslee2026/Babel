// M06: Clock Manager
// Module: M06_ClockManager
// Description: NPU system clock generation and distribution with DVFS support
// Clock Domain: CLK_AON (1 MHz)
// Power Domain: PD_AON
// Generated: 2026-05-17

module M06_ClockManager (
    // Clock Inputs
    input  logic        ext_clk_i,        // External 50 MHz crystal

    // Control Inputs (CLK_AON domain)
    input  logic        pll_lock_i,       // PLL lock status
    input  logic [1:0]  dvfs_op_i,        // DVFS operating point (OP0/OP1/OP2)
    input  logic        dvfs_req_i,       // DVFS switch request
    input  logic [13:0] clk_gating_en_i,  // Module clock gating enables

    // Power Interface
    input  logic        pd_aon_vdd_i,     // PD_AON power status

    // Clock Outputs
    output logic        clk_sys_o,        // System clock (250-500 MHz)
    output logic        clk_aon_o,        // Always-on clock (1 MHz)
    output logic        clk_io_o,         // IO clock (50 MHz)
    output logic [13:0] clk_gating_o,     // Gated clocks to modules

    // Status Outputs
    output logic        dvfs_ack_o,       // DVFS completion acknowledge
    output logic [2:0]  clk_status_o,     // Clock status (STABLE/SWITCHING/ERROR)
    output logic        pll_pwr_en_o      // PLL power enable
);

    //=========================================================================
    // Parameters and Constants
    //=========================================================================

    // FSM State Encoding
    localparam STATE_IDLE      = 3'b000;
    localparam STATE_EVAL      = 3'b001;
    localparam STATE_CONFIG    = 3'b010;
    localparam STATE_LOCK_WAIT = 3'b011;
    localparam STATE_SWITCH    = 3'b100;
    localparam STATE_ACK       = 3'b101;
    localparam STATE_ERROR     = 3'b111;

    // Clock Status Encoding
    localparam STATUS_STABLE    = 3'b000;
    localparam STATUS_SWITCHING = 3'b001;
    localparam STATUS_ERROR     = 3'b100;

    // Operating Point Encoding
    localparam OP0 = 2'b00;  // 500 MHz, N=10
    localparam OP1 = 2'b01;  // 250 MHz, N=5
    localparam OP2 = 2'b10;  // 1 MHz (AON PLL)

    // PLL Divider Values
    localparam PLL_N_OP0 = 8'd10;  // N=10 for 500 MHz
    localparam PLL_N_OP1 = 8'd5;   // N=5 for 250 MHz
    localparam PLL_N_OP2 = 8'd0;   // N=0 for AON mode

    // Timeout Values (in AON clock cycles)
    localparam CONFIG_TIMEOUT  = 16'd10;    // 10 us timeout (10 cycles @ 1MHz)
    localparam LOCK_TIMEOUT    = 16'd100;   // 100 us timeout (100 cycles @ 1MHz)
    localparam SWITCH_TIMEOUT  = 16'd5;     // 5 cycles for switch

    //=========================================================================
    // Internal Signals
    //=========================================================================

    // FSM State Register
    logic [2:0] current_state;
    logic [2:0] next_state;

    // DVFS Control Signals
    logic        dvfs_req_sync;
    logic        dvfs_req_edge;
    logic        dvfs_req_prev;
    logic [1:0]  dvfs_op_latched;
    logic        op_valid;

    // PLL Configuration
    logic [7:0]  pll_n_divider;
    logic        pll_config_done;
    logic        pll_relock_wait;

    // Timeout Counter
    logic [15:0] timeout_counter;
    logic        timeout_expired;

    // Clock Switch Control
    logic        switch_done;
    logic        glitch_detected;
    logic [2:0]  clk_mux_select;

    // Clock Gate Control
    logic [13:0] clk_gating_sync;
    logic [13:0] clk_gating_status;

    // Acknowledge Generation
    logic        ack_sent;

    //=========================================================================
    // Clock Generation (Simplified Model)
    //=========================================================================

    // In real implementation, these would be PLL outputs
    // For RTL simulation, use clock dividers

    // AON Clock: 1 MHz (derived from ext_clk_i / 50)
    logic [5:0]  aon_div_counter;
    logic        aon_clk_pulse;

    always_ff @(posedge ext_clk_i) begin
        aon_div_counter <= aon_div_counter + 1'b1;
        if (aon_div_counter == 6'd49) begin
            aon_div_counter <= 6'd0;
            aon_clk_pulse <= 1'b1;
        end else begin
            aon_clk_pulse <= 1'b0;
        end
    end

    // Generate clk_aon_o from pulse
    logic aon_clk_reg;
    always_ff @(posedge ext_clk_i) begin
        if (aon_clk_pulse) begin
            aon_clk_reg <= ~aon_clk_reg;
        end
    end
    assign clk_aon_o = aon_clk_reg;

    // System Clock: 250-500 MHz (simplified, use ext_clk scaled)
    // In real HW: PLL_MAIN output with divider
    assign clk_sys_o = ext_clk_i;  // Simplified for RTL

    // IO Clock: 50 MHz (same as ext_clk)
    assign clk_io_o = ext_clk_i;

    //=========================================================================
    // DVFS Request Edge Detection
    //=========================================================================

    always_ff @(posedge clk_aon_o) begin
        if (!pd_aon_vdd_i) begin
            dvfs_req_prev <= 1'b0;
        end else begin
            dvfs_req_prev <= dvfs_req_i;
        end
    end

    assign dvfs_req_edge = dvfs_req_i && !dvfs_req_prev;

    //=========================================================================
    // Operating Point Validation
    //=========================================================================

    always_comb begin
        op_valid = 1'b0;
        case (dvfs_op_i)
            OP0, OP1, OP2: op_valid = 1'b1;
            default:       op_valid = 1'b0;
        endcase
    end

    //=========================================================================
    // PLL Divider Configuration
    //=========================================================================

    always_ff @(posedge clk_aon_o) begin
        if (!pd_aon_vdd_i) begin
            pll_n_divider <= PLL_N_OP0;
        end else if (current_state == STATE_CONFIG) begin
            case (dvfs_op_latched)
                OP0: pll_n_divider <= PLL_N_OP0;
                OP1: pll_n_divider <= PLL_N_OP1;
                OP2: pll_n_divider <= PLL_N_OP2;
                default: pll_n_divider <= PLL_N_OP0;
            endcase
        end
    end

    //=========================================================================
    // Timeout Counter
    //=========================================================================

    always_ff @(posedge clk_aon_o) begin
        if (!pd_aon_vdd_i) begin
            timeout_counter <= 16'd0;
        end else begin
            case (current_state)
                STATE_CONFIG: begin
                    if (timeout_counter < CONFIG_TIMEOUT) begin
                        timeout_counter <= timeout_counter + 1'b1;
                    end
                end
                STATE_LOCK_WAIT: begin
                    if (timeout_counter < LOCK_TIMEOUT) begin
                        timeout_counter <= timeout_counter + 1'b1;
                    end
                end
                STATE_SWITCH: begin
                    if (timeout_counter < SWITCH_TIMEOUT) begin
                        timeout_counter <= timeout_counter + 1'b1;
                    end
                end
                default: begin
                    timeout_counter <= 16'd0;
                end
            endcase
        end
    end

    assign timeout_expired = (current_state == STATE_CONFIG  && timeout_counter >= CONFIG_TIMEOUT) ||
                             (current_state == STATE_LOCK_WAIT && timeout_counter >= LOCK_TIMEOUT) ||
                             (current_state == STATE_SWITCH   && timeout_counter >= SWITCH_TIMEOUT);

    //=========================================================================
    // Configuration Done Signal
    //=========================================================================

    assign pll_config_done = (current_state == STATE_CONFIG) && (timeout_counter >= 16'd1);

    //=========================================================================
    // Switch Done Signal
    //=========================================================================

    assign switch_done = (current_state == STATE_SWITCH) && (timeout_counter >= SWITCH_TIMEOUT);

    //=========================================================================
    // Glitch Detection (Simplified)
    //=========================================================================

    // In real implementation, glitch detector monitors clock mux output
    assign glitch_detected = 1'b0;  // No glitch for safe operation

    //=========================================================================
    // Clock Gating Control
    //=========================================================================

    // Synchronize gating enables from AON domain
    always_ff @(posedge clk_aon_o) begin
        if (!pd_aon_vdd_i) begin
            clk_gating_sync <= 14'd0;
        end else begin
            clk_gating_sync <= clk_gating_en_i;
        end
    end

    // Apply gating with status feedback
    always_ff @(posedge clk_aon_o) begin
        if (!pd_aon_vdd_i) begin
            clk_gating_status <= 14'd0;
        end else begin
            clk_gating_status <= clk_gating_sync;
        end
    end

    // Clock gate outputs (per-module)
    // Each bit corresponds to one module clock gate
    assign clk_gating_o = clk_gating_status;

    //=========================================================================
    // Acknowledge Generation
    //=========================================================================

    assign ack_sent = (current_state == STATE_ACK) && (timeout_counter >= 16'd1);

    //=========================================================================
    // FSM State Register
    //=========================================================================

    always_ff @(posedge clk_aon_o) begin
        if (!pd_aon_vdd_i) begin
            current_state <= STATE_IDLE;
        end else begin
            current_state <= next_state;
        end
    end

    //=========================================================================
    // DVFS OP Latch
    //=========================================================================

    always_ff @(posedge clk_aon_o) begin
        if (!pd_aon_vdd_i) begin
            dvfs_op_latched <= OP0;
        end else if (current_state == STATE_EVAL && op_valid) begin
            dvfs_op_latched <= dvfs_op_i;
        end
    end

    //=========================================================================
    // FSM Next State Logic
    //=========================================================================

    always_comb begin
        next_state = STATE_IDLE;

        case (current_state)
            STATE_IDLE: begin
                if (dvfs_req_edge && pll_lock_i && op_valid) begin
                    next_state = STATE_EVAL;
                end else if (dvfs_req_edge && !pll_lock_i) begin
                    next_state = STATE_ERROR;
                end else begin
                    next_state = STATE_IDLE;
                end
            end

            STATE_EVAL: begin
                if (op_valid) begin
                    next_state = STATE_CONFIG;
                end else begin
                    next_state = STATE_ERROR;
                end
            end

            STATE_CONFIG: begin
                if (pll_config_done) begin
                    next_state = STATE_LOCK_WAIT;
                end else if (timeout_expired) begin
                    next_state = STATE_ERROR;
                end else begin
                    next_state = STATE_CONFIG;
                end
            end

            STATE_LOCK_WAIT: begin
                if (pll_lock_i) begin
                    next_state = STATE_SWITCH;
                end else if (timeout_expired) begin
                    next_state = STATE_ERROR;
                end else begin
                    next_state = STATE_LOCK_WAIT;
                end
            end

            STATE_SWITCH: begin
                if (switch_done && !glitch_detected) begin
                    next_state = STATE_ACK;
                end else if (glitch_detected) begin
                    next_state = STATE_ERROR;
                end else begin
                    next_state = STATE_SWITCH;
                end
            end

            STATE_ACK: begin
                if (ack_sent) begin
                    next_state = STATE_IDLE;
                end else begin
                    next_state = STATE_ACK;
                end
            end

            STATE_ERROR: begin
                // Error recovery: return to IDLE after one cycle
                next_state = STATE_IDLE;
            end

            default: begin
                next_state = STATE_IDLE;
            end
        endcase
    end

    //=========================================================================
    // Output Logic
    //=========================================================================

    // Clock Status Output
    always_comb begin
        case (current_state)
            STATE_IDLE:    clk_status_o = STATUS_STABLE;
            STATE_EVAL:    clk_status_o = STATUS_SWITCHING;
            STATE_CONFIG:  clk_status_o = STATUS_SWITCHING;
            STATE_LOCK_WAIT: clk_status_o = STATUS_SWITCHING;
            STATE_SWITCH:  clk_status_o = STATUS_SWITCHING;
            STATE_ACK:     clk_status_o = STATUS_STABLE;
            STATE_ERROR:   clk_status_o = STATUS_ERROR;
            default:       clk_status_o = STATUS_STABLE;
        endcase
    end

    // DVFS Acknowledge Output
    always_comb begin
        if (current_state == STATE_ACK) begin
            dvfs_ack_o = 1'b1;
        end else if (current_state == STATE_ERROR) begin
            dvfs_ack_o = 1'b0;
        end else begin
            dvfs_ack_o = 1'b0;
        end
    end

    // PLL Power Enable
    always_comb begin
        pll_pwr_en_o = pd_aon_vdd_i && (current_state != STATE_ERROR);
    end

    //=========================================================================
    // Clock Mux Select
    //=========================================================================

    // Mux control based on current OP
    always_comb begin
        case (dvfs_op_latched)
            OP0: clk_mux_select = 3'b001;  // PLL_MAIN direct
            OP1: clk_mux_select = 3'b010;  // PLL_MAIN/2
            OP2: clk_mux_select = 3'b100;  // PLL_AON
            default: clk_mux_select = 3'b001;
        endcase
    end

endmodule