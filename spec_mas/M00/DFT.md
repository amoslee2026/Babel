---
module: M00
type: DFT
status: complete
parent: M00
module_type: compute
generated: "2026-05-17T16:30:00+08:00"
---

# M00: Systolic Array - DFT Specification

## 1. Overview

M00 Systolic Array 是 128x128 PE 阵列核心计算单元，DFT 策略采用多层次测试架构，覆盖 PE Array、MAC Logic、Precision Control、Data Flow 四大测试对象。目标测试覆盖率 >= 95% (REQ-DFT-001)。

| Test Object | Coverage Target | Priority |
|-------------|-----------------|----------|
| PE Array Logic | 98% | Highest |
| MAC Units | 98% | Highest |
| Precision Control | 95% | High |
| Data Flow Interface | 95% | High |

## 2. Scan Chain Configuration

### 2.1 Scan Chain Architecture

采用 Hierarchical Scan 架构，按 PE 行/列分组。

| Chain Group | Chain ID | Elements | Length (FFs) | Description |
|--------------|----------|----------|--------------|-------------|
| PE Row 0-31 | SC0-SC31 | 32 PE rows | 32*128*25 = 102,400 | PE[0-31][0-127] weight/input/acc regs |
| PE Row 32-63 | SC32-SC63 | 32 PE rows | 32*128*25 = 102,400 | PE[32-63][0-127] weight/input/acc regs |
| PE Row 64-95 | SC64-SC95 | 32 PE rows | 32*128*25 = 102,400 | PE[64-95][0-127] weight/input/acc regs |
| PE Row 96-127 | SC96-SC127 | 32 PE rows | 32*128*25 = 102,400 | PE[96-127][0-127] weight/input/acc regs |
| Control Logic | SC128 | 1 chain | 5,000 | Mode control, precision config |
| Data Interface | SC129 | 1 chain | 2,000 | Input/output flow registers |

**Total Scan Chains**: 130 chains
**Total Scan Elements**: ~416,200 FFs

### 2.2 Scan Chain Interface

| Signal | Direction | Width | Description |
|--------|-----------|-------|-------------|
| scan_enable_i | Input | 1 | Global scan enable |
| scan_mode_i | Input | 2 | Scan mode (00=Normal, 01=Scan, 10=MBIST, 11=Reserved) |
| scan_in_i | Input | 130 | Scan data input (per chain) |
| scan_out_o | Output | 130 | Scan data output (per chain) |
| scan_clk_i | Input | 1 | Scan clock (low frequency test clock) |
| scan_rst_n_i | Input | 1 | Scan reset |

### 2.3 Scan Chain Timing

| Parameter | Value | Description |
|-----------|-------|-------------|
| Scan Clock Frequency | 10-50 MHz | Low frequency for reliable capture |
| Scan Chain Cycle | <= 20 us | Max chain length / scan_clk |
| Scan Capture Window | >= 10 ns | Setup + Hold time margin |

## 3. BIST Design

### 3.1 Logic BIST (LBIST) for MAC Units

LBIST 覆盖每个 PE 内的 MAC Logic。

| Parameter | Value | Description |
|-----------|-------|-------------|
| BIST Controller | 1 instance | Centralized LBIST controller |
| PRPG (Pseudo-Random Pattern Generator) | LFSR-32 | 32-bit Linear Feedback Shift Register |
| MISR (Multiple Input Signature Register) | MISR-32 | 32-bit signature compactor |
| Test Patterns | 10,000 | Random patterns per precision mode |
| Coverage Target | 98% | MAC logic fault coverage |

**LBIST Sequence**:

```
LBIST Initialization:
  1. Enable scan_mode_i = 01 (Scan Mode)
  2. Initialize LFSR seed (user configurable)
  3. Set precision mode via scan chain
  
LBIST Execution:
  4. Generate PRPG patterns
  5. Apply patterns to MAC inputs via scan chain
  6. Capture MAC outputs in MISR
  7. Repeat for all precision modes (FP8, FP16, INT8, FP32)
  
LBIST Completion:
  8. Compare MISR signature with golden signature
  9. Report pass/fail status via bist_status_o
```

### 3.2 Precision Mode BIST

针对不同精度模式的专用测试。

| Precision | Test Patterns | Coverage Target | Special Tests |
|-----------|---------------|-----------------|---------------|
| FP8 (E4M3) | 2,000 | 98% | Overflow, saturation, quantization |
| FP8 (E5M2) | 2,000 | 98% | Denormal handling, NaN detection |
| FP16 | 3,000 | 98% | IEEE 754 compliance |
| INT8 | 2,000 | 98% | Signed/unsigned, overflow |
| FP32 | 1,000 | 95% | Full precision baseline |

### 3.3 PE Array BIST

PE Array 测试采用行/列扫描策略。

| Test Type | Description | Coverage |
|-----------|-------------|----------|
| Row-wise Scan | 测试每行 PE 连接和数据流 | 100% row connectivity |
| Column-wise Scan | 测试每列 PE 连接和数据流 | 100% column connectivity |
| Diagonal Test | 测试 PE 间数据传递路径 | 100% inter-PE paths |
| Partial Array Test | 测试活动区域控制 (pe_row_cnt/pe_col_cnt) | All 128x128 combinations |

**PE Array BIST Sequence**:

```
PE Array Row Scan:
  1. For each row i = 0 to 127:
     - Load test pattern via weight_in
     - Verify propagation to all 128 PEs in row
     - Capture output at row boundary
     
PE Array Column Scan:
  2. For each column j = 0 to 127:
     - Load test pattern via input_in
     - Verify propagation to all 128 PEs in column
     - Capture output at column boundary
     
Inter-PE Data Flow:
  3. Test data flow direction:
     - WS Mode: weight stationary, input flow
     - OS Mode: output stationary, weight/input flow
```

## 4. Test Access Mechanism (TAM)

### 4.1 JTAG TAP Controller

标准 IEEE 1149.1 JTAG TAP 接口。

| Signal | Direction | Width | Description |
|--------|-----------|-------|-------------|
| tck_i | Input | 1 | JTAG Test Clock |
| tms_i | Input | 1 | JTAG Test Mode Select |
| tdi_i | Input | 1 | JTAG Test Data Input |
| tdo_o | Output | 1 | JTAG Test Data Output |
| trst_n_i | Input | 1 | JTAG Test Reset (optional) |

**JTAG Instructions**:

| Instruction | Opcode | Description |
|-------------|--------|-------------|
| EXTEST | 0x00 | External test (boundary scan) |
| SAMPLE | 0x01 | Sample boundary registers |
| INTEST | 0x02 | Internal test (scan chain) |
| USERCODE | 0x03 | Read user-defined code |
| IDCODE | 0x04 | Read device ID (32-bit) |
| BYPASS | 0x0F | Bypass mode |

### 4.2 Test Access Port (TAP) Integration

| TAP Function | Access Method | Description |
|--------------|---------------|-------------|
| Scan Chain Control | JTAG INTEST instruction | Access all 130 scan chains |
| LBIST Control | JTAG USER1 instruction (0x08) | Start/monitor LBIST |
| PE Array Test | JTAG USER2 instruction (0x09) | Row/column scan test |
| Precision Test | JTAG USER3 instruction (0x0A) | Precision mode BIST |

### 4.3 Test Wrapper Architecture

采用 IEEE 1500 Standard Test Wrapper。

| Wrapper Element | Function | Description |
|-----------------|----------|-------------|
| Wrapper Boundary Register (WBR) | Isolate PE array I/O | 128-bit data in/out + control |
| Wrapper Instruction Register (WIR) | Test mode selection | 4-bit instruction register |
| Wrapper Data Register (WDR) | Test data path | Scan chain connection |

## 5. Test Mode Definition

### 5.1 Test Mode Register

| Mode | Code | Description | Active Chains |
|------|------|-------------|---------------|
| NORMAL_MODE | 0x00 | Functional operation | None |
| SCAN_MODE | 0x01 | Scan chain access | All 130 chains |
| LBIST_MODE | 0x02 | Logic BIST execution | MAC logic chains |
| PE_ARRAY_TEST | 0x03 | PE connectivity test | PE row/column chains |
| PRECISION_TEST | 0x04 | Precision mode test | Precision control chain |
| DATA_FLOW_TEST | 0x05 | Data flow path test | Data interface chains |
| BURN_IN_MODE | 0x06 | Burn-in stress test | Selected chains |

### 5.2 Test Mode Control Signals

| Signal | Width | Description |
|--------|-------|-------------|
| test_mode_i | 3 | Test mode selection |
| test_start_i | 1 | Test execution start pulse |
| test_done_o | 1 | Test completion flag |
| test_pass_o | 1 | Test pass indicator |
| test_fail_o | 1 | Test fail indicator |
| test_error_code_o | 8 | Detailed error code |

## 6. Coverage Target

### 6.1 Fault Coverage Summary

| Fault Type | Target Coverage | Method |
|------------|-----------------|--------|
| Stuck-at Fault | 98% | Scan + LBIST |
| Transition Fault | 95% | At-speed scan |
| Path Delay Fault | 90% | At-speed LBIST |
| Bridging Fault | 95% | LBIST + PE Array Test |
| Open Fault | 95% | PE connectivity test |

### 6.2 Module-Level Coverage

| Sub-Module | Stuck-at | Transition | Path Delay | Overall |
|------------|----------|------------|------------|---------|
| PE Array (128x128) | 98% | 95% | 90% | 95% |
| MAC Units | 98% | 95% | 92% | 96% |
| Precision Control | 95% | 92% | 88% | 94% |
| Data Flow Interface | 95% | 93% | 90% | 94% |
| Control Logic | 98% | 95% | 90% | 96% |

### 6.3 Test Time Estimation

| Test Type | Duration | Patterns |
|-----------|----------|----------|
| Scan Chain Load/Unload | ~20 ms | 130 chains @ 10 MHz |
| LBIST Execution | ~100 ms | 10,000 patterns per precision |
| PE Array Test | ~50 ms | Row/column scan |
| Total Test Time | ~200 ms | All modes combined |

## 7. DFT Implementation Notes

### 7.1 Scan Insertion Guidelines

1. **Scan Chain Grouping**: PE 按行分组，每行独立 scan chain，便于局部测试。
2. **Scan FF Selection**: 所有 PE 寄存器（weight, input, accumulator）均插入 scan。
3. **Scan Compression**: 采用 scan compression 技术减少测试时间和 IO 数量。

### 7.2 LBIST Design Guidelines

1. **At-Speed Testing**: LBIST 在 functional clock (500 MHz) 下执行，检测 delay faults。
2. **Signature Compaction**: MISR 签名存储在 dedicated register，可通过 JTAG 读取。
3. **Self-Checking**: LBIST 自动比较签名，输出 pass/fail 结果。

### 7.3 Test Integration

| Integration Point | Description |
|-------------------|-------------|
| M01 Dataflow Controller | 提供测试模式控制信号 |
| M15 JTAG Interface | JTAG TAP 接入 |
| M05 Power Manager | 测试模式功耗管理 |
| M02 SRAM Scratchpad | 测试数据存储 |

## 8. References

- IEEE 1149.1: JTAG Standard
- IEEE 1500: Standard Test Wrapper
- REQ-DFT-001: Test coverage >= 95%
- M00 MAS.md: Module architecture specification