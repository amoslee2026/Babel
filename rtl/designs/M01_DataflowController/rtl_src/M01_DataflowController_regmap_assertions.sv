//==============================================================================
// Module: M01_DataflowController_regmap_assertions
//
// SPEC HEADER
// ─────────────────────────────────────────────────────────────────────────────
// Source:       spec/MAS/M01_DataflowController/regmap.md
// Version:      1.0
// Status:       AUTO-GENERATED
// Spec Hash:    sha256:91d2b1405f45  ← Run: uv run scripts/compute_spec_hash.py spec/MAS/M01_DataflowController/regmap.md --inject <this_file>
// Generated:    2026-05-30 16:30:21
//
// Purpose:
//   SVA assertions for M01_DataflowController register map (reset, RO, W1C, reserved, addr range)
//
// Traceability:
//   REGMAP: spec/MAS/M01_DataflowController/regmap.md
//==============================================================================

module M01_DataflowController_regmap_assertions (
    input  logic        clk,
    input  logic        rst_n,
    input  logic [31:0] addr,
    input  logic        sel,
    input  logic        enable,
    input  logic        write,
    input  logic [31:0] wdata,
    input  logic [31:0] rdata,
    input  logic [31:0] CTRL_reg,
    input  logic [31:0] STATUS_reg,
    input  logic [31:0] THREAD_CFG0_reg,
    input  logic [31:0] THREAD_CFG1_reg,
    input  logic [31:0] OP_QUEUE_reg,
    input  logic [31:0] PERF_CNT0_reg,
    input  logic [31:0] PERF_CNT1_reg,
    input  logic [31:0] PERF_UTIL_reg,
    input  logic [31:0] IRQ_MASK_reg,
    input  logic [31:0] IRQ_STATUS_reg
);

    // ══ CTRL (0x00) ════════════════════════════════════════

    // @verifies REQ-M01-R001
    // @spec_ref MAS/M01_DataflowController/regmap.md §1
    // @constraint CTRL 复位值必须为 0x0
    property p_ctrl_reset;
        @(posedge clk)
        $rose(rst_n) |-> (CTRL_reg == 32'h00000000);
    endproperty
    assert property (p_ctrl_reset)
        else $error("[REGMAP §1] CTRL reset value violation: %h", CTRL_reg);

    // @verifies REQ-M01-R001
    // @spec_ref MAS/M01_DataflowController/regmap.md §2
    // @constraint CTRL.RESERVED[7:4] 保留位，写入被忽略
    property p_ctrl_reserved_7_4_reserved;
        @(posedge clk) disable iff (!rst_n)
        (sel && enable && write && addr == 32'h00000000)
        |-> (CTRL_reg[7:4] == $past(CTRL_reg[7:4]));
    endproperty
    assert property (p_ctrl_reserved_7_4_reserved);

    // @verifies REQ-M01-R001
    // @spec_ref MAS/M01_DataflowController/regmap.md §2
    // @constraint CTRL.RESERVED[31:8] 保留位，写入被忽略
    property p_ctrl_reserved_31_8_reserved;
        @(posedge clk) disable iff (!rst_n)
        (sel && enable && write && addr == 32'h00000000)
        |-> (CTRL_reg[31:8] == $past(CTRL_reg[31:8]));
    endproperty
    assert property (p_ctrl_reserved_31_8_reserved);

    // ══ STATUS (0x04) ════════════════════════════════════════

    // @verifies REQ-M01-R002
    // @spec_ref MAS/M01_DataflowController/regmap.md §1
    // @constraint STATUS 复位值必须为 0x0
    property p_status_reset;
        @(posedge clk)
        $rose(rst_n) |-> (STATUS_reg == 32'h00000000);
    endproperty
    assert property (p_status_reset)
        else $error("[REGMAP §1] STATUS reset value violation: %h", STATUS_reg);

    // @verifies REQ-M01-R002
    // @spec_ref MAS/M01_DataflowController/regmap.md §1
    // @constraint STATUS 是只读寄存器，写操作无效
    property p_status_readonly;
        @(posedge clk) disable iff (!rst_n)
        (sel && enable && write && addr == 32'h00000004)
        |-> (STATUS_reg == $past(STATUS_reg));
    endproperty
    assert property (p_status_readonly)
        else $error("[REGMAP §1] STATUS write attempted (read-only)");

    // @verifies REQ-M01-R002
    // @spec_ref MAS/M01_DataflowController/regmap.md §2
    // @constraint STATUS.RESERVED[31:8] 保留位，写入被忽略
    property p_status_reserved_31_8_reserved;
        @(posedge clk) disable iff (!rst_n)
        (sel && enable && write && addr == 32'h00000004)
        |-> (STATUS_reg[31:8] == $past(STATUS_reg[31:8]));
    endproperty
    assert property (p_status_reserved_31_8_reserved);

    // ══ THREAD_CFG0 (0x08) ════════════════════════════════════════

    // @verifies REQ-M01-R003
    // @spec_ref MAS/M01_DataflowController/regmap.md §1
    // @constraint THREAD_CFG0 复位值必须为 0x0
    property p_thread_cfg0_reset;
        @(posedge clk)
        $rose(rst_n) |-> (THREAD_CFG0_reg == 32'h00000000);
    endproperty
    assert property (p_thread_cfg0_reset)
        else $error("[REGMAP §1] THREAD_CFG0 reset value violation: %h", THREAD_CFG0_reg);

    // @verifies REQ-M01-R003
    // @spec_ref MAS/M01_DataflowController/regmap.md §2
    // @constraint THREAD_CFG0.RESERVED[31:8] 保留位，写入被忽略
    property p_thread_cfg0_reserved_31_8_reserved;
        @(posedge clk) disable iff (!rst_n)
        (sel && enable && write && addr == 32'h00000008)
        |-> (THREAD_CFG0_reg[31:8] == $past(THREAD_CFG0_reg[31:8]));
    endproperty
    assert property (p_thread_cfg0_reserved_31_8_reserved);

    // ══ THREAD_CFG1 (0x0C) ════════════════════════════════════════

    // @verifies REQ-M01-R004
    // @spec_ref MAS/M01_DataflowController/regmap.md §1
    // @constraint THREAD_CFG1 复位值必须为 0x0
    property p_thread_cfg1_reset;
        @(posedge clk)
        $rose(rst_n) |-> (THREAD_CFG1_reg == 32'h00000000);
    endproperty
    assert property (p_thread_cfg1_reset)
        else $error("[REGMAP §1] THREAD_CFG1 reset value violation: %h", THREAD_CFG1_reg);

    // @verifies REQ-M01-R004
    // @spec_ref MAS/M01_DataflowController/regmap.md §2
    // @constraint THREAD_CFG1.RESERVED[31:8] 保留位，写入被忽略
    property p_thread_cfg1_reserved_31_8_reserved;
        @(posedge clk) disable iff (!rst_n)
        (sel && enable && write && addr == 32'h0000000C)
        |-> (THREAD_CFG1_reg[31:8] == $past(THREAD_CFG1_reg[31:8]));
    endproperty
    assert property (p_thread_cfg1_reserved_31_8_reserved);

    // ══ OP_QUEUE (0x10) ════════════════════════════════════════

    // @verifies REQ-M01-R005
    // @spec_ref MAS/M01_DataflowController/regmap.md §1
    // @constraint OP_QUEUE 复位值必须为 0x0
    property p_op_queue_reset;
        @(posedge clk)
        $rose(rst_n) |-> (OP_QUEUE_reg == 32'h00000000);
    endproperty
    assert property (p_op_queue_reset)
        else $error("[REGMAP §1] OP_QUEUE reset value violation: %h", OP_QUEUE_reg);

    // ══ PERF_CNT0 (0x14) ════════════════════════════════════════

    // @verifies REQ-M01-R006
    // @spec_ref MAS/M01_DataflowController/regmap.md §1
    // @constraint PERF_CNT0 复位值必须为 0x0
    property p_perf_cnt0_reset;
        @(posedge clk)
        $rose(rst_n) |-> (PERF_CNT0_reg == 32'h00000000);
    endproperty
    assert property (p_perf_cnt0_reset)
        else $error("[REGMAP §1] PERF_CNT0 reset value violation: %h", PERF_CNT0_reg);

    // @verifies REQ-M01-R006
    // @spec_ref MAS/M01_DataflowController/regmap.md §1
    // @constraint PERF_CNT0 是只读寄存器，写操作无效
    property p_perf_cnt0_readonly;
        @(posedge clk) disable iff (!rst_n)
        (sel && enable && write && addr == 32'h00000014)
        |-> (PERF_CNT0_reg == $past(PERF_CNT0_reg));
    endproperty
    assert property (p_perf_cnt0_readonly)
        else $error("[REGMAP §1] PERF_CNT0 write attempted (read-only)");

    // ══ PERF_CNT1 (0x18) ════════════════════════════════════════

    // @verifies REQ-M01-R007
    // @spec_ref MAS/M01_DataflowController/regmap.md §1
    // @constraint PERF_CNT1 复位值必须为 0x0
    property p_perf_cnt1_reset;
        @(posedge clk)
        $rose(rst_n) |-> (PERF_CNT1_reg == 32'h00000000);
    endproperty
    assert property (p_perf_cnt1_reset)
        else $error("[REGMAP §1] PERF_CNT1 reset value violation: %h", PERF_CNT1_reg);

    // @verifies REQ-M01-R007
    // @spec_ref MAS/M01_DataflowController/regmap.md §1
    // @constraint PERF_CNT1 是只读寄存器，写操作无效
    property p_perf_cnt1_readonly;
        @(posedge clk) disable iff (!rst_n)
        (sel && enable && write && addr == 32'h00000018)
        |-> (PERF_CNT1_reg == $past(PERF_CNT1_reg));
    endproperty
    assert property (p_perf_cnt1_readonly)
        else $error("[REGMAP §1] PERF_CNT1 write attempted (read-only)");

    // ══ PERF_UTIL (0x1C) ════════════════════════════════════════

    // @verifies REQ-M01-R008
    // @spec_ref MAS/M01_DataflowController/regmap.md §1
    // @constraint PERF_UTIL 复位值必须为 0x0
    property p_perf_util_reset;
        @(posedge clk)
        $rose(rst_n) |-> (PERF_UTIL_reg == 32'h00000000);
    endproperty
    assert property (p_perf_util_reset)
        else $error("[REGMAP §1] PERF_UTIL reset value violation: %h", PERF_UTIL_reg);

    // @verifies REQ-M01-R008
    // @spec_ref MAS/M01_DataflowController/regmap.md §1
    // @constraint PERF_UTIL 是只读寄存器，写操作无效
    property p_perf_util_readonly;
        @(posedge clk) disable iff (!rst_n)
        (sel && enable && write && addr == 32'h0000001C)
        |-> (PERF_UTIL_reg == $past(PERF_UTIL_reg));
    endproperty
    assert property (p_perf_util_readonly)
        else $error("[REGMAP §1] PERF_UTIL write attempted (read-only)");

    // @verifies REQ-M01-R008
    // @spec_ref MAS/M01_DataflowController/regmap.md §2
    // @constraint PERF_UTIL.RESERVED[31:16] 保留位，写入被忽略
    property p_perf_util_reserved_31_16_reserved;
        @(posedge clk) disable iff (!rst_n)
        (sel && enable && write && addr == 32'h0000001C)
        |-> (PERF_UTIL_reg[31:16] == $past(PERF_UTIL_reg[31:16]));
    endproperty
    assert property (p_perf_util_reserved_31_16_reserved);

    // ══ IRQ_MASK (0x20) ════════════════════════════════════════

    // @verifies REQ-M01-R009
    // @spec_ref MAS/M01_DataflowController/regmap.md §1
    // @constraint IRQ_MASK 复位值必须为 0x0
    property p_irq_mask_reset;
        @(posedge clk)
        $rose(rst_n) |-> (IRQ_MASK_reg == 32'h00000000);
    endproperty
    assert property (p_irq_mask_reset)
        else $error("[REGMAP §1] IRQ_MASK reset value violation: %h", IRQ_MASK_reg);

    // @verifies REQ-M01-R009
    // @spec_ref MAS/M01_DataflowController/regmap.md §2
    // @constraint IRQ_MASK.RESERVED[31:3] 保留位，写入被忽略
    property p_irq_mask_reserved_31_3_reserved;
        @(posedge clk) disable iff (!rst_n)
        (sel && enable && write && addr == 32'h00000020)
        |-> (IRQ_MASK_reg[31:3] == $past(IRQ_MASK_reg[31:3]));
    endproperty
    assert property (p_irq_mask_reserved_31_3_reserved);

    // ══ IRQ_STATUS (0x24) ════════════════════════════════════════

    // @verifies REQ-M01-R010
    // @spec_ref MAS/M01_DataflowController/regmap.md §1
    // @constraint IRQ_STATUS 复位值必须为 0x0
    property p_irq_status_reset;
        @(posedge clk)
        $rose(rst_n) |-> (IRQ_STATUS_reg == 32'h00000000);
    endproperty
    assert property (p_irq_status_reset)
        else $error("[REGMAP §1] IRQ_STATUS reset value violation: %h", IRQ_STATUS_reg);

    // @verifies REQ-M01-R010
    // @spec_ref MAS/M01_DataflowController/regmap.md §2
    // @constraint IRQ_STATUS.DONE_IRQ 写 1 清零，写 0 无效
    property p_irq_status_done_irq_w1c;
        @(posedge clk) disable iff (!rst_n)
        (sel && enable && write && addr == 32'h00000024)
        |-> (
            (wdata[0] == 1'b1) |-> (IRQ_STATUS_reg[0] == 1'b0)
            &&
            (wdata[0] == 1'b0) |-> (IRQ_STATUS_reg[0] == $past(IRQ_STATUS_reg[0]))
        );
    endproperty
    assert property (p_irq_status_done_irq_w1c);

    // @verifies REQ-M01-R010
    // @spec_ref MAS/M01_DataflowController/regmap.md §2
    // @constraint IRQ_STATUS.ERROR_IRQ 写 1 清零，写 0 无效
    property p_irq_status_error_irq_w1c;
        @(posedge clk) disable iff (!rst_n)
        (sel && enable && write && addr == 32'h00000024)
        |-> (
            (wdata[1] == 1'b1) |-> (IRQ_STATUS_reg[1] == 1'b0)
            &&
            (wdata[1] == 1'b0) |-> (IRQ_STATUS_reg[1] == $past(IRQ_STATUS_reg[1]))
        );
    endproperty
    assert property (p_irq_status_error_irq_w1c);

    // @verifies REQ-M01-R010
    // @spec_ref MAS/M01_DataflowController/regmap.md §2
    // @constraint IRQ_STATUS.QUEUE_FULL_IRQ 写 1 清零，写 0 无效
    property p_irq_status_queue_full_irq_w1c;
        @(posedge clk) disable iff (!rst_n)
        (sel && enable && write && addr == 32'h00000024)
        |-> (
            (wdata[2] == 1'b1) |-> (IRQ_STATUS_reg[2] == 1'b0)
            &&
            (wdata[2] == 1'b0) |-> (IRQ_STATUS_reg[2] == $past(IRQ_STATUS_reg[2]))
        );
    endproperty
    assert property (p_irq_status_queue_full_irq_w1c);

    // @verifies REQ-M01-R010
    // @spec_ref MAS/M01_DataflowController/regmap.md §2
    // @constraint IRQ_STATUS.RESERVED[31:3] 保留位，写入被忽略
    property p_irq_status_reserved_31_3_reserved;
        @(posedge clk) disable iff (!rst_n)
        (sel && enable && write && addr == 32'h00000024)
        |-> (IRQ_STATUS_reg[31:3] == $past(IRQ_STATUS_reg[31:3]));
    endproperty
    assert property (p_irq_status_reserved_31_3_reserved);

    // ══ Address Range ════════════════════════════════════════════════════
    //
    // @verifies REQ-SYS-ADDR
    // @spec_ref ARCH/memory_map.md §2
    // @constraint 访问地址必须在有效范围内 (0x00 ~ 0x24)
    property p_addr_range;
        @(posedge clk) disable iff (!rst_n)
        (sel && enable)
        |-> (addr <= 32'h00000024);
    endproperty
    assert property (p_addr_range)
        else $error("[SPEC §2] Address out of range: 0x%h", addr);

endmodule
