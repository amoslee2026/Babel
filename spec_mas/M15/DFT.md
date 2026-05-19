---
module: M15
type: DFT
status: complete
parent: null
module_type: io
generated: "2026-05-17T16:30:00+08:00"
---

# M15: JTAG Interface DFT Specification

## 1. Overview

M15 JTAG Interface 是 TinyStories NPU 的测试访问端口模块，DFT 设计重点包括：
- **TAP Controller Test**: IEEE 1149.1 TAP FSM 状态转换测试
- **IR/DR Path Test**: 指令寄存器和数据寄存器路径验证
- **Boundary Scan**: IEEE 1149.1 边界扫描实现

### 1.1 DFT Strategy Summary

| Strategy | Target | Coverage |
|----------|--------|----------|
| TAP FSM Test | 16 states + all transitions | 100% FSM coverage |
| IR Path Test | 16 instructions | 100% instruction coverage |
| DR Path Test | 8 data registers | 100% DR coverage |
| Boundary Scan | 24 pins | IEEE 1149.1 compliance |
| TEST_MODE Security | Gate validation | 100% security coverage |

### 1.2 Test Access Architecture

M15 是测试访问的顶层接口，直接连接外部 JTAG。

```
External JTAG (TCK/TMS/TDI/TDO/TRST)
    |
    v
M15 JTAG Interface
    |
    +-- TAP Controller FSM (16 states)
    |       |
    |       +-- IR Logic (Instruction Register)
    |       +-- DR Logic (Data Register selection)
    |
    +-- TEST_MODE Security Gate
    |       |
    |       +-- Instruction filtering
    |       +-- Access validation
    |
    +-- Boundary Scan Register (BSR)
    |       |
    |       +-- 24 Boundary Scan Cells
    |
    +-- Scan Chain Controller
            |
            +-- SC0-SC3 distribution
            +-- Scan protocol generation
```

## 2. Scan Chain Configuration

### 2.1 Scan Chain Distribution

M15 控制 4 条 Scan Chain 的访问和切换。

| Chain ID | Chain Name | Length | Target Modules | Description |
|----------|------------|--------|----------------|-------------|
| SC0 | Logic Chain 0 | ~10k cells | M00, M01, M08, M09 | Compute + Control |
| SC1 | Logic Chain 1 | ~10k cells | M02, M10, M11 | Storage + Operators |
| SC2 | Logic Chain 2 | ~10k cells | M03, M04, M12 | DRAM + Bus + SoftMax |
| SC3 | Logic Chain 3 | ~10k cells | M05, M06, M07, M13, M14 | AON + Control |

### 2.2 M15 Internal Scan Chain

M15 内部寄存器单独构成 mini-chain，用于 TAP 自测试。

| Register | Width | Scan Cells | Description |
|----------|-------|------------|-------------|
| IR Register | 5 | 5 | Instruction Register |
| IR Shadow | 5 | 5 | IR Shadow register |
| DR_BYPASS | 1 | 1 | Bypass register |
| DR_IDCODE | 32 | 32 | IDCODE register |
| DR_SCAN Control | 32 | 32 | Scan chain control |
| DR_DEBUG Control | 48 | 48 | Debug control register |
| DR_MBIST Control | 32 | 32 | MBIST control |
| BSR | 24 | 24 | Boundary Scan Register |
| TAP FSM State | 4 | 4 | FSM state register |
| TEST_MODE Regs | 8 | 8 | TEST_MODE control |
| **Total M15 Scan Cells** | | **~155** | |

### 2.3 Scan Chain Timing

| Parameter | Value | Description |
|-----------|-------|-------------|
| Scan Frequency | 50 MHz | TCK clock rate |
| Shift Rate | 1 bit/TCK | Standard scan shift |
| Capture Cycle | 1 TCK | Capture DR state |
| Update Cycle | 1 TCK | Update DR state |
| Chain Switch Latency | 2 TCK cycles | Chain selection overhead |
| Full Chip Scan Time | ~800 us | 40k cells @ 50 MHz |
| M15 Internal Scan | ~3.1 us | 155 cells @ 50 MHz |

### 2.4 Scan Control Signals

| Signal | Direction | Width | Description |
|--------|-----------|-------|-------------|
| scan_select | Internal | 4 | Chain select decoder output |
| scan_enable | Internal | 1 | Scan mode enable from TAP |
| scan_in_ch0-3 | Output | 4 | Scan data to each chain |
| scan_out_ch0-3 | Input | 4 | Scan data from each chain |
| scan_capture | Internal | 1 | Capture control from TAP |
| scan_update | Internal | 1 | Update control from TAP |

## 3. BIST Design

### 3.1 TAP Controller FSM Test

TAP FSM Test 验证 IEEE 1149.1 标准的 16 状态转换。

#### 3.1.1 TAP FSM Architecture

```
TAP FSM (16 states):
    +-- Test-Logic-Reset (0x0)
    +-- Run-Test/Idle (0x1)
    +-- Select-DR (0x2)
    +-- Capture-DR (0x3)
    +-- Shift-DR (0x4)
    +-- Exit1-DR (0x5)
    +-- Pause-DR (0x6)
    +-- Exit2-DR (0x7)
    +-- Update-DR (0x8)
    +-- Select-IR (0x9)
    +-- Capture-IR (0xA)
    +-- Shift-IR (0xB)
    +-- Exit1-IR (0xC)
    +-- Pause-IR (0xD)
    +-- Exit2-IR (0xE)
    +-- Update-IR (0xF)
```

#### 3.1.2 FSM Test Matrix

| Test Vector # | Current State | TMS | Expected Next State | Test Focus |
|---------------|---------------|-----|---------------------|------------|
| TV0 | Test-Logic-Reset | 0 | Run-Test/Idle | Reset exit |
| TV1 | Test-Logic-Reset | 1 | Test-Logic-Reset | Reset hold |
| TV2 | Run-Test/Idle | 0 | Run-Test/Idle | Idle hold |
| TV3 | Run-Test/Idle | 1 | Select-DR | Enter DR path |
| TV4 | Select-DR | 0 | Capture-DR | Enter DR capture |
| TV5 | Select-DR | 1 | Select-IR | Switch to IR path |
| TV6 | Capture-DR | 0 | Shift-DR | Begin shift |
| TV7 | Capture-DR | 1 | Exit1-DR | Quick exit |
| TV8 | Shift-DR | 0 | Shift-DR | Continue shift |
| TV9 | Shift-DR | 1 | Exit1-DR | End shift |
| TV10 | Exit1-DR | 0 | Pause-DR | Pause shift |
| TV11 | Exit1-DR | 1 | Update-DR | Apply update |
| TV12 | Pause-DR | 0 | Pause-DR | Hold pause |
| TV13 | Pause-DR | 1 | Exit2-DR | Resume path |
| TV14 | Exit2-DR | 0 | Shift-DR | Resume shift |
| TV15 | Exit2-DR | 1 | Update-DR | End operation |
| TV16-31 | IR path mirrors DR | Various | Various | IR path coverage |

#### 3.1.3 TAP FSM BIST Sequence

```
TAP_FSM_BIST_START:
    1. Apply TRST or TMS=1 for 5+ cycles (reset TAP)
    2. Verify state = Test-Logic-Reset
    
FSM_TEST_LOOP:
    For each test vector:
        3. Set current state via scan
        4. Apply TMS input
        5. Capture next state
        6. Compare with expected_next_state
        7. If mismatch: set fsm_error_flag
        8. Continue to next vector
        
TAP_FSM_BIST_DONE:
    9. Set fsm_bist_complete = 1
    10. Report pass/fail
```

### 3.2 IR/DR Path Test

IR/DR Path Test 验证所有指令和数据寄存器的正确行为。

#### 3.2.1 IR Test Matrix

| Instruction | Opcode | Expected IR Value | Expected DR Selected | Security |
|-------------|--------|-------------------|---------------------|----------|
| BYPASS | 0x0 | 0x0 | DR_BYPASS (1-bit) | Always allowed |
| IDCODE | 0x1 | 0x1 | DR_IDCODE (32-bit) | Always allowed |
| EXTEST | 0x2 | 0x2 | DR_BSR (24-bit) | TEST_MODE required |
| INTEST | 0x3 | 0x3 | DR_BSR (24-bit) | TEST_MODE required |
| SCAN_IN | 0x4 | 0x4 | DR_SCAN | TEST_MODE required |
| SCAN_OUT | 0x5 | 0x5 | DR_SCAN | TEST_MODE required |
| SCAN_CAPTURE | 0x6 | 0x6 | DR_SCAN | TEST_MODE required |
| DEBUG | 0x7 | 0x7 | DR_DEBUG (48-bit) | TEST_MODE required |
| MBIST_CTRL | 0x8 | 0x8 | DR_MBIST (32-bit) | TEST_MODE required |
| MBIST_STATUS | 0x9 | 0x9 | DR_MBIST (32-bit) | TEST_MODE required |
| USERCODE | 0xA | 0xA | DR_USERCODE (32-bit) | TEST_MODE required |
| HIGHZ | 0xB | 0xB | DR_BYPASS | TEST_MODE required |
| CLAMP | 0xC | 0xC | DR_BYPASS | TEST_MODE required |

#### 3.2.2 IR BIST Sequence

```
IR_PATH_BIST:
    For each instruction:
        1. Enter Select-IR -> Capture-IR -> Shift-IR
        2. Shift opcode via TDI
        3. Verify TDO echoes opcode (IR readback)
        4. Exit to Update-IR
        5. Capture selected DR via scan
        6. Verify DR_select matches opcode
        7. Test DR operation (shift data through)
        8. If TEST_MODE required: verify gate response
```

#### 3.2.3 DR Test Matrix

| DR | Width | Test Pattern | Test Operation |
|----|-------|--------------|----------------|
| DR_BYPASS | 1 | 0->1->0 | Shift through |
| DR_IDCODE | 32 | Expected IDCODE | Read and compare |
| DR_BSR | 24 | Walking-1/0 | Shift + capture + update |
| DR_SCAN | Variable | Chain test pattern | Select SC0-SC3, shift |
| DR_DEBUG | 48 | Address + data | Debug read/write test |
| DR_MBIST | 32 | Control + status | BIST start/status read |

### 3.3 Boundary Scan Test

Boundary Scan Test 验证 IEEE 1149.1 边界扫描功能。

#### 3.3.1 Boundary Scan Cell Assignment

| Cell # | Pin | Type | Direction | Description |
|--------|-----|------|-----------|-------------|
| 0 | POR_N | Input | Input only | Power-on reset input |
| 1-8 | ISA_IF[0:7] | Bidir | Bidir | ISA data bus lower |
| 9-10 | ISA_CLK, ISA_VALID | Bidir | Output | ISA control signals |
| 11 | ISA_DIR | Output | Output only | ISA direction control |
| 12 | ISA_READY | Input | Input only | ISA ready signal |
| 13 | SEC_BOOT_EN | Input | Input only | Secure boot enable |
| 14 | SEC_STATUS | Output | Output only | Security status |
| 15 | EXT_CLK | Input | Input only | External clock |
| 16 | WAKEUP | Input | Input only | Wakeup signal |
| 17-23 | Reserved | - | - | Reserved for expansion |

#### 3.3.2 EXTEST Test Sequence

```
EXTEST_BIST (TEST_MODE required):
    1. IR = EXTEST (0x2)
    2. Enter Capture-DR: capture all input pins
    3. Shift test pattern into BSR (output cells)
    4. Update-DR: drive outputs
    5. Capture-DR: capture input response
    6. Shift out captured data
    7. Verify input/output behavior
```

#### 3.3.3 INTEST Test Sequence

```
INTEST_BIST (TEST_MODE required):
    1. IR = INTEST (0x3)
    2. Capture-DR: capture internal signals
    3. Shift test stimulus into BSR
    4. Update-DR: apply stimulus to internal logic
    5. Capture-DR: capture internal response
    6. Shift out response
    7. Verify internal test capability
```

### 3.4 TEST_MODE Security Gate Test

TEST_MODE Gate Test 验证安全门控逻辑。

#### 3.4.1 TEST_MODE Gate Test Matrix

| Test Condition | TEST_MODE | Instruction | Expected Response |
|----------------|-----------|-------------|-------------------|
| No TEST_MODE | 0 | BYPASS | Allowed |
| No TEST_MODE | 0 | IDCODE | Allowed |
| No TEST_MODE | 0 | EXTEST | Blocked -> BYPASS |
| No TEST_MODE | 0 | DEBUG | Blocked -> BYPASS |
| TEST_MODE Valid | 1 (valid) | EXTEST | Allowed |
| TEST_MODE Invalid | 1 (invalid) | EXTEST | Blocked -> BYPASS |
| TEST_MODE Timeout | Expired | Any sensitive | Blocked |

#### 3.4.2 TEST_MODE Gate BIST

```
TEST_MODE_GATE_BIST:
    1. Set TEST_MODE = 0
    2. Attempt EXTEST instruction
    3. Verify instruction blocked (DR = BYPASS)
    4. Set TEST_MODE = 1 (with valid key)
    5. Attempt EXTEST instruction
    6. Verify instruction allowed (DR = BSR)
    7. Set TEST_MODE = 1 (with invalid key)
    8. Attempt EXTEST instruction
    9. Verify instruction blocked
    10. Set TEST_MODE timeout trigger
    11. Verify auto-disable after timeout
```

## 4. Test Access Mechanism

### 4.1 JTAG Interface (Primary)

M15 是外部 JTAG 的直接接口。

#### 4.1.1 JTAG Pin Interface

| Pin | Signal | Direction | Voltage | Description |
|-----|--------|-----------|---------|-------------|
| 5 | TCK | Input | 1.8V | Test Clock (50 MHz max) |
| 6 | TMS | Input | 1.8V | Test Mode Select |
| 7 | TDI | Input | 1.8V | Test Data In |
| 8 | TDO | Output | 1.8V | Test Data Out |
| 9 | TRST | Input | 1.8V | Test Reset (optional) |

#### 4.1.2 JTAG Timing Parameters

| Parameter | Symbol | Min | Max | Unit |
|-----------|--------|-----|-----|------|
| TCK Frequency | f_TCK | 0 | 50 | MHz |
| TCK Period | t_TCK | 20 | - | ns |
| TMS/TDI Setup | t_SU | 2 | - | ns |
| TMS/TDI Hold | t_H | 2 | - | ns |
| TDO Valid | t_DO | - | 5 | ns |

### 4.2 TEST_MODE Security Interface

TEST_MODE 从 M14 Security Manager 验证。

#### 4.2.1 TEST_MODE Signals

| Signal | Direction | Width | Description |
|--------|-----------|-------|-------------|
| test_mode_en | Input | 1 | TEST_MODE enable request |
| test_mode_valid | Input | 1 | TEST_MODE validation result |
| test_access_grant | Output | 1 | Access granted flag |
| test_access_denied | Output | 1 | Access denied flag (security alarm) |

#### 4.2.2 TEST_MODE Validation Protocol

```
TEST_MODE Validation (M14):
    1. JTAG sets test_mode_en = 1
    2. M14 validates physical access + test_mode_key
    3. If valid: test_mode_valid = 1
    4. If invalid: test_mode_valid = 0
    5. M15 gates sensitive instructions based on test_mode_valid
```

### 4.3 Scan Chain Interface

Scan Chain Interface 连接 4 条 Scan Chain。

#### 4.3.1 Scan Chain Selection Protocol

| DR_SCAN Field | Value | Selected Chain |
|---------------|-------|----------------|
| chain_select[0:3] | 0x0 | SC0 (M00, M01, M08, M09) |
| chain_select[0:3] | 0x1 | SC1 (M02, M10, M11) |
| chain_select[0:3] | 0x2 | SC2 (M03, M04, M12) |
| chain_select[0:3] | 0x3 | SC3 (M05-M07, M13, M14) |

#### 4.3.2 Scan Chain Control Signals

| Signal | Source | Destination | Description |
|--------|--------|-------------|-------------|
| scan_select | M15 | All modules | Chain decoder output |
| scan_enable | M15 | All modules | TAP Shift-DR state |
| scan_capture | M15 | All modules | TAP Capture-DR state |
| scan_update | M15 | All modules | TAP Update-DR state |

### 4.4 Debug Interface

Debug Interface 提供 JTAG DEBUG 指令支持。

#### 4.4.1 Debug Address/Data Protocol

```
DEBUG Access (IR = 0x7):
    DR_SHIFT:
        - TDI: debug_addr[0:15] + debug_data[16:47]
    DR_UPDATE:
        - Apply debug read/write
    DR_CAPTURE (next cycle):
        - TDO: debug_addr + debug_read_data (if read)
```

## 5. Test Mode Definition

### 5.1 Test Mode Levels

| Level | Name | Access | TEST_MODE Required |
|-------|------|--------|-------------------|
| 0 | Functional | BYPASS/IDCODE only | No |
| 1 | Scan Debug | Scan + Debug access | Yes (Level 1) |
| 2 | BIST Mode | MBIST + EXTEST/INTEST | Yes (Level 2) |
| 3 | Development | Full boundary scan | Yes (Level 3) |

### 5.2 Test Mode Entry via JTAG

```
Functional Mode (Level 0):
    - TAP active for BYPASS/IDCODE
    - TEST_MODE = 0
    - All sensitive instructions blocked

Enter Test Mode Level 1:
    1. JTAG physical connection established
    2. test_mode_en = 1 (via JTAG instruction)
    3. M14 validation: test_mode_key input
    4. test_mode_valid = 1
    5. SCAN/DEBUG instructions enabled

Enter Test Mode Level 2:
    1. Level 1 established
    2. MBIST_CTRL instruction allowed
    3. BIST execution enabled

Enter Test Mode Level 3:
    1. Level 2 established
    2. Full EXTEST/INTEST boundary scan
    3. Development access enabled
```

### 5.3 IEEE 1149.1 Compliance

M15 必须完全符合 IEEE 1149.1-2013 标准。

| Requirement | Implementation | Status |
|-------------|----------------|--------|
| TAP Controller | 16-state FSM | Required |
| Instruction Register | 5-bit IR + parity | Required |
| BYPASS Register | 1-bit DR | Required |
| IDCODE Register | 32-bit DR | Required |
| Boundary Scan Register | 24-bit BSR | Required |
| EXTEST Instruction | Pin external test | Required |
| INTEST Instruction | Internal test | Optional (implemented) |
| TEST_MODE Security | Access gating | Custom extension |

## 6. Coverage Target

### 6.1 Fault Coverage Target

| Coverage Type | Target | Method |
|---------------|--------|--------|
| TAP FSM Coverage | 100% | FSM BIST |
| IR Path Coverage | 100% | IR BIST |
| DR Path Coverage | 100% | DR BIST |
| Boundary Scan Coverage | 100% | BSR BIST |
| TEST_MODE Gate Coverage | 100% | Gate BIST |
| Scan Fault Coverage | 95%+ | ATPG |

### 6.2 ATPG Test Patterns

| Pattern Type | Count | Coverage | Description |
|--------------|-------|----------|-------------|
| Stuck-at Fault | ~80 | 95% | M15 internal scan cells |
| Transition Fault | ~30 | 90% | TAP state transitions |
| Path Delay | ~20 | 85% | Critical TCK paths |
| Bridging Fault | ~10 | 80% | Adjacent BSR cells |

### 6.3 Coverage Analysis

```
M15 DFT Coverage Summary:
    +-- TAP FSM Coverage: 100% (16 states + all transitions)
    +-- IR Path Coverage: 100% (13 instructions)
    +-- DR Path Coverage: 100% (6 DR types)
    +-- Boundary Scan Coverage: 100% (24 BSR cells)
    +-- TEST_MODE Gate Coverage: 100% (gate BIST)
    +-- Scan Fault Coverage: 95%+ (ATPG)
    +-- Total Coverage: >= 95% (combined)
```

## 7. Implementation Requirements

### 7.1 DFT RTL Requirements

| Requirement | Description |
|-------------|-------------|
| IEEE 1149.1 TAP | Full 16-state TAP controller |
| 5-bit IR + Parity | Instruction register with parity |
| 24-bit BSR | Boundary scan register for all IO pins |
| TEST_MODE Gate | Security gate for sensitive instructions |
| Scan Chain Controller | 4-chain distribution logic |
| Debug Interface | 48-bit debug access protocol |

### 7.2 Physical Design Requirements

| Parameter | Value | Description |
|-----------|-------|-------------|
| TAP Controller Area | < 0.02 mm² | FSM + IR/DR logic |
| BSR Area | < 0.03 mm² | 24 boundary scan cells |
| IO Buffer Area | < 0.05 mm² | JTAG pin buffers |
| Test Power | < 15 mW | JTAG operation power |
| BSR Placement | Adjacent to IO pads | Boundary scan cells |

### 7.3 Verification Requirements

| Test | Description | Standard |
|------|-------------|----------|
| TAP FSM | 16-state coverage | IEEE 1149.1-2013 |
| IR/DR Path | Instruction/DR operation | IEEE 1149.1-2013 |
| Boundary Scan | EXTEST/INTEST | IEEE 1149.1-2013 |
| TEST_MODE Security | Gate validation | Custom security |
| Timing Compliance | JTAG timing specs | IEEE 1149.1-2013 |
| Coverage Analysis | ATPG patterns | DFT standard |