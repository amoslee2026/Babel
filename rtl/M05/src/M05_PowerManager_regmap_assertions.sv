//==============================================================================
// Module: M05_PowerManager_regmap_assertions
//
// SPEC HEADER
// ─────────────────────────────────────────────────────────────────────────────
// Source:       spec/MAS/M05_PowerManager/regmap.md
// Version:      1.0
// Status:       AUTO-GENERATED
// Spec Hash:    sha256:b04a03e91656  ← Run: uv run scripts/compute_spec_hash.py spec/MAS/M05_PowerManager/regmap.md --inject <this_file>
// Generated:    2026-05-30 16:30:21
//
// Purpose:
//   SVA assertions for M05_PowerManager register map (reset, RO, W1C, reserved, addr range)
//
// Traceability:
//   REGMAP: spec/MAS/M05_PowerManager/regmap.md
//==============================================================================

module M05_PowerManager_regmap_assertions (
    input  logic        clk,
    input  logic        rst_n,
    input  logic [31:0] addr,
    input  logic        sel,
    input  logic        enable,
    input  logic        write,
    input  logic [31:0] wdata,
    input  logic [31:0] rdata,
    input  logic [31:0] PWR_CTRL_reg,
    input  logic [31:0] DVFS_CFG_reg,
    input  logic [31:0] PWR_STATUS_reg
);

    // ══ PWR_CTRL (0x00) ════════════════════════════════════════

    // @verifies REQ-M05-R001
    // @spec_ref MAS/M05_PowerManager/regmap.md §1
    // @constraint PWR_CTRL 复位值必须为 0x0
    property p_pwr_ctrl_reset;
        @(posedge clk)
        $rose(rst_n) |-> (PWR_CTRL_reg == 32'h00000000);
    endproperty
    assert property (p_pwr_ctrl_reset)
        else $error("[REGMAP §1] PWR_CTRL reset value violation: %h", PWR_CTRL_reg);

    // @verifies REQ-M05-R001
    // @spec_ref MAS/M05_PowerManager/regmap.md §2
    // @constraint PWR_CTRL.RESERVED[7:4] 保留位，写入被忽略
    property p_pwr_ctrl_reserved_7_4_reserved;
        @(posedge clk) disable iff (!rst_n)
        (sel && enable && write && addr == 32'h00000000)
        |-> (PWR_CTRL_reg[7:4] == $past(PWR_CTRL_reg[7:4]));
    endproperty
    assert property (p_pwr_ctrl_reserved_7_4_reserved);

    // @verifies REQ-M05-R001
    // @spec_ref MAS/M05_PowerManager/regmap.md §2
    // @constraint PWR_CTRL.RESERVED[31:8] 保留位，写入被忽略
    property p_pwr_ctrl_reserved_31_8_reserved;
        @(posedge clk) disable iff (!rst_n)
        (sel && enable && write && addr == 32'h00000000)
        |-> (PWR_CTRL_reg[31:8] == $past(PWR_CTRL_reg[31:8]));
    endproperty
    assert property (p_pwr_ctrl_reserved_31_8_reserved);

    // ══ DVFS_CFG (0x04) ════════════════════════════════════════

    // @verifies REQ-M05-R002
    // @spec_ref MAS/M05_PowerManager/regmap.md §1
    // @constraint DVFS_CFG 复位值必须为 0x810
    property p_dvfs_cfg_reset;
        @(posedge clk)
        $rose(rst_n) |-> (DVFS_CFG_reg == 32'h00000810);
    endproperty
    assert property (p_dvfs_cfg_reset)
        else $error("[REGMAP §1] DVFS_CFG reset value violation: %h", DVFS_CFG_reg);

    // @verifies REQ-M05-R002
    // @spec_ref MAS/M05_PowerManager/regmap.md §2
    // @constraint DVFS_CFG.RESERVED[31:18] 保留位，写入被忽略
    property p_dvfs_cfg_reserved_31_18_reserved;
        @(posedge clk) disable iff (!rst_n)
        (sel && enable && write && addr == 32'h00000004)
        |-> (DVFS_CFG_reg[31:18] == $past(DVFS_CFG_reg[31:18]));
    endproperty
    assert property (p_dvfs_cfg_reserved_31_18_reserved);

    // ══ PWR_STATUS (0x08) ════════════════════════════════════════

    // @verifies REQ-M05-R003
    // @spec_ref MAS/M05_PowerManager/regmap.md §1
    // @constraint PWR_STATUS 复位值必须为 0x0
    property p_pwr_status_reset;
        @(posedge clk)
        $rose(rst_n) |-> (PWR_STATUS_reg == 32'h00000000);
    endproperty
    assert property (p_pwr_status_reset)
        else $error("[REGMAP §1] PWR_STATUS reset value violation: %h", PWR_STATUS_reg);

    // @verifies REQ-M05-R003
    // @spec_ref MAS/M05_PowerManager/regmap.md §1
    // @constraint PWR_STATUS 是只读寄存器，写操作无效
    property p_pwr_status_readonly;
        @(posedge clk) disable iff (!rst_n)
        (sel && enable && write && addr == 32'h00000008)
        |-> (PWR_STATUS_reg == $past(PWR_STATUS_reg));
    endproperty
    assert property (p_pwr_status_readonly)
        else $error("[REGMAP §1] PWR_STATUS write attempted (read-only)");

    // @verifies REQ-M05-R003
    // @spec_ref MAS/M05_PowerManager/regmap.md §2
    // @constraint PWR_STATUS.RESERVED[7:6] 保留位，写入被忽略
    property p_pwr_status_reserved_7_6_reserved;
        @(posedge clk) disable iff (!rst_n)
        (sel && enable && write && addr == 32'h00000008)
        |-> (PWR_STATUS_reg[7:6] == $past(PWR_STATUS_reg[7:6]));
    endproperty
    assert property (p_pwr_status_reserved_7_6_reserved);

    // @verifies REQ-M05-R003
    // @spec_ref MAS/M05_PowerManager/regmap.md §2
    // @constraint PWR_STATUS.RESERVED[31:8] 保留位，写入被忽略
    property p_pwr_status_reserved_31_8_reserved;
        @(posedge clk) disable iff (!rst_n)
        (sel && enable && write && addr == 32'h00000008)
        |-> (PWR_STATUS_reg[31:8] == $past(PWR_STATUS_reg[31:8]));
    endproperty
    assert property (p_pwr_status_reserved_31_8_reserved);

    // ══ Address Range ════════════════════════════════════════════════════
    //
    // @verifies REQ-SYS-ADDR
    // @spec_ref ARCH/memory_map.md §2
    // @constraint 访问地址必须在有效范围内 (0x00 ~ 0x08)
    property p_addr_range;
        @(posedge clk) disable iff (!rst_n)
        (sel && enable)
        |-> (addr <= 32'h00000008);
    endproperty
    assert property (p_addr_range)
        else $error("[SPEC §2] Address out of range: 0x%h", addr);

endmodule
