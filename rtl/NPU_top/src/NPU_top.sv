//-----------------------------------------------------------------------------
// Module: NPU_top - Complete Integration (Port-Matched Version)
// Version: 2.0 - Fixed port name mismatches with actual module definitions
//-----------------------------------------------------------------------------
module NPU_top (
    input  logic ext_clk_50MHz, ext_rst_por_n, pll_lock_ext,
    output logic pll_pwr_en, irq_compute_done, status_sec_boot_done
);

//=============================================================================
// Internal Signals
//=============================================================================
logic clk_sys, clk_aon, clk_io, rst_sys_n, pg_main_en;
logic sec_boot_done, sec_boot_fail, sec_lockdown;

// M05 Power Manager internal signals
logic [1:0] dvfs_op_req;
logic dvfs_op_ack;
logic [2:0] dvfs_vdd_req;
logic [31:0] dvfs_freq_req;
logic dvfs_busy;
logic [7:0] vdd_main_set;
logic vdd_main_ack, vdd_main_ready, vdd_main_error;
logic pg_main_status, pg_main_switch, pg_iso_en;
logic [1:0] pmode_state, pmode_req;
logic pmode_ack, pmode_error;
logic [7:0] wakeup_ext, wakeup_en, wakeup_status;
logic wakeup_pending, wakeup_clear;
logic [15:0] pwr_estimate, pwr_budget, pwr_counters;
logic pwr_alert;
logic activity_main, activity_io, activity_dram;
logic [15:0] idle_timeout;
logic idle_detected;
logic [7:0] pm_status;
logic pm_irq;
logic [2:0] pm_irq_type;

// M04 System Bus signals
logic bus_busy, bus_error;
logic [4:0] arb_winner;
logic [6:0] route_target;
logic timeout_irq, error_irq;

// M02 SRAM signals
logic bus_cmd_ready_m02;
logic bus_rsp_valid_m02;
logic [63:0] bus_rsp_rdata_m02;
logic bus_rsp_error_m02;
logic sram_rsp_valid_m02;
logic [63:0] sram_rsp_rdata_m02;
logic sram_rsp_error_m02;

// M03 DRAM signals
logic bus_cmd_ready_m03;
logic bus_rsp_valid_m03;
logic [71:0] bus_rsp_data_m03;
logic bus_rsp_error_m03;
logic [7:0] bus_rsp_latency_m03;
logic d2d_cmd_valid, d2d_cmd_ready;
logic [31:0] d2d_cmd_addr;
logic d2d_cmd_rw;
logic [7:0] d2d_cmd_burst;
logic d2d_wdata_valid, d2d_wdata_last;
logic [71:0] d2d_wdata;
logic d2d_rdata_valid, d2d_rdata_last, d2d_rdata_error;
logic [71:0] d2d_rdata;
logic [15:0] d2d_tx_data, d2d_rx_data;
logic d2d_tx_clk, d2d_rx_clk, d2d_pll_lock;
logic [31:0] ecc_err_addr;
logic [1:0] ecc_err_type;
logic ecc_err_valid, ecc_err_clear, ecc_corrected;
logic [15:0] bw_request, bw_grant;
logic [3:0] bw_priority;
logic [7:0] bw_status;
logic dram_active, dram_idle;
logic [1:0] dram_power_mode;
logic dram_self_refresh_req, dram_self_refresh_ack;
logic [7:0] dram_status;
logic dram_irq;
logic [3:0] dram_irq_type;

// M00 Systolic Array signals
logic pe_done, pe_size_error;
logic [2:0] pe_size_error_code;
logic [511:0] weight_in, input_in, output_out;
logic [511:0] partial_out;

// M01 Dataflow Controller signals
logic syst_done, syst_err;
logic [3:0] op_ready_m01, op_done_m01;
logic [7:0] op_err_m01;
logic mem_req_valid, mem_req_ready;
logic [1:0] mem_req_type;
logic [31:0] mem_req_addr;
logic [15:0] mem_req_size;
logic mem_req_tid;
logic mem_resp_valid;
logic [63:0] mem_resp_data;
logic mem_resp_last;
logic [1:0] mem_resp_err;
logic [1:0] sched_thread_en, sched_priority;
logic sched_yield, sched_current_tid;
logic [3:0] sched_status;
logic irq_op_done, irq_err, irq_tid;
logic [31:0] reg_addr, reg_wdata, reg_rdata;
logic reg_write, reg_read;
logic start_en, soft_reset;

// M08 Thread Scheduler signals
logic thread_cmd_ready;
logic reg_req_ready;
logic reg_rsp_valid;
logic [31:0] reg_rsp_data;
logic reg_rsp_error;
logic dispatch_valid, dispatch_ready;
logic [2:0] dispatch_thread_id;
logic [31:0] dispatch_entry_addr;
logic [7:0] dispatch_context_ptr;
logic [1:0] dispatch_cmd;
logic dispatch_done, dispatch_error;
logic ctx_rd_valid, ctx_rd_ready;
logic [7:0] ctx_rd_ptr;
logic [255:0] ctx_rd_data;
logic ctx_wr_valid, ctx_wr_ready;
logic [7:0] ctx_wr_ptr;
logic [255:0] ctx_wr_data;
logic [2:0] thread_active_id;
logic [1:0] thread_active_state;
logic [3:0] thread_pending_cnt, thread_blocked_cnt;
logic thread_irq;
logic [2:0] thread_irq_id;
logic [3:0] thread_irq_type;
logic sched_status_ready, sched_status_busy, sched_status_ctx_switch, sched_status_error;

// M09 Attention Unit signals
logic act_ready, qkv_ready;
logic [19:0] kv_addr;
logic [63:0] kv_wdata;
logic kv_wen, kv_valid;
logic kv_ready;
logic [63:0] kv_rdata;
logic sa_cmd_valid, sa_cmd_ready;
logic [1:0] sa_op;
logic [7:0] sa_head;
logic [15:0] sa_pos;
logic sa_result_valid;
logic [255:0] sa_result_data;
logic sa_result_ready;
logic sm_valid;
logic [511:0] sm_data;
logic [7:0] sm_head;
logic sm_ready;
logic out_valid;
logic [511:0] out_data;
logic [7:0] out_layer;
logic attn_done, attn_busy;
logic kv_overflow;

// M10 FFN signals
logic ffn_busy, ffn_done, ffn_error;
logic [7:0] ffn_error_code;
logic [255:0] ffn_x_in, ffn_y_out;
logic ffn_x_valid, ffn_x_ready;
logic ffn_y_valid, ffn_y_ready;
logic [15:0] ffn_s_dim;
logic [31:0] ffn_w_base, ffn_w1_offset, ffn_w3_offset, ffn_w2_offset;
logic sa1_cmd_valid, sa1_cmd_ready;
logic [1:0] sa1_op;
logic sa1_start, sa1_done, sa1_busy;
logic [255:0] sa1_wdata;
logic [255:0] sa1_result;
logic sa2_cmd_valid, sa2_cmd_ready;
logic [1:0] sa2_op;
logic sa2_start, sa2_done, sa2_busy;
logic [255:0] sa2_wdata;
logic [255:0] sa2_result;

// M11 RMSNorm/RoPE signals
logic sram_req_valid;
logic [19:0] sram_req_addr;
logic sram_req_rw;
logic [63:0] sram_req_wdata;
logic [7:0] sram_req_wstrb;
logic sram_rsp_valid;
logic [63:0] sram_rsp_rdata;
logic sram_rsp_error;
logic op_done_m11, op_busy_m11, op_error_m11;
logic data_in_valid;
logic [31:0] data_in_addr;
logic [15:0] data_in_size;
logic [31:0] weight_addr;
logic data_out_valid;
logic [31:0] data_out_addr, data_out_addr_i;
logic [15:0] data_out_size;
logic data_out_done;
logic [31:0] rope_table_addr;
logic [15:0] rope_table_size;
logic rope_table_en;
logic [7:0] op_status;
logic op_irq;
logic [2:0] op_irq_type;
logic [31:0] cycle_count;

// M12 SoftMax signals
logic score_ready;
logic [511:0] score_data;
logic [7:0] score_len;
logic prob_valid;
logic [511:0] prob_data;
logic [7:0] prob_len;
logic softmax_busy, softmax_done, softmax_error;

// M13 ISA Decoder signals
logic isa_inst_ready;
logic isa_pc_update;
logic dec_valid;
logic [5:0] dec_opcode;
logic [1:0] dec_format;
logic [4:0] dec_vd, dec_vs1, dec_vs2, dec_vs3, dec_sd, dec_base;
logic [15:0] dec_imm16;
logic [20:0] dec_imm21;
logic [10:0] dec_offset;
logic [5:0] dec_func;
logic op_valid_m13;
logic [3:0] op_target;
logic op_start;
logic op_ready_m13;
logic op_done_m13;
logic sa_cmd_valid_m13;
logic [1:0] sa_op_m13;
logic sa_ready_m13;
logic [31:0] mem_addr;
logic mem_wen, mem_valid, mem_ready;
logic dec_done, dec_busy;
logic error_invalid_opcode, error_invalid_format, error_invalid_reg, error_sec_boot_fail;

// M14 Secure Boot signals
logic fw_data_req;
logic [31:0] fw_data_addr;
logic fw_data_valid;
logic [255:0] fw_data;
logic fw_data_last;
logic [255:0] sig_r, sig_s;
logic sig_valid;
logic [7:0] otp_key_addr;
logic [511:0] otp_key_data;
logic otp_key_valid, otp_read_ack, otp_read_req, otp_locked;
logic sec_status, sec_lock, sec_unlock_req;
logic test_mode_en;
logic [255:0] test_mode_key;
logic test_mode_valid;
logic test_bypass;
logic boot_start, boot_complete;
logic boot_fail, boot_fw_valid;
logic [2:0] boot_state;
logic boot_abort;
logic isa_decoder_en, isa_decoder_lock;
logic bus_cmd_ready_m14;
logic bus_rsp_valid_m14;
logic [31:0] bus_rsp_data_m14;
logic bus_rsp_error_m14;
logic sec_irq;
logic [3:0] sec_irq_type;

// M15 JTAG signals
logic tdo, tdo_en;
logic test_access_grant, test_access_denied;
logic [3:0] scan_select;
logic scan_enable, scan_in, scan_out, scan_capture, scan_update;
logic bsr_select, bsr_capture, bsr_update;
logic [23:0] bsr_data_in, bsr_data_out;
logic [15:0] debug_addr;
logic [31:0] debug_data_in, debug_data_out;
logic debug_rw, debug_valid, debug_ack;
logic mbist_start, mbist_stop;
logic [1:0] mbist_target;
logic [3:0] mbist_algorithm;
logic [23:0] mbist_status;

// M16 ISA Interface signals
logic [15:0] ISA_IF;
logic ISA_VALID, ISA_DIR, ISA_READY;
logic [31:0] isa_data_sys;
logic isa_valid_sys, isa_ready_sys, isa_req_sys;
logic [31:0] isa_pc;
logic isa_access_grant, isa_access_denied, isa_crc_error;
logic [127:0] isa_auth_token;
logic error_cdc_timeout, error_invalid_opcode_m16, error_security, error_crc;

//=============================================================================
// Reset Generation
//=============================================================================
always_ff @(posedge clk_aon or negedge ext_rst_por_n)
    if(!ext_rst_por_n) {rst_sys_n,pg_main_en} <= '0;
    else if(pll_lock_ext&&pll_pwr_en) {rst_sys_n,pg_main_en} <= '1;

//=============================================================================
// Module Instantiations
//=============================================================================

// M06: Clock Manager
M06_ClockManager u_M06 (
    .ext_clk_i      (ext_clk_50MHz),
    .pll_lock_i     (pll_lock_ext),
    .dvfs_op_i      ('0),
    .dvfs_req_i     ('0),
    .clk_gating_en_i('0),
    .pd_aon_vdd_i   ('0),
    .clk_sys_o      (clk_sys),
    .clk_aon_o      (clk_aon),
    .clk_io_o       (clk_io),
    .clk_gating_o   (),
    .dvfs_ack_o     (),
    .clk_status_o   (),
    .pll_pwr_en_o   (pll_pwr_en)
);

// M05: Power Manager (PD_AON)
M05_PowerManager u_M05 (
    .clk_aon        (clk_aon),
    .rst_aon_n      (ext_rst_por_n),
    .rst_por_n      (ext_rst_por_n),
    .bus_cmd_valid  ('0),
    .bus_cmd_ready  (),
    .bus_cmd_addr   ('0),
    .bus_cmd_rw     ('0),
    .bus_cmd_data   ('0),
    .bus_rsp_valid  (),
    .bus_rsp_data   (),
    .bus_rsp_error  (),
    .dvfs_op_req    (dvfs_op_req),
    .dvfs_op_ack    ('0),
    .dvfs_vdd_req   (dvfs_vdd_req),
    .dvfs_freq_req  (dvfs_freq_req),
    .dvfs_busy      (),
    .vdd_main_set   (vdd_main_set),
    .vdd_main_ack   ('0),
    .vdd_main_ready ('0),
    .vdd_main_error ('0),
    .pg_main_en     (pg_main_en),  // Correct: output port is pg_main_en
    .pg_main_status ('0),
    .pg_main_switch (pg_main_switch),
    .pg_iso_en      (pg_iso_en),
    .pmode_state    (pmode_state),
    .pmode_req      ('0),
    .pmode_ack      (pmode_ack),
    .pmode_error    (pmode_error),
    .wakeup_ext     ('0),
    .wakeup_en      (wakeup_en),
    .wakeup_status  (wakeup_status),
    .wakeup_pending (wakeup_pending),
    .wakeup_clear   ('0),
    .pwr_estimate   (pwr_estimate),
    .pwr_budget     ('0),
    .pwr_alert      (pwr_alert),
    .pwr_counters   (pwr_counters),
    .activity_main  ('0),
    .activity_io    ('0),
    .activity_dram  ('0),
    .idle_timeout   ('0),
    .idle_detected  (idle_detected),
    .pm_status      (pm_status),
    .pm_irq         (pm_irq),
    .pm_irq_type    (pm_irq_type)
);

// M04: System Bus
M04_SystemBus u_M04 (
    .clk_sys        (clk_sys),
    .clk_io         (clk_io),
    .clk_aon        (clk_aon),
    .rst_por_n      (ext_rst_por_n),
    .rst_sys_n      (rst_sys_n),
    .bus_enable     (pg_main_en),
    .bus_busy       (bus_busy),
    .bus_error      (bus_error),
    .arb_winner     (arb_winner),
    .route_target   (route_target),
    .timeout_irq    (timeout_irq),
    .error_irq      (error_irq)
);

// M02: SRAM Scratchpad
M02_SRAMScratchpad u_M02 (
    .clk_sys_i      (clk_sys),
    .rst_sys_n_i    (rst_sys_n),
    .pg_main_en_i   (pg_main_en),
    .bus_cmd_valid_i('0),
    .bus_cmd_ready_o(bus_cmd_ready_m02),
    .bus_cmd_addr_i ('0),
    .bus_cmd_rw_i   ('0),
    .bus_cmd_width_i('0),
    .bus_cmd_wdata_i('0),
    .bus_cmd_wstrb_i('0),
    .bus_rsp_valid_o(bus_rsp_valid_m02),
    .bus_rsp_rdata_o(bus_rsp_rdata_m02),
    .bus_rsp_error_o(bus_rsp_error_m02),
    .sram_req_valid_i('0),
    .sram_req_addr_i('0),
    .sram_req_rw_i  ('0),
    .sram_req_wdata_i('0),
    .sram_req_wstrb_i('0),
    .sram_rsp_valid_o(sram_rsp_valid_m02),
    .sram_rsp_rdata_o(sram_rsp_rdata_m02),
    .sram_rsp_error_o(sram_rsp_error_m02)
);

// M03: DRAM Controller
M03_DRAMController u_M03 (
    .clk_sys_i      (clk_sys),
    .rst_sys_n_i    (rst_sys_n),
    .clk_d2d_i      (clk_sys),
    .clk_d2d_pll_i  (clk_sys),
    .bus_cmd_valid_i('0),
    .bus_cmd_ready_o(bus_cmd_ready_m03),
    .bus_cmd_addr_i ('0),
    .bus_cmd_rw_i   ('0),
    .bus_cmd_data_i ('0),
    .bus_cmd_mask_i ('0),
    .bus_rsp_valid_o(bus_rsp_valid_m03),
    .bus_rsp_data_o (bus_rsp_data_m03),
    .bus_rsp_error_o(bus_rsp_error_m03),
    .bus_rsp_latency_o(bus_rsp_latency_m03),
    .d2d_cmd_valid_o(d2d_cmd_valid),
    .d2d_cmd_ready_i('0),
    .d2d_cmd_addr_o (d2d_cmd_addr),
    .d2d_cmd_rw_o   (d2d_cmd_rw),
    .d2d_cmd_burst_o(d2d_cmd_burst),
    .d2d_wdata_valid_o(d2d_wdata_valid),
    .d2d_wdata_o    (d2d_wdata),
    .d2d_wdata_last_o(d2d_wdata_last),
    .d2d_rdata_valid_i('0),
    .d2d_rdata_i    ('0),
    .d2d_rdata_last_i('0),
    .d2d_rdata_error_i('0),
    .d2d_tx_data_o  (d2d_tx_data),
    .d2d_tx_clk_o   (d2d_tx_clk),
    .d2d_rx_data_i  ('0),
    .d2d_rx_clk_i   ('0),
    .d2d_pll_lock_i ('0),
    .ecc_err_addr_o (ecc_err_addr),
    .ecc_err_type_o (ecc_err_type),
    .ecc_err_valid_o(ecc_err_valid),
    .ecc_err_clear_i('0),
    .ecc_corrected_o(ecc_corrected),
    .bw_request_i   ('0),
    .bw_grant_o     (bw_grant),
    .bw_priority_i  ('0),
    .bw_status_o    (bw_status),
    .dram_active_o  (dram_active),
    .dram_idle_o    (dram_idle),
    .dram_power_mode_i('0),
    .dram_self_refresh_req_i('0),
    .dram_self_refresh_ack_o(dram_self_refresh_ack),
    .dram_status_o  (dram_status),
    .dram_irq_o     (dram_irq),
    .dram_irq_type_o(dram_irq_type)
);

// M00: Systolic Array
M00_SystolicArray u_M00 (
    .clk_i          (clk_sys),
    .rst_ni         (rst_sys_n),
    .pe_mode_i      ('0),
    .pe_precision_i ('0),
    .pe_start_i     ('0),
    .pe_done_o      (pe_done),
    .pe_row_cnt_i   ('0),
    .pe_col_cnt_i   ('0),
    .weight_in_i    ('0),
    .input_in_i     ('0),
    .output_out_o   (output_out),
    .partial_out_o  (partial_out),
    .weight_addr_i  ('0),
    .input_addr_i   ('0),
    .output_addr_i  ('0),
    .fp8_format_i   ('0),
    .round_mode_i   ('0),
    .saturation_i   ('0),
    .mix_precision_en_i('0),
    .pe_k_cnt_i     ('0),
    .pe_size_error_o(pe_size_error),
    .pe_size_error_code_o(pe_size_error_code)
);

// M01: Dataflow Controller
M01_DataflowController u_M01 (
    .clk_sys        (clk_sys),
    .rst_sys_n      (rst_sys_n),
    .syst_mode      ('0),
    .syst_precision ('0),
    .syst_start     ('0),
    .syst_done      ('0),
    .syst_err       ('0),
    .syst_row_cnt   ('0),
    .syst_col_cnt   ('0),
    .syst_src_addr  ('0),
    .syst_dst_addr  ('0),
    .syst_shape     ('0),
    .op_valid       ('0),
    .op_ready       ('0),
    .op_code        ('0),
    .op_unit_sel    ('0),
    .op_tid         ('0),
    .op_precision   ('0),
    .op_src_addr    ('0),
    .op_dst_addr    ('0),
    .op_params      ('0),
    .op_done        ('0),
    .op_err         ('0),
    .mem_req_valid  ('0),
    .mem_req_ready  ('0),
    .mem_req_type   ('0),
    .mem_req_addr   ('0),
    .mem_req_size   ('0),
    .mem_req_tid    ('0),
    .mem_resp_valid ('0),
    .mem_resp_data  ('0),
    .mem_resp_last  ('0),
    .mem_resp_err   ('0),
    .sched_thread_en('0),
    .sched_priority ('0),
    .sched_yield    (sched_yield),
    .sched_current_tid(sched_current_tid),
    .sched_status   (sched_status),
    .irq_op_done    (irq_op_done),
    .irq_err        (irq_err),
    .irq_tid        (irq_tid),
    .reg_addr       ('0),
    .reg_wdata      ('0),
    .reg_write      ('0),
    .reg_read       ('0),
    .reg_rdata      (reg_rdata),
    .start_en       ('0),
    .soft_reset     ('0)
);

assign irq_compute_done = irq_op_done;

// M08: Thread Scheduler
M08_ThreadScheduler u_M08 (
    .clk_sys        (clk_sys),
    .rst_sys_n      (rst_sys_n),
    .rst_por_n      (ext_rst_por_n),
    .clk_enable     ('0),
    .power_gate_n   (pg_main_en),
    .thread_cmd_valid('0),
    .thread_cmd_ready(thread_cmd_ready),
    .thread_cmd_opcode('0),
    .thread_cmd_thread_id('0),
    .thread_cmd_priority('0),
    .thread_cmd_addr('0),
    .thread_cmd_data('0),
    .reg_req_valid  ('0),
    .reg_req_ready  (reg_req_ready),
    .reg_req_addr   ('0),
    .reg_req_rw     ('0),
    .reg_req_data   ('0),
    .reg_rsp_valid  (reg_rsp_valid),
    .reg_rsp_data   (reg_rsp_data),
    .reg_rsp_error  (reg_rsp_error),
    .dispatch_valid (dispatch_valid),
    .dispatch_ready ('0),
    .dispatch_thread_id(dispatch_thread_id),
    .dispatch_entry_addr(dispatch_entry_addr),
    .dispatch_context_ptr(dispatch_context_ptr),
    .dispatch_cmd   (dispatch_cmd),
    .dispatch_done  ('0),
    .dispatch_error ('0),
    .ctx_rd_valid   (ctx_rd_valid),
    .ctx_rd_ready   ('0),
    .ctx_rd_ptr     (ctx_rd_ptr),
    .ctx_rd_data    ('0),
    .ctx_wr_valid   (ctx_wr_valid),
    .ctx_wr_ready   ('0),
    .ctx_wr_ptr     (ctx_wr_ptr),
    .ctx_wr_data    (ctx_wr_data),
    .thread_active_id(thread_active_id),
    .thread_active_state(thread_active_state),
    .thread_pending_cnt(thread_pending_cnt),
    .thread_blocked_cnt(thread_blocked_cnt),
    .thread_irq     (thread_irq),
    .thread_irq_id  (thread_irq_id),
    .thread_irq_type(thread_irq_type),
    .sched_status_ready(sched_status_ready),
    .sched_status_busy(sched_status_busy),
    .sched_status_ctx_switch(sched_status_ctx_switch),
    .sched_status_error(sched_status_error)
);

// M09: Attention Unit
M09_AttentionUnit u_M09 (
    .clk_sys_i      (clk_sys),
    .rst_sys_n_i    (rst_sys_n),
    .pg_main_en_i   (pg_main_en),
    .act_valid_i    ('0),
    .act_data_i     ('0),
    .act_pos_i      ('0),
    .act_layer_i    ('0),
    .act_ready_o    (act_ready),
    .q_valid_i      ('0),
    .q_data_i       ('0),
    .k_valid_i      ('0),
    .k_data_i       ('0),
    .v_valid_i      ('0),
    .v_data_i       ('0),
    .qkv_ready_o    (qkv_ready),
    .kv_addr_o      (kv_addr),
    .kv_wdata_o     (kv_wdata),
    .kv_wen_o       (kv_wen),
    .kv_rdata_i     ('0),
    .kv_valid_o     (kv_valid),
    .kv_ready_i     ('0),
    .sa_cmd_valid_o (sa_cmd_valid),
    .sa_cmd_ready_i ('0),
    .sa_op_o        (sa_op),
    .sa_head_o      (sa_head),
    .sa_pos_o       (sa_pos),
    .sa_result_valid_i('0),
    .sa_result_data_i('0),
    .sa_result_ready_o(sa_result_ready),
    .sm_valid_o     (sm_valid),
    .sm_data_o      (sm_data),
    .sm_head_o      (sm_head),
    .sm_ready_i     ('0),
    .out_valid_o    (out_valid),
    .out_data_o     (out_data),
    .out_layer_o    (out_layer),
    .attn_done_o    (attn_done),
    .attn_busy_o    (attn_busy),
    .kv_overflow_o  (kv_overflow)
);

// M10: FFN/MatMul
M10_FFNMatMul u_M10 (
    .clk            (clk_sys),
    .rst_n          (rst_sys_n),
    .enable         ('0),
    .start          ('0),
    .mode           ('0),
    .busy           (ffn_busy),
    .done           (ffn_done),
    .error          (ffn_error),
    .error_code     (ffn_error_code),
    .x_in           ('0),
    .x_valid        ('0),
    .x_ready        (ffn_x_ready),
    .y_out          (ffn_y_out),
    .y_valid        (ffn_y_valid),
    .y_ready        ('0),
    .s_dim          ('0),
    .w_base         ('0),
    .w1_offset      ('0),
    .w3_offset      ('0),
    .w2_offset      ('0)
);

// M11: RMSNorm/RoPE
M11_RMSNormRoPE u_M11 (
    .clk_sys_i      (clk_sys),
    .rst_sys_n_i    (rst_sys_n),
    .pg_main_en_i   (pg_main_en),
    .sram_req_valid_o(sram_req_valid),
    .sram_req_addr_o(sram_req_addr),
    .sram_req_rw_o  (sram_req_rw),
    .sram_req_wdata_o(sram_req_wdata),
    .sram_req_wstrb_o(sram_req_wstrb),
    .sram_rsp_valid_i('0),
    .sram_rsp_rdata_i('0),
    .sram_rsp_error_i('0),
    .op_start_i     ('0),
    .op_type_i      ('0),
    .op_mode_i      ('0),
    .op_dim_i       ('0),
    .op_head_size_i ('0),
    .op_pos_i       ('0),
    .op_precision_i ('0),
    .op_done_o      (op_done_m11),
    .op_busy_o      (op_busy_m11),
    .op_error_o     (op_error_m11),
    .data_in_valid_i('0),
    .data_in_addr_i ('0),
    .data_in_size_i ('0),
    .weight_addr_i  ('0),
    .data_out_valid_o(data_out_valid),
    .data_out_addr_o(data_out_addr),
    .data_out_addr_i('0),
    .data_out_size_o(data_out_size),
    .data_out_done_o(data_out_done),
    .rope_table_addr_i('0),
    .rope_table_size_i('0),
    .rope_table_en_i('0),
    .op_status_o    (op_status),
    .op_irq_o       (op_irq),
    .op_irq_type_o  (op_irq_type),
    .cycle_count_o  (cycle_count)
);

// M12: SoftMax
M12_SoftMax u_M12 (
    .clk_sys        (clk_sys),
    .rst_sys_n      (rst_sys_n),
    .score_valid    ('0),
    .score_ready    (score_ready),
    .score_data     ('0),
    .score_len      ('0),
    .prob_valid     (prob_valid),
    .prob_ready     ('0),
    .prob_data      (prob_data),
    .prob_len       (prob_len),
    .softmax_start  ('0),
    .softmax_busy   (softmax_busy),
    .softmax_done   (softmax_done),
    .softmax_error  (softmax_error)
);

// M13: ISA Decoder
M13_ISADecoder u_M13 (
    .clk_sys_i      (clk_sys),
    .rst_sys_n_i    (rst_sys_n),
    .pg_main_en_i   (pg_main_en),
    .isa_inst_valid_i('0),
    .isa_inst_data_i('0),
    .isa_inst_ready_o(isa_inst_ready),
    .isa_pc_i       ('0),
    .isa_pc_update_o(isa_pc_update),
    .dec_valid_o    (dec_valid),
    .dec_opcode_o   (dec_opcode),
    .dec_format_o   (dec_format),
    .dec_vd_o       (dec_vd),
    .dec_vs1_o      (dec_vs1),
    .dec_vs2_o      (dec_vs2),
    .dec_vs3_o      (dec_vs3),
    .dec_sd_o       (dec_sd),
    .dec_imm16_o    (dec_imm16),
    .dec_imm21_o    (dec_imm21),
    .dec_base_o     (dec_base),
    .dec_offset_o   (dec_offset),
    .dec_func_o     (dec_func),
    .op_valid_o     (op_valid_m13),
    .op_target_o    (op_target),
    .op_ready_i     ('0),
    .op_start_o     (op_start),
    .op_done_i      ('0),
    .sa_cmd_valid_o (sa_cmd_valid_m13),
    .sa_op_o        (sa_op_m13),
    .sa_ready_i     ('0),
    .mem_addr_o     (mem_addr),
    .mem_wen_o      (mem_wen),
    .mem_valid_o    (mem_valid),
    .mem_ready_i    ('0),
    .sec_valid_i    ('0),
    .sec_en_i       ('0),
    .sched_start_i  ('0),
    .sched_pause_i  ('0),
    .sched_abort_i  ('0),
    .dec_done_o     (dec_done),
    .dec_busy_o     (dec_busy),
    .error_invalid_opcode_o(error_invalid_opcode),
    .error_invalid_format_o(error_invalid_format),
    .error_invalid_reg_o(error_invalid_reg),
    .error_secure_boot_fail_o(error_sec_boot_fail)
);

// M14: Secure Boot
M14_SecureBoot u_M14 (
    .clk_sys        (clk_sys),
    .rst_sys_n      (rst_sys_n),
    .rst_por_n      (ext_rst_por_n),
    .fw_addr        ('0),
    .fw_size        ('0),
    .fw_data_req    (fw_data_req),
    .fw_data_addr   (fw_data_addr),
    .fw_data_valid  ('0),
    .fw_data        ('0),
    .fw_data_last   ('0),
    .sig_r          ('0),
    .sig_s          ('0),
    .sig_valid      ('0),
    .otp_key_addr   (otp_key_addr),
    .otp_key_data   ('0),
    .otp_key_valid  ('0),
    .otp_read_ack   ('0),
    .otp_read_req   (otp_read_req),
    .otp_locked     ('0),
    .sec_boot_en    ('0),
    .sec_status     (sec_status),
    .sec_lock       (sec_lock),
    .sec_unlock_req ('0),
    .test_mode_en   ('0),
    .test_mode_key  ('0),
    .test_mode_valid('0),
    .test_bypass    (test_bypass),
    .boot_start     ('0),
    .boot_complete  (sec_boot_done),  // Correct: port is boot_complete
    .boot_fail      (sec_boot_fail),
    .boot_fw_valid  (boot_fw_valid),
    .boot_state     (boot_state),
    .boot_abort     ('0),
    .isa_decoder_en (isa_decoder_en),
    .isa_decoder_lock(isa_decoder_lock),
    .bus_cmd_valid  ('0),
    .bus_cmd_ready  (bus_cmd_ready_m14),
    .bus_cmd_addr   ('0),
    .bus_cmd_rw     ('0),
    .bus_cmd_data   ('0),
    .bus_rsp_valid  (bus_rsp_valid_m14),
    .bus_rsp_data   (bus_rsp_data_m14),
    .bus_rsp_error  (bus_rsp_error_m14),
    .sec_irq        (sec_irq),
    .sec_irq_type   (sec_irq_type)
);

assign status_sec_boot_done = sec_boot_done;
assign sec_lockdown = sec_lock;

// M15: JTAG Interface
M15_JTAGInterface u_M15 (
    .tck            ('0),
    .tms            ('0),
    .tdi            ('0),
    .tdo            (tdo),
    .trst_n         (ext_rst_por_n),
    .tdo_en         (tdo_en),
    .test_mode_en   ('0),
    .test_mode_valid(sec_boot_done),
    .sec_boot_en    (sec_boot_done),
    .test_access_grant(test_access_grant),
    .test_access_denied(test_access_denied),
    .scan_select    (scan_select),
    .scan_enable    (scan_enable),
    .scan_in        (scan_in),
    .scan_out       (scan_out),
    .scan_capture   (scan_capture),
    .scan_update    (scan_update),
    .bsr_select     (bsr_select),
    .bsr_capture    (bsr_capture),
    .bsr_update     (bsr_update),
    .bsr_data_in    ('0),
    .bsr_data_out   (bsr_data_out),
    .debug_addr     (debug_addr),
    .debug_data_in  (debug_data_in),
    .debug_data_out (debug_data_out),
    .debug_rw       (debug_rw),
    .debug_valid    (debug_valid),
    .debug_ack      ('0),
    .mbist_start    (mbist_start),
    .mbist_stop     (mbist_stop),
    .mbist_target   (mbist_target),
    .mbist_algorithm(mbist_algorithm),
    .mbist_status   ('0),
    .rst_io_n       (rst_sys_n)
);

// M16: ISA Interface
M16_ISAInterface u_M16 (
    .ISA_IF         (ISA_IF),
    .ISA_CLK        (clk_io),
    .ISA_VALID      (ISA_VALID),
    .ISA_DIR        (ISA_DIR),
    .ISA_READY      ('0),
    .isa_data_sys_o (isa_data_sys),
    .isa_valid_sys_o(isa_valid_sys),
    .isa_ready_sys_i('0),
    .isa_req_sys_o  (isa_req_sys),
    .isa_pc_o       (isa_pc),
    .m16_reset_n_i  (rst_sys_n),
    .m16_enable_i   ('0),
    .m16_mode_i     ('0),
    .sec_boot_done_i(sec_boot_done),
    .sec_status_pass_i(sec_boot_done),
    .sec_status_fail_i(sec_boot_fail),
    .sec_lockdown_i (sec_lockdown),
    .isa_access_grant_o(isa_access_grant),
    .isa_access_denied_o(isa_access_denied),
    .isa_crc_error_o(isa_crc_error),
    .isa_auth_token_i('0),
    .clk_sys_i      (clk_sys),
    .rst_sys_n_i    (rst_sys_n),
    .error_cdc_timeout_o(error_cdc_timeout),
    .error_invalid_opcode_o(error_invalid_opcode_m16),
    .error_security_o(error_security),
    .error_crc_o    (error_crc)
);

endmodule