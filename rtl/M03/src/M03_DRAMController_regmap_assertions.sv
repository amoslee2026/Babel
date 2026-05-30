//==============================================================================
// Module: M03_DRAMController_regmap_assertions
//
// SPEC HEADER
// ─────────────────────────────────────────────────────────────────────────────
// Source:       spec/MAS/M03_DRAMController/regmap.md
// Version:      1.0
// Status:       AUTO-GENERATED
// Spec Hash:    sha256:081931ff9be5  ← Run: uv run scripts/compute_spec_hash.py spec/MAS/M03_DRAMController/regmap.md --inject <this_file>
// Generated:    2026-05-30 16:30:21
//
// Purpose:
//   SVA assertions for M03_DRAMController register map (reset, RO, W1C, reserved, addr range)
//
// Traceability:
//   REGMAP: spec/MAS/M03_DRAMController/regmap.md
//==============================================================================

module M03_DRAMController_regmap_assertions (
    input  logic        clk,
    input  logic        rst_n,
    input  logic [31:0] addr,
    input  logic        sel,
    input  logic        enable,
    input  logic        write,
    input  logic [31:0] wdata,
    input  logic [31:0] rdata,
    input  logic [31:0] DRAM_CTRL_reg,
    input  logic [31:0] TIMING_CFG_reg,
    input  logic [31:0] ECC_STATUS_reg,
    input  logic [31:0] PERF_CNT_reg
);

    // ══ DRAM_CTRL (0x00) ════════════════════════════════════════

    // @verifies REQ-M03-R001
    // @spec_ref MAS/M03_DRAMController/regmap.md §1
    // @constraint DRAM_CTRL 复位值必须为 0x1
    property p_dram_ctrl_reset;
        @(posedge clk)
        $rose(rst_n) |-> (DRAM_CTRL_reg == 32'h00000001);
    endproperty
    assert property (p_dram_ctrl_reset)
        else $error("[REGMAP §1] DRAM_CTRL reset value violation: %h", DRAM_CTRL_reg);

    // @verifies REQ-M03-R001
    // @spec_ref MAS/M03_DRAMController/regmap.md §2
    // @constraint DRAM_CTRL.RESERVED[31:8] 保留位，写入被忽略
    property p_dram_ctrl_reserved_31_8_reserved;
        @(posedge clk) disable iff (!rst_n)
        (sel && enable && write && addr == 32'h00000000)
        |-> (DRAM_CTRL_reg[31:8] == $past(DRAM_CTRL_reg[31:8]));
    endproperty
    assert property (p_dram_ctrl_reserved_31_8_reserved);

    // ══ TIMING_CFG (0x04) ════════════════════════════════════════

    // @verifies REQ-M03-R002
    // @spec_ref MAS/M03_DRAMController/regmap.md §1
    // @constraint TIMING_CFG 复位值必须为 0x24121218
    property p_timing_cfg_reset;
        @(posedge clk)
        $rose(rst_n) |-> (TIMING_CFG_reg == 32'h24121218);
    endproperty
    assert property (p_timing_cfg_reset)
        else $error("[REGMAP §1] TIMING_CFG reset value violation: %h", TIMING_CFG_reg);

    // ══ ECC_STATUS (0x08) ════════════════════════════════════════

    // @verifies REQ-M03-R003
    // @spec_ref MAS/M03_DRAMController/regmap.md §1
    // @constraint ECC_STATUS 复位值必须为 0x0
    property p_ecc_status_reset;
        @(posedge clk)
        $rose(rst_n) |-> (ECC_STATUS_reg == 32'h00000000);
    endproperty
    assert property (p_ecc_status_reset)
        else $error("[REGMAP §1] ECC_STATUS reset value violation: %h", ECC_STATUS_reg);

    // @verifies REQ-M03-R003
    // @spec_ref MAS/M03_DRAMController/regmap.md §2
    // @constraint ECC_STATUS.SBE 写 1 清零，写 0 无效
    property p_ecc_status_sbe_w1c;
        @(posedge clk) disable iff (!rst_n)
        (sel && enable && write && addr == 32'h00000008)
        |-> (
            (wdata[0] == 1'b1) |-> (ECC_STATUS_reg[0] == 1'b0)
            &&
            (wdata[0] == 1'b0) |-> (ECC_STATUS_reg[0] == $past(ECC_STATUS_reg[0]))
        );
    endproperty
    assert property (p_ecc_status_sbe_w1c);

    // @verifies REQ-M03-R003
    // @spec_ref MAS/M03_DRAMController/regmap.md §2
    // @constraint ECC_STATUS.DBE 写 1 清零，写 0 无效
    property p_ecc_status_dbe_w1c;
        @(posedge clk) disable iff (!rst_n)
        (sel && enable && write && addr == 32'h00000008)
        |-> (
            (wdata[1] == 1'b1) |-> (ECC_STATUS_reg[1] == 1'b0)
            &&
            (wdata[1] == 1'b0) |-> (ECC_STATUS_reg[1] == $past(ECC_STATUS_reg[1]))
        );
    endproperty
    assert property (p_ecc_status_dbe_w1c);

    // @verifies REQ-M03-R003
    // @spec_ref MAS/M03_DRAMController/regmap.md §2
    // @constraint ECC_STATUS.RESERVED[15:2] 保留位，写入被忽略
    property p_ecc_status_reserved_15_2_reserved;
        @(posedge clk) disable iff (!rst_n)
        (sel && enable && write && addr == 32'h00000008)
        |-> (ECC_STATUS_reg[15:2] == $past(ECC_STATUS_reg[15:2]));
    endproperty
    assert property (p_ecc_status_reserved_15_2_reserved);

    // ══ PERF_CNT (0x0C) ════════════════════════════════════════

    // @verifies REQ-M03-R004
    // @spec_ref MAS/M03_DRAMController/regmap.md §1
    // @constraint PERF_CNT 复位值必须为 0x0
    property p_perf_cnt_reset;
        @(posedge clk)
        $rose(rst_n) |-> (PERF_CNT_reg == 32'h00000000);
    endproperty
    assert property (p_perf_cnt_reset)
        else $error("[REGMAP §1] PERF_CNT reset value violation: %h", PERF_CNT_reg);

    // @verifies REQ-M03-R004
    // @spec_ref MAS/M03_DRAMController/regmap.md §1
    // @constraint PERF_CNT 是只读寄存器，写操作无效
    property p_perf_cnt_readonly;
        @(posedge clk) disable iff (!rst_n)
        (sel && enable && write && addr == 32'h0000000C)
        |-> (PERF_CNT_reg == $past(PERF_CNT_reg));
    endproperty
    assert property (p_perf_cnt_readonly)
        else $error("[REGMAP §1] PERF_CNT write attempted (read-only)");

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
