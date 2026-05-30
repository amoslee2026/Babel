//==============================================================================
// Module: M02_SRAM_regmap_assertions
//
// SPEC HEADER
// ─────────────────────────────────────────────────────────────────────────────
// Source:       spec/MAS/M02_SRAM/regmap.md
// Version:      1.0
// Status:       AUTO-GENERATED
// Spec Hash:    sha256:66d1bba70afc  ← Run: uv run scripts/compute_spec_hash.py spec/MAS/M02_SRAM/regmap.md --inject <this_file>
// Generated:    2026-05-30 16:30:21
//
// Purpose:
//   SVA assertions for M02_SRAM register map (reset, RO, W1C, reserved, addr range)
//
// Traceability:
//   REGMAP: spec/MAS/M02_SRAM/regmap.md
//==============================================================================

module M02_SRAM_regmap_assertions (
    input  logic        clk,
    input  logic        rst_n,
    input  logic [31:0] addr,
    input  logic        sel,
    input  logic        enable,
    input  logic        write,
    input  logic [31:0] wdata,
    input  logic [31:0] rdata,
    input  logic [31:0] SRAM_CTRL_reg,
    input  logic [31:0] ECC_STATUS_reg,
    input  logic [31:0] ECC_ADDR_reg
);

    // ══ SRAM_CTRL (0x00) ════════════════════════════════════════

    // @verifies REQ-M02-R001
    // @spec_ref MAS/M02_SRAM/regmap.md §1
    // @constraint SRAM_CTRL 复位值必须为 0x3
    property p_sram_ctrl_reset;
        @(posedge clk)
        $rose(rst_n) |-> (SRAM_CTRL_reg == 32'h00000003);
    endproperty
    assert property (p_sram_ctrl_reset)
        else $error("[REGMAP §1] SRAM_CTRL reset value violation: %h", SRAM_CTRL_reg);

    // @verifies REQ-M02-R001
    // @spec_ref MAS/M02_SRAM/regmap.md §2
    // @constraint SRAM_CTRL.RESERVED[7:4] 保留位，写入被忽略
    property p_sram_ctrl_reserved_7_4_reserved;
        @(posedge clk) disable iff (!rst_n)
        (sel && enable && write && addr == 32'h00000000)
        |-> (SRAM_CTRL_reg[7:4] == $past(SRAM_CTRL_reg[7:4]));
    endproperty
    assert property (p_sram_ctrl_reserved_7_4_reserved);

    // @verifies REQ-M02-R001
    // @spec_ref MAS/M02_SRAM/regmap.md §2
    // @constraint SRAM_CTRL.RESERVED[31:8] 保留位，写入被忽略
    property p_sram_ctrl_reserved_31_8_reserved;
        @(posedge clk) disable iff (!rst_n)
        (sel && enable && write && addr == 32'h00000000)
        |-> (SRAM_CTRL_reg[31:8] == $past(SRAM_CTRL_reg[31:8]));
    endproperty
    assert property (p_sram_ctrl_reserved_31_8_reserved);

    // ══ ECC_STATUS (0x04) ════════════════════════════════════════

    // @verifies REQ-M02-R002
    // @spec_ref MAS/M02_SRAM/regmap.md §1
    // @constraint ECC_STATUS 复位值必须为 0x0
    property p_ecc_status_reset;
        @(posedge clk)
        $rose(rst_n) |-> (ECC_STATUS_reg == 32'h00000000);
    endproperty
    assert property (p_ecc_status_reset)
        else $error("[REGMAP §1] ECC_STATUS reset value violation: %h", ECC_STATUS_reg);

    // @verifies REQ-M02-R002
    // @spec_ref MAS/M02_SRAM/regmap.md §1
    // @constraint ECC_STATUS 是只读寄存器，写操作无效
    property p_ecc_status_readonly;
        @(posedge clk) disable iff (!rst_n)
        (sel && enable && write && addr == 32'h00000004)
        |-> (ECC_STATUS_reg == $past(ECC_STATUS_reg));
    endproperty
    assert property (p_ecc_status_readonly)
        else $error("[REGMAP §1] ECC_STATUS write attempted (read-only)");

    // ══ ECC_ADDR (0x08) ════════════════════════════════════════

    // @verifies REQ-M02-R003
    // @spec_ref MAS/M02_SRAM/regmap.md §1
    // @constraint ECC_ADDR 复位值必须为 0x0
    property p_ecc_addr_reset;
        @(posedge clk)
        $rose(rst_n) |-> (ECC_ADDR_reg == 32'h00000000);
    endproperty
    assert property (p_ecc_addr_reset)
        else $error("[REGMAP §1] ECC_ADDR reset value violation: %h", ECC_ADDR_reg);

    // @verifies REQ-M02-R003
    // @spec_ref MAS/M02_SRAM/regmap.md §1
    // @constraint ECC_ADDR 是只读寄存器，写操作无效
    property p_ecc_addr_readonly;
        @(posedge clk) disable iff (!rst_n)
        (sel && enable && write && addr == 32'h00000008)
        |-> (ECC_ADDR_reg == $past(ECC_ADDR_reg));
    endproperty
    assert property (p_ecc_addr_readonly)
        else $error("[REGMAP §1] ECC_ADDR write attempted (read-only)");

    // @verifies REQ-M02-R003
    // @spec_ref MAS/M02_SRAM/regmap.md §2
    // @constraint ECC_ADDR.RESERVED[31:19] 保留位，写入被忽略
    property p_ecc_addr_reserved_31_19_reserved;
        @(posedge clk) disable iff (!rst_n)
        (sel && enable && write && addr == 32'h00000008)
        |-> (ECC_ADDR_reg[31:19] == $past(ECC_ADDR_reg[31:19]));
    endproperty
    assert property (p_ecc_addr_reserved_31_19_reserved);

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
