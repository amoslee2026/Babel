---
module: M03
type: DFT
status: complete
parent: M03
module_type: storage
generated: "2026-05-17T16:30:00+08:00"
---

# M03: DRAM Controller - DFT Specification

## 1. Overview

M03 DRAM Controller 管理 2 GB 3D Stacked DRAM，DFT 策略重点覆盖 D2D Interface、Memory BIST、ECC Logic、PHY Test 四大测试对象。目标测试覆盖率 >= 95% (REQ-DFT-001)。

| Test Object | Coverage Target | Priority |
|-------------|-----------------|----------|
| D2D Interface | 100% | Highest |
| DRAM Controller Logic | 98% | Highest |
| ECC Logic | 100% | Highest |
| D2D PHY | 95% | High |

## 2. Scan Chain Configuration

### 2.1 Scan Chain Architecture

DRAM Controller 采用 Logic Scan + Memory BIST + PHY Test 混合架构。

| Chain Group | Chain ID | Elements | Length (FFs) | Description |
|--------------|----------|----------|--------------|-------------|
| LPDDR4X Protocol | SC0 | 1 chain | 1,200 | Protocol FSM + command logic |
| Bandwidth Arbiter | SC1 | 1 chain | 800 | Bandwidth arbitration logic |
| ECC Controller | SC2 | 1 chain | 600 | ECC generation + check logic |
| D2D Controller | SC3 | 1 chain | 500 | D2D interface control |
| Bus Interface | SC4 | 1 chain | 400 | TileLink/AXI interface |
| Power Control | SC5 | 1 chain | 300 | DRAM power mode logic |
| Status Registers | SC6 | 1 chain | 500 | Error + performance registers |

**Total Scan Chains**: 7 chains
**Total Scan Elements**: ~4,300 FFs

### 2.2 Scan Chain Interface

| Signal | Direction | Width | Description |
|--------|-----------|-------|-------------|
| scan_enable_i | Input | 1 | Global scan enable |
| scan_mode_i | Input | 2 | Scan mode selection |
| scan_in_i | Input | 7 | Scan data input |
| scan_out_o | Output | 7 | Scan data output |
| scan_clk_i | Input | 1 | Scan clock |
| scan_rst_n_i | Input | 1 | Scan reset |

### 2.3 Scan Chain Timing

| Parameter | Value | Description |
|-----------|-------|-------------|
| Scan Clock Frequency | 10-50 MHz | Test clock |
| Scan Chain Cycle | <= 1 ms | Max chain load/unload |
| Scan Capture Window | >= 10 ns | Setup + Hold margin |

## 3. BIST Design

### 3.1 Memory BIST (MBIST) for DRAM

由于 DRAM 是外部 Die，采用 D2D Loopback Test 策略。

| Parameter | Value | Description |
|-----------|-------|-------------|
| MBIST Controller | 1 instance | D2D loopback test controller |
| Algorithm | March C+ | Memory test via D2D interface |
| Address Range | 0x0000_0000 - 0x7FFF_FFFF | Full 2 GB coverage |
| Test Pattern | 0x0000, 0xFFFF, checkerboard, walking | Standard patterns |
| Test Time | ~500 ms | Full 2 GB test (estimate) |

**D2D Loopback Test Sequence**:

```
D2D Loopback Test:
  1. Enable D2D training mode (d2d_training_en = 1)
  2. Execute D2D lane calibration
  3. Write test pattern via D2D interface
  4. Read back and verify via D2D interface
  5. Compare data, log errors
  
Coverage:
  - D2D TX/RX paths
  - DRAM die functionality
  - ECC protection path
```

### 3.2 D2D Interface Test

D2D 接口测试覆盖 16-lane 互连。

| Test Type | Description | Coverage |
|-----------|-------------|----------|
| Lane Test | 16 lanes 独立测试 | 100% lane coverage |
| Clock Alignment | TX/RX clock alignment | PLL lock verification |
| Deskew Test | Lane deskew 校准 | All lane combinations |
| Training Sequence | D2D training 协议 | Training FSM coverage |

**D2D Test Signals**:

| Signal | Direction | Width | Description |
|--------|-----------|-------|-------------|
| d2d_test_mode_i | Input | 1 | D2D test enable |
| d2d_lane_mask_i | Input | 16 | Lane test mask |
| d2d_pattern_i | Input | 16 | Test pattern input |
| d2d_pattern_o | Output | 16 | Test pattern output |
| d2d_lane_status_o | Output | 16 | Lane pass/fail status |

**D2D Lane Test Sequence**:

```
D2D Lane Calibration Test:
  For each lane i = 0 to 15:
    1. Enable single lane (d2d_lane_mask = 1 << i)
    2. Transmit known pattern (e.g., 10101010)
    3. Receive pattern
    4. Verify pattern match
    5. Log lane status
    
  Aggregate lane status:
    - All 16 lanes pass: D2D ready
    - Any lane fail: report lane ID, retry calibration
```

### 3.3 PHY Test

D2D PHY 物理层测试。

| Test Type | Description | Coverage |
|-----------|-------------|----------|
| PLL Test | PLL lock 和稳定性 | PLL lock verification |
| Eye Width Test | 数据眼图宽度 >= 0.3 UI | Signal integrity |
| Eye Height Test | 数据眼图高度 >= 200 mV | Signal integrity |
| Jitter Test | 时钟抖动 < 0.1 UI | Jitter measurement |

**PHY Test Mode Signals**:

| Signal | Direction | Width | Description |
|--------|-----------|-------|-------------|
| phy_test_mode_i | Input | 2 | PHY test mode selection |
| phy_eye_width_o | Output | 8 | Eye width measurement (UI units) |
| phy_eye_height_o | Output | 8 | Eye height measurement (mV) |
| phy_jitter_o | Output | 8 | Jitter measurement |

### 3.4 ECC Test Design

SECDED (72,64) ECC 逻辑测试。

| Test Type | Description | Coverage |
|-----------|-------------|----------|
| No Error Test | Syndrome = 0 | Normal operation |
| Single Error Injection | 单错纠正 | All 72 bit positions |
| Double Error Detection | 双错检测 | Pair combinations |
| ECC Generation Test | Write path ECC 编码 | All data patterns |
| ECC Check Test | Read path ECC 检查 | All syndrome values |

**ECC Test Sequence**:

```
ECC Write Path Test:
  1. Generate test data (64-bit)
  2. Write via D2D interface
  3. Verify ECC encoding (72-bit) transmitted
  
ECC Read Path Test:
  4. Inject single bit error at position 0-71
  5. Read via D2D interface
  6. Verify:
     - Syndrome != 0
     - Corrected data matches original
     - ecc_err_type_o = 0
     
ECC Double Error Test:
  7. Inject double bit errors
  8. Verify detection, IRQ generation
```

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
| USER1 | 0x08 | D2D loopback test |
| USER2 | 0x09 | ECC test |
| USER3 | 0x0A | PHY test |

### 4.2 D2D Test Access

| Access Method | Description |
|---------------|-------------|
| JTAG USER1 | D2D loopback test control |
| Register Interface | D2D_CTRL 寄存器配置 |
| Direct D2D Signals | d2d_test_mode, lane_mask |

### 4.3 PHY Test Access

| Access Method | Description |
|---------------|-------------|
| JTAG USER3 | PHY test mode control |
| Register Interface | PHY status registers |
| Analog Test Points | PLL output, lane signals |

## 5. Test Mode Definition

### 5.1 Test Mode Register

| Mode | Code | Description | Active Elements |
|------|------|-------------|-----------------|
| NORMAL_MODE | 0x00 | Functional operation | None |
| SCAN_MODE | 0x01 | Scan chain access | All 7 chains |
| D2D_LOOPBACK | 0x02 | D2D interface test | D2D controller |
| ECC_TEST_MODE | 0x03 | ECC injection test | ECC logic |
| PHY_TEST_MODE | 0x04 | PHY signal test | D2D PHY |
| POWER_TEST_MODE | 0x05 | DRAM power mode test | Power control |
| BURN_IN_MODE | 0x06 | Burn-in stress | Selected regions |

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

### 6.1 D2D Interface Fault Coverage

| Fault Type | Target Coverage | Method |
|------------|-----------------|--------|
| Lane Fault | 100% | Lane test |
| Clock Alignment Fault | 100% | Training sequence |
| Deskew Fault | 100% | Lane calibration |
| Signal Integrity | 95% | Eye/Jitter test |

### 6.2 Logic Fault Coverage

| Fault Type | Target Coverage | Method |
|------------|-----------------|--------|
| Stuck-at Fault | 98% | Scan + LBIST |
| Transition Fault | 95% | At-speed scan |
| Path Delay Fault | 92% | At-speed D2D test |

### 6.3 Module-Level Coverage

| Sub-Module | Stuck-at | Transition | Overall |
|------------|----------|------------|---------|
| LPDDR4X Protocol | 98% | 95% | 96% |
| Bandwidth Arbiter | 98% | 95% | 96% |
| ECC Logic | 100% | 95% | 98% |
| D2D Controller | 98% | 95% | 96% |
| D2D PHY | 95% | 92% | 94% |

### 6.4 Test Time Estimation

| Test Type | Duration | Description |
|-----------|----------|-------------|
| D2D Loopback Test | ~500 ms | 2 GB DRAM test |
| D2D Lane Calibration | ~100 us | 16 lanes calibration |
| ECC Test | ~10 ms | All error injections |
| PHY Test | ~5 ms | Eye/Jitter measurement |
| Scan Chain | ~1 ms | Control logic scan |
| Total Test Time | ~520 ms | All modes combined |

## 7. DFT Implementation Notes

### 7.1 D2D Test Guidelines

1. **Loopback Mode**: D2D 接口支持内部 loopback 测试，不依赖外部 DRAM die。
2. **Lane Repair**: 单 lane 失败可通过 lane masking 绕过，保持系统功能。
3. **Training Verification**: 每次初始化后执行 D2D training 验证。

### 7.2 ECC Test Guidelines

1. **Error Injection**: 通过 ECC_CTRL 寄存器控制错误注入。
2. **Full Coverage**: 测试所有 72-bit 位置的单错。
3. **IRQ Test**: 验证错误中断触发和清除机制。

### 7.3 PHY Test Guidelines

1. **Built-in Eye Monitor**: PHY 内置 eye monitor 用于信号完整性测试。
2. **Jitter Measurement**: PLL jitter 实时测量。
3. **Margin Analysis**: PHY timing margin 分析。

### 7.4 Power Test Guidelines

| Power Mode | Test Description |
|------------|------------------|
| Active | 正常 DRAM 访问 |
| Self-Refresh | 自刷新进入/退出验证 |
| Deep Power Down | 深度功耗模式验证 |

### 7.5 Test Integration

| Integration Point | Description |
|-------------------|-------------|
| M04 System Bus | Bus interface test coordination |
| M05 Power Manager | DRAM power mode coordination |
| M15 JTAG Interface | JTAG TAP access |
| DRAM Die | External DRAM test coordination |

## 8. References

- IEEE 1149.1: JTAG Standard
- LPDDR4X Specification: JEDEC standard
- REQ-DFT-001: Test coverage >= 95%
- REQ-D2D-001: D2D interface specification
- REQ-MEM-005: ECC SECDED protection
- M03 MAS.md: Module architecture specification