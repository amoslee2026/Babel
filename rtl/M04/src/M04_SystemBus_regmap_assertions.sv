//==============================================================================
// Module: M04_SystemBus_regmap_assertions
//
// SPEC HEADER
// ─────────────────────────────────────────────────────────────────────────────
// Source:       spec/MAS/M04_SystemBus/regmap.md
// Version:      1.0
// Status:       AUTO-GENERATED
// Spec Hash:    sha256:0e08e60cc0ad  ← Run: uv run scripts/compute_spec_hash.py spec/MAS/M04_SystemBus/regmap.md --inject <this_file>
// Generated:    2026-05-30 16:30:21
//
// Purpose:
//   SVA assertions for M04_SystemBus register map (reset, RO, W1C, reserved, addr range)
//
// Traceability:
//   REGMAP: spec/MAS/M04_SystemBus/regmap.md
//==============================================================================

module M04_SystemBus_regmap_assertions (
    input  logic        clk,
    input  logic        rst_n,
    input  logic [31:0] addr,
    input  logic        sel,
    input  logic        enable,
    input  logic        write,
    input  logic [31:0] wdata,
    input  logic [31:0] rdata,
    input  logic [31:0] BUS_CTRL_reg,
    input  logic [31:0] ARB_CFG_reg,
    input  logic [31:0] BUS_STATUS_reg,
    input  logic [31:0] BW_COUNTER_M00_reg,
    input  logic [31:0] BW_COUNTER_M01_reg,
    input  logic [31:0] BW_COUNTER_M02_reg,
    input  logic [31:0] BW_COUNTER_M03_reg
);

    // ══ BUS_CTRL (0x00) ════════════════════════════════════════

    // @verifies REQ-M04-R001
    // @spec_ref MAS/M04_SystemBus/regmap.md §1
    // @constraint BUS_CTRL 复位值必须为 0x1
    property p_bus_ctrl_reset;
        @(posedge clk)
        $rose(rst_n) |-> (BUS_CTRL_reg == 32'h00000001);
    endproperty
    assert property (p_bus_ctrl_reset)
        else $error("[REGMAP §1] BUS_CTRL reset value violation: %h", BUS_CTRL_reg);

    // @verifies REQ-M04-R001
    // @spec_ref MAS/M04_SystemBus/regmap.md §2
    // @constraint BUS_CTRL.RESERVED[7:2] 保留位，写入被忽略
    property p_bus_ctrl_reserved_7_2_reserved;
        @(posedge clk) disable iff (!rst_n)
        (sel && enable && write && addr == 32'h00000000)
        |-> (BUS_CTRL_reg[7:2] == $past(BUS_CTRL_reg[7:2]));
    endproperty
    assert property (p_bus_ctrl_reserved_7_2_reserved);

    // @verifies REQ-M04-R001
    // @spec_ref MAS/M04_SystemBus/regmap.md §2
    // @constraint BUS_CTRL.RESERVED[31:8] 保留位，写入被忽略
    property p_bus_ctrl_reserved_31_8_reserved;
        @(posedge clk) disable iff (!rst_n)
        (sel && enable && write && addr == 32'h00000000)
        |-> (BUS_CTRL_reg[31:8] == $past(BUS_CTRL_reg[31:8]));
    endproperty
    assert property (p_bus_ctrl_reserved_31_8_reserved);

    // ══ ARB_CFG (0x04) ════════════════════════════════════════

    // @verifies REQ-M04-R002
    // @spec_ref MAS/M04_SystemBus/regmap.md §1
    // @constraint ARB_CFG 复位值必须为 0x3210
    property p_arb_cfg_reset;
        @(posedge clk)
        $rose(rst_n) |-> (ARB_CFG_reg == 32'h00003210);
    endproperty
    assert property (p_arb_cfg_reset)
        else $error("[REGMAP §1] ARB_CFG reset value violation: %h", ARB_CFG_reg);

    // @verifies REQ-M04-R002
    // @spec_ref MAS/M04_SystemBus/regmap.md §2
    // @constraint ARB_CFG.RESERVED[31:16] 保留位，写入被忽略
    property p_arb_cfg_reserved_31_16_reserved;
        @(posedge clk) disable iff (!rst_n)
        (sel && enable && write && addr == 32'h00000004)
        |-> (ARB_CFG_reg[31:16] == $past(ARB_CFG_reg[31:16]));
    endproperty
    assert property (p_arb_cfg_reserved_31_16_reserved);

    // ══ BUS_STATUS (0x08) ════════════════════════════════════════

    // @verifies REQ-M04-R003
    // @spec_ref MAS/M04_SystemBus/regmap.md §1
    // @constraint BUS_STATUS 复位值必须为 0x0
    property p_bus_status_reset;
        @(posedge clk)
        $rose(rst_n) |-> (BUS_STATUS_reg == 32'h00000000);
    endproperty
    assert property (p_bus_status_reset)
        else $error("[REGMAP §1] BUS_STATUS reset value violation: %h", BUS_STATUS_reg);

    // @verifies REQ-M04-R003
    // @spec_ref MAS/M04_SystemBus/regmap.md §1
    // @constraint BUS_STATUS 是只读寄存器，写操作无效
    property p_bus_status_readonly;
        @(posedge clk) disable iff (!rst_n)
        (sel && enable && write && addr == 32'h00000008)
        |-> (BUS_STATUS_reg == $past(BUS_STATUS_reg));
    endproperty
    assert property (p_bus_status_readonly)
        else $error("[REGMAP §1] BUS_STATUS write attempted (read-only)");

    // @verifies REQ-M04-R003
    // @spec_ref MAS/M04_SystemBus/regmap.md §2
    // @constraint BUS_STATUS.RESERVED[7:6] 保留位，写入被忽略
    property p_bus_status_reserved_7_6_reserved;
        @(posedge clk) disable iff (!rst_n)
        (sel && enable && write && addr == 32'h00000008)
        |-> (BUS_STATUS_reg[7:6] == $past(BUS_STATUS_reg[7:6]));
    endproperty
    assert property (p_bus_status_reserved_7_6_reserved);

    // @verifies REQ-M04-R003
    // @spec_ref MAS/M04_SystemBus/regmap.md §2
    // @constraint BUS_STATUS.RESERVED[31:8] 保留位，写入被忽略
    property p_bus_status_reserved_31_8_reserved;
        @(posedge clk) disable iff (!rst_n)
        (sel && enable && write && addr == 32'h00000008)
        |-> (BUS_STATUS_reg[31:8] == $past(BUS_STATUS_reg[31:8]));
    endproperty
    assert property (p_bus_status_reserved_31_8_reserved);

    // ══ BW_COUNTER_M00 (0x0C) ════════════════════════════════════════

    // @verifies REQ-M04-R004
    // @spec_ref MAS/M04_SystemBus/regmap.md §1
    // @constraint BW_COUNTER_M00 复位值必须为 0x0
    property p_bw_counter_m00_reset;
        @(posedge clk)
        $rose(rst_n) |-> (BW_COUNTER_M00_reg == 32'h00000000);
    endproperty
    assert property (p_bw_counter_m00_reset)
        else $error("[REGMAP §1] BW_COUNTER_M00 reset value violation: %h", BW_COUNTER_M00_reg);

    // @verifies REQ-M04-R004
    // @spec_ref MAS/M04_SystemBus/regmap.md §1
    // @constraint BW_COUNTER_M00 是只读寄存器，写操作无效
    property p_bw_counter_m00_readonly;
        @(posedge clk) disable iff (!rst_n)
        (sel && enable && write && addr == 32'h0000000C)
        |-> (BW_COUNTER_M00_reg == $past(BW_COUNTER_M00_reg));
    endproperty
    assert property (p_bw_counter_m00_readonly)
        else $error("[REGMAP §1] BW_COUNTER_M00 write attempted (read-only)");

    // ══ BW_COUNTER_M01 (0x10) ════════════════════════════════════════

    // @verifies REQ-M04-R005
    // @spec_ref MAS/M04_SystemBus/regmap.md §1
    // @constraint BW_COUNTER_M01 复位值必须为 0x0
    property p_bw_counter_m01_reset;
        @(posedge clk)
        $rose(rst_n) |-> (BW_COUNTER_M01_reg == 32'h00000000);
    endproperty
    assert property (p_bw_counter_m01_reset)
        else $error("[REGMAP §1] BW_COUNTER_M01 reset value violation: %h", BW_COUNTER_M01_reg);

    // @verifies REQ-M04-R005
    // @spec_ref MAS/M04_SystemBus/regmap.md §1
    // @constraint BW_COUNTER_M01 是只读寄存器，写操作无效
    property p_bw_counter_m01_readonly;
        @(posedge clk) disable iff (!rst_n)
        (sel && enable && write && addr == 32'h00000010)
        |-> (BW_COUNTER_M01_reg == $past(BW_COUNTER_M01_reg));
    endproperty
    assert property (p_bw_counter_m01_readonly)
        else $error("[REGMAP §1] BW_COUNTER_M01 write attempted (read-only)");

    // ══ BW_COUNTER_M02 (0x14) ════════════════════════════════════════

    // @verifies REQ-M04-R006
    // @spec_ref MAS/M04_SystemBus/regmap.md §1
    // @constraint BW_COUNTER_M02 复位值必须为 0x0
    property p_bw_counter_m02_reset;
        @(posedge clk)
        $rose(rst_n) |-> (BW_COUNTER_M02_reg == 32'h00000000);
    endproperty
    assert property (p_bw_counter_m02_reset)
        else $error("[REGMAP §1] BW_COUNTER_M02 reset value violation: %h", BW_COUNTER_M02_reg);

    // @verifies REQ-M04-R006
    // @spec_ref MAS/M04_SystemBus/regmap.md §1
    // @constraint BW_COUNTER_M02 是只读寄存器，写操作无效
    property p_bw_counter_m02_readonly;
        @(posedge clk) disable iff (!rst_n)
        (sel && enable && write && addr == 32'h00000014)
        |-> (BW_COUNTER_M02_reg == $past(BW_COUNTER_M02_reg));
    endproperty
    assert property (p_bw_counter_m02_readonly)
        else $error("[REGMAP §1] BW_COUNTER_M02 write attempted (read-only)");

    // ══ BW_COUNTER_M03 (0x18) ════════════════════════════════════════

    // @verifies REQ-M04-R007
    // @spec_ref MAS/M04_SystemBus/regmap.md §1
    // @constraint BW_COUNTER_M03 复位值必须为 0x0
    property p_bw_counter_m03_reset;
        @(posedge clk)
        $rose(rst_n) |-> (BW_COUNTER_M03_reg == 32'h00000000);
    endproperty
    assert property (p_bw_counter_m03_reset)
        else $error("[REGMAP §1] BW_COUNTER_M03 reset value violation: %h", BW_COUNTER_M03_reg);

    // @verifies REQ-M04-R007
    // @spec_ref MAS/M04_SystemBus/regmap.md §1
    // @constraint BW_COUNTER_M03 是只读寄存器，写操作无效
    property p_bw_counter_m03_readonly;
        @(posedge clk) disable iff (!rst_n)
        (sel && enable && write && addr == 32'h00000018)
        |-> (BW_COUNTER_M03_reg == $past(BW_COUNTER_M03_reg));
    endproperty
    assert property (p_bw_counter_m03_readonly)
        else $error("[REGMAP §1] BW_COUNTER_M03 write attempted (read-only)");

    // ══ Address Range ════════════════════════════════════════════════════
    //
    // @verifies REQ-SYS-ADDR
    // @spec_ref ARCH/memory_map.md §2
    // @constraint 访问地址必须在有效范围内 (0x00 ~ 0x18)
    property p_addr_range;
        @(posedge clk) disable iff (!rst_n)
        (sel && enable)
        |-> (addr <= 32'h00000018);
    endproperty
    assert property (p_addr_range)
        else $error("[SPEC §2] Address out of range: 0x%h", addr);

endmodule
