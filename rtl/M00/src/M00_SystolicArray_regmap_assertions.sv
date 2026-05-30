//==============================================================================
// Module: M00_SystolicArray_regmap_assertions
//
// SPEC HEADER
// ─────────────────────────────────────────────────────────────────────────────
// Source:       spec/MAS/M00_SystolicArray/regmap.md
// Version:      1.0
// Status:       AUTO-GENERATED
// Spec Hash:    sha256:40d48df8c266  ← Run: uv run scripts/compute_spec_hash.py spec/MAS/M00_SystolicArray/regmap.md --inject <this_file>
// Generated:    2026-05-30 16:30:21
//
// Purpose:
//   SVA assertions for M00_SystolicArray register map (reset, RO, W1C, reserved, addr range)
//
// Traceability:
//   REGMAP: spec/MAS/M00_SystolicArray/regmap.md
//==============================================================================

module M00_SystolicArray_regmap_assertions (
    input  logic        clk,
    input  logic        rst_n,
    input  logic [31:0] addr,
    input  logic        sel,
    input  logic        enable,
    input  logic        write,
    input  logic [31:0] wdata,
    input  logic [31:0] rdata,
    input  logic [31:0] SA_CTRL_reg,
    input  logic [31:0] SA_STATUS_reg,
    input  logic [31:0] SA_DIM_CFG_reg,
    input  logic [31:0] SA_PERF_CNT_reg
);

    // ══ SA_CTRL (0x00) ════════════════════════════════════════

    // @verifies REQ-M00-R001
    // @spec_ref MAS/M00_SystolicArray/regmap.md §1
    // @constraint SA_CTRL 复位值必须为 0x0
    property p_sa_ctrl_reset;
        @(posedge clk)
        $rose(rst_n) |-> (SA_CTRL_reg == 32'h00000000);
    endproperty
    assert property (p_sa_ctrl_reset)
        else $error("[REGMAP §1] SA_CTRL reset value violation: %h", SA_CTRL_reg);

    // @verifies REQ-M00-R001
    // @spec_ref MAS/M00_SystolicArray/regmap.md §2
    // @constraint SA_CTRL.RESERVED[7:5] 保留位，写入被忽略
    property p_sa_ctrl_reserved_7_5_reserved;
        @(posedge clk) disable iff (!rst_n)
        (sel && enable && write && addr == 32'h00000000)
        |-> (SA_CTRL_reg[7:5] == $past(SA_CTRL_reg[7:5]));
    endproperty
    assert property (p_sa_ctrl_reserved_7_5_reserved);

    // @verifies REQ-M00-R001
    // @spec_ref MAS/M00_SystolicArray/regmap.md §2
    // @constraint SA_CTRL.RESERVED[31:8] 保留位，写入被忽略
    property p_sa_ctrl_reserved_31_8_reserved;
        @(posedge clk) disable iff (!rst_n)
        (sel && enable && write && addr == 32'h00000000)
        |-> (SA_CTRL_reg[31:8] == $past(SA_CTRL_reg[31:8]));
    endproperty
    assert property (p_sa_ctrl_reserved_31_8_reserved);

    // ══ SA_STATUS (0x04) ════════════════════════════════════════

    // @verifies REQ-M00-R002
    // @spec_ref MAS/M00_SystolicArray/regmap.md §1
    // @constraint SA_STATUS 复位值必须为 0x0
    property p_sa_status_reset;
        @(posedge clk)
        $rose(rst_n) |-> (SA_STATUS_reg == 32'h00000000);
    endproperty
    assert property (p_sa_status_reset)
        else $error("[REGMAP §1] SA_STATUS reset value violation: %h", SA_STATUS_reg);

    // @verifies REQ-M00-R002
    // @spec_ref MAS/M00_SystolicArray/regmap.md §1
    // @constraint SA_STATUS 是只读寄存器，写操作无效
    property p_sa_status_readonly;
        @(posedge clk) disable iff (!rst_n)
        (sel && enable && write && addr == 32'h00000004)
        |-> (SA_STATUS_reg == $past(SA_STATUS_reg));
    endproperty
    assert property (p_sa_status_readonly)
        else $error("[REGMAP §1] SA_STATUS write attempted (read-only)");

    // @verifies REQ-M00-R002
    // @spec_ref MAS/M00_SystolicArray/regmap.md §2
    // @constraint SA_STATUS.RESERVED[31:8] 保留位，写入被忽略
    property p_sa_status_reserved_31_8_reserved;
        @(posedge clk) disable iff (!rst_n)
        (sel && enable && write && addr == 32'h00000004)
        |-> (SA_STATUS_reg[31:8] == $past(SA_STATUS_reg[31:8]));
    endproperty
    assert property (p_sa_status_reserved_31_8_reserved);

    // ══ SA_DIM_CFG (0x08) ════════════════════════════════════════

    // @verifies REQ-M00-R003
    // @spec_ref MAS/M00_SystolicArray/regmap.md §1
    // @constraint SA_DIM_CFG 复位值必须为 0x0
    property p_sa_dim_cfg_reset;
        @(posedge clk)
        $rose(rst_n) |-> (SA_DIM_CFG_reg == 32'h00000000);
    endproperty
    assert property (p_sa_dim_cfg_reset)
        else $error("[REGMAP §1] SA_DIM_CFG reset value violation: %h", SA_DIM_CFG_reg);

    // @verifies REQ-M00-R003
    // @spec_ref MAS/M00_SystolicArray/regmap.md §2
    // @constraint SA_DIM_CFG.RESERVED[31:20] 保留位，写入被忽略
    property p_sa_dim_cfg_reserved_31_20_reserved;
        @(posedge clk) disable iff (!rst_n)
        (sel && enable && write && addr == 32'h00000008)
        |-> (SA_DIM_CFG_reg[31:20] == $past(SA_DIM_CFG_reg[31:20]));
    endproperty
    assert property (p_sa_dim_cfg_reserved_31_20_reserved);

    // ══ SA_PERF_CNT (0x0C) ════════════════════════════════════════

    // @verifies REQ-M00-R004
    // @spec_ref MAS/M00_SystolicArray/regmap.md §1
    // @constraint SA_PERF_CNT 复位值必须为 0x0
    property p_sa_perf_cnt_reset;
        @(posedge clk)
        $rose(rst_n) |-> (SA_PERF_CNT_reg == 32'h00000000);
    endproperty
    assert property (p_sa_perf_cnt_reset)
        else $error("[REGMAP §1] SA_PERF_CNT reset value violation: %h", SA_PERF_CNT_reg);

    // @verifies REQ-M00-R004
    // @spec_ref MAS/M00_SystolicArray/regmap.md §1
    // @constraint SA_PERF_CNT 是只读寄存器，写操作无效
    property p_sa_perf_cnt_readonly;
        @(posedge clk) disable iff (!rst_n)
        (sel && enable && write && addr == 32'h0000000C)
        |-> (SA_PERF_CNT_reg == $past(SA_PERF_CNT_reg));
    endproperty
    assert property (p_sa_perf_cnt_readonly)
        else $error("[REGMAP §1] SA_PERF_CNT write attempted (read-only)");

    // ══ Address Range ════════════════════════════════════════════════════
    //
    // @verifies REQ-SYS-ADDR
    // @spec_ref ARCH/memory_map.md §2
    // @constraint 访问地址必须在有效范围内 (0x00 ~ 0x0C)
    property p_addr_range;
        @(posedge clk) disable iff (!rst_n)
        (sel && enable)
        |-> (addr <= 32'h0000000C);
    endproperty
    assert property (p_addr_range)
        else $error("[SPEC §2] Address out of range: 0x%h", addr);

endmodule
