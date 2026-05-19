//-----------------------------------------------------------------------------
// Module: M05_PowerManager
// Description: Power Manager for TinyStories NPU
//              Implements DVFS, Power Mode FSM, Wakeup Controller,
//              Power Gate Controller, Power Estimator, and Idle Detection
//
// Power Domain: PD_AON (Always-On, never power-gated)
// Clock Domain: CLK_AON (1 MHz)
// Target Power: 7 mW
//
// Specification: spec_mas/M05/MAS.md, FSM.md, datapath.md
//-----------------------------------------------------------------------------

module M05_PowerManager
    #(parameter int MAX_POWER_OP0 = 1700,  // mW, Max power at OP0
      parameter int MAX_POWER_IO  = 15,    // mW, Max IO power
      parameter int MAX_POWER_DRAM = 80)   // mW, Max DRAM power
    (
        //========================================
        // Clock & Reset (MAS.md §2.1.1)
        //========================================
        input  logic        clk_aon,           // Always-On clock, 1 MHz
        input  logic        rst_aon_n,         // Always-On async reset, active low
        input  logic        rst_por_n,         // Power-On Reset, active low

        //========================================
        // System Bus Interface (MAS.md §2.1.2)
        //========================================
        input  logic        bus_cmd_valid,
        output logic        bus_cmd_ready,
        input  logic [15:0] bus_cmd_addr,
        input  logic        bus_cmd_rw,        // 0=Read, 1=Write
        input  logic [31:0] bus_cmd_data,
        output logic        bus_rsp_valid,
        output logic [31:0] bus_rsp_data,
        output logic        bus_rsp_error,

        //========================================
        // DVFS Control Interface (MAS.md §2.1.3)
        //========================================
        output logic [1:0]  dvfs_op_req,       // OP request: 0=OP0, 1=OP1, 2=OP2
        input  logic        dvfs_op_ack,
        output logic [2:0]  dvfs_vdd_req,      // VDD_MAIN voltage encoding
        output logic [31:0] dvfs_freq_req,     // CLK_SYS frequency request (Hz)
        input  logic        dvfs_busy,

        //========================================
        // Voltage Regulator Interface (MAS.md §2.1.4)
        //========================================
        output logic [7:0]  vdd_main_set,      // VDD_MAIN setting (0.7-0.9V, 50mV step)
        input  logic        vdd_main_ack,
        input  logic        vdd_main_ready,
        input  logic        vdd_main_error,

        //========================================
        // Power Gate Control (MAS.md §2.1.5)
        //========================================
        output logic        pg_main_en,        // PD_MAIN Power Gate enable
        input  logic        pg_main_status,    // PD_MAIN Power Gate status feedback
        output logic        pg_main_switch,    // Header/Footer Switch control
        output logic        pg_iso_en,         // Isolation Cell enable

        //========================================
        // Power Mode Interface (MAS.md §2.1.6)
        //========================================
        output logic [1:0]  pmode_state,       // 0=Active, 1=Sleep, 2=Deep Sleep
        input  logic [1:0]  pmode_req,
        output logic        pmode_ack,
        output logic        pmode_error,

        //========================================
        // Wakeup Interface (MAS.md §2.1.7)
        //========================================
        input  logic [7:0]  wakeup_ext,        // External wakeup signals (8 sources)
        output logic [7:0]  wakeup_en,         // Wakeup source enable mask
        output logic [7:0]  wakeup_status,     // Wakeup source status
        output logic        wakeup_pending,    // Wakeup request pending
        input  logic        wakeup_clear,      // Clear wakeup status

        //========================================
        // Power Estimator Interface (MAS.md §2.1.8)
        //========================================
        output logic [15:0] pwr_estimate,      // Current power estimate (mW)
        input  logic [15:0] pwr_budget,        // Power budget setting (mW)
        output logic        pwr_alert,         // Power over-budget alert
        output logic [31:0] pwr_counters,      // Power counter sample values

        //========================================
        // Activity Monitoring (MAS.md §2.1.9)
        //========================================
        input  logic        activity_main,     // PD_MAIN activity status
        input  logic        activity_io,       // PD_IO activity status
        input  logic        activity_dram,     // DRAM activity status
        input  logic [15:0] idle_timeout,      // Idle timeout threshold (ms)
        output logic        idle_detected,     // Idle state detection flag

        //========================================
        // Status & Interrupt (MAS.md §2.1.10)
        //========================================
        output logic [7:0]  pm_status,         // Power Manager status register
        output logic        pm_irq,            // Power Manager interrupt request
        output logic [2:0]  pm_irq_type        // Interrupt type encoding
    );

    //========================================================================
    // State Encoding (FSM.md §State Encoding Details)
    //========================================================================
    localparam logic [1:0]
        STATE_RESET      = 2'b11,  // 0x3 - Initial state after POR
        STATE_ACTIVE     = 2'b00,  // 0x0 - Normal operation
        STATE_SLEEP      = 2'b01,  // 0x1 - Low power standby
        STATE_DEEP_SLEEP = 2'b10;  // 0x2 - Minimum power

    //========================================================================
    // DVFS Operating Points (MAS.md §3.2.1)
    //========================================================================
    localparam logic [1:0]
        OP0 = 2'b00,  // 0.9V, 500 MHz, 1.79 W (Active inference)
        OP1 = 2'b01,  // 0.7V, 250 MHz, 0.61 W (Light load)
        OP2 = 2'b10;  // 0.6V, 1 MHz, 0.09 W (Deep sleep)

    // DVFS OP LUT values (datapath.md §3.2)
    localparam logic [7:0]
        VDD_OP0 = 8'h12,  // 0.9V = 0x12
        VDD_OP1 = 8'h0E,  // 0.7V = 0x0E
        VDD_OP2 = 8'h0C;  // 0.6V = 0x0C

    localparam logic [31:0]
        FREQ_OP0 = 32'h1F4,  // 500 MHz = 0x1F4 (kHz units for simplicity)
        FREQ_OP1 = 32'h0FA,  // 250 MHz = 0x0FA
        FREQ_OP2 = 32'h001;  // 1 MHz = 0x001

    //========================================================================
    // Interrupt Type Encoding
    //========================================================================
    localparam logic [2:0]
        IRQ_TYPE_DVFS_DONE   = 3'b000,
        IRQ_TYPE_WAKEUP      = 3'b001,
        IRQ_TYPE_PWR_ALERT   = 3'b010,
        IRQ_TYPE_PMODE_DONE  = 3'b011,
        IRQ_TYPE_PG_DONE     = 3'b100,
        IRQ_TYPE_ERROR       = 3'b111;

    //========================================================================
    // Register Addresses (MAS.md §2.2)
    //========================================================================
    localparam logic [15:0]
        ADDR_PM_CTRL       = 16'h0000,
        ADDR_PM_STATUS     = 16'h0004,
        ADDR_PM_MODE       = 16'h0008,
        ADDR_DVFS_CTRL     = 16'h000C,
        ADDR_DVFS_STATUS   = 16'h0010,
        ADDR_DVFS_OP0      = 16'h0014,
        ADDR_DVFS_OP1      = 16'h0018,
        ADDR_DVFS_OP2      = 16'h001C,
        ADDR_VDD_CTRL      = 16'h0020,
        ADDR_VDD_STATUS    = 16'h0024,
        ADDR_PG_CTRL       = 16'h0028,
        ADDR_PG_STATUS     = 16'h002C,
        ADDR_WAKEUP_EN     = 16'h0030,
        ADDR_WAKEUP_STATUS = 16'h0034,
        ADDR_WAKEUP_CLEAR  = 16'h0038,
        ADDR_PWR_ESTIMATE  = 16'h003C,
        ADDR_PWR_BUDGET    = 16'h0040,
        ADDR_PWR_COUNTERS  = 16'h0044,
        ADDR_IDLE_CTRL     = 16'h0048,
        ADDR_IDLE_STATUS   = 16'h004C,
        ADDR_IRQ_ENABLE    = 16'h0050,
        ADDR_IRQ_STATUS    = 16'h0054,
        ADDR_IRQ_CLEAR     = 16'h0058;

    //========================================================================
    // Internal Registers
    //========================================================================

    // Power Mode FSM state
    logic [1:0] pmode_state_reg, pmode_state_next;

    // DVFS state and control
    logic [1:0] current_op_reg, target_op_reg;
    logic       dvfs_switch_req_reg;
    logic       dvfs_switching_reg;
    logic [7:0] vdd_target_reg;
    logic [31:0] freq_target_reg;

    // Power Gate state
    logic       pg_entering_reg, pg_exiting_reg;
    logic [3:0] pg_seq_cnt_reg;

    // Wakeup state
    logic [7:0] wakeup_en_reg;
    logic [7:0] wakeup_status_reg;
    logic       wakeup_pending_reg;
    logic       wakeup_detected_reg;

    // Idle detection
    logic [15:0] idle_counter_reg;
    logic       idle_detected_reg;

    // Activity for power estimation
    logic       activity_main_sync_reg, activity_io_sync_reg, activity_dram_sync_reg;

    // Power estimation
    logic [15:0] pwr_estimate_reg;
    logic [15:0] pwr_budget_reg;
    logic       pwr_alert_reg;

    // Control registers
    logic       pm_enable_reg;
    logic       dvfs_enable_reg;
    logic       pg_enable_reg;
    logic       wakeup_enable_reg;
    logic       pwr_est_enable_reg;
    logic       idle_det_enable_reg;
    logic       auto_pmode_en_reg;
    logic       irq_enable_reg;

    // Status registers
    logic       pm_ready_reg;
    logic       pm_busy_reg;
    logic       pm_error_reg;

    // Interrupt
    logic       irq_pending_reg;
    logic [2:0] irq_type_reg;

    // Mode transition control
    logic       mode_transition_active_reg;
    logic       mode_ack_reg;
    logic       mode_error_reg;

    // Bus interface
    logic       bus_rsp_valid_reg;
    logic [31:0] bus_rsp_data_reg;
    logic       bus_rsp_error_reg;

    //========================================================================
    // CDC: Activity Monitor Synchronization (CLK_SYS -> CLK_AON)
    // 2-stage synchronizer for level signals
    //========================================================================
    logic activity_main_stage0, activity_main_stage1;
    logic activity_io_stage0, activity_io_stage1;
    logic activity_dram_stage0, activity_dram_stage1;

    always_ff @(posedge clk_aon or negedge rst_por_n) begin
        if (!rst_por_n) begin
            activity_main_stage0 <= 1'b0;
            activity_main_stage1 <= 1'b0;
            activity_main_sync_reg <= 1'b0;
            activity_io_stage0 <= 1'b0;
            activity_io_stage1 <= 1'b0;
            activity_io_sync_reg <= 1'b0;
            activity_dram_stage0 <= 1'b0;
            activity_dram_stage1 <= 1'b0;
            activity_dram_sync_reg <= 1'b0;
        end else begin
            activity_main_stage0 <= activity_main;
            activity_main_stage1 <= activity_main_stage0;
            activity_main_sync_reg <= activity_main_stage1;

            activity_io_stage0 <= activity_io;
            activity_io_stage1 <= activity_io_stage0;
            activity_io_sync_reg <= activity_io_stage1;

            activity_dram_stage0 <= activity_dram;
            activity_dram_stage1 <= activity_dram_stage0;
            activity_dram_sync_reg <= activity_dram_stage1;
        end
    end

    //========================================================================
    // CDC: Wakeup External Signal Synchronization (Async -> CLK_AON)
    //========================================================================
    logic [7:0] wakeup_ext_stage0, wakeup_ext_stage1, wakeup_ext_sync;

    always_ff @(posedge clk_aon or negedge rst_por_n) begin
        if (!rst_por_n) begin
            wakeup_ext_stage0 <= 8'b0;
            wakeup_ext_stage1 <= 8'b0;
            wakeup_ext_sync <= 8'b0;
        end else begin
            wakeup_ext_stage0 <= wakeup_ext;
            wakeup_ext_stage1 <= wakeup_ext_stage0;
            wakeup_ext_sync <= wakeup_ext_stage1;
        end
    end

    //========================================================================
    // Idle Detection (MAS.md §3.6)
    //========================================================================
    // Idle counter increments when all activity signals are zero
    // Reset counter when any activity signal is active

    always_ff @(posedge clk_aon or negedge rst_por_n) begin
        if (!rst_por_n) begin
            idle_counter_reg <= 16'b0;
            idle_detected_reg <= 1'b0;
        end else if (!idle_det_enable_reg) begin
            idle_counter_reg <= 16'b0;
            idle_detected_reg <= 1'b0;
        end else begin
            // Check if all domains are idle
            if (!activity_main_sync_reg && !activity_io_sync_reg && !activity_dram_sync_reg) begin
                // All idle, increment counter
                if (idle_counter_reg < idle_timeout) begin
                    idle_counter_reg <= idle_counter_reg + 16'b1;
                end else begin
                    // Counter reached timeout, set idle_detected
                    idle_detected_reg <= 1'b1;
                end
            end else begin
                // Activity detected, reset counter
                idle_counter_reg <= 16'b0;
                idle_detected_reg <= 1'b0;
            end
        end
    end

    //========================================================================
    // Power Estimator (MAS.md §3.4, datapath.md §3.6)
    //========================================================================
    // Estimation model:
    // PD_MAIN_Power = Activity_Factor * Max_Power * DVFS_Factor
    // DVFS_Factor = (VDD/VDD_max)^2 * (CLK/CLK_max)
    // Simplified: use OP-dependent factors

    logic [7:0] activity_factor_reg;
    logic [7:0] dvfs_factor_reg;
    logic [15:0] main_power_est;
    logic [15:0] io_power_est;
    logic [15:0] dram_power_est;

    // Activity factor calculation (0-100%)
    always_ff @(posedge clk_aon or negedge rst_por_n) begin
        if (!rst_por_n) begin
            activity_factor_reg <= 8'b0;
        end else begin
            // Simplified: direct mapping of activity signals
            activity_factor_reg <= {5'b0, activity_main_sync_reg, activity_io_sync_reg, activity_dram_sync_reg};
        end
    end

    // DVFS factor based on current OP
    always_ff @(posedge clk_aon or negedge rst_por_n) begin
        if (!rst_por_n) begin
            dvfs_factor_reg <= 8'h64;  // 100% at OP0
        end else begin
            case (current_op_reg)
                OP0: dvfs_factor_reg <= 8'h64;  // 100%
                OP1: dvfs_factor_reg <= 8'h28;  // ~40% (0.7/0.9)^2 * 0.5
                OP2: dvfs_factor_reg <= 8'h05;  // ~5% (0.6/0.9)^2 * 0.002
                default: dvfs_factor_reg <= 8'h64;
            endcase
        end
    end

    // Power estimation calculation
    assign main_power_est = (MAX_POWER_OP0[15:0] * dvfs_factor_reg) / 8'h64;
    assign io_power_est = activity_io_sync_reg ? MAX_POWER_IO[15:0] : 16'b0;
    assign dram_power_est = activity_dram_sync_reg ? MAX_POWER_DRAM[15:0] : 16'b0;

    always_ff @(posedge clk_aon or negedge rst_por_n) begin
        if (!rst_por_n) begin
            pwr_estimate_reg <= 16'b0;
            pwr_budget_reg <= 16'h700;  // Default 700 mW budget
            pwr_alert_reg <= 1'b0;
        end else begin
            // Update budget from input
            pwr_budget_reg <= pwr_budget;

            // Calculate total power estimate
            if (pwr_est_enable_reg) begin
                pwr_estimate_reg <= main_power_est + io_power_est + dram_power_est + 16'h7;  // +7mW AON
            end else begin
                pwr_estimate_reg <= 16'b0;
            end

            // Alert check
            pwr_alert_reg <= (pwr_estimate_reg > pwr_budget_reg) && pwr_est_enable_reg;
        end
    end

    //========================================================================
    // Wakeup Controller (MAS.md §3.3, datapath.md §3.5)
    //========================================================================

    // Wakeup enable register
    always_ff @(posedge clk_aon or negedge rst_por_n) begin
        if (!rst_por_n) begin
            wakeup_en_reg <= 8'hFF;  // All sources enabled by default
        end else begin
            wakeup_en_reg <= wakeup_en;
        end
    end

    // Wakeup status detection and status register
    always_ff @(posedge clk_aon or negedge rst_por_n) begin
        if (!rst_por_n) begin
            wakeup_status_reg <= 8'b0;
            wakeup_pending_reg <= 1'b0;
            wakeup_detected_reg <= 1'b0;
        end else begin
            // Clear on wakeup_clear
            if (wakeup_clear) begin
                wakeup_status_reg <= 8'b0;
                wakeup_pending_reg <= 1'b0;
            end else begin
                // Detect new wakeup sources
                wakeup_detected_reg <= |(wakeup_ext_sync & wakeup_en_reg);

                // Latch wakeup sources
                if (wakeup_detected_reg && wakeup_enable_reg) begin
                    wakeup_status_reg <= wakeup_status_reg | (wakeup_ext_sync & wakeup_en_reg);
                    wakeup_pending_reg <= 1'b1;
                end
            end
        end
    end

    //========================================================================
    // Power Gate Sequencer (MAS.md §3.5, datapath.md §3.4)
    //========================================================================
    // Sequence states
    localparam logic [3:0]
        PG_SEQ_IDLE      = 4'b0000,
        PG_SEQ_ISO_EN    = 4'b0001,  // Phase 1: Enable isolation
        PG_SEQ_ISO_WAIT  = 4'b0010,  // Phase 2: Wait 10 cycles
        PG_SEQ_SW_OFF    = 4'b0011,  // Phase 3: Switch OFF
        PG_SEQ_SW_WAIT   = 4'b0100,  // Phase 4: Wait status
        PG_SEQ_PG_EN     = 4'b0101,  // Phase 5: PG enable (enter complete)
        PG_SEQ_SW_ON     = 4'b0110,  // Exit Phase 1: Switch ON
        PG_SEQ_EXIT_WAIT = 4'b0111,  // Exit Phase 2: Wait status
        PG_SEQ_ISO_DIS   = 4'b1000;  // Exit Phase 3: Disable isolation

    logic [3:0] pg_seq_state_reg, pg_seq_state_next;

    always_ff @(posedge clk_aon or negedge rst_por_n) begin
        if (!rst_por_n) begin
            pg_seq_state_reg <= PG_SEQ_IDLE;
            pg_seq_cnt_reg <= 4'b0;
            pg_main_en <= 1'b0;
            pg_main_switch <= 1'b1;  // Switch ON by default
            pg_iso_en <= 1'b0;       // Isolation OFF by default
        end else begin
            pg_seq_state_reg <= pg_seq_state_next;

            case (pg_seq_state_reg)
                PG_SEQ_IDLE: begin
                    pg_seq_cnt_reg <= 4'b0;
                end

                PG_SEQ_ISO_EN: begin
                    pg_iso_en <= 1'b1;
                    pg_seq_cnt_reg <= pg_seq_cnt_reg + 4'b1;
                end

                PG_SEQ_ISO_WAIT: begin
                    if (pg_seq_cnt_reg < 4'hA) begin  // Wait 10 cycles
                        pg_seq_cnt_reg <= pg_seq_cnt_reg + 4'b1;
                    end
                end

                PG_SEQ_SW_OFF: begin
                    pg_main_switch <= 1'b0;
                end

                PG_SEQ_SW_WAIT: begin
                    // Wait for pg_main_status = 0
                    pg_seq_cnt_reg <= pg_seq_cnt_reg + 4'b1;
                end

                PG_SEQ_PG_EN: begin
                    pg_main_en <= 1'b1;
                end

                PG_SEQ_SW_ON: begin
                    pg_main_en <= 1'b0;
                    pg_main_switch <= 1'b1;
                end

                PG_SEQ_EXIT_WAIT: begin
                    // Wait for pg_main_status = 1
                    pg_seq_cnt_reg <= pg_seq_cnt_reg + 4'b1;
                end

                PG_SEQ_ISO_DIS: begin
                    pg_iso_en <= 1'b0;
                end

                default: begin
                    pg_seq_state_reg <= PG_SEQ_IDLE;
                end
            endcase
        end
    end

    // Power Gate sequence state transition
    always_comb begin
        pg_seq_state_next = pg_seq_state_reg;

        case (pg_seq_state_reg)
            PG_SEQ_IDLE: begin
                if (pg_entering_reg && pg_enable_reg) begin
                    pg_seq_state_next = PG_SEQ_ISO_EN;
                end else if (pg_exiting_reg && pg_enable_reg) begin
                    pg_seq_state_next = PG_SEQ_SW_ON;
                end
            end

            PG_SEQ_ISO_EN: begin
                pg_seq_state_next = PG_SEQ_ISO_WAIT;
            end

            PG_SEQ_ISO_WAIT: begin
                if (pg_seq_cnt_reg >= 4'hA) begin
                    pg_seq_state_next = PG_SEQ_SW_OFF;
                end
            end

            PG_SEQ_SW_OFF: begin
                pg_seq_state_next = PG_SEQ_SW_WAIT;
            end

            PG_SEQ_SW_WAIT: begin
                if (!pg_main_status || pg_seq_cnt_reg >= 4'hF) begin  // Timeout
                    pg_seq_state_next = PG_SEQ_PG_EN;
                end
            end

            PG_SEQ_PG_EN: begin
                pg_seq_state_next = PG_SEQ_IDLE;  // Enter complete
            end

            PG_SEQ_SW_ON: begin
                pg_seq_state_next = PG_SEQ_EXIT_WAIT;
            end

            PG_SEQ_EXIT_WAIT: begin
                if (pg_main_status || pg_seq_cnt_reg >= 4'hF) begin  // Timeout
                    pg_seq_state_next = PG_SEQ_ISO_DIS;
                end
            end

            PG_SEQ_ISO_DIS: begin
                pg_seq_state_next = PG_SEQ_IDLE;  // Exit complete
            end

            default: begin
                pg_seq_state_next = PG_SEQ_IDLE;
            end
        endcase
    end

    //========================================================================
    // DVFS Controller (MAS.md §3.2, datapath.md §3.2-3.3)
    //========================================================================
    // DVFS switching sequence:
    // Frequency Up: V increase -> wait ACK -> F increase -> wait ACK
    // Frequency Down: F decrease -> wait ACK -> V decrease -> wait ACK

    localparam logic [2:0]
        DVFS_IDLE       = 3'b000,
        DVFS_V_REQ      = 3'b001,   // Request voltage change
        DVFS_V_WAIT     = 3'b010,   // Wait for vdd_main_ack
        DVFS_F_REQ      = 3'b011,   // Request frequency change
        DVFS_F_WAIT     = 3'b100,   // Wait for dvfs_op_ack
        DVFS_DONE       = 3'b101;

    logic [2:0] dvfs_state_reg, dvfs_state_next;
    logic       freq_up_reg;  // Direction flag: 1=up, 0=down
    logic [7:0] dvfs_timeout_cnt_reg;

    // DVFS state register
    always_ff @(posedge clk_aon or negedge rst_por_n) begin
        if (!rst_por_n) begin
            dvfs_state_reg <= DVFS_IDLE;
            current_op_reg <= OP0;
            target_op_reg <= OP0;
            dvfs_switch_req_reg <= 1'b0;
            dvfs_switching_reg <= 1'b0;
            vdd_target_reg <= VDD_OP0;
            freq_target_reg <= FREQ_OP0;
            freq_up_reg <= 1'b0;
            dvfs_timeout_cnt_reg <= 8'b0;
            vdd_main_set <= VDD_OP0;
            dvfs_vdd_req <= 3'b000;
            dvfs_freq_req <= FREQ_OP0;
            dvfs_op_req <= OP0;
        end else begin
            dvfs_state_reg <= dvfs_state_next;

            case (dvfs_state_reg)
                DVFS_IDLE: begin
                    dvfs_timeout_cnt_reg <= 8'b0;
                    dvfs_switching_reg <= 1'b0;

                    // Handle DVFS request
                    if (dvfs_switch_req_reg && dvfs_enable_reg && !dvfs_busy) begin
                        target_op_reg <= target_op_reg;
                        dvfs_switching_reg <= 1'b1;

                        // Determine direction
                        freq_up_reg <= (target_op_reg < current_op_reg);

                        // Set target values
                        case (target_op_reg)
                            OP0: begin
                                vdd_target_reg <= VDD_OP0;
                                freq_target_reg <= FREQ_OP0;
                            end
                            OP1: begin
                                vdd_target_reg <= VDD_OP1;
                                freq_target_reg <= FREQ_OP1;
                            end
                            OP2: begin
                                vdd_target_reg <= VDD_OP2;
                                freq_target_reg <= FREQ_OP2;
                            end
                            default: begin
                                vdd_target_reg <= VDD_OP0;
                                freq_target_reg <= FREQ_OP0;
                            end
                        endcase
                    end
                end

                DVFS_V_REQ: begin
                    // Request voltage change
                    vdd_main_set <= vdd_target_reg;
                    dvfs_vdd_req <= {1'b0, target_op_reg};
                end

                DVFS_V_WAIT: begin
                    // Wait for voltage ACK with timeout (100 us ~ 100 cycles at 1MHz)
                    if (vdd_main_ack) begin
                        dvfs_timeout_cnt_reg <= 8'b0;
                    end else if (dvfs_timeout_cnt_reg < 8'h64) begin
                        dvfs_timeout_cnt_reg <= dvfs_timeout_cnt_reg + 8'b1;
                    end
                end

                DVFS_F_REQ: begin
                    // Request frequency change
                    dvfs_freq_req <= freq_target_reg;
                    dvfs_op_req <= target_op_reg;
                    dvfs_timeout_cnt_reg <= 8'b0;
                end

                DVFS_F_WAIT: begin
                    // Wait for DVFS ACK with timeout (1 ms ~ 1000 cycles)
                    if (dvfs_op_ack) begin
                        dvfs_timeout_cnt_reg <= 8'b0;
                    end else if (dvfs_timeout_cnt_reg < 8'h64) begin  // Simplified timeout
                        dvfs_timeout_cnt_reg <= dvfs_timeout_cnt_reg + 8'b1;
                    end
                end

                DVFS_DONE: begin
                    // Update current OP
                    current_op_reg <= target_op_reg;
                    dvfs_switching_reg <= 1'b0;
                end

                default: begin
                    dvfs_state_reg <= DVFS_IDLE;
                end
            endcase
        end
    end

    // DVFS state transition
    always_comb begin
        dvfs_state_next = dvfs_state_reg;

        case (dvfs_state_reg)
            DVFS_IDLE: begin
                if (dvfs_switch_req_reg && dvfs_enable_reg && !dvfs_busy) begin
                    if (freq_up_reg) begin
                        // Frequency UP: First voltage
                        dvfs_state_next = DVFS_V_REQ;
                    end else begin
                        // Frequency DOWN: First frequency
                        dvfs_state_next = DVFS_F_REQ;
                    end
                end
            end

            DVFS_V_REQ: begin
                if (vdd_main_ready) begin
                    dvfs_state_next = DVFS_V_WAIT;
                end
            end

            DVFS_V_WAIT: begin
                if (vdd_main_ack || dvfs_timeout_cnt_reg >= 8'h64) begin
                    if (freq_up_reg) begin
                        dvfs_state_next = DVFS_F_REQ;
                    end else begin
                        dvfs_state_next = DVFS_DONE;
                    end
                end
            end

            DVFS_F_REQ: begin
                dvfs_state_next = DVFS_F_WAIT;
            end

            DVFS_F_WAIT: begin
                if (dvfs_op_ack || dvfs_timeout_cnt_reg >= 8'h64) begin
                    if (freq_up_reg) begin
                        dvfs_state_next = DVFS_DONE;
                    end else begin
                        dvfs_state_next = DVFS_V_REQ;
                    end
                end
            end

            DVFS_DONE: begin
                dvfs_state_next = DVFS_IDLE;
            end

            default: begin
                dvfs_state_next = DVFS_IDLE;
            end
        endcase
    end

    //========================================================================
    // Power Mode FSM (FSM.md, MAS.md §3.1)
    //========================================================================

    // FSM state register
    always_ff @(posedge clk_aon or negedge rst_por_n) begin
        if (!rst_por_n) begin
            pmode_state_reg <= STATE_RESET;
        end else begin
            pmode_state_reg <= pmode_state_next;
        end
    end

    // FSM output generation based on state (FSM.md Output Actions by State)
    always_ff @(posedge clk_aon or negedge rst_por_n) begin
        if (!rst_por_n) begin
            pmode_state <= STATE_RESET;
            dvfs_switch_req_reg <= 1'b0;
            target_op_reg <= OP0;
            pg_entering_reg <= 1'b0;
            pg_exiting_reg <= 1'b0;
            mode_ack_reg <= 1'b0;
            mode_error_reg <= 1'b0;
        end else begin
            pmode_state <= pmode_state_reg;

            case (pmode_state_reg)
                STATE_RESET: begin
                    // Reset state outputs
                    pg_main_en <= 1'b1;     // PG enabled (powered off)
                    pg_iso_en <= 1'b1;      // Isolation enabled
                    target_op_reg <= OP0;   // Prepare for OP0
                    dvfs_switch_req_reg <= 1'b0;
                    pg_entering_reg <= 1'b0;
                    pg_exiting_reg <= 1'b1; // Request power gate exit
                    mode_ack_reg <= 1'b0;
                end

                STATE_ACTIVE: begin
                    // Active state outputs
                    pg_main_en <= 1'b0;     // PG disabled
                    pg_iso_en <= 1'b0;      // Isolation disabled
                    dvfs_switch_req_reg <= 1'b0;
                    pg_entering_reg <= 1'b0;
                    pg_exiting_reg <= 1'b0;
                    mode_ack_reg <= 1'b1;   // Acknowledge mode
                    mode_error_reg <= 1'b0;
                end

                STATE_SLEEP: begin
                    // Sleep state outputs
                    pg_main_en <= 1'b0;     // PG disabled
                    pg_iso_en <= 1'b0;      // Isolation disabled
                    target_op_reg <= OP1;   // OP1 for sleep
                    dvfs_switch_req_reg <= 1'b1;
                    pg_entering_reg <= 1'b0;
                    pg_exiting_reg <= 1'b0;
                    mode_ack_reg <= 1'b1;
                end

                STATE_DEEP_SLEEP: begin
                    // Deep Sleep state outputs
                    pg_main_en <= 1'b1;     // PG enabled
                    pg_iso_en <= 1'b1;      // Isolation enabled
                    target_op_reg <= OP2;   // OP2 for deep sleep
                    dvfs_switch_req_reg <= 1'b1;
                    pg_entering_reg <= 1'b1; // Request power gate enter
                    pg_exiting_reg <= 1'b0;
                    mode_ack_reg <= 1'b1;
                end

                default: begin
                    pmode_state <= STATE_RESET;
                end
            endcase
        end
    end

    // FSM state transition logic (FSM.md State Transition Table)
    always_comb begin
        pmode_state_next = pmode_state_reg;

        case (pmode_state_reg)
            STATE_RESET: begin
                // POR release -> ACTIVE
                if (rst_por_n && pm_enable_reg) begin
                    pmode_state_next = STATE_ACTIVE;
                end
            end

            STATE_ACTIVE: begin
                // idle_timeout OR pmode_req=1 -> SLEEP
                if ((idle_detected_reg && auto_pmode_en_reg) || (pmode_req == 2'b01)) begin
                    pmode_state_next = STATE_SLEEP;
                end
                // pmode_req=2 OR long_idle -> DEEP_SLEEP
                else if (pmode_req == 2'b10) begin
                    pmode_state_next = STATE_DEEP_SLEEP;
                end
            end

            STATE_SLEEP: begin
                // wakeup OR pmode_req=0 -> ACTIVE
                if (wakeup_pending_reg || (pmode_req == 2'b00)) begin
                    pmode_state_next = STATE_ACTIVE;
                end
                // pmode_req=2 -> DEEP_SLEEP
                else if (pmode_req == 2'b10) begin
                    pmode_state_next = STATE_DEEP_SLEEP;
                end
            end

            STATE_DEEP_SLEEP: begin
                // wakeup OR pmode_req=0 -> ACTIVE
                if (wakeup_pending_reg || (pmode_req == 2'b00)) begin
                    pmode_state_next = STATE_ACTIVE;
                end
                // pmode_req=1 -> SLEEP
                else if (pmode_req == 2'b01) begin
                    pmode_state_next = STATE_SLEEP;
                end
            end

            default: begin
                pmode_state_next = STATE_RESET;
            end
        endcase
    end

    //========================================================================
    // Control Registers (from bus interface)
    //========================================================================

    // PM_CTRL register
    always_ff @(posedge clk_aon or negedge rst_por_n) begin
        if (!rst_por_n) begin
            pm_enable_reg <= 1'b0;
            dvfs_enable_reg <= 1'b1;
            pg_enable_reg <= 1'b1;
            wakeup_enable_reg <= 1'b1;
            pwr_est_enable_reg <= 1'b1;
            idle_det_enable_reg <= 1'b0;
            auto_pmode_en_reg <= 1'b0;
            irq_enable_reg <= 1'b0;
        end
    end

    //========================================================================
    // Status Register Generation
    //========================================================================

    always_ff @(posedge clk_aon or negedge rst_por_n) begin
        if (!rst_por_n) begin
            pm_ready_reg <= 1'b0;
            pm_busy_reg <= 1'b0;
            pm_error_reg <= 1'b0;
        end else begin
            // Ready when in ACTIVE state and not busy
            pm_ready_reg <= (pmode_state_reg == STATE_ACTIVE) && !dvfs_switching_reg;

            // Busy during transitions
            pm_busy_reg <= dvfs_switching_reg || mode_transition_active_reg ||
                           (pg_seq_state_reg != PG_SEQ_IDLE);

            // Error from voltage regulator or timeout
            pm_error_reg <= vdd_main_error || (dvfs_timeout_cnt_reg >= 8'h64);
        end
    end

    //========================================================================
    // Interrupt Generation
    //========================================================================

    always_ff @(posedge clk_aon or negedge rst_por_n) begin
        if (!rst_por_n) begin
            irq_pending_reg <= 1'b0;
            irq_type_reg <= 3'b0;
            pm_irq <= 1'b0;
            pm_irq_type <= 3'b0;
        end else begin
            // Generate interrupts based on events
            if (irq_enable_reg) begin
                // DVFS done interrupt
                if (dvfs_state_reg == DVFS_DONE) begin
                    irq_pending_reg <= 1'b1;
                    irq_type_reg <= IRQ_TYPE_DVFS_DONE;
                end

                // Wakeup interrupt
                if (wakeup_detected_reg) begin
                    irq_pending_reg <= 1'b1;
                    irq_type_reg <= IRQ_TYPE_WAKEUP;
                end

                // Power alert interrupt
                if (pwr_alert_reg) begin
                    irq_pending_reg <= 1'b1;
                    irq_type_reg <= IRQ_TYPE_PWR_ALERT;
                end

                // Power Gate done interrupt
                if (pg_seq_state_reg == PG_SEQ_PG_EN || pg_seq_state_reg == PG_SEQ_ISO_DIS) begin
                    irq_pending_reg <= 1'b1;
                    irq_type_reg <= IRQ_TYPE_PG_DONE;
                end

                // Mode transition done interrupt
                if (mode_ack_reg && mode_transition_active_reg) begin
                    irq_pending_reg <= 1'b1;
                    irq_type_reg <= IRQ_TYPE_PMODE_DONE;
                end

                // Error interrupt
                if (pm_error_reg) begin
                    irq_pending_reg <= 1'b1;
                    irq_type_reg <= IRQ_TYPE_ERROR;
                end
            end else begin
                irq_pending_reg <= 1'b0;
            end

            // Output interrupt signals
            pm_irq <= irq_pending_reg && irq_enable_reg;
            pm_irq_type <= irq_type_reg;
        end
    end

    //========================================================================
    // Bus Interface (MAS.md §2.1.2)
    //========================================================================

    // Register read logic
    always_ff @(posedge clk_aon or negedge rst_por_n) begin
        if (!rst_por_n) begin
            bus_cmd_ready <= 1'b0;
            bus_rsp_valid_reg <= 1'b0;
            bus_rsp_data_reg <= 32'b0;
            bus_rsp_error_reg <= 1'b0;
        end else begin
            bus_cmd_ready <= 1'b1;

            if (bus_cmd_valid && !bus_cmd_rw) begin
                // Read operation
                bus_rsp_valid_reg <= 1'b1;
                bus_rsp_error_reg <= 1'b0;

                case (bus_cmd_addr)
                    ADDR_PM_CTRL: begin
                        bus_rsp_data_reg <= {16'b0,
                            irq_enable_reg, auto_pmode_en_reg, idle_det_enable_reg,
                            pwr_est_enable_reg, wakeup_enable_reg, pg_enable_reg,
                            dvfs_enable_reg, pm_enable_reg};
                    end

                    ADDR_PM_STATUS: begin
                        bus_rsp_data_reg <= {8'b0,
                            current_op_reg,
                            pmode_state_reg,
                            idle_detected_reg, pwr_alert_reg, wakeup_pending_reg,
                            pg_enable_reg && pg_main_en, dvfs_switching_reg,
                            pm_error_reg, pm_busy_reg, pm_ready_reg};
                    end

                    ADDR_PM_MODE: begin
                        bus_rsp_data_reg <= {22'b0, 2'b0, mode_ack_reg, pmode_state_reg, pmode_req};
                    end

                    ADDR_DVFS_CTRL: begin
                        bus_rsp_data_reg <= {28'b0, 4'b0, dvfs_switch_req_reg, target_op_reg};
                    end

                    ADDR_DVFS_STATUS: begin
                        bus_rsp_data_reg <= {28'b0, dvfs_switching_reg, current_op_reg};
                    end

                    ADDR_WAKEUP_EN: begin
                        bus_rsp_data_reg <= {24'b0, wakeup_en_reg};
                    end

                    ADDR_WAKEUP_STATUS: begin
                        bus_rsp_data_reg <= {24'b0, wakeup_status_reg};
                    end

                    ADDR_PWR_ESTIMATE: begin
                        bus_rsp_data_reg <= {16'b0, pwr_estimate_reg};
                    end

                    ADDR_PWR_BUDGET: begin
                        bus_rsp_data_reg <= {16'b0, pwr_budget_reg};
                    end

                    ADDR_PWR_COUNTERS: begin
                        bus_rsp_data_reg <= pwr_counters;
                    end

                    ADDR_IDLE_STATUS: begin
                        bus_rsp_data_reg <= {16'b0, idle_counter_reg};
                    end

                    default: begin
                        bus_rsp_data_reg <= 32'b0;
                        bus_rsp_error_reg <= 1'b1;
                    end
                endcase
            end else if (bus_cmd_valid && bus_cmd_rw) begin
                // Write operation
                bus_rsp_valid_reg <= 1'b1;
                bus_rsp_error_reg <= 1'b0;
                bus_rsp_data_reg <= 32'b0;

                case (bus_cmd_addr)
                    ADDR_PM_CTRL: begin
                        pm_enable_reg <= bus_cmd_data[0];
                        dvfs_enable_reg <= bus_cmd_data[1];
                        pg_enable_reg <= bus_cmd_data[2];
                        wakeup_enable_reg <= bus_cmd_data[3];
                        pwr_est_enable_reg <= bus_cmd_data[4];
                        idle_det_enable_reg <= bus_cmd_data[5];
                        auto_pmode_en_reg <= bus_cmd_data[6];
                        irq_enable_reg <= bus_cmd_data[7];
                    end

                    ADDR_DVFS_CTRL: begin
                        target_op_reg <= bus_cmd_data[1:0];
                        dvfs_switch_req_reg <= bus_cmd_data[2];
                    end

                    ADDR_WAKEUP_EN: begin
                        wakeup_en_reg <= bus_cmd_data[7:0];
                    end

                    ADDR_WAKEUP_CLEAR: begin
                        if (bus_cmd_data[0]) begin
                            wakeup_status_reg <= 8'b0;
                            wakeup_pending_reg <= 1'b0;
                        end
                    end

                    ADDR_PWR_BUDGET: begin
                        pwr_budget_reg <= bus_cmd_data[15:0];
                    end

                    default: begin
                        bus_rsp_error_reg <= 1'b1;
                    end
                endcase
            end else begin
                bus_rsp_valid_reg <= 1'b0;
                bus_rsp_data_reg <= 32'b0;
                bus_rsp_error_reg <= 1'b0;
            end
        end
    end

    assign bus_rsp_valid = bus_rsp_valid_reg;
    assign bus_rsp_data = bus_rsp_data_reg;
    assign bus_rsp_error = bus_rsp_error_reg;

    //========================================================================
    // Output Assignments
    //========================================================================

    assign wakeup_en = wakeup_en_reg;
    assign wakeup_status = wakeup_status_reg;
    assign wakeup_pending = wakeup_pending_reg;
    assign pwr_estimate = pwr_estimate_reg;
    assign pwr_alert = pwr_alert_reg;
    assign pwr_counters = {16'b0, idle_counter_reg, activity_factor_reg, dvfs_factor_reg};
    assign idle_detected = idle_detected_reg;
    assign pm_status = {pm_error_reg, pm_busy_reg, pm_ready_reg,
                        dvfs_switching_reg, pg_main_en, wakeup_pending_reg,
                        pwr_alert_reg, idle_detected_reg};
    assign pmode_ack = mode_ack_reg;
    assign pmode_error = mode_error_reg;

endmodule