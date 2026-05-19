---
module: M02
type: DFT
status: complete
parent: M02
module_type: storage
generated: "2026-05-17T16:30:00+08:00"
---

# M02: SRAM Scratchpad - DFT Specification

## 1. Overview

M02 SRAM Scratchpad 是 512 KB 片上存储模块，DFT 策略重点覆盖 SRAM Array、ECC Logic、Arbitration Logic、Power Management 四大测试对象。目标测试覆盖率 >= 95% (REQ-DFT-001)。

| Test Object | Coverage Target | Priority |
|-------------|-----------------|----------|
| SRAM Array | 100% | Highest |
| ECC Logic | 100% | Highest |
| Arbitration Logic | 98% | High |
| Power Management | 95% | High |

## 2. Scan Chain Configuration

### 2.1 Scan Chain Architecture

SRAM 模块采用 Control Logic Scan + Memory BIST 混合架构。

| Chain Group | Chain ID | Elements | Length (FFs) | Description |
|--------------|----------|----------|--------------|-------------|
| Arbitration Logic | SC0 | 1 chain | 800 | Arbitration FSM + priority logic |
| ECC Control | SC1 | 1 chain | 600 | ECC control registers |
| Bus Interface | SC2 | 1 chain | 400 | TileLink/AXI interface logic |
| Direct Interface | SC3 | 1 chain | 400 | Compute unit direct access logic |
| Power Control | SC4 | 1 chain | 300 | Power management registers |
| Status Registers | SC5 | 1 chain | 500 | Error status + counter registers |

**Total Scan Chains**: 6 chains
**Total Scan Elements**: ~3,000 FFs

### 2.2 Scan Chain Interface

| Signal | Direction | Width | Description |
|--------|-----------|-------|-------------|
| scan_enable_i | Input | 1 | Global scan enable |
| scan_mode_i | Input | 2 | Scan mode selection |
| scan_in_i | Input | 6 | Scan data input |
| scan_out_o | Output | 6 | Scan data output |
| scan_clk_i | Input | 1 | Scan clock |
| scan_rst_n_i | Input | 1 | Scan reset |

### 2.3 Scan Chain Timing

| Parameter | Value | Description |
|-----------|-------|-------------|
| Scan Clock Frequency | 10-50 MHz | Test clock frequency |
| Scan Chain Cycle | <= 0.5 ms | Max chain load/unload |
| Scan Capture Window | >= 10 ns | Setup + Hold margin |

## 3. BIST Design

### 3.1 Memory BIST (MBIST) for SRAM Array

MBIST 覆盖 512 KB SRAM 阵列，采用 March C+ 算法。

| Parameter | Value | Description |
|-----------|-------|-------------|
| MBIST Controller | 1 instance | Centralized MBIST controller |
| Algorithm | March C+ | Industry standard memory test algorithm |
| Address Range | 0x8000_0000 - 0x8007_FFFF | Full 512 KB coverage |
| Bank Coverage | All 128 banks | Parallel bank testing |
| Test Time | ~50 ms | Full array test duration |

**March C+ Algorithm Sequence**:

```
March C+ Algorithm:
  1. Write 0 to all addresses (up order)
  2. Read 0, Write 1 (up order)
  3. Read 1, Write 0 (up order)
  4. Read 0, Write 1 (down order)
  5. Read 1, Write 0 (down order)
  6. Read 0 (down order)
  
Coverage:
  - Stuck-at faults (SA0, SA1)
  - Address decoder faults
  - Coupling faults
  - Transition faults
```

### 3.2 MBIST Architecture

| Element | Description | Implementation |
|---------|-------------|----------------|
| Address Generator | Sequential + random address | Counter + LFSR |
| Data Generator | Test pattern generation | 0x00000000, 0xFFFFFFFF, checkerboard |
| Comparator | Read data verification | XOR comparator |
| Error Logger | Fail address capture | FIFO-based error logging |

**MBIST Interface Signals**:

| Signal | Direction | Width | Description |
|--------|-----------|-------|-------------|
| mbist_start_i | Input | 1 | MBIST start command |
| mbist_done_o | Output | 1 | MBIST completion flag |
| mbist_pass_o | Output | 1 | MBIST pass indicator |
| mbist_fail_o | Output | 1 | MBIST fail indicator |
| mbist_error_addr_o | Output | 32 | First error address |
| mbist_error_count_o | Output | 16 | Total error count |

### 3.3 ECC Test Design

ECC 逻辑测试覆盖 SECDED (39,32) 编码。

| Test Type | Description | Coverage |
|-----------|-------------|----------|
| No Error Test | Syndrome = 0 验证 | Normal operation |
| Single Error Injection | 单错纠正验证 | All 39 bit positions |
| Double Error Detection | 双错检测验证 | Pair combinations |
| Syndrome Decode Test | Syndrome 解码正确性 | All syndrome values |

**ECC Test Mode Signals**:

| Signal | Direction | Width | Description |
|--------|-----------|-------|-------------|
| ecc_test_mode_i | Input | 1 | ECC test mode enable |
| ecc_error_inject_i | Input | 7 | Error injection position |
| ecc_error_type_i | Input | 2 | Error type (0=single, 1=double) |
| ecc_test_addr_i | Input | 20 | Test address |

**ECC Test Sequence**:

```
ECC Single Error Test:
  1. Write known data to test address
  2. Inject single bit error at position 0-38
  3. Read data
  4. Verify:
     - Syndrome != 0
     - Corrected data matches original
     - ecc_err_type_o = 0 (single error)
     - ecc_corrected_o = 1
     
ECC Double Error Test:
  5. Write known data
  6. Inject double bit errors
  7. Read data
  8. Verify:
     - Syndrome != 0, parity fail
     - ecc_err_type_o = 1 (double error)
     - ecc_corrected_o = 0
     - IRQ triggered if enabled
```

### 3.4 Address Decoder Test

验证 Bank 选择和地址解码正确性。

| Test Type | Description | Coverage |
|-----------|-------------|----------|
| Bank Select Test | Address[16:19] Bank 选择 | All 16 banks |
| Boundary Test | Bank 边界地址访问 | 0x8000_0000, 0x8007_FFFF |
| Interleaving Test | Bank interleaving 功能 | Consecutive addresses |

## 4. Test Access Mechanism (TAM)

### 4.1 JTAG TAP Controller

| Signal | Direction | Width | Description |
|--------|-----------|-------|-------------|
| tck_i | Input | 1 | JTAG Test Clock |
| tms_i | Input | 1 | JTAG Test Mode Select |
| tdi_i | Input | 1 | JTAG Test Data Input |
| tdo_o | Output | 1 | JTAG Test Data Output |
| trst_n_i | Input | 1 | JTAG Test Reset |

**JTAG Instructions**:

| Instruction | Opcode | Description |
|-------------|--------|-------------|
| EXTEST | 0x00 | External test |
| SAMPLE | 0x01 | Sample boundary |
| INTEST | 0x02 | Internal test |
| IDCODE | 0x04 | Device ID |
| BYPASS | 0x0F | Bypass |
| USER1 | 0x08 | MBIST control |
| USER2 | 0x09 | ECC test control |
| USER3 | 0x0A | Margin test |

### 4.2 Memory BIST Access

| Access Method | Description |
|---------------|-------------|
| JTAG USER1 Instruction | MBIST 启动和状态读取 |
| Register Interface | ECC_SRAM_CTRL 寄存器配置 |
| Direct MBIST Signals | mbist_start/done/pass/fail |

### 4.3 Margin Test Access

SRAM 时序裕量测试。

| Signal | Direction | Width | Description |
|--------|-----------|-------|-------------|
| margin_test_en_i | Input | 1 | Margin test enable |
| margin_delay_i | Input | 8 | Timing margin adjustment |
| margin_result_o | Output | 2 | Pass/Margin/Fail |

## 5. Test Mode Definition

### 5.1 Test Mode Register

| Mode | Code | Description | Active Elements |
|------|------|-------------|-----------------|
| NORMAL_MODE | 0x00 | Functional operation | None |
| SCAN_MODE | 0x01 | Scan chain access | All 6 chains |
| MBIST_MODE | 0x02 | Memory BIST | MBIST controller |
| ECC_TEST_MODE | 0x03 | ECC injection test | ECC logic |
| MARGIN_TEST_MODE | 0x04 | Timing margin test | SRAM timing |
| POWER_TEST_MODE | 0x05 | Power mode test | Power control |
| BURN_IN_MODE | 0x06 | Burn-in stress | Selected banks |

### 5.2 Test Mode Control Signals

| Signal | Width | Description |
|--------|-------|-------------|
| test_mode_i | 3 | Test mode selection |
| test_start_i | 1 | Test start command |
| test_done_o | 1 | Test completion |
| test_pass_o | 1 | Pass indicator |
| test_fail_o | 1 | Fail indicator |
| test_error_code_o | 8 | Error detail |

## 6. Coverage Target

### 6.1 Memory Fault Coverage

| Fault Type | Target Coverage | Method |
|------------|-----------------|--------|
| Stuck-at Fault (Memory) | 100% | MBIST March C+ |
| Address Decoder Fault | 100% | Address decoder test |
| Coupling Fault | 100% | March C+ |
| Transition Fault | 100% | March C+ |
| Retention Fault | 95% | Retention test |

### 6.2 Logic Fault Coverage

| Fault Type | Target Coverage | Method |
|------------|-----------------|--------|
| Stuck-at Fault (Logic) | 98% | Scan + LBIST |
| Transition Fault | 95% | At-speed scan |
| Path Delay Fault | 92% | At-speed MBIST |

### 6.3 Module-Level Coverage

| Sub-Module | Stuck-at | Transition | Overall |
|------------|----------|------------|---------|
| SRAM Array | 100% | 100% | 100% |
| ECC Logic | 100% | 95% | 98% |
| Arbitration | 98% | 95% | 96% |
| Bus Interface | 95% | 92% | 94% |
| Power Control | 95% | 92% | 94% |

### 6.4 Test Time Estimation

| Test Type | Duration | Description |
|-----------|----------|-------------|
| MBIST Full Array | ~50 ms | 512 KB March C+ |
| ECC Test | ~10 ms | All error injections |
| Margin Test | ~5 ms | Timing margin sweep |
| Scan Chain | ~0.5 ms | Control logic scan |
| Total Test Time | ~70 ms | All modes combined |

## 7. DFT Implementation Notes

### 7.1 MBIST Design Guidelines

1. **Parallel Bank Test**: 128 Bank 可并行测试，减少测试时间。
2. **Test Point Insertion**: 每个 Bank 添加 test point 用于诊断。
3. **Repair Analysis**: MBIST 结果可用于 repair 分析 (备用的 column/row)。

### 7.2 ECC Test Guidelines

1. **Error Injection**: 通过 ECC_SRAM_CTRL 寄存器控制错误注入。
2. **Full Syndrome Coverage**: 测试所有 39-bit 位置的单错。
3. **IRQ Verification**: 验证错误中断触发正确性。

### 7.3 Power Test Guidelines

| Power Mode | Test Description |
|------------|------------------|
| Active | 正常访问功能验证 |
| Sleep (Retention ON) | 数据保持验证 |
| Deep Sleep (Power Gate) | Power Gate 序列测试 |

### 7.4 Test Integration

| Integration Point | Description |
|-------------------|-------------|
| M04 System Bus | Bus interface test coordination |
| M00/M09-M12 | Compute unit direct access test |
| M05 Power Manager | Power mode test coordination |
| M15 JTAG Interface | JTAG TAP access |

## 8. References

- IEEE 1149.1: JTAG Standard
- March C+ Algorithm: Standard memory BIST algorithm
- REQ-DFT-001: Test coverage >= 95%
- REQ-MEM-005: ECC SECDED protection
- M02 MAS.md: Module architecture specification