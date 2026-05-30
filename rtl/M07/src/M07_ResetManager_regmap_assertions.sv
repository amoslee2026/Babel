//==============================================================================
// Module: M07_ResetManager_regmap_assertions
//
// SPEC HEADER
// ─────────────────────────────────────────────────────────────────────────────
// Source:       spec/MAS/M07_ResetManager/regmap.md
// Version:      1.0
// Status:       AUTO-GENERATED
// Spec Hash:    sha256:1fd07a37ec6a  ← Run: uv run scripts/compute_spec_hash.py spec/MAS/M07_ResetManager/regmap.md --inject <this_file>
// Generated:    2026-05-30 16:30:21
//
// Purpose:
//   SVA assertions for M07_ResetManager register map (reset, RO, W1C, reserved, addr range)
//
// Traceability:
//   REGMAP: spec/MAS/M07_ResetManager/regmap.md
//==============================================================================

module M07_ResetManager_regmap_assertions (
    input  logic        clk,
    input  logic        rst_n,
    input  logic [31:0] addr,
    input  logic        sel,
    input  logic        enable,
    input  logic        write,
    input  logic [31:0] wdata,
    input  logic [31:0] rdata,
    input  logic [31:0] RST_CTRL_reg,
    input  logic [31:0] RST_STATUS_reg,
    input  logic [31:0] WDT_CFG_reg
);

    // ══ RST_CTRL (0x00) ════════════════════════════════════════

    // @verifies REQ-M07-R001
    // @spec_ref MAS/M07_ResetManager/regmap.md §1
    // @constraint RST_CTRL 复位值必须为 0xE
    property p_rst_ctrl_reset;
        @(posedge clk)
        $rose(rst_n) |-> (RST_CTRL_reg == 32'h0000000E);
    endproperty
    assert property (p_rst_ctrl_reset)
        else $error("[REGMAP §1] RST_CTRL reset value violation: %h", RST_CTRL_reg);

    // @verifies REQ-M07-R001
    // @spec_ref MAS/M07_ResetManager/regmap.md §2
    // @constraint RST_CTRL.RESERVED[7:4] 保留位，写入被忽略
    property p_rst_ctrl_reserved_7_4_reserved;
        @(posedge clk) disable iff (!rst_n)
        (sel && enable && write && addr == 32'h00000000)
        |-> (RST_CTRL_reg[7:4] == $past(RST_CTRL_reg[7:4]));
    endproperty
    assert property (p_rst_ctrl_reserved_7_4_reserved);

    // @verifies REQ-M07-R001
    // @spec_ref MAS/M07_ResetManager/regmap.md §2
    // @constraint RST_CTRL.RESERVED[31:8] 保留位，写入被忽略
    property p_rst_ctrl_reserved_31_8_reserved;
        @(posedge clk) disable iff (!rst_n)
        (sel && enable && write && addr == 32'h00000000)
        |-> (RST_CTRL_reg[31:8] == $past(RST_CTRL_reg[31:8]));
    endproperty
    assert property (p_rst_ctrl_reserved_31_8_reserved);

    // ══ RST_STATUS (0x04) ════════════════════════════════════════

    // @verifies REQ-M07-R002
    // @spec_ref MAS/M07_ResetManager/regmap.md §1
    // @constraint RST_STATUS 复位值必须为 0x1
    property p_rst_status_reset;
        @(posedge clk)
        $rose(rst_n) |-> (RST_STATUS_reg == 32'h00000001);
    endproperty
    assert property (p_rst_status_reset)
        else $error("[REGMAP §1] RST_STATUS reset value violation: %h", RST_STATUS_reg);

    // @verifies REQ-M07-R002
    // @spec_ref MAS/M07_ResetManager/regmap.md §1
    // @constraint RST_STATUS 是只读寄存器，写操作无效
    property p_rst_status_readonly;
        @(posedge clk) disable iff (!rst_n)
        (sel && enable && write && addr == 32'h00000004)
        |-> (RST_STATUS_reg == $past(RST_STATUS_reg));
    endproperty
    assert property (p_rst_status_readonly)
        else $error("[REGMAP §1] RST_STATUS write attempted (read-only)");

    // @verifies REQ-M07-R002
    // @spec_ref MAS/M07_ResetManager/regmap.md §2
    // @constraint RST_STATUS.RESERVED[7:4] 保留位，写入被忽略
    property p_rst_status_reserved_7_4_reserved;
        @(posedge clk) disable iff (!rst_n)
        (sel && enable && write && addr == 32'h00000004)
        |-> (RST_STATUS_reg[7:4] == $past(RST_STATUS_reg[7:4]));
    endproperty
    assert property (p_rst_status_reserved_7_4_reserved);

    // @verifies REQ-M07-R002
    // @spec_ref MAS/M07_ResetManager/regmap.md §2
    // @constraint RST_STATUS.RESERVED[31:8] 保留位，写入被忽略
    property p_rst_status_reserved_31_8_reserved;
        @(posedge clk) disable iff (!rst_n)
        (sel && enable && write && addr == 32'h00000004)
        |-> (RST_STATUS_reg[31:8] == $past(RST_STATUS_reg[31:8]));
    endproperty
    assert property (p_rst_status_reserved_31_8_reserved);

    // ══ WDT_CFG (0x08) ════════════════════════════════════════

    // @verifies REQ-M07-R003
    // @spec_ref MAS/M07_ResetManager/regmap.md §1
    // @constraint WDT_CFG 复位值必须为 0xFFFF
    property p_wdt_cfg_reset;
        @(posedge clk)
        $rose(rst_n) |-> (WDT_CFG_reg == 32'h0000FFFF);
    endproperty
    assert property (p_wdt_cfg_reset)
        else $error("[REGMAP §1] WDT_CFG reset value violation: %h", WDT_CFG_reg);

    // @verifies REQ-M07-R003
    // @spec_ref MAS/M07_ResetManager/regmap.md §2
    // @constraint WDT_CFG.RESERVED[31:18] 保留位，写入被忽略
    property p_wdt_cfg_reserved_31_18_reserved;
        @(posedge clk) disable iff (!rst_n)
        (sel && enable && write && addr == 32'h00000008)
        |-> (WDT_CFG_reg[31:18] == $past(WDT_CFG_reg[31:18]));
    endproperty
    assert property (p_wdt_cfg_reserved_31_18_reserved);

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
