---
module: M14
type: DFT
status: complete
parent: null
module_type: control
generated: "2026-05-17T16:30:00+08:00"
---

# M14: Secure Boot DFT Specification

## 1. Overview

M14 Secure Boot 是 TinyStories NPU 的安全启动模块，DFT 设计重点包括：
- **Scan Chain**: 全控制逻辑可扫描
- **SHA-256 Engine BIST**: 自测试哈希计算引擎
- **ECDSA Engine Test**: 签名验证逻辑测试
- **OTP/eFuse Test**: 安全存储接口验证

### 1.1 DFT Strategy Summary

| Strategy | Target | Coverage |
|----------|--------|----------|
| Full Scan | 100% registers (excluding crypto secrets) | 95%+ fault coverage |
| SHA-256 BIST | Hash engine + compression function | 100% functional |
| ECDSA Test | Modular arithmetic + point multiplication | 100% functional |
| OTP/eFuse Test | Key storage interface | 100% interface coverage |
| Boot FSM Test | State transition coverage | 100% FSM coverage |

### 1.2 Test Access Architecture

```
JTAG TAP (M15)
    |
    v
TEST_MODE Gate (Security Critical)
    |
    v
Scan Chain Controller (Limited - excludes OTP secrets)
    |
    v
BIST Controller
    |
    +-- SHA-256 Engine BIST
    +-- ECDSA Engine BIST (development only)
    +-- Boot FSM Test
    +-- OTP/eFuse Interface Test
```

### 1.3 Security Considerations

**CRITICAL**: M14 DFT 必须平衡测试能力和安全要求：
- OTP/eFuse 密钥区域 **不可扫描**
- TEST_MODE 绕过需要 **物理认证**
- BIST 结果 **不暴露密钥内容**

## 2. Scan Chain Configuration

### 2.1 Scan Chain Assignment

M14 寄存器分配到 **Scan Chain 3 (SC3)**，与 M05, M06, M07, M13 共享。

| Chain ID | Chain Name | Length | Modules | M14 Cells |
|----------|------------|--------|---------|-----------|
| SC3 | Logic Chain 3 | ~10k cells | M05-M07, M13, M14 | ~1,800 cells |

### 2.2 Scan Chain Cell List

| Register | Width | Scan Cells | Security | Description |
|----------|-------|------------|----------|-------------|
| SEC_CTRL | 32 | 32 | Yes | Control register |
| SEC_STATUS | 32 | 32 | Yes | Status register |
| SEC_CONFIG | 32 | 32 | Yes | Configuration register |
| FW_ADDR | 32 | 32 | Yes | Firmware address |
| FW_SIZE | 32 | 32 | Yes | Firmware size |
| FW_HASH | 64 | 64 | Yes | Hash result (non-secret) |
| SIG_R/SIG_S | 512 | 0 | **NO** | Signature (scan bypass) |
| OTP_CTRL | 32 | 32 | Yes | OTP control |
| OTP_STATUS | 32 | 32 | Yes | OTP status |
| OTP_KEY (Qx/Qy) | 512 | 0 | **NO** | Public key (scan bypass) |
| TEST_CTRL | 32 | 32 | Yes | TEST_MODE control |
| TEST_STATUS | 32 | 32 | Yes | TEST_MODE status |
| BOOT_STATE | 32 | 32 | Yes | Boot FSM state |
| BOOT_COUNTER | 32 | 32 | Yes | Boot counter |
| FAIL_COUNTER | 32 | 32 | Yes | Fail counter |
| IRQ registers | 96 | 96 | Yes | Interrupt registers |
| SHA-256 Pipeline Regs | 256 | 256 | Yes | Hash engine registers |
| ECDSA Control Regs | 64 | 64 | Yes | ECDSA control (no crypto) |
| Boot FSM State Regs | 8 | 8 | Yes | FSM state |
| **Total Scan Cells** | | **~880** | | Excludes crypto secrets |

### 2.3 Scan Exclusion Zones

**Security-sensitive registers excluded from scan chain:**

| Excluded Area | Width | Reason | Alternative Test |
|---------------|-------|--------|-------------------|
| OTP_KEY (Qx/Qy) | 512 | Secret key storage | Interface test only |
| SIG_R/SIG_S | 512 | Signature input | Functional test |
| ECDSA Internal Crypto Regs | ~256 | Crypto intermediates | BIST with obfuscated output |

### 2.4 Scan Chain Timing

| Parameter | Value | Description |
|-----------|-------|-------------|
| Scan Frequency | 50 MHz | TCK clock rate |
| Shift Rate | 1 bit/TCK | Standard scan shift |
| Capture Cycle | 1 TCK | Capture DR state |
| Update Cycle | 1 TCK | Update DR state |
| Full Scan Time | ~17.6 us | 880 cells @ 50 MHz |

### 2.5 Scan Control Signals

| Signal | Direction | Width | Description |
|--------|-----------|-------|-------------|
| scan_select | Input | 4 | Chain select (SC3 = 0x3) |
| scan_enable | Input | 1 | Scan mode enable |
| scan_in | Input | 1 | Scan data input (from M15) |
| scan_out | Output | 1 | Scan data output (to M15) |
| scan_capture | Input | 1 | Capture control |
| scan_update | Input | 1 | Update control |
| scan_bypass | Internal | 512 | Crypto secret bypass signal |

## 3. BIST Design

### 3.1 SHA-256 Engine BIST

SHA-256 BIST 验证哈希计算引擎的功能正确性。

#### 3.1.1 BIST Architecture

```
SHA-256 BIST Controller
    |
    +-- Test Vector Generator
    |       |
    |       +-- NIST SHA-256 test vectors
    |       +-- Internal test patterns
    |
    +-- Hash Engine Interface
    |       |
    |       +-- fw_data input
    |       +-- Hash engine control
    |       +-- fw_hash output capture
    |
    +-- Result Comparator
            |
            +-- Expected hash vs computed hash
            +-- Pass/Fail reporting (no intermediate exposure)
```

#### 3.1.2 NIST Test Vectors

| Test Vector # | Input | Expected Hash (hex) | Test Focus |
|---------------|-------|---------------------|------------|
| TV0 | "" (empty) | e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855 | Empty input |
| TV1 | "abc" | ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad | Short input |
| TV2 | "abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq" | 248d6a61d20638b8e5c026930c7e51c49e0b5df9c8f6db78b9b6c699c3d77dd1 | Block boundary |
| TV3 | 1MB pattern | Calculated | Long input throughput |
| TV4 | Walking pattern | Calculated | Data path test |
| TV5 | All-zeros | Calculated | Zero handling |
| TV6 | All-ones | Calculated | Ones handling |

#### 3.1.3 BIST Sequence

```
SHA256_BIST_START:
    1. Initialize BIST controller
    2. Set test_vector_index = 0
    
TEST_LOOP:
    3. Load test_input[test_vector_index]
    4. Set fw_size = input_length
    5. Trigger hash computation
    6. Wait for hash_complete
    7. Capture fw_hash
    8. Compare with expected_hash
    9. If mismatch: set sha_error_flag
    10. test_vector_index++
    11. If test_vector_index < 7: goto TEST_LOOP
    
SHA256_BIST_DONE:
    12. Set sha_bist_complete = 1
    13. Report pass/fail (no hash value exposed)
```

#### 3.1.4 BIST Timing

| Parameter | Value | Description |
|-----------|-------|-------------|
| Test Vector Count | 7 | NIST + internal |
| Empty Hash Latency | 64 cycles | Padding only |
| 1 Block Hash Latency | 64 cycles | 64-byte block |
| 1MB Hash Latency | ~1M cycles | Throughput test |
| Total BIST Time | ~1.1M cycles | ~2.2 ms @ 500 MHz |

### 3.2 ECDSA Engine Test

ECDSA Test 验证签名验证逻辑（development mode only）。

#### 3.2.1 ECDSA Test Strategy

**Security Constraint**: ECDSA Test 仅在 TEST_MODE Level 3 (Development) 下执行，不暴露密钥或中间值。

| Test Type | Level Required | Output Exposed |
|-----------|----------------|----------------|
| Modular Arithmetic Unit | Level 3 | No (obfuscated) |
| Point Multiplication Unit | Level 3 | No (obfuscated) |
| Signature Verification | Level 3 | Pass/Fail only |

#### 3.2.2 ECDSA Test Vectors (NIST P-256)

| Test Vector # | Description | Expected Result | Test Focus |
|---------------|-------------|-----------------|------------|
| TV0 | Valid signature | Pass | Normal verification |
| TV1 | Invalid R component | Fail | R validation |
| TV2 | Invalid S component | Fail | S validation |
| TV3 | Wrong signature | Fail | Signature mismatch |
| TV4 | Edge case (r=1) | Fail | Boundary check |
| TV5 | Edge case (s=n-1) | Pass | Boundary handling |

#### 3.2.3 ECDSA BIST Sequence (Development)

```
ECDSA_BIST_START (TEST_MODE Level 3):
    1. Load test signature (r, s)
    2. Load test public key (Qx, Qy) -- development only
    3. Load test message hash
    4. Trigger ECDSA verification
    5. Wait for verify_complete
    6. Capture pass/fail result only
    7. Compare with expected_result
    8. Report test pass/fail
```

### 3.3 OTP/eFuse Test

OTP/eFuse Test 验证存储接口功能，不读取密钥内容。

#### 3.3.1 OTP/eFuse Test Strategy

| Test | Description | Key Content Exposure |
|------|-------------|---------------------|
| Interface Connectivity | Read OTP_STATUS | No |
| Lock Status Check | Verify otp_locked bit | No |
| Address Decode Test | Write/read OTP_CTRL | No |
| Access Timing Test | Measure otp_read_ack latency | No |
| Key Validity Check | Verify otp_key_valid flag | No |

#### 3.3.2 OTP/eFuse Test Sequence

```
OTP_INTERFACE_TEST:
    1. Set otp_key_addr = test_address
    2. Set otp_read_req = 1
    3. Wait for otp_read_ack
    4. Check otp_key_valid flag (not key content)
    5. Check otp_locked status
    6. Measure access timing
    7. Report interface status
```

#### 3.3.3 OTP/eFuse Security During Test

| Security Measure | Implementation |
|------------------|----------------|
| Key Content Shielding | OTP_KEY registers not readable in scan |
| Interface Only Test | Test OTP_CTRL/OTP_STATUS, not OTP_KEY |
| Lock Verification | Verify otp_locked=1 (production) |
| Timing Validation | OTP access timing within spec |

### 3.4 Boot FSM Test

Boot FSM Test 验证状态机的完整转换路径。

#### 3.4.1 FSM State Coverage

| State | Test | Transition Covered |
|-------|------|-------------------|
| RESET | TV0 | RESET -> IDLE |
| IDLE | TV1 | IDLE -> LOAD_FW (sec_boot_en=1) |
| IDLE | TV2 | IDLE -> COMPLETE (sec_boot_en=0) |
| LOAD_FW | TV3 | LOAD_FW -> COMPUTE_HASH |
| COMPUTE_HASH | TV4 | COMPUTE_HASH -> READ_OTP |
| READ_OTP | TV5 | READ_OTP -> VERIFY_SIG |
| VERIFY_SIG | TV6 | VERIFY_SIG -> COMPLETE (pass) |
| VERIFY_SIG | TV7 | VERIFY_SIG -> FAILED (fail) |
| FAILED | TV8 | FAILED -> LOCKED (fail_counter>=3) |
| FAILED | TV9 | FAILED -> IDLE (retry) |
| LOCKED | TV10 | LOCKED -> IDLE (TEST_MODE unlock) |
| COMPLETE | TV11 | COMPLETE -> IDLE (boot_complete) |

#### 3.4.2 FSM Test Sequence

```
BOOT_FSM_TEST:
    For each state transition:
        1. Initialize FSM to source state
        2. Apply trigger condition
        3. Capture FSM next state
        4. Verify correct transition
        5. Verify state register update
        6. Record pass/fail
```

## 4. Test Access Mechanism

### 4.1 JTAG Interface

M14 通过 M15 JTAG Interface 接入测试访问。

#### 4.1.1 JTAG Instruction Support

| Instruction | Opcode | DR | M14 Access | Security |
|-------------|--------|-----|------------|----------|
| BYPASS | 0x0 | 1-bit | None | Always |
| IDCODE | 0x1 | 32-bit | None | Always |
| SCAN_IN/OUT/CAPTURE | 0x4-0x6 | Variable | SC3 registers (limited) | TEST_MODE Level 1 |
| DEBUG | 0x7 | 48-bit | SEC registers (non-secret) | TEST_MODE Level 1 |
| MBIST_CTRL | 0x8 | 32-bit | SHA-256 BIST start | TEST_MODE Level 2 |
| MBIST_STATUS | 0x9 | 32-bit | BIST result read | TEST_MODE Level 2 |
| USERCODE | 0xA | 32-bit | Secure Boot version | TEST_MODE Level 1 |

#### 4.1.2 Debug Address Map (M14)

| Address | Register | Access | Security | Description |
|---------|----------|--------|----------|-------------|
| 0x0000 | SEC_CTRL | RW | Level 1 | Control register |
| 0x0004 | SEC_STATUS | R | Level 1 | Status register |
| 0x000C | FW_ADDR | RW | Level 1 | Firmware address |
| 0x0010 | FW_SIZE | RW | Level 1 | Firmware size |
| 0x0014 | FW_HASH | R | Level 1 | Hash result |
| 0x002C | OTP_CTRL | RW | Level 1 | OTP control |
| 0x0030 | OTP_STATUS | R | Level 1 | OTP status |
| 0x0034-0x0050 | OTP_KEY | **NO ACCESS** | Level 3 only | Public key (blocked) |
| 0x0054 | TEST_CTRL | RW | Level 2 | TEST_MODE control |
| 0x0058 | TEST_STATUS | R | Level 2 | TEST_MODE status |
| 0x005C | BOOT_STATE | R | Level 1 | Boot FSM state |

### 4.2 TEST_MODE Security Gate (Critical)

M14 TEST_MODE 是最敏感的安全门控。

#### 4.2.1 TEST_MODE Level Requirements

| Level | Required Authentication | Access Scope |
|-------|------------------------|--------------|
| 0 | None | Functional mode only |
| 1 | Physical access + TEST_MODE key | Scan + Debug (non-secret) |
| 2 | Physical access + Level 1 + BIST auth | BIST execution |
| 3 | Physical access + Level 2 + Development key | OTP access + ECDSA test |

#### 4.2.2 TEST_MODE Validation Flow

```
TEST_MODE Request (from M15 JTAG):
    |
    v
Check Physical Access (JTAG connected)
    |
    v
test_mode_key Authentication
    |
    +-- Invalid: Reject, stay Level 0
    |
    v
Level Selection (test_mode_level)
    |
    +-- Level 1: Enable scan + debug (non-secret)
    +-- Level 2: Enable BIST
    +-- Level 3: Enable OTP + ECDSA test (dev only)
    |
    v
test_access_grant = level_selected
```

#### 4.2.3 TEST_MODE Bypass Control

| Bypass Mode | Level Required | Security Audit |
|-------------|----------------|----------------|
| No Bypass | Level 0 | Normal operation |
| Hash-Only (skip signature) | Level 2 | Logged in boot_counter |
| Full Bypass | Level 3 (dev only) | Logged + audit required |

### 4.3 Security Audit Trail

所有 TEST_MODE 操作记录在安全审计寄存器。

| Audit Register | Content | Purpose |
|----------------|---------|---------|
| BOOT_COUNTER | Boot attempts | Retry tracking |
| FAIL_COUNTER | Verify failures | Lockout trigger |
| TEST_STATUS | TEST_MODE usage | Audit trail |

## 5. Test Mode Definition

### 5.1 Test Mode Levels (Security-Critical)

| Level | Name | Access | Authentication | Use Case |
|-------|------|--------|----------------|----------|
| 0 | Functional | None | None | Production operation |
| 1 | Scan Debug | Scan + Debug (limited) | Physical + key | Manufacturing test |
| 2 | BIST Mode | BIST execution | Physical + BIST auth | Factory validation |
| 3 | Development | Full (OTP + ECDSA) | Physical + dev key | Pre-production only |

### 5.2 Test Mode Entry Sequence

```
Functional Mode (Level 0):
    - Normal secure boot operation
    - No test access
    - OTP locked
    - TEST_MODE = 0

Enter Test Mode Level 1:
    1. Physical JTAG connection
    2. JTAG: IR=SCAN/DEBUG
    3. test_mode_key input (from JTAG)
    4. test_mode_valid check
    5. scan_enable + debug_enable

Enter Test Mode Level 2:
    1. Level 1 established
    2. JTAG: IR=MBIST_CTRL
    3. bist_auth input
    4. SHA-256 BIST enabled

Enter Test Mode Level 3 (Development):
    1. Level 2 established
    2. dev_auth_key input
    3. OTP_KEY access enabled
    4. ECDSA test enabled
    5. **Production lock required after use**
```

### 5.3 Production Lockout

| Lockout State | Trigger | Effect |
|---------------|---------|--------|
| OTP Locked | otp_lock_force=1 | OTP_KEY read-only |
| TEST_MODE Disabled | Production config | Level 3 unavailable |
| Secure Boot Enforced | sec_boot_en=1 | No bypass without Level 2 |

## 6. Coverage Target

### 6.1 Fault Coverage Target

| Coverage Type | Target | Method | Security Constraint |
|---------------|--------|--------|---------------------|
| Scan Fault Coverage | >= 95% | ATPG | Excludes crypto secrets |
| SHA-256 Functional | 100% | SHA-256 BIST | NIST test vectors |
| Boot FSM Coverage | 100% | FSM test | All state transitions |
| OTP Interface Coverage | 100% | Interface test | No key content |
| ECDSA Coverage | 100% | ECDSA test | Level 3 only |

### 6.2 ATPG Test Patterns

| Pattern Type | Count | Coverage | Exclusion |
|--------------|-------|----------|-----------|
| Stuck-at Fault | ~400 | 95% | OTP_KEY/SIG registers bypassed |
| Transition Fault | ~150 | 90% | Crypto intermediates bypassed |
| Path Delay | ~80 | 85% | Critical SHA-256 paths |
| Bridging Fault | ~30 | 80% | Adjacent non-crypto cells |

### 6.3 Coverage Analysis

```
M14 DFT Coverage Summary:
    +-- Scan Coverage: 95% (880 cells, ATPG, excludes crypto secrets)
    +-- SHA-256 BIST Coverage: 100% (NIST vectors + throughput)
    +-- Boot FSM Coverage: 100% (12 state transitions)
    +-- OTP Interface Coverage: 100% (interface test, no key content)
    +-- ECDSA Coverage: 100% (Level 3 dev only, pass/fail only)
    +-- Total Fault Coverage: >= 95% (combined, security-preserving)
```

## 7. Implementation Requirements

### 7.1 DFT RTL Requirements

| Requirement | Description | Security Impact |
|-------------|-------------|-----------------|
| Scan Insertion | All non-secret registers | OTP_KEY/SIG bypassed |
| SHA-256 BIST Controller | Integrated hash test | No intermediate exposure |
| ECDSA BIST Controller | Level 3 only, obfuscated | Development-only feature |
| TEST_MODE Gate | Multi-level authentication | Critical security gate |
| OTP Interface Test | Interface-only test | Key content protected |

### 7.2 Physical Design Requirements

| Parameter | Value | Description |
|-----------|-------|-------------|
| Scan Chain Routing | Balanced | SC3 length ~1,800 cells (M14 portion) |
| BIST Area | < 0.08 mm² | SHA-256 + Boot FSM BIST |
| Crypto Shielding | Required | OTP_KEY/SIG physical isolation |
| Test Power | < 100 mW | SHA-256 BIST peak power |

### 7.3 Verification Requirements

| Test | Description | Security Verification |
|------|-------------|----------------------|
| Scan Chain Integrity | Scan shift (limited) | Verify crypto bypass |
| SHA-256 BIST | Hash computation | No intermediate leak |
| Boot FSM | State transitions | All paths covered |
| TEST_MODE Security | Level authentication | Security audit |
| OTP Interface | Interface connectivity | Key protection |
| Coverage Analysis | ATPG patterns | Security-preserving |