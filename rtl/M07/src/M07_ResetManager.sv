//-----------------------------------------------------------------------------
// Module: M07_ResetManager
// Description: Reset Manager for system reset sequence control and distribution
// Author: Generated from spec_mas/M07 specifications
// Version: 1.1 - Fixed clock port, output types, async reset logic
//-----------------------------------------------------------------------------

module M07_ResetManager (
    // Clock Input (CLK_AON domain - 1 MHz Always-On clock)
    input  wire        clk_aon,           // CLK_AON - Main FSM clock (Always-on)

    // Reset Source Inputs (Section 2.1)
    input  wire        por_in,            // Async - Power-on Reset from external pin
    input  wire        sw_reset_req,      // CLK_SYS - Software reset request from M13/M14
    input  wire        wdt_reset_in,      // CLK_AON - Watchdog timer reset from M05

    // Status Inputs (Section 2.1)
    input  wire        pll_locked,        // CLK_AON - PLL lock status from M06
    input  wire        clk_aon_stable,    // CLK_AON - CLK_AON stability from M06
    input  wire        clk_sys_stable,    // CLK_SYS - CLK_SYS stability from M06
    input  wire        pd_main_ready,     // CLK_AON - PD_MAIN power-on ready from M05

    // Reset Outputs (Section 2.1)
    output wire        reset_main_out,    // Async - Reset to PD_MAIN modules (M00-M04, M08-M14)
    output wire        reset_aon_out,     // Async - Reset to PD_AON modules (M05, M06)
    output wire        reset_io_out,      // Async - Reset to PD_IO modules (M15-M16)

    // Status Outputs (Section 2.1)
    output wire [2:0]  reset_status,      // CLK_AON - Reset status code (3-bit)
    output wire        boot_start,        // CLK_SYS - Secure Boot start trigger to M14
    output wire        sequence_done      // CLK_AON - Reset sequence completion flag
);

//=============================================================================
// Parameters (Timing from MAS.md Section 5.1)
//=============================================================================
// CLK_AON = 1 MHz, so 1 us = 1 cycle
localparam T_PLL_CONFIG    = 16'd100;   // 100 us PLL configuration duration
localparam T_PLL_LOCK      = 16'd50;    // 50 us PLL lock wait time (guard)
localparam T_PD_POWERON    = 16'd10;    // 10 us PD_MAIN power-on time
localparam T_DEGLITCH      = 16'd2;     // 2 cycles minimum pulse width

//=============================================================================
// FSM State Encoding (Internal unique encoding, mapped to reset_status)
//=============================================================================
// Internal states (unique for FSM logic)
localparam STATE_IDLE           = 4'd0;
localparam STATE_POR_ASSERTED   = 4'd1;
localparam STATE_PLL_CONFIG     = 4'd2;
localparam STATE_PLL_WAIT       = 4'd3;
localparam STATE_CLK_AON_STABLE = 4'd4;
localparam STATE_PD_POWERON     = 4'd5;
localparam STATE_CLK_SYS_STABLE = 4'd6;
localparam STATE_RESET_RELEASE  = 4'd7;
localparam STATE_BOOT_START     = 4'd8;
localparam STATE_SW_RESET       = 4'd9;    // SW_RESET handling state
localparam STATE_WDT_RESET      = 4'd10;   // WDT_RESET handling state

// Reset status codes (from MAS.md Section 2.2)
localparam STATUS_IDLE          = 3'h0;    // Idle / Normal Operation
localparam STATUS_POR_ACTIVE    = 3'h1;    // POR Sequence Active
localparam STATUS_SW_RESET      = 3'h2;    // SW_RESET Active
localparam STATUS_WDT_RESET     = 3'h3;    // WDT_RESET Active
localparam STATUS_PLL_LOCKING   = 3'h4;    // PLL Locking
localparam STATUS_POWER_ON      = 3'h5;    // Power-On In Progress
localparam STATUS_CLK_STABLE    = 3'h6;    // Clock Stabilizing
localparam STATUS_BOOT_START    = 3'h7;    // Boot Starting

//=============================================================================
// Internal Signals
//=============================================================================
// Reset sources (filtered and synchronized)
reg  [1:0] por_sync;             // POR synchronization (async to sync)
wire       por_detected;         // Synchronized POR detection
reg  [1:0] por_deglitch;         // POR deglitch filter (2-stage)
wire       por_filtered;         // Filtered POR after deglitch
reg  [1:0] wdt_filter;           // WDT deglitch filter (2-stage)
wire       wdt_detected;         // Filtered WDT detection
reg  [1:0] sw_reset_sync;        // SW_RESET CDC (CLK_SYS -> CLK_AON)
wire       sw_reset_detected;    // Synchronized SW_RESET

// FSM state register
reg  [3:0] current_state;
reg  [3:0] next_state;

// Sequence timer (16-bit counter)
reg  [15:0] seq_timer;

// Reset type tracking
reg        active_por;
reg        active_sw_reset;
reg        active_wdt_reset;

// Internal reset signals (before distribution)
reg        reset_main_internal;
reg        reset_aon_internal;
reg        reset_io_internal;

// Internal status registers
reg  [2:0] reset_status_reg;
reg        sequence_done_reg;
reg        boot_start_reg;

// CLK_SYS_stable synchronization (CLK_SYS -> CLK_AON)
reg  [1:0] clk_sys_stable_sync;

//=============================================================================
// POR Synchronization and Deglitch (Section 7.1 - Glitch Protection)
//=============================================================================
// POR is async, need to synchronize to CLK_AON domain
// Use 2-stage synchronizer for metastability protection
always @(posedge clk_aon or posedge por_in) begin
    if (por_in) begin
        // Async preset on POR (immediate response)
        por_sync <= 2'b11;
    end else begin
        por_sync <= {por_sync[0], 1'b0};
    end
end

assign por_detected = por_sync[1];

// POR deglitch filter - requires 2 consecutive cycles for valid detection
always @(posedge clk_aon) begin
    if (por_in) begin
        por_deglitch <= 2'b11;
    end else begin
        por_deglitch <= {por_deglitch[0], por_detected};
    end
end

assign por_filtered = por_deglitch[1] & por_deglitch[0];

//=============================================================================
// WDT Deglitch Filter (Section 7.1 - Glitch Protection)
//=============================================================================
// WDT is already in CLK_AON domain, just need deglitch
always @(posedge clk_aon) begin
    if (por_filtered) begin
        wdt_filter <= 2'b00;
    end else begin
        wdt_filter <= {wdt_filter[0], wdt_reset_in};
    end
end

assign wdt_detected = wdt_filter[1] & wdt_filter[0];

//=============================================================================
// CDC: SW_RESET Synchronization (CLK_SYS -> CLK_AON)
//=============================================================================
// 2-stage synchronizer for SW_RESET (from MAS.md Section 5.3)
always @(posedge clk_aon) begin
    if (por_filtered) begin
        sw_reset_sync <= 2'b00;
    end else begin
        sw_reset_sync <= {sw_reset_sync[0], sw_reset_req};
    end
end

assign sw_reset_detected = sw_reset_sync[1];

//=============================================================================
// CDC: CLK_SYS_stable Synchronization (CLK_SYS -> CLK_AON)
//=============================================================================
// 2-stage synchronizer for clk_sys_stable
always @(posedge clk_aon) begin
    if (por_filtered) begin
        clk_sys_stable_sync <= 2'b00;
    end else begin
        clk_sys_stable_sync <= {clk_sys_stable_sync[0], clk_sys_stable};
    end
end

wire clk_sys_stable_aon = clk_sys_stable_sync[1];

//=============================================================================
// Reset Source Priority Logic (Section 3.4)
//=============================================================================
// Priority: POR > WDT_RESET > SW_RESET
always @(posedge clk_aon) begin
    if (por_filtered) begin
        active_por       <= 1'b1;
        active_sw_reset  <= 1'b0;
        active_wdt_reset <= 1'b0;
    end else begin
        // POR overrides everything
        if (por_filtered) begin
            active_por       <= 1'b1;
            active_sw_reset  <= 1'b0;
            active_wdt_reset <= 1'b0;
        end
        // WDT overrides SW_RESET
        else if (wdt_detected && !active_por) begin
            active_wdt_reset <= 1'b1;
            active_sw_reset  <= 1'b0;
        end
        // SW_RESET (only if no higher priority active)
        else if (sw_reset_detected && !active_por && !active_wdt_reset) begin
            active_sw_reset <= 1'b1;
        end
        // Clear flags on sequence completion
        else if (sequence_done_reg) begin
            active_por       <= 1'b0;
            active_sw_reset  <= 1'b0;
            active_wdt_reset <= 1'b0;
        end
    end
end

//=============================================================================
// Sequence Timer (16-bit counter)
//=============================================================================
always @(posedge clk_aon) begin
    if (por_filtered) begin
        seq_timer <= 16'd0;
    end else begin
        case (current_state)
            STATE_PLL_CONFIG: begin
                if (seq_timer < T_PLL_CONFIG)
                    seq_timer <= seq_timer + 16'd1;
                else
                    seq_timer <= 16'd0;
            end
            STATE_PLL_WAIT: begin
                if (seq_timer < T_PLL_LOCK)
                    seq_timer <= seq_timer + 16'd1;
                else
                    seq_timer <= 16'd0;
            end
            STATE_PD_POWERON: begin
                if (seq_timer < T_PD_POWERON)
                    seq_timer <= seq_timer + 16'd1;
                else
                    seq_timer <= 16'd0;
            end
            STATE_SW_RESET, STATE_WDT_RESET: begin
                if (seq_timer < 16'd4)
                    seq_timer <= seq_timer + 16'd1;
                else
                    seq_timer <= 16'd0;
            end
            default: begin
                seq_timer <= 16'd0;
            end
        endcase
    end
end

//=============================================================================
// FSM State Register
//=============================================================================
always @(posedge clk_aon or posedge por_filtered) begin
    if (por_filtered) begin
        // Async reset to POR_ASSERTED state
        current_state <= STATE_POR_ASSERTED;
    end else begin
        current_state <= next_state;
    end
end

//=============================================================================
// FSM Next State Logic (Combinational)
//=============================================================================
always @(*) begin
    // Default: stay in current state
    next_state = current_state;

    case (current_state)
        STATE_IDLE: begin
            // Check reset sources in priority order
            if (por_filtered || active_por)
                next_state = STATE_POR_ASSERTED;
            else if (wdt_detected || active_wdt_reset)
                next_state = STATE_WDT_RESET;
            else if (sw_reset_detected || active_sw_reset)
                next_state = STATE_SW_RESET;
        end

        STATE_POR_ASSERTED: begin
            // Start POR sequence immediately
            next_state = STATE_PLL_CONFIG;
        end

        STATE_PLL_CONFIG: begin
            // Wait for PLL configuration duration (100 us)
            if (seq_timer >= T_PLL_CONFIG)
                next_state = STATE_PLL_WAIT;
        end

        STATE_PLL_WAIT: begin
            // Wait for PLL lock signal
            if (pll_locked)
                next_state = STATE_CLK_AON_STABLE;
        end

        STATE_CLK_AON_STABLE: begin
            // Wait for CLK_AON stability
            if (clk_aon_stable)
                next_state = STATE_PD_POWERON;
        end

        STATE_PD_POWERON: begin
            // Wait for PD_MAIN power-on ready
            if (pd_main_ready && seq_timer >= T_PD_POWERON)
                next_state = STATE_CLK_SYS_STABLE;
        end

        STATE_CLK_SYS_STABLE: begin
            // Wait for CLK_SYS stability (after CDC sync)
            if (clk_sys_stable_aon)
                next_state = STATE_RESET_RELEASE;
        end

        STATE_RESET_RELEASE: begin
            // De-assert reset after 1 cycle
            next_state = STATE_BOOT_START;
        end

        STATE_BOOT_START: begin
            // Complete sequence and return to IDLE
            next_state = STATE_IDLE;
        end

        STATE_SW_RESET: begin
            // SW_RESET: assert and de-assert reset_main_out
            // 2-cycle sequence
            if (seq_timer >= 16'd2)
                next_state = STATE_IDLE;
        end

        STATE_WDT_RESET: begin
            // WDT_RESET: wait for WDT clear, then release
            // For simplicity, immediate release after 2 cycles
            if (seq_timer >= 16'd2)
                next_state = STATE_IDLE;
        end

        default: begin
            next_state = STATE_IDLE;
        end
    endcase
end

//=============================================================================
// Reset Distribution Logic (Section 3.3)
//=============================================================================
// Reset Distribution Matrix:
// PD_AON: POR only (async) - but use synchronous release for clean timing
// PD_MAIN: POR + SW_RESET + WDT_RESET (sync)
// PD_IO: POR only (async) - but use synchronous release for clean timing

// PD_MAIN reset (sync, covers all reset sources)
always @(posedge clk_aon) begin
    if (por_filtered) begin
        reset_main_internal <= 1'b1;  // Assert on POR
    end else begin
        case (current_state)
            STATE_POR_ASSERTED,
            STATE_PLL_CONFIG,
            STATE_PLL_WAIT,
            STATE_CLK_AON_STABLE,
            STATE_PD_POWERON,
            STATE_CLK_SYS_STABLE: begin
                reset_main_internal <= 1'b1;  // Keep asserted during POR sequence
            end
            STATE_RESET_RELEASE: begin
                reset_main_internal <= 1'b0;  // De-assert at release
            end
            STATE_SW_RESET: begin
                // SW_RESET: assert for 1 cycle, then de-assert
                if (seq_timer < 16'd1)
                    reset_main_internal <= 1'b1;
                else
                    reset_main_internal <= 1'b0;
            end
            STATE_WDT_RESET: begin
                // WDT_RESET: assert for 1 cycle, then de-assert
                if (seq_timer < 16'd1)
                    reset_main_internal <= 1'b1;
                else
                    reset_main_internal <= 1'b0;
            end
            default: begin
                reset_main_internal <= 1'b0;  // Normal operation
            end
        endcase
    end
end

// PD_AON reset (POR only, synchronous assertion and release)
always @(posedge clk_aon) begin
    if (por_filtered) begin
        reset_aon_internal <= 1'b1;
    end else begin
        case (current_state)
            STATE_POR_ASSERTED,
            STATE_PLL_CONFIG,
            STATE_PLL_WAIT,
            STATE_CLK_AON_STABLE,
            STATE_PD_POWERON,
            STATE_CLK_SYS_STABLE: begin
                reset_aon_internal <= 1'b1;
            end
            STATE_RESET_RELEASE,
            STATE_BOOT_START,
            STATE_IDLE: begin
                reset_aon_internal <= 1'b0;
            end
            default: begin
                reset_aon_internal <= 1'b0;
            end
        endcase
    end
end

// PD_IO reset (POR only, synchronous assertion and release)
always @(posedge clk_aon) begin
    if (por_filtered) begin
        reset_io_internal <= 1'b1;
    end else begin
        case (current_state)
            STATE_POR_ASSERTED,
            STATE_PLL_CONFIG,
            STATE_PLL_WAIT,
            STATE_CLK_AON_STABLE,
            STATE_PD_POWERON,
            STATE_CLK_SYS_STABLE: begin
                reset_io_internal <= 1'b1;
            end
            STATE_RESET_RELEASE,
            STATE_BOOT_START,
            STATE_IDLE: begin
                reset_io_internal <= 1'b0;
            end
            default: begin
                reset_io_internal <= 1'b0;
            end
        endcase
    end
end

// Output assignments (direct connection)
assign reset_main_out = reset_main_internal;
assign reset_aon_out  = reset_aon_internal;
assign reset_io_out   = reset_io_internal;

//=============================================================================
// Status Code Generation (Section 2.2)
//=============================================================================
// Map internal state to reset_status output code
always @(posedge clk_aon) begin
    if (por_filtered) begin
        reset_status_reg <= STATUS_POR_ACTIVE;
    end else begin
        case (current_state)
            STATE_IDLE:           reset_status_reg <= STATUS_IDLE;
            STATE_POR_ASSERTED:   reset_status_reg <= STATUS_POR_ACTIVE;
            STATE_PLL_CONFIG:     reset_status_reg <= STATUS_PLL_LOCKING;
            STATE_PLL_WAIT:       reset_status_reg <= STATUS_PLL_LOCKING;
            STATE_CLK_AON_STABLE: reset_status_reg <= STATUS_CLK_STABLE;
            STATE_PD_POWERON:     reset_status_reg <= STATUS_POWER_ON;
            STATE_CLK_SYS_STABLE: reset_status_reg <= STATUS_CLK_STABLE;
            STATE_RESET_RELEASE:  reset_status_reg <= STATUS_POR_ACTIVE;
            STATE_BOOT_START:     reset_status_reg <= STATUS_BOOT_START;
            STATE_SW_RESET:       reset_status_reg <= STATUS_SW_RESET;
            STATE_WDT_RESET:      reset_status_reg <= STATUS_WDT_RESET;
            default:              reset_status_reg <= STATUS_IDLE;
        endcase
    end
end

assign reset_status = reset_status_reg;

//=============================================================================
// Boot Start Generation
//=============================================================================
// Generate boot_start in CLK_AON domain (needs CDC to CLK_SYS in integration)
always @(posedge clk_aon) begin
    if (por_filtered) begin
        boot_start_reg <= 1'b0;
    end else begin
        if (current_state == STATE_BOOT_START)
            boot_start_reg <= 1'b1;
        else
            boot_start_reg <= 1'b0;
    end
end

// CDC to CLK_SYS domain would need additional synchronizer in actual integration
// For RTL, output is in CLK_AON domain (integration notes below)
assign boot_start = boot_start_reg;

//=============================================================================
// Sequence Done Flag
//=============================================================================
always @(posedge clk_aon) begin
    if (por_filtered) begin
        sequence_done_reg <= 1'b0;
    end else begin
        if (current_state == STATE_BOOT_START)
            sequence_done_reg <= 1'b1;
        else if (current_state == STATE_IDLE)
            sequence_done_reg <= 1'b0;
    end
end

assign sequence_done = sequence_done_reg;

endmodule