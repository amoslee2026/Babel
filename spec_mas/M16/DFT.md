---
module: M16
type: DFT
status: complete
parent: null
module_type: io
generated: "2026-05-17T16:30:00+08:00"
---

# M16: ISA Interface DFT Specification

## 1. Overview

M16 ISA Interface 是 TinyStories NPU 的指令 IO 接口模块，DFT 设计重点包括：
- **CDC Test**: 跨时钟域同步逻辑测试
- **Handshake Protocol Test**: 接收/发送协议验证
- **Instruction Parser Test**: 指令数据解析逻辑测试

### 1.1 DFT Strategy Summary

| Strategy | Target | Coverage |
|----------|--------|----------|
| CDC Verification | 2-stage synchronizer + handshake | 100% CDC coverage |
| Handshake Protocol | Receive/Transmit FSM | 100% FSM coverage |
| Instruction Parser | 16-bit data parsing | 100% data path coverage |
| IO Timing Test | Setup/Hold timing | 100% timing coverage |
| Boundary Scan | ISA pin BSR cells | IEEE 1149.1 compliant |

### 1.2 Test Access Architecture

```
JTAG TAP (M15)
    |
    v
TEST_MODE Gate
    |
    v
M16 DFT Controller
    |
    +-- CDC Test Controller
    |       |
    |       +-- Synchronizer test
    |       +-- Handshake verification
    |       +-- Metastability injection
    |
    +-- Handshake Protocol BIST
    |       |
    |       +-- Receive FSM test
    |       +-- Transmit FSM test
    |       +-- Turnaround test
    |
    +-- Instruction Parser BIST
            |
            +-- Data path test
            +-- Direction control test
            +-- Buffer test
```

### 1.3 CDC Criticality

**CDC is the primary DFT challenge for M16:**
- CLK_IO (50 MHz) -> CLK_SYS (200 MHz) crossing
- Multi-bit data requires handshake protocol
- Metastability protection via 2-stage synchronizer

## 2. Scan Chain Configuration

### 2.1 Scan Chain Assignment

M16 不分配到主要 Scan Chain，内部寄存器构成独立 mini-chain 用于 IO 测试。

| Chain Name | Length | Description |
|-------------|--------|-------------|
| M16 Mini-Chain | ~80 cells | IO-specific registers |
| BSR Chain | 15 cells | ISA pin boundary scan |

### 2.2 Scan Chain Cell List

| Register | Width | Scan Cells | Description |
|----------|-------|------------|-------------|
| isa_data_io | 16 | 16 | IO domain data buffer |
| isa_data_sys | 16 | 16 | System domain data buffer |
| isa_valid_io | 1 | 1 | IO domain valid flag |
| isa_valid_sys | 1 | 1 | System domain valid flag |
| isa_dir | 1 | 1 | Direction control |
| isa_mode | 2 | 2 | Operation mode |
| sync_stage_1 | 16 | 16 | CDC stage 1 |
| sync_stage_2 | 16 | 16 | CDC stage 2 |
| handshake_regs | 8 | 8 | Handshake control registers |
| FSM_state | 4 | 4 | Protocol FSM state |
| **Total M16 Scan Cells** | | **~80** | |

### 2.3 Boundary Scan Register (BSR)

M16 BSR 连接到 M15 Boundary Scan Chain。

| BSR Cell # | Pin | Type | Description |
|------------|-----|------|-------------|
| 1-8 | ISA_IF[0:7] | Bidir | ISA data lower byte |
| 9-10 | ISA_CLK, ISA_VALID | Output | ISA control signals |
| 11 | ISA_DIR | Output | Direction control |
| 12 | ISA_READY | Input | External ready signal |
| **Total BSR Cells** | | **15** | Part of M15 BSR chain |

### 2.4 Scan Chain Timing

| Parameter | Value | Description |
|-----------|-------|-------------|
| Scan Frequency | 50 MHz | TCK clock rate |
| Shift Rate | 1 bit/TCK | Standard scan shift |
| Capture Cycle | 1 TCK | Capture DR state |
| Update Cycle | 1 TCK | Update DR state |
| M16 Mini-Chain Scan | ~1.6 us | 80 cells @ 50 MHz |

## 3. BIST Design

### 3.1 CDC Test

CDC Test 是 M16 最关键的 DFT 功能，验证跨时钟域同步的正确性。

#### 3.1.1 CDC Test Architecture

```
CDC Test Controller
    |
    +-- Input CDC Test (CLK_IO -> CLK_SYS)
    |       |
    |       +-- Data synchronizer test
    |       +-- Valid signal synchronizer test
    |       +-- Metastability injection
    |       +-- Latency measurement
    |
    +-- Output CDC Test (CLK_SYS -> CLK_IO)
    |       |
    |       +-- Handshake request test
    |       +-- Acknowledge synchronizer test
    |       +-- Timing alignment test
    |
    +-- Gray Counter Test (for FIFO pointers)
            |
            +-- Gray encoding verification
            +-- Single-bit change per increment
```

#### 3.1.2 CDC Test Vectors

| Test Vector # | Domain Crossing | Test Focus | Expected Behavior |
|---------------|-----------------|------------|-------------------|
| TV0 | Data input CDC | 2-stage sync | Data stable after 2 CLK_SYS cycles |
| TV1 | Valid signal CDC | Edge detection | Valid detected after sync |
| TV2 | Handshake request | Req->Ack cycle | Ack within 3 CLK_IO cycles |
| TV3 | Metastability injection | Setup violation | Recovery within MTBF spec |
| TV4 | Gray counter | Sequential increment | Single-bit change per cycle |
| TV5 | Back-to-back transfer | Consecutive data | No data loss |

#### 3.1.3 CDC BIST Sequence

```
CDC_BIST_START:
    1. Initialize CDC test controller
    
INPUT_CDC_TEST:
    2. Apply data pattern to ISA_IF (CLK_IO domain)
    3. Trigger valid signal (CLK_IO domain)
    4. Wait 2 CLK_SYS cycles
    5. Capture isa_data_sys
    6. Compare with expected data
    7. Measure CDC latency
    
METASTABILITY_TEST:
    8. Apply timing violation (edge case setup/hold)
    9. Monitor sync_stage_1 for metastability
    10. Wait settling time
    11. Verify sync_stage_2 stability
    
OUTPUT_CDC_TEST:
    12. Set isa_req_sys (CLK_SYS domain)
    13. Monitor handshake completion
    14. Verify data alignment in CLK_IO domain
    
CDC_BIST_DONE:
    15. Report CDC pass/fail
    16. Report latency measurements
```

#### 3.1.4 CDC Timing Requirements

| Parameter | Requirement | Test Target |
|-----------|-------------|-------------|
| CDC Latency (Input) | <= 3 CLK_SYS cycles | Measured <= 15 ns |
| CDC Latency (Output) | <= 3 CLK_IO cycles | Measured <= 60 ns |
| Metastability MTBF | > 10^6 cycles | Formal verification |
| Gray Counter | Single-bit change | Sequential test |

### 3.2 Handshake Protocol Test

Handshake Protocol Test 验证接收和发送状态机的正确性。

#### 3.2.1 Receive FSM Test

```
Receive FSM States:
    IDLE -> WAIT_READY -> SAMPLE_DATA -> VALID_ASSERT -> CDC_SYNC -> COMPLETE
```

| FSM Test # | State Transition | Trigger | Expected Action |
|------------|------------------|---------|-----------------|
| R0 | IDLE -> WAIT_READY | ISA_READY=1 | Set ISA_DIR=0 |
| R1 | WAIT_READY -> SAMPLE_DATA | ISA_CLK edge | Sample ISA_IF |
| R2 | SAMPLE_DATA -> VALID_ASSERT | Data stable | Set ISA_VALID=1 |
| R3 | VALID_ASSERT -> CDC_SYNC | Valid asserted | Start CDC sync |
| R4 | CDC_SYNC -> COMPLETE | Sync done | Set isa_valid_sys=1 |
| R5 | COMPLETE -> IDLE | Transfer done | Clear flags |

#### 3.2.2 Transmit FSM Test

```
Transmit FSM States:
    IDLE -> WAIT_DATA -> CDC_SYNC -> DRIVE_BUS -> VALID_ASSERT -> WAIT_READY -> COMPLETE
```

| FSM Test # | State Transition | Trigger | Expected Action |
|------------|------------------|---------|-----------------|
| T0 | IDLE -> WAIT_DATA | isa_data_sys ready | Set ISA_DIR=1 |
| T1 | WAIT_DATA -> CDC_SYNC | Data available | Start CDC sync |
| T2 | CDC_SYNC -> DRIVE_BUS | Sync done | Drive ISA_IF |
| T3 | DRIVE_BUS -> VALID_ASSERT | Bus driven | Set ISA_VALID=1 |
| T4 | VALID_ASSERT -> WAIT_READY | Valid asserted | Wait ISA_READY |
| T5 | WAIT_READY -> COMPLETE | ISA_READY=1 | Transfer done |
| T6 | COMPLETE -> IDLE | Transfer done | Clear flags |

#### 3.2.3 Turnaround Test

Turnaround Test 验证方向切换的正确性。

| Test # | Current Direction | Target Direction | Turnaround Time | Expected Behavior |
|--------|-------------------|------------------|-----------------|-------------------|
| TT0 | Receive (DIR=0) | Transmit (DIR=1) | 1 CLK_IO cycle | ISA_IF tri-state -> driven |
| TT1 | Transmit (DIR=1) | Receive (DIR=0) | 1 CLK_IO cycle | ISA_IF driven -> tri-state |
| TT2 | Back-to-back receive | Receive | 0 cycles | No turnaround needed |
| TT3 | Back-to-back transmit | Transmit | 0 cycles | No turnaround needed |

#### 3.2.4 Handshake BIST Sequence

```
HANDSHAKE_BIST_START:
    1. Initialize FSM to IDLE
    
RECEIVE_FSM_TEST:
    For each receive state transition:
        2. Set trigger condition
        3. Capture FSM next state
        4. Verify expected action
        5. Record pass/fail
        
TRANSMIT_FSM_TEST:
    For each transmit state transition:
        6. Set trigger condition
        7. Capture FSM next state
        8. Verify expected action
        9. Record pass/fail
        
TURNAROUND_TEST:
    10. Execute direction switch test
    11. Measure turnaround time
    12. Verify bus control transition
    
HANDSHAKE_BIST_DONE:
    13. Report FSM coverage
    14. Report timing measurements
```

### 3.3 Instruction Parser Test

Instruction Parser Test 验证 16-bit 指令数据的解析和缓冲。

#### 3.3.1 Parser Test Matrix

| Test # | Input Data | Parser Action | Expected Output |
|--------|------------|---------------|-----------------|
| P0 | 0x0000 | Parse + buffer | isa_data_sys=0x0000 |
| P1 | 0xFFFF | Parse + buffer | isa_data_sys=0xFFFF |
| P2 | Walking-1 (bit-by-bit) | Parse each | Correct data per bit |
| P3 | Walking-0 (bit-by-bit) | Parse each | Correct data per bit |
| P4 | Alternating 0x5555/0xAAAA | Alternating parse | Correct alternation |
| P5 | Back-to-back data | Buffer FIFO | FIFO depth test |

#### 3.3.2 Parser BIST Sequence

```
PARSER_BIST_START:
    1. Initialize parser + buffer
    
DATA_PARSE_TEST:
    For each test vector:
        2. Apply input data to ISA_IF
        3. Trigger parse cycle
        4. Capture isa_data_sys
        5. Compare with expected
        6. Record pass/fail
        
BUFFER_TEST:
    7. Fill input FIFO to max depth
    8. Verify FIFO overflow handling
    9. Drain FIFO
    10. Verify FIFO underflow handling
    
PARSER_BIST_DONE:
    11. Report parser coverage
    12. Report buffer status
```

## 4. Test Access Mechanism

### 4.1 JTAG Interface

M16 通过 M15 JTAG Interface 接入测试访问。

#### 4.1.1 JTAG Instruction Support

| Instruction | Opcode | DR | M16 Access | Security |
|-------------|--------|-----|------------|----------|
| BYPASS | 0x0 | 1-bit | None | Always |
| IDCODE | 0x1 | 32-bit | None | Always |
| SCAN_IN/OUT | 0x4/0x5 | Variable | M16 mini-chain | TEST_MODE Level 1 |
| DEBUG | 0x7 | 48-bit | M16 registers | TEST_MODE Level 1 |
| MBIST_CTRL | 0x8 | 32-bit | CDC/Handshake BIST | TEST_MODE Level 2 |
| MBIST_STATUS | 0x9 | 32-bit | BIST result | TEST_MODE Level 2 |
| EXTEST/INTEST | 0x2/0x3 | 24-bit | BSR cells | TEST_MODE Level 2 |

#### 4.1.2 Debug Address Map (M16)

| Address | Register | Access | Description |
|---------|----------|--------|-------------|
| 0xD00 | isa_data_io | RW | IO domain data |
| 0xD04 | isa_data_sys | RW | System domain data |
| 0xD08 | isa_valid_io | R | IO domain valid |
| 0xD0C | isa_valid_sys | R | System domain valid |
| 0xD10 | isa_dir | RW | Direction control |
| 0xD14 | isa_mode | RW | Operation mode |
| 0xD18 | CDC_status | R | CDC sync status |
| 0xD1C | FSM_state | R | Protocol FSM state |

### 4.2 TEST_MODE Security Gate

M16 需 TEST_MODE 验证才能访问 CDC 和 BIST 功能。

#### 4.2.1 TEST_MODE Requirements

| Test Function | TEST_MODE Required | Level |
|---------------|-------------------|-------|
| M16 mini-chain scan | Yes | Level 1 |
| Debug register access | Yes | Level 1 |
| CDC BIST | Yes | Level 2 |
| Handshake BIST | Yes | Level 2 |
| Parser BIST | Yes | Level 2 |
| Boundary Scan (BSR) | Yes | Level 2 |

#### 4.2.2 TEST_MODE Validation Flow

```
TEST_MODE Request (from M15 JTAG):
    |
    v
M14 Security Manager Validation
    |
    v
Check test_mode_valid
    |
    +-- Invalid: Reject, return BYPASS
    |
    v
test_access_grant = 1
    |
    v
Allow M16 test access (per level)
```

### 4.3 Boundary Scan Interface

M16 BSR 连接到 M15 Boundary Scan Register。

#### 4.3.1 BSR Cell Configuration

| Cell Type | Count | Description |
|-----------|-------|-------------|
| Input Cell | 1 | ISA_READY capture |
| Output Cell | 3 | ISA_CLK, ISA_VALID, ISA_DIR drive |
| Bidirectional Cell | 8 | ISA_IF[0:7] bidir control |

#### 4.3.2 BSR Test Operation

```
EXTEST for M16:
    1. Capture ISA_READY input
    2. Shift test pattern to output cells
    3. Drive ISA_CLK, ISA_VALID, ISA_DIR
    4. Drive/Receive ISA_IF bidirectional cells
    5. Capture external response
```

## 5. Test Mode Definition

### 5.1 Test Mode Levels

| Level | Name | Access | TEST_MODE Required |
|-------|------|--------|-------------------|
| 0 | Functional | None | No |
| 1 | Scan Debug | M16 mini-chain + Debug | Yes (Level 1) |
| 2 | BIST Mode | CDC + Handshake + Parser BIST | Yes (Level 2) |
| 3 | Development | Full IO test + timing injection | Yes (Level 3) |

### 5.2 Test Mode Entry Sequence

```
Functional Mode (Level 0):
    - Normal ISA interface operation
    - No test access
    - TEST_MODE = 0

Enter Test Mode Level 1:
    1. JTAG: IR=SCAN/DEBUG
    2. TEST_MODE validation (M14)
    3. test_mode_valid = 1
    4. M16 mini-chain enabled
    5. Debug register access enabled

Enter Test Mode Level 2:
    1. Level 1 established
    2. JTAG: IR=MBIST_CTRL
    3. CDC/Handshake/Parser BIST enabled
    4. Boundary Scan enabled

Enter Test Mode Level 3:
    1. Level 2 established
    2. Timing violation injection enabled
    3. Development-only features
```

### 5.3 CDC Test Mode Considerations

| CDC Test | Clock Relationship | Constraint |
|----------|-------------------|------------|
| Normal CDC | CLK_IO != CLK_SYS | Asynchronous |
| Synchronous CDC Test | CLK_IO = CLK_SYS (forced) | Development only |
| Timing Injection | Setup/Hold violation | Level 3 only |

## 6. Coverage Target

### 6.1 Fault Coverage Target

| Coverage Type | Target | Method |
|---------------|--------|--------|
| CDC Functional Coverage | 100% | CDC BIST |
| FSM Coverage | 100% | Handshake BIST |
| Parser Data Path Coverage | 100% | Parser BIST |
| IO Timing Coverage | 100% | Timing BIST |
| Scan Fault Coverage | 95%+ | ATPG |

### 6.2 CDC Coverage Detail

| CDC Element | Coverage Target | Test Method |
|-------------|-----------------|-------------|
| 2-stage synchronizer | 100% | Data + valid sync test |
| Handshake protocol | 100% | Request/acknowledge test |
| Gray counter | 100% | Sequential increment test |
| Metastability recovery | 100% | Formal verification + injection |

### 6.3 ATPG Test Patterns

| Pattern Type | Count | Coverage | Description |
|--------------|-------|----------|-------------|
| Stuck-at Fault | ~40 | 95% | M16 mini-chain cells |
| Transition Fault | ~20 | 90% | CDC synchronizer transitions |
| Path Delay | ~15 | 85% | CDC critical paths |
| Bridging Fault | ~8 | 80% | Adjacent data cells |

### 6.4 Coverage Analysis

```
M16 DFT Coverage Summary:
    +-- CDC Coverage: 100% (synchronizer + handshake + gray counter)
    +-- FSM Coverage: 100% (receive + transmit FSMs)
    +-- Parser Coverage: 100% (data path + buffer)
    +-- IO Timing Coverage: 100% (setup/hold + turnaround)
    +-- Scan Fault Coverage: 95%+ (ATPG)
    +-- Total Coverage: >= 95% (combined)
```

## 7. Implementation Requirements

### 7.1 DFT RTL Requirements

| Requirement | Description |
|-------------|-------------|
| CDC Test Controller | Integrated synchronizer + handshake test |
| FSM BIST | Receive/Transmit FSM coverage |
| Parser BIST | Data path + buffer test |
| TEST_MODE Gate | All test access gated |
| Boundary Scan | IEEE 1149.1 BSR cells |

### 7.2 CDC Verification Requirements

| Requirement | Tool | Verification Target |
|-------------|------|---------------------|
| CDC Protocol Check | SpyGlass CDC | REQ-M16-009 compliance |
| Metastability MTBF | Formal verification | > 10^6 cycles |
| Gray Counter Check | Lint + CDC tool | Single-bit change |
| Timing Corner Analysis | OpenSTA | Setup/Hold margin |

### 7.3 Physical Design Requirements

| Parameter | Value | Description |
|-----------|-------|-------------|
| CDC Test Controller Area | < 0.02 mm² | BIST overhead |
| IO Buffer Area | < 0.04 mm² | ISA pin buffers |
| BSR Placement | Adjacent to ISA pads | Boundary scan cells |
| Test Power | < 20 mW | CDC BIST peak power |

### 7.4 Verification Requirements

| Test | Description | Tool |
|------|-------------|------|
| CDC Protocol | Synchronizer + handshake | SpyGlass CDC |
| FSM Coverage | State transition test | Verilator simulation |
| Parser Test | Data path verification | Verilator simulation |
| Timing Analysis | Setup/Hold margin | OpenSTA |
| Coverage Analysis | ATPG patterns | Synopsys TetraMAX |