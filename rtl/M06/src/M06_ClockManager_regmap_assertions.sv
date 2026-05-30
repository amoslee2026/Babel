//==============================================================================
// Module: M06_ClockManager_regmap_assertions
//
// SPEC HEADER
// ─────────────────────────────────────────────────────────────────────────────
// Source:       spec/MAS/M06_ClockManager/regmap.md
// Version:      1.0
// Status:       AUTO-GENERATED
// Spec Hash:    sha256:eefa1152b74a  ← Run: uv run scripts/compute_spec_hash.py spec/MAS/M06_ClockManager/regmap.md --inject <this_file>
// Generated:    2026-05-30 16:30:21
//
// Purpose:
//   SVA assertions for M06_ClockManager register map (reset, RO, W1C, reserved, addr range)
//
// Traceability:
//   REGMAP: spec/MAS/M06_ClockManager/regmap.md
//==============================================================================

module M06_ClockManager_regmap_assertions (
    input  logic        clk,
    input  logic        rst_n,
    input  logic [31:0] addr,
    input  logic        sel,
    input  logic        enable,
    input  logic        write,
    input  logic [31:0] wdata,
    input  logic [31:0] rdata,
    input  logic [31:0] CLK_CTRL_reg,
    input  logic [31:0] PLL_CFG_reg,
    input  logic [31:0] CLK_STATUS_reg
);

    // ══ CLK_CTRL (0x00) ════════════════════════════════════════

    // @verifies REQ-M06-R001
    // @spec_ref MAS/M06_ClockManager/regmap.md §1
    // @constraint CLK_CTRL 复位值必须为 0x0
    property p_clk_ctrl_reset;
        @(posedge clk)
        $rose(rst_n) |-> (CLK_CTRL_reg == 32'h00000000);
    endproperty
    assert property (p_clk_ctrl_reset)
        else $error("[REGMAP §1] CLK_CTRL reset value violation: %h", CLK_CTRL_reg);

    // @verifies REQ-M06-R001
    // @spec_ref MAS/M06_ClockManager/regmap.md §2
    // @constraint CLK_CTRL.RESERVED[7:2] 保留位，写入被忽略
    property p_clk_ctrl_reserved_7_2_reserved;
        @(posedge clk) disable iff (!rst_n)
        (sel && enable && write && addr == 32'h00000000)
        |-> (CLK_CTRL_reg[7:2] == $past(CLK_CTRL_reg[7:2]));
    endproperty
    assert property (p_clk_ctrl_reserved_7_2_reserved);

    // @verifies REQ-M06-R001
    // @spec_ref MAS/M06_ClockManager/regmap.md §2
    // @constraint CLK_CTRL.RESERVED[31:8] 保留位，写入被忽略
    property p_clk_ctrl_reserved_31_8_reserved;
        @(posedge clk) disable iff (!rst_n)
        (sel && enable && write && addr == 32'h00000000)
        |-> (CLK_CTRL_reg[31:8] == $past(CLK_CTRL_reg[31:8]));
    endproperty
    assert property (p_clk_ctrl_reserved_31_8_reserved);

    // ══ PLL_CFG (0x04) ════════════════════════════════════════

    // @verifies REQ-M06-R002
    // @spec_ref MAS/M06_ClockManager/regmap.md §1
    // @constraint PLL_CFG 复位值必须为 0x103D09
    property p_pll_cfg_reset;
        @(posedge clk)
        $rose(rst_n) |-> (PLL_CFG_reg == 32'h00103D09);
    endproperty
    assert property (p_pll_cfg_reset)
        else $error("[REGMAP §1] PLL_CFG reset value violation: %h", PLL_CFG_reg);

    // @verifies REQ-M06-R002
    // @spec_ref MAS/M06_ClockManager/regmap.md §2
    // @constraint PLL_CFG.RESERVED[31:24] 保留位，写入被忽略
    property p_pll_cfg_reserved_31_24_reserved;
        @(posedge clk) disable iff (!rst_n)
        (sel && enable && write && addr == 32'h00000004)
        |-> (PLL_CFG_reg[31:24] == $past(PLL_CFG_reg[31:24]));
    endproperty
    assert property (p_pll_cfg_reserved_31_24_reserved);

    // ══ CLK_STATUS (0x08) ════════════════════════════════════════

    // @verifies REQ-M06-R003
    // @spec_ref MAS/M06_ClockManager/regmap.md §1
    // @constraint CLK_STATUS 复位值必须为 0x0
    property p_clk_status_reset;
        @(posedge clk)
        $rose(rst_n) |-> (CLK_STATUS_reg == 32'h00000000);
    endproperty
    assert property (p_clk_status_reset)
        else $error("[REGMAP §1] CLK_STATUS reset value violation: %h", CLK_STATUS_reg);

    // @verifies REQ-M06-R003
    // @spec_ref MAS/M06_ClockManager/regmap.md §1
    // @constraint CLK_STATUS 是只读寄存器，写操作无效
    property p_clk_status_readonly;
        @(posedge clk) disable iff (!rst_n)
        (sel && enable && write && addr == 32'h00000008)
        |-> (CLK_STATUS_reg == $past(CLK_STATUS_reg));
    endproperty
    assert property (p_clk_status_readonly)
        else $error("[REGMAP §1] CLK_STATUS write attempted (read-only)");

    // @verifies REQ-M06-R003
    // @spec_ref MAS/M06_ClockManager/regmap.md §2
    // @constraint CLK_STATUS.RESERVED[7:2] 保留位，写入被忽略
    property p_clk_status_reserved_7_2_reserved;
        @(posedge clk) disable iff (!rst_n)
        (sel && enable && write && addr == 32'h00000008)
        |-> (CLK_STATUS_reg[7:2] == $past(CLK_STATUS_reg[7:2]));
    endproperty
    assert property (p_clk_status_reserved_7_2_reserved);

    // @verifies REQ-M06-R003
    // @spec_ref MAS/M06_ClockManager/regmap.md §2
    // @constraint CLK_STATUS.RESERVED[31:8] 保留位，写入被忽略
    property p_clk_status_reserved_31_8_reserved;
        @(posedge clk) disable iff (!rst_n)
        (sel && enable && write && addr == 32'h00000008)
        |-> (CLK_STATUS_reg[31:8] == $past(CLK_STATUS_reg[31:8]));
    endproperty
    assert property (p_clk_status_reserved_31_8_reserved);

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
