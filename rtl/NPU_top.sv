//=============================================================================
// Module: NPU_top
// Description: TinyStories 15M LLM NPU Top-Level Integration Module
//-----------------------------------------------------------------------------
// Architecture:
//   - 17 sub-modules (M00-M16) organized into 3 power domains
//   - PD_MAIN: M00-M04, M08-M14 (Compute, Memory, Operators, ISA)
//   - PD_AON:  M05-M07 (Power, Clock, Reset Managers)
//   - PD_IO:   M15-M16 (JTAG, ISA Interface)
//
// Clock Domains:
//   - CLK_SYS: 250-500 MHz (DVFS), Main compute domain
//   - CLK_AON: 1 MHz, Always-on domain
//   - CLK_IO:  50 MHz, IO domain
//
// Naming Convention (per user rule):
//   - Single die top module: <die_name>_top (this file: NPU_top)
//   - Multi-die chip top module: chip_top
//
// Reference: spec/ARCH/block_diagram.md, chip_overview.md
//=============================================================================

module NPU_top #(
    // System Parameters
    parameter DATA_WIDTH     = 128,
    parameter ADDR_WIDTH     = 32,

    // Systolic Array Parameters
    parameter PE_ROWS        = 128,
    parameter PE_COLS        = 128,

    // Attention Parameters
    parameter N_HEADS        = 8,
    parameter N_KV_HEADS     = 4,
    parameter HEAD_SIZE      = 8,
    parameter SEQ_LEN        = 512,

    // Memory Parameters
    parameter SRAM_SIZE_KB   = 512,
    parameter DRAM_SIZE_GB   = 2
)(
    //=========================================================================
    // External IO Interface (Pad-level signals)
    //=========================================================================

    // Power & Ground (from external pads)
    input  wire        vdd_main,         // PD_MAIN supply (0.7-0.9V DVFS)
    input  wire        vdd_aon,          // PD_AON supply (always-on)
    input  wire        vdd_io,           // PD_IO supply (IO pads)
    input  wire        vss,              // Common ground

    // External Clock Input
    input  wire        ext_clk_50m,      // External 50 MHz crystal

    // External Resets
    input  wire        por_n,            // Power-on reset (active low)
    input  wire        ext_reset_n,      // External reset pin

    // DRAM Interface (3D Stacked Wafer-on-Wafer)
    output wire [ADDR_WIDTH-1:0] dram_addr_o,
    inout  wire [DATA_WIDTH-1:0] dram_data_io,
    output wire                   dram_clk_o,
    output wire                   dram_cs_n_o,
    output wire                   dram_we_n_o,
    output wire [3:0]             dram_dqs_o,

    // JTAG Interface (IEEE 1149.1)
    input  wire        jtag_tck,
    input  wire        jtag_tms,
    input  wire        jtag_tdi,
    output wire        jtag_tdo,
    input  wire        jtag_trst_n,

    // ISA Interface (External Instruction Stream)
    input  wire [31:0] isa_inst_in,
    input  wire        isa_inst_valid,
    output wire        isa_inst_ready,
    input  wire [31:0] isa_pc_in,

    // Secure Boot Interface
    input  wire [255:0] boot_signature_i,  // External firmware signature
    input  wire        boot_fw_valid_i,

    // GPIO / Status Outputs
    output wire [2:0]  chip_status_o,      // Chip operational status
    output wire        pll_locked_o,       // PLL lock status
    output wire        dvfs_ack_o          // DVFS completion flag
);

    //=========================================================================
    // Internal Clock/Reset Signals
    //=========================================================================

    // Clocks (from M06_ClockManager)
    wire        clk_sys;           // System clock (250-500 MHz)
    wire        clk_aon;           // Always-on clock (1 MHz)
    wire        clk_io;            // IO clock (50 MHz)
    wire [13:0] clk_gating;        // Per-module clock gating

    // Resets (from M07_ResetManager)
    wire        reset_main_n;      // Reset for PD_MAIN modules
    wire        reset_aon_n;       // Reset for PD_AON modules
    wire        reset_io_n;        // Reset for PD_IO modules
    wire        boot_start;        // Secure Boot trigger
    wire [2:0]  reset_status;      // Reset sequence status

    //=========================================================================
    // Power Domain Control Signals
    //=========================================================================

    // Power Manager (M05) outputs
    wire        pd_main_en;        // PD_MAIN power enable
    wire        pd_main_ready;     // PD_MAIN ready status
    wire [1:0]  dvfs_op;           // DVFS operating point
    wire        dvfs_req;          // DVFS request
    wire [2:0]  pwr_state;         // Power state (ACTIVE/IDLE/SLEEP)

    //=========================================================================
    // Clock Manager (M06) Signals
    //=========================================================================

    wire        pll_locked;        // PLL lock status
    wire [2:0]  clk_status;        // Clock stability status
    wire        pll_pwr_en;        // PLL power enable

    //=========================================================================
    // System Bus (M04) Interconnect Signals
    //=========================================================================

    // TileLink-UH Master interfaces (M00, M02, M03)
    wire        tl_m0_valid, tl_m1_valid, tl_m2_valid;
    wire [ADDR_WIDTH-1:0] tl_m0_addr, tl_m1_addr, tl_m2_addr;
    wire [DATA_WIDTH-1:0] tl_m0_data, tl_m1_data, tl_m2_data;
    wire        tl_m0_ready, tl_m1_ready, tl_m2_ready;

    // AXI4 Master interfaces (M13, M15)
    wire        axi_m3_valid, axi_m4_valid;
    wire [ADDR_WIDTH-1:0] axi_m3_addr, axi_m4_addr;
    wire [DATA_WIDTH-1:0] axi_m3_data, axi_m4_data;
    wire        axi_m3_ready, axi_m4_ready;

    //=========================================================================
    // Memory Interfaces (M02 SRAM, M03 DRAM)
    //=========================================================================

    // SRAM Scratchpad (M02)
    wire [ADDR_WIDTH-1:0] sram_addr;
    wire [DATA_WIDTH-1:0] sram_wdata, sram_rdata;
    wire        sram_we, sram_re;
    wire        sram_valid, sram_ready;
    wire [1:0]  sram_ecc_status;   // ECC status (OK/ERR_CORR/ERR_DET)

    // DRAM Controller (M03)
    wire [ADDR_WIDTH-1:0] dram_ctrl_addr;
    wire [DATA_WIDTH-1:0] dram_ctrl_wdata, dram_ctrl_rdata;
    wire        dram_ctrl_we, dram_ctrl_re;
    wire        dram_ctrl_valid, dram_ctrl_ready;
    wire [1:0]  dram_ecc_status;

    //=========================================================================
    // Compute Subsystem Signals (M00, M01, M08)
    //=========================================================================

    // Systolic Array (M00)
    wire        sa_mode;           // WS=0 / OS=1
    wire [1:0]  sa_precision;      // FP8/FP16/INT8/FP32
    wire        sa_start, sa_done;
    wire [7:0]  sa_row_cnt, sa_col_cnt;
    wire [PE_COLS*32-1:0] sa_weight_in;
    wire [PE_ROWS*32-1:0] sa_input_in;
    wire [PE_ROWS*32-1:0] sa_output_out;

    // Dataflow Controller (M01)
    wire        df_mode;           // Spatial pipeline mode
    wire        df_start, df_done;
    wire        df_pipeline_ready;
    wire [7:0]  df_stage_cnt;

    // Thread Scheduler (M08)
    wire [1:0]  thread_id;         // Thread selection (>=2 threads)
    wire        thread_start, thread_done;
    wire [3:0]  thread_priority;

    //=========================================================================
    // Transformer Operator Signals (M09-M12)
    //=========================================================================

    // Attention Unit (M09)
    wire        attn_valid, attn_ready;
    wire [511:0] attn_act_data;
    wire [15:0] attn_pos;
    wire [7:0]  attn_layer;
    wire        attn_done;

    // FFN/MatMul Unit (M10)
    wire        ffn_valid, ffn_ready;
    wire [DATA_WIDTH-1:0] ffn_input, ffn_output;
    wire        ffn_done;

    // RMSNorm/RoPE Unit (M11)
    wire        norm_valid, norm_ready;
    wire [DATA_WIDTH-1:0] norm_input, norm_output;
    wire        norm_mode;         // RMSNorm=0 / RoPE=1
    wire        norm_done;

    // SoftMax Unit (M12)
    wire        softmax_valid, softmax_ready;
    wire [DATA_WIDTH-1:0] softmax_input, softmax_output;
    wire        softmax_done;

    //=========================================================================
    // ISA Decoder (M13) Signals
    //=========================================================================

    wire [31:0] dec_inst;
    wire        dec_valid;
    wire [5:0]  dec_opcode;

    //=========================================================================
    // Secure Boot (M14) Signals
    //=========================================================================

    wire        boot_verify_req;
    wire        boot_verify_done;
    wire        boot_verify_pass;
    wire [255:0] boot_fw_hash;

    //=========================================================================
    // JTAG Interface (M15) Signals
    //=========================================================================

    wire        jtag_tap_select;
    wire [31:0] jtag_ir_out;
    wire [31:0] jtag_dr_out;

    //=========================================================================
    // ISA Interface (M16) Signals
    //=========================================================================

    wire [31:0] isa_inst_internal;
    wire        isa_inst_valid_internal;
    wire        isa_inst_ready_internal;
    wire [31:0] isa_pc_internal;

    //=========================================================================
    // Module Instantiations
    //=========================================================================

    //-------------------------------------------------------------------------
    // Power Domain: PD_AON (Always-On) - M05, M06, M07
    //-------------------------------------------------------------------------

    // M05: Power Manager
    M05_PowerManager u_M05_PowerManager (
        .clk_aon_i       (clk_aon),
        .rst_aon_n_i     (reset_aon_n),
        .pll_locked_i    (pll_locked),
        .clk_stable_i    (clk_status[0]),
        .dvfs_req_i      (dvfs_req),
        .dvfs_op_i       (dvfs_op),
        .pd_main_en_o    (pd_main_en),
        .pd_main_ready_o (pd_main_ready),
        .dvfs_ack_o      (dvfs_ack_o),
        .pwr_state_o     (pwr_state)
    );

    // M06: Clock Manager
    M06_ClockManager u_M06_ClockManager (
        .ext_clk_i       (ext_clk_50m),
        .pll_lock_i      (pll_locked),
        .dvfs_op_i       (dvfs_op),
        .dvfs_req_i      (dvfs_req),
        .clk_gating_en_i (14'h3FFF),    // All modules enabled
        .pd_aon_vdd_i    (vdd_aon),
        .clk_sys_o       (clk_sys),
        .clk_aon_o       (clk_aon),
        .clk_io_o        (clk_io),
        .clk_gating_o    (clk_gating),
        .dvfs_ack_o      (pll_locked_o),
        .clk_status_o    (clk_status),
        .pll_pwr_en_o    (pll_pwr_en)
    );

    // M07: Reset Manager
    M07_ResetManager u_M07_ResetManager (
        .clk_aon         (clk_aon),
        .por_in          (~por_n),
        .sw_reset_req    (1'b0),        // No software reset initially
        .wdt_reset_in    (1'b0),        // No watchdog reset initially
        .pll_locked      (pll_locked),
        .clk_aon_stable  (clk_status[0]),
        .clk_sys_stable  (clk_status[1]),
        .pd_main_ready   (pd_main_ready),
        .reset_main_out  (~reset_main_n),
        .reset_aon_out   (~reset_aon_n),
        .reset_io_out    (~reset_io_n),
        .reset_status    (reset_status),
        .boot_start      (boot_start),
        .sequence_done   (chip_status_o[2])
    );

    //-------------------------------------------------------------------------
    // Power Domain: PD_MAIN - M00-M04, M08-M14
    //-------------------------------------------------------------------------

    // M00: Systolic Array
    M00_SystolicArray #(
        .PE_ROWS   (PE_ROWS),
        .PE_COLS   (PE_COLS),
        .DATA_W_MAX (32),
        .ACC_W     (32)
    ) u_M00_SystolicArray (
        .clk_i           (clk_sys),
        .rst_ni          (reset_main_n),
        .pe_mode_i       (sa_mode),
        .pe_precision_i  (sa_precision),
        .pe_start_i      (sa_start),
        .pe_done_o       (sa_done),
        .pe_row_cnt_i    (sa_row_cnt),
        .pe_col_cnt_i    (sa_col_cnt),
        .weight_in_i     (sa_weight_in),
        .input_in_i      (sa_input_in),
        .output_out_o    (sa_output_out)
    );

    // M01: Dataflow Controller
    M01_DataflowController u_M01_DataflowController (
        .clk_sys_i       (clk_sys),
        .rst_sys_n_i     (reset_main_n),
        .pg_main_en_i    (pd_main_en),
        .mode_i          (df_mode),
        .start_i         (df_start),
        .done_o          (df_done),
        .pipeline_ready_o(df_pipeline_ready),
        .stage_cnt_i     (df_stage_cnt)
    );

    // M02: SRAM Scratchpad
    M02_SRAMScratchpad #(
        .SIZE_KB  (SRAM_SIZE_KB)
    ) u_M02_SRAMScratchpad (
        .clk_sys_i       (clk_sys),
        .rst_sys_n_i     (reset_main_n),
        .addr_i          (sram_addr),
        .wdata_i         (sram_wdata),
        .rdata_o         (sram_rdata),
        .we_i            (sram_we),
        .re_i            (sram_re),
        .valid_i         (sram_valid),
        .ready_o         (sram_ready),
        .ecc_status_o    (sram_ecc_status)
    );

    // M03: DRAM Controller
    M03_DRAMController #(
        .DRAM_SIZE_GB (DRAM_SIZE_GB)
    ) u_M03_DRAMController (
        .clk_sys_i       (clk_sys),
        .rst_sys_n_i     (reset_main_n),
        .addr_i          (dram_ctrl_addr),
        .wdata_i         (dram_ctrl_wdata),
        .rdata_o         (dram_ctrl_rdata),
        .we_i            (dram_ctrl_we),
        .re_i            (dram_ctrl_re),
        .valid_i         (dram_ctrl_valid),
        .ready_o         (dram_ctrl_ready),
        .ecc_status_o    (dram_ecc_status),
        // External DRAM interface
        .dram_addr_o     (dram_addr_o),
        .dram_data_io    (dram_data_io),
        .dram_clk_o      (dram_clk_o),
        .dram_cs_n_o     (dram_cs_n_o),
        .dram_we_n_o     (dram_we_n_o)
    );

    // M04: System Bus
    M04_SystemBus #(
        .DATA_WIDTH  (DATA_WIDTH),
        .ADDR_WIDTH  (ADDR_WIDTH)
    ) u_M04_SystemBus (
        .clk_sys_i       (clk_sys),
        .rst_sys_n_i     (reset_main_n),
        // Master interfaces (connections to be elaborated)
        .tl_m0_valid_i   (tl_m0_valid),
        .tl_m0_addr_i    (tl_m0_addr),
        .tl_m0_data_i    (tl_m0_data),
        .tl_m0_ready_o   (tl_m0_ready),
        // Slave interfaces
        .tl_s0_valid_o   (dram_ctrl_valid),
        .tl_s0_addr_o    (dram_ctrl_addr),
        .tl_s0_data_o    (dram_ctrl_wdata),
        .tl_s1_valid_o   (sram_valid),
        .tl_s1_addr_o    (sram_addr),
        .tl_s1_data_o    (sram_wdata)
    );

    // M08: Thread Scheduler
    M08_ThreadScheduler u_M08_ThreadScheduler (
        .clk_sys_i       (clk_sys),
        .rst_sys_n_i     (reset_main_n),
        .pg_main_en_i    (pd_main_en),
        .thread_id_o     (thread_id),
        .thread_start_i  (thread_start),
        .thread_done_o   (thread_done),
        .thread_priority_i(thread_priority)
    );

    // M09: Attention Unit
    M09_AttentionUnit #(
        .N_HEADS    (N_HEADS),
        .N_KV_HEADS (N_KV_HEADS),
        .HEAD_SIZE  (HEAD_SIZE),
        .SEQ_LEN    (SEQ_LEN)
    ) u_M09_AttentionUnit (
        .clk_sys_i       (clk_sys),
        .rst_sys_n_i     (reset_main_n),
        .pg_main_en_i    (pd_main_en),
        .act_valid_i     (attn_valid),
        .act_data_i      (attn_act_data),
        .act_pos_i       (attn_pos),
        .act_layer_i     (attn_layer),
        .act_ready_o     (attn_ready),
        .attn_done_o     (attn_done)
    );

    // M10: FFN/MatMul Unit
    M10_FFNMatMul u_M10_FFNMatMul (
        .clk_sys_i       (clk_sys),
        .rst_sys_n_i     (reset_main_n),
        .pg_main_en_i    (pd_main_en),
        .valid_i         (ffn_valid),
        .input_i         (ffn_input),
        .ready_o         (ffn_ready),
        .output_o        (ffn_output),
        .done_o          (ffn_done)
    );

    // M11: RMSNorm/RoPE Unit
    M11_RMSNormRoPE u_M11_RMSNormRoPE (
        .clk_sys_i       (clk_sys),
        .rst_sys_n_i     (reset_main_n),
        .pg_main_en_i    (pd_main_en),
        .valid_i         (norm_valid),
        .input_i         (norm_input),
        .mode_i          (norm_mode),
        .ready_o         (norm_ready),
        .output_o        (norm_output),
        .done_o          (norm_done)
    );

    // M12: SoftMax Unit
    M12_SoftMax u_M12_SoftMax (
        .clk_sys_i       (clk_sys),
        .rst_sys_n_i     (reset_main_n),
        .pg_main_en_i    (pd_main_en),
        .valid_i         (softmax_valid),
        .input_i         (softmax_input),
        .ready_o         (softmax_ready),
        .output_o        (softmax_output),
        .done_o          (softmax_done)
    );

    // M13: ISA Decoder
    M13_ISADecoder u_M13_ISADecoder (
        .clk_sys_i       (clk_sys),
        .rst_sys_n_i     (reset_main_n),
        .pg_main_en_i    (pd_main_en),
        .isa_inst_valid_i(isa_inst_valid_internal),
        .isa_inst_data_i (isa_inst_internal),
        .isa_inst_ready_o(isa_inst_ready_internal),
        .isa_pc_i        (isa_pc_internal),
        .dec_valid_o     (dec_valid),
        .dec_opcode_o    (dec_opcode)
    );

    // M14: Secure Boot
    M14_SecureBoot u_M14_SecureBoot (
        .clk_sys_i       (clk_sys),
        .rst_sys_n_i     (reset_main_n),
        .boot_start_i    (boot_start),
        .fw_signature_i  (boot_signature_i),
        .fw_valid_i      (boot_fw_valid_i),
        .verify_req_o    (boot_verify_req),
        .verify_done_o   (boot_verify_done),
        .verify_pass_o   (boot_verify_pass),
        .fw_hash_o       (boot_fw_hash)
    );

    //-------------------------------------------------------------------------
    // Power Domain: PD_IO - M15, M16
    //-------------------------------------------------------------------------

    // M15: JTAG Interface
    M15_JTAGInterface u_M15_JTAGInterface (
        .clk_io_i        (clk_io),
        .rst_io_n_i      (reset_io_n),
        .tck_i           (jtag_tck),
        .tms_i           (jtag_tms),
        .tdi_i           (jtag_tdi),
        .tdo_o           (jtag_tdo),
        .trst_n_i        (jtag_trst_n),
        .tap_select_o    (jtag_tap_select),
        .ir_out_o        (jtag_ir_out),
        .dr_out_o        (jtag_dr_out)
    );

    // M16: ISA Interface
    M16_ISAInterface u_M16_ISAInterface (
        .clk_io_i        (clk_io),
        .rst_io_n_i      (reset_io_n),
        .inst_in_i       (isa_inst_in),
        .inst_valid_i    (isa_inst_valid),
        .inst_ready_o    (isa_inst_ready),
        .pc_in_i         (isa_pc_in),
        // Internal interface to M13
        .inst_out_o      (isa_inst_internal),
        .inst_valid_o    (isa_inst_valid_internal),
        .inst_ready_i    (isa_inst_ready_internal),
        .pc_out_o        (isa_pc_internal)
    );

    //=========================================================================
    // Status Output Mapping
    //=========================================================================

    assign chip_status_o[0] = pll_locked;
    assign chip_status_o[1] = pd_main_ready;

    //=========================================================================
    // Control Signal Defaults (Placeholder - needs full interconnect)
    //=========================================================================

    // These signals need to be properly connected based on the System Bus
    // routing and Dataflow Controller pipeline control

    assign sa_mode       = 1'b0;     // WS mode default
    assign sa_precision  = 2'b01;    // FP16 default
    assign sa_start      = 1'b0;
    assign sa_row_cnt    = 8'd128;
    assign sa_col_cnt    = 8'd128;

    assign df_mode       = 1'b0;
    assign df_start      = 1'b0;
    assign df_stage_cnt  = 8'd4;

    assign thread_start  = 1'b0;
    assign thread_priority = 4'h0;

    assign dvfs_op       = 2'b00;    // OP0 (500 MHz)
    assign dvfs_req      = 1'b0;

endmodule : NPU_top