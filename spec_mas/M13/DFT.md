---
module: M13
type: DFT
status: complete
parent: null
module_type: control
generated: "2026-05-17T16:30:00+08:00"
---

# M13: ISA Decoder DFT Specification

## 1. Overview

M13 ISA Decoder 是 TinyStories NPU 的指令解码单元，DFT 设计重点包括：
- **Scan Chain**: 全内部寄存器可扫描，支持 ATPG
- **Decode Logic Test**: 所有32条指令解码路径测试
- **Micro-op Generation Test**: 算子分发逻辑验证

### 1.1 DFT Strategy Summary

| Strategy | Target | Coverage |
|----------|--------|----------|
| Full Scan | 100% registers | 95%+ fault coverage |
| Instruction Decode BIST | 32 ISA opcodes | 100% opcode coverage |
| Dispatch Path Test | 7 target modules | 100% path coverage |
| Register File BIST | ISA Registers | 100% register coverage |

### 1.2 Test Access Architecture

```
JTAG TAP (M15)
    |
    v
TEST_MODE Gate
    |
    v
Scan Chain Controller
    |
    +-- SC3 (M13 registers) --> Decode Logic --> Dispatch Logic
    |
    v
BIST Controller
    |
    +-- Instruction Decode BIST
    +-- Register File BIST
    +-- Dispatch Path BIST
```

## 2. Scan Chain Configuration

### 2.1 Scan Chain Assignment

M13 寄存器分配到 **Scan Chain 3 (SC3)**，与 M05, M06, M07 共享。

| Chain ID | Chain Name | Length | Modules | M13 Cells |
|----------|------------|--------|---------|-----------|
| SC3 | Logic Chain 3 | ~10k cells | M05, M06, M07, M13 | ~2,500 cells |

### 2.2 Scan Chain Cell List

| Register | Width | Scan Cells | Description |
|----------|-------|------------|-------------|
| ISA_CTRL | 32 | 32 | 控制寄存器 |
| ISA_INST | 32 | 32 | 当前指令寄存器 |
| ISA_OP | 32 | 32 | 解码操作码寄存器 |
| ISA_RD | 32 | 32 | 目标寄存器索引 |
| ISA_RS1 | 32 | 32 | 源寄存器1索引 |
| ISA_RS2 | 32 | 32 | 源寄存器2索引 |
| ISA_IMM | 32 | 32 | 立即数寄存器 |
| ISA_PC | 32 | 32 | Program Counter |
| ISA_STATUS | 32 | 32 | 状态寄存器 |
| ISA_ERROR | 32 | 32 | 错误寄存器 |
| Decode Pipeline Registers | 4×32 | 128 | S0-S3 pipeline stages |
| Dispatch Registers | 16 | 16 | Target selection + handshake |
| **Total Scan Cells** | | **~370** | |

### 2.3 Scan Chain Timing

| Parameter | Value | Description |
|-----------|-------|-------------|
| Scan Frequency | 50 MHz | TCK clock rate |
| Shift Rate | 1 bit/TCK | Standard scan shift |
| Capture Cycle | 1 TCK | Capture DR state |
| Update Cycle | 1 TCK | Update DR state |
| Full Scan Time | ~74 us | 370 cells @ 50 MHz |

### 2.4 Scan Control Signals

| Signal | Direction | Width | Description |
|--------|-----------|-------|-------------|
| scan_select | Input | 4 | Chain select (SC3 = 0x3) |
| scan_enable | Input | 1 | Scan mode enable |
| scan_in | Input | 1 | Scan data input (from M15) |
| scan_out | Output | 1 | Scan data output (to M15) |
| scan_capture | Input | 1 | Capture control |
| scan_update | Input | 1 | Update control |

## 3. BIST Design

### 3.1 Instruction Decode BIST

Instruction Decode BIST 验证所有32条 ISA 指令的正确解码。

#### 3.1.1 BIST Architecture

```
Instruction Decode BIST Controller
    |
    +-- Instruction Generator (32 test vectors)
    |       |
    |       +-- Opcode 0x00-0x34 coverage
    |       +-- Format V/VI/M/S coverage
    |       +-- Field extraction test
    |
    +-- Decode Logic Monitor
    |       |
    |       +-- Opcode match check
    |       +-- Format match check
    |       +-- Operand extraction check
    |
    +-- Result Comparator
            |
            +-- Expected vs Actual
            +-- Pass/Fail reporting
```

#### 3.1.2 Test Vector Definition

| Test Vector # | Opcode | Format | Expected Fields | Test Focus |
|---------------|--------|--------|-----------------|------------|
| TV0 | 0x00 (VADD) | V | vd, vs1, vs2, func | V-Type decode |
| TV1 | 0x01 (VMUL) | V | vd, vs1, vs2, func | V-Type decode |
| TV2 | 0x02 (VSMUL) | VI | vd, vs1, imm16 | VI-Type decode |
| TV3 | 0x03 (VMAC) | V | vd, vs1, vs2, func | V-Type decode |
| TV4 | 0x04 (VSUB) | V | vd, vs1, vs2, func | V-Type decode |
| TV5 | 0x05 (VCOPY) | V | vd, vs1, func | V-Type decode |
| TV6 | 0x08 (MLOAD) | M | vd, base, sd, offset11 | M-Type decode |
| TV7 | 0x09 (MMUL) | V | vd, vs1, base, func | MatMul dispatch |
| TV8 | 0x0A (MSET_DIM) | S | sd, imm21 | S-Type decode |
| TV9-13 | 0x10-0x14 | V | vd, vs1, func | Special func decode |
| TV14-17 | 0x18-0x1B | V | vd, vs1, func | Reduction decode |
| TV18-23 | 0x20-0x25 | M/S | Various | Memory decode |
| TV24-26 | 0x28-0x2A | V/S/M | Various | KV Cache decode |
| TV27-31 | 0x30-0x34 | S | sd, imm21 | Scalar/Control decode |

#### 3.1.3 BIST Sequence

```
BIST_START:
    1. Initialize BIST controller
    2. Set test_vector_index = 0
    
TEST_LOOP:
    3. Load instruction_test_vector[test_vector_index]
    4. Apply to ISA_INST register
    5. Trigger decode cycle
    6. Capture decode outputs (opcode, format, fields)
    7. Compare with expected values
    8. If mismatch: set error flag, record error_vector
    9. test_vector_index++
    10. If test_vector_index < 32: goto TEST_LOOP
    
BIST_DONE:
    11. Set bist_complete = 1
    12. Report pass/fail status
    13. If fail: output error_vector to ISA_ERROR
```

#### 3.1.4 BIST Timing

| Parameter | Value | Description |
|-----------|-------|-------------|
| Test Vector Count | 32 | All ISA opcodes |
| Decode Latency | 4 cycles | Per instruction |
| Total BIST Time | 128 cycles + setup | ~256 ns @ 500 MHz |
| Error Reporting | 2 cycles | Per mismatch |

### 3.2 Micro-op Generation Test (Dispatch BIST)

Dispatch BIST 验证算子分发逻辑的正确性。

#### 3.2.1 Dispatch Target Test Matrix

| Opcode Range | Target Module | Test ID | Expected op_target |
|--------------|---------------|---------|-------------------|
| 0x00-0x05 | M09/M10/M11 | D0-D5 | 0x1-0x3 |
| 0x08-0x0A | M00 | D6-D8 | 0x0 |
| 0x10-0x14 | M11/M12 | D9-D13 | 0x3-0x4 |
| 0x18-0x1B | M09/M12 | D14-D17 | 0x1-0x4 |
| 0x20-0x25 | M02/M03 | D18-D23 | Memory interface |
| 0x28-0x2A | M09 | D24-D26 | 0x1 |
| 0x30-0x34 | M13 | D27-D31 | Internal scalar |

#### 3.2.2 Dispatch BIST Sequence

```
DISPATCH_BIST:
    For each opcode in test matrix:
        1. Decode instruction
        2. Check op_target_o matches expected
        3. Verify handshake signals (op_valid, op_ready)
        4. Simulate op_start -> op_done handshake
        5. Record dispatch success/failure
```

### 3.3 Register File BIST

ISA Register File BIST 验证所有寄存器的读写功能。

#### 3.3.1 Register BIST Algorithm

```
REGISTER_BIST:
    For each register in ISA register file:
        1. Write test pattern A (0xAAAAAAAA)
        2. Read back and verify
        3. Write test pattern B (0x55555555)
        4. Read back and verify
        5. Write walking-1 pattern (bit-by-bit)
        6. Read back and verify
        7. Write walking-0 pattern
        8. Read back and verify
        9. Record error if mismatch
```

#### 3.3.2 Register Coverage

| Register Set | Count | Test Pattern | Coverage |
|--------------|-------|--------------|----------|
| ISA_CTRL | 1 | All patterns | 100% |
| ISA_INST | 1 | All patterns | 100% |
| ISA_OP/ISA_RD/ISA_RS1/ISA_RS2 | 4 | All patterns | 100% |
| ISA_IMM | 1 | All patterns | 100% |
| ISA_PC | 1 | All patterns | 100% |
| ISA_STATUS | 1 | Read-only + status bits | 100% |
| ISA_ERROR | 1 | Error injection + read | 100% |

## 4. Test Access Mechanism

### 4.1 JTAG Interface

M13 通过 M15 JTAG Interface 接入测试访问。

#### 4.1.1 JTAG Instruction Support

| Instruction | Opcode | DR | M13 Access | Security |
|-------------|--------|-----|------------|----------|
| BYPASS | 0x0 | 1-bit | None | Always |
| IDCODE | 0x1 | 32-bit | None | Always |
| SCAN_IN/OUT/CAPTURE | 0x4-0x6 | Variable | SC3 registers | TEST_MODE |
| DEBUG | 0x7 | 48-bit | ISA registers | TEST_MODE |
| MBIST_CTRL | 0x8 | 32-bit | Decode BIST start | TEST_MODE |
| MBIST_STATUS | 0x9 | 32-bit | BIST result read | TEST_MODE |

#### 4.1.2 Debug Address Map (M13)

| Address | Register | Access | Description |
|---------|----------|--------|-------------|
| 0x8000 | ISA_CTRL | RW | Control register |
| 0x8004 | ISA_INST | RW | Instruction register |
| 0x8008 | ISA_OP | R | Opcode register |
| 0x800C | ISA_RD | R | Destination register |
| 0x8010 | ISA_RS1 | R | Source register 1 |
| 0x8014 | ISA_RS2 | R | Source register 2 |
| 0x8018 | ISA_IMM | R | Immediate register |
| 0x801C | ISA_PC | RW | Program Counter |
| 0x8020 | ISA_STATUS | R | Status register |
| 0x802C | ISA_ERROR | R | Error register |

### 4.2 TEST_MODE Security Gate

M13 需 TEST_MODE 验证才能访问敏感测试功能。

#### 4.2.1 TEST_MODE Requirements

| Test Function | TEST_MODE Required | Security Level |
|---------------|-------------------|----------------|
| Scan Chain Access | Yes | Level 1 |
| Debug Register Access | Yes | Level 1 |
| BIST Start | Yes | Level 2 |
| Error Injection | Yes | Level 2 |

#### 4.2.2 TEST_MODE Validation Flow

```
TEST_MODE Request (from M15 JTAG):
    |
    v
M14 Security Manager Validation
    |
    v
Check sec_boot_en AND test_mode_valid
    |
    +-- Invalid: Reject, return BYPASS
    |
    v
test_access_grant = 1
    |
    v
Allow M13 test access
```

### 4.3 Internal Test Interface

| Signal | Direction | Width | Description |
|--------|-----------|-------|-------------|
| bist_start | Input | 1 | BIST start trigger |
| bist_opcode | Input | 6 | BIST opcode select |
| bist_complete | Output | 1 | BIST completion flag |
| bist_pass | Output | 1 | BIST pass flag |
| bist_error | Output | 32 | BIST error vector |
| error_inject | Input | 4 | Error injection control |

## 5. Test Mode Definition

### 5.1 Test Mode Levels

| Level | Name | Access | Description |
|-------|------|--------|-------------|
| 0 | Functional | None | Normal operation, no test access |
| 1 | Scan Debug | Scan + Debug | Scan chain + register debug access |
| 2 | BIST Mode | All | Full BIST execution + error injection |
| 3 | Development | All + OTP | OTP access (development only) |

### 5.2 Test Mode Entry Sequence

```
Functional Mode (Level 0):
    - Normal decode operation
    - No scan/debug access
    - TEST_MODE = 0

Enter Test Mode Level 1:
    1. JTAG: IR=DEBUG/SCAN
    2. TEST_MODE validation (M14)
    3. test_mode_valid = 1
    4. Scan chain enabled
    5. Debug register access enabled

Enter Test Mode Level 2:
    1. JTAG: IR=MBIST_CTRL
    2. TEST_MODE Level 2 validation
    3. BIST controller enabled
    4. Error injection enabled
```

### 5.3 Test Mode Timing

| Mode | Frequency | Duration | Constraint |
|------|-----------|----------|------------|
| Functional | 250-500 MHz | Unlimited | Normal operation |
| Scan Mode | 50 MHz (TCK) | Unlimited | TEST_MODE timeout 10 min |
| BIST Mode | 500 MHz | ~1 ms | BIST execution time |

## 6. Coverage Target

### 6.1 Fault Coverage Target

| Coverage Type | Target | Method |
|---------------|--------|--------|
| Scan Fault Coverage | >= 95% | ATPG (Synopsys/TetraMAX) |
| Opcode Decode Coverage | 100% | Instruction Decode BIST |
| Dispatch Path Coverage | 100% | Dispatch BIST |
| Register Coverage | 100% | Register File BIST |

### 6.2 ATPG Test Patterns

| Pattern Type | Count | Coverage | Description |
|--------------|-------|----------|-------------|
| Stuck-at Fault | ~500 | 95% | Standard stuck-at patterns |
| Transition Fault | ~200 | 90% | At-speed transition test |
| Path Delay | ~100 | 85% | Critical path timing |
| Bridging Fault | ~50 | 80% | Adjacent cell bridging |

### 6.3 Coverage Analysis

```
M13 DFT Coverage Summary:
    +-- Scan Coverage: 95% (370 cells, ATPG patterns)
    +-- BIST Coverage: 100% (32 opcodes + 7 dispatch paths)
    +-- Total Fault Coverage: >= 95% (combined)
```

### 6.4 Coverage Reporting

| Report | Content | Tool |
|--------|---------|------|
| ATPG Report | Fault coverage, pattern count | Synopsys TetraMAX |
| BIST Report | Opcode/dispatch coverage | Internal BIST controller |
| Coverage Summary | Combined coverage | DFT integration script |

## 7. Implementation Requirements

### 7.1 DFT RTL Requirements

| Requirement | Description |
|-------------|-------------|
| Scan Insertion | All registers must have scan capability |
| BIST Controller | Integrated Instruction Decode + Dispatch + Register BIST |
| TEST_MODE Gate | All test access gated by TEST_MODE validation |
| Debug Interface | JTAG DEBUG instruction support |

### 7.2 Physical Design Requirements

| Parameter | Value | Description |
|-----------|-------|-------------|
| Scan Chain Routing | Balanced | SC3 length ~2,500 cells |
| BIST Area | < 0.05 mm² | BIST controller overhead |
| Test Power | < 100 mW | Scan + BIST peak power |

### 7.3 Verification Requirements

| Test | Description | Tool |
|------|-------------|------|
| Scan Chain Integrity | Scan shift/capture/update | Verilator + formal |
| BIST Functionality | Instruction Decode BIST | Verilator simulation |
| TEST_MODE Security | Gate validation | Security verification |
| Coverage Analysis | ATPG pattern generation | Synopsys TetraMAX |