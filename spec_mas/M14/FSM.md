---
module: M14
type: FSM
status: complete
parent: M14
fsm_type: Boot State Machine
generated: "2026-05-17T15:07:00+08:00"
---

# M14 FSM: Boot State Machine

## 1. Overview

M14 Boot State Machine 实现 Secure Boot 的安全启动流程控制，管理从 POR (Power-On Reset) 到固件验证完成的完整生命周期。该 FSM 确保 TinyStories NPU 仅加载经授权签名的固件，满足 REQ-SEC-001 安全要求。

### 1.1 FSM Type

| Type | Description |
|------|-------------|
| Boot State Machine | POR → Hash → Verify → Boot/Lock |

### 1.2 FSM Characteristics

| Characteristic | Value | Description |
|----------------|-------|-------------|
| State Encoding | 3-bit binary | 8 states total |
| Clock Domain | CLK_SYS | 250-500 MHz |
| Power Domain | PD_MAIN | 0.7-0.9 V |
| Reset | rst_por_n | Power-On Reset |
| Max Latency | ~1.1M cycles | Complete boot flow (1 MB firmware) |

## 2. State Definitions

### 2.1 State Encoding

| State | Code | Description | Actions | Typical Duration |
|-------|------|-------------|---------|------------------|
| IDLE | 0x0 | 等待启动命令 | 无 | - |
| LOAD_FW | 0x1 | 加载固件到验证缓冲区 | fw_data_req, 地址计数 | fw_size / 32B per cycle |
| COMPUTE_HASH | 0x2 | 计算 SHA-256 哈希 | SHA-256 engine active | fw_size / hash throughput |
| READ_OTP | 0x3 | 读取 OTP/eFuse 公钥 | otp_read_req, key_addr | OTP access time (~10 us) |
| VERIFY_SIG | 0x4 | ECDSA-P256 签名验证 | ECDSA engine active | ~50K cycles @ 500 MHz |
| COMPLETE | 0x5 | 验证通过，启动完成 | isa_decoder_en=1, boot_complete=1 | Persistent |
| FAILED | 0x6 | 验证失败 | boot_fail=1, sec_irq | Transient |
| LOCKED | 0x7 | 安全锁定状态 | sec_lock=1, isa_decoder_lock=1 | Persistent |

### 2.2 State Register

**BOOT_STATE Register (0x005C)**

| Bit | Field | Description |
|-----|-------|-------------|
| [0:2] | state | 当前状态编码 (0-7) |
| [3] | error | 错误标志 |
| [4:7] | error_code | 错误代码 |
| [8:15] | retry_count | 重试计数 |
| [16:31] | reserved | 保留 |

### 2.3 State Output Signals

| State | boot_complete | boot_fail | isa_decoder_en | isa_decoder_lock | sec_lock | sec_irq |
|-------|---------------|-----------|----------------|------------------|----------|---------|
| IDLE | 0 | 0 | 0 | 0 | 0 | 0 |
| LOAD_FW | 0 | 0 | 0 | 0 | 0 | 0 |
| COMPUTE_HASH | 0 | 0 | 0 | 0 | 0 | 0 |
| READ_OTP | 0 | 0 | 0 | 0 | 0 | 0 |
| VERIFY_SIG | 0 | 0 | 0 | 0 | 0 | 0 |
| COMPLETE | 1 | 0 | 1 | 0 | 0 | 0 |
| FAILED | 0 | 1 | 0 | 0 | 0 | 1 |
| LOCKED | 0 | 1 | 0 | 1 | 1 | 0 |

## 3. State Transitions

### 3.1 State Diagram

```
      +-------+
      | RESET |
      +---+---+
          |
          | (rst_por_n release)
          v
      +-------+
      | IDLE  |<--------------------------+
      +---+---+                           |
          |                               |
    (sec_boot_en=1, boot_start)           |
          v                               |
      +-------+                           |
      |LOAD_FW|                           |
      +---+---+                           |
          |                               |
    (fw_data_last)                        |
          v                               |
      +-------+                           |
      |COMPUTE|                           |
      | HASH  |                           |
      +---+---+                           |
          |                               |
    (hash_complete)                       |
          v                               |
      +-------+                           |
      |READ_OTP|                          |
      +---+---+                           |
          |                               |
    (otp_key_valid)                       |
          v                               |
      +-------+                           |
      |VERIFY |                           |
      | SIG   |                           |
      +---+---+                           |
          |                               |
    +-----+-----+                          |
    |           |                          |
(pass)       (fail)                       |
    |           |                          |
    v           v                          |
+-------+   +-------+                      |
|COMPLETE|  | FAILED |                     |
+---+---+   +---+---+                      |
    |           |                          |
    |           | (fail_counter >= 3)      |
    |           v                          |
    |       +-------+                      |
    |       | LOCKED |--------------------+
    |       +-------+
    |
    | (isa_decoder_en=1)
    v
 Boot Complete (M13 enabled)
```

### 3.2 Transition Table

| From | To | Trigger | Actions | Timing |
|------|----|---------|---------|--------|
| RESET | IDLE | rst_por_n release | Initialize FSM, clear counters | 1 cycle |
| IDLE | LOAD_FW | boot_start AND sec_boot_en=1 | fw_load_start=1, load fw_addr/fw_size | 1 cycle |
| IDLE | COMPLETE | boot_start AND sec_boot_en=0 | Bypass verification, isa_decoder_en=1 | 1 cycle |
| IDLE | COMPLETE | boot_start AND test_bypass=1 | TEST_MODE bypass verification | 1 cycle |
| LOAD_FW | COMPUTE_HASH | fw_data_last=1 | Start SHA-256 engine | 1 cycle |
| COMPUTE_HASH | READ_OTP | hash_complete=1 | otp_read_req=1 | 1 cycle |
| READ_OTP | VERIFY_SIG | otp_key_valid=1 | Start ECDSA engine | 1 cycle |
| VERIFY_SIG | COMPLETE | verify_passed=1 | isa_decoder_en=1, boot_complete=1 | 1 cycle |
| VERIFY_SIG | FAILED | verify_failed=1 | boot_fail=1, fail_counter++ | 1 cycle |
| FAILED | LOCKED | fail_counter >= 3 OR sec_lock_set=1 | sec_lock=1, isa_decoder_lock=1 | 1 cycle |
| FAILED | IDLE | retry AND fail_counter < 3 | Reset state, wait retry | Retry delay |
| LOCKED | IDLE | sec_unlock_req AND test_mode_en AND test_auth | Unlock via TEST_MODE authentication | Auth time |

### 3.3 Transition Conditions

#### 3.3.1 IDLE → LOAD_FW

```verilog
// Condition
always @(posedge clk_sys or negedge rst_por_n) begin
    if (!rst_por_n) begin
        state <= IDLE;
    end else if (state == IDLE && boot_start && sec_boot_en && !test_bypass) begin
        state <= LOAD_FW;
        fw_load_start <= 1'b1;
        fw_addr_reg <= fw_addr;
        fw_size_reg <= fw_size;
    end
end
```

#### 3.3.2 IDLE → COMPLETE (Bypass)

```verilog
// Bypass conditions
always @(posedge clk_sys) begin
    if (state == IDLE && boot_start) begin
        if (!sec_boot_en || test_bypass) begin
            state <= COMPLETE;
            isa_decoder_en <= 1'b1;
            boot_complete <= 1'b1;
        end
    end
end
```

#### 3.3.3 VERIFY_SIG → COMPLETE/FAILED

```verilog
// Verification result
always @(posedge clk_sys) begin
    if (state == VERIFY_SIG) begin
        if (verify_passed) begin
            state <= COMPLETE;
            isa_decoder_en <= 1'b1;
            boot_complete <= 1'b1;
        end else if (verify_failed) begin
            state <= FAILED;
            boot_fail <= 1'b1;
            fail_counter <= fail_counter + 1;
            sec_irq <= 1'b1;
        end
    end
end
```

#### 3.3.4 FAILED → LOCKED/IDLE

```verilog
// Retry and lockout logic
always @(posedge clk_sys) begin
    if (state == FAILED) begin
        if (fail_counter >= 3 || sec_lock_set) begin
            state <= LOCKED;
            sec_lock <= 1'b1;
            isa_decoder_lock <= 1'b1;
        end else if (retry) begin
            state <= IDLE;
            // Wait retry_delay before allowing next attempt
        end
    end
end
```

## 4. FSM Operations

### 4.1 LOAD_FW State Operation

```
Operation Sequence:
  1. Initialize fw_addr_counter = fw_addr_reg
  2. Initialize fw_size_counter = fw_size_reg
  3. Assert fw_data_req = 1
  4. For each fw_data packet:
     - fw_data_addr = fw_addr_counter
     - fw_addr_counter += 32 (32 bytes per cycle)
     - fw_size_counter -= 32
     - Buffer fw_data for SHA-256
  5. When fw_data_last = 1:
     - Transition to COMPUTE_HASH
     - fw_data_req = 0
```

### 4.2 COMPUTE_HASH State Operation

```
SHA-256 Computation:
  1. Initialize H[0..7] with SHA-256 initial values
  2. Set message_length = fw_size_reg
  3. Process buffered fw_data through SHA-256 engine:
     - 64-round compression per block
     - Block size: 64 bytes (2 cycles of fw_data)
  4. Process final block with padding
  5. Output fw_hash (256-bit) to registers:
     - FW_HASH (hash[0:31])
     - FW_HASH_HI (hash[32:63])
  6. Set hash_computed = 1
  7. Transition to READ_OTP
```

### 4.3 READ_OTP State Operation

```
OTP/eFuse Read Sequence:
  1. Set otp_key_addr = key_addr (from config)
  2. Assert otp_read_req = 1
  3. Wait for otp_read_ack = 1
  4. Read otp_key_data (512-bit: Qx + Qy)
  5. Check otp_key_valid = 1
  6. Check otp_locked = 1 (key immutable)
  7. Store Qx, Qy in ECDSA registers
  8. Transition to VERIFY_SIG
```

### 4.4 VERIFY_SIG State Operation

```
ECDSA-P256 Verification:
  1. Load inputs:
     - e = fw_hash (message hash)
     - r, s = signature from SIG_R/SIG_S registers
     - Qx, Qy = public key from OTP
  2. Verify r, s in [1, n-1] (curve order check)
  3. Compute w = s^-1 mod n (modular inverse)
  4. Compute u1 = e * w mod n
  5. Compute u2 = r * w mod n
  6. Compute (x1, y1) = u1*G + u2*Q (point multiplication)
  7. Compare r == x1 mod n:
     - Match: verify_passed = 1, transition to COMPLETE
     - No match: verify_failed = 1, transition to FAILED
  8. Verification latency: ~50K cycles @ 500 MHz
```

### 4.5 Retry Mechanism

```
Retry Policy:
  - Max retry attempts: 3
  - Retry delay: 100 ms
  - fail_counter increments on each failure
  - fail_counter >= 3 triggers LOCKED state
  - Retry only allowed when fail_counter < 3
  - Lockout persistent until TEST_MODE unlock
```

## 5. Control Registers

### 5.1 FSM Control Interface

| Register | Offset | Control Field | Description |
|----------|--------|---------------|-------------|
| SEC_CTRL | 0x0000 | enable | FSM enable |
| SEC_CTRL | 0x0000 | fw_load_start | Trigger LOAD_FW |
| SEC_CTRL | 0x0000 | verify_start | Trigger verification |
| SEC_CTRL | 0x0000 | abort | Abort current operation |
| BOOT_STATE | 0x005C | state | Current FSM state |
| BOOT_COUNTER | 0x0060 | count | Boot attempt counter |
| FAIL_COUNTER | 0x0064 | count | Failure counter |

### 5.2 Interrupt Generation

| State | IRQ Trigger | IRQ Type Code |
|-------|-------------|---------------|
| FAILED | Boot failure | 0x1 (BOOT_FAIL) |
| LOCKED | Lockout reached | 0x2 (LOCKOUT) |
| VERIFY_SIG | Verification timeout | 0x3 (VERIFY_TIMEOUT) |
| READ_OTP | OTP read error | 0x4 (OTP_ERROR) |

### 5.3 Status Monitoring

| Status Bit | Register | Meaning |
|------------|----------|---------|
| ready | SEC_STATUS[0] | FSM ready for boot |
| busy | SEC_STATUS[1] | FSM operation in progress |
| fw_loaded | SEC_STATUS[2] | Firmware loaded |
| hash_computed | SEC_STATUS[3] | Hash computed |
| verify_passed | SEC_STATUS[4] | Verification passed |
| verify_failed | SEC_STATUS[5] | Verification failed |
| boot_complete | SEC_STATUS[11] | Boot complete |
| boot_failed | SEC_STATUS[12] | Boot failed |

## 6. Timing Parameters

### 6.1 State Duration

| State | Duration (1 MB FW) | Duration Formula |
|-------|-------------------|------------------|
| IDLE | - | Wait for trigger |
| LOAD_FW | 64 us | fw_size / 32B * cycle_time |
| COMPUTE_HASH | 2 ms | fw_size / 64B * 64 cycles |
| READ_OTP | 10 us | OTP access latency |
| VERIFY_SIG | 100 us | ~50K cycles @ 500 MHz |
| FAILED | Transient | 1 cycle + retry delay |
| LOCKED | Persistent | Until TEST_MODE unlock |
| COMPLETE | Persistent | Until system reset |

### 6.2 DVFS Impact

| DVFS OP | Frequency | LOAD_FW | COMPUTE_HASH | VERIFY_SIG | Total |
|---------|-----------|---------|--------------|------------|-------|
| OP0 | 500 MHz | 64 us | 2 ms | 100 us | ~2.2 ms |
| OP1 | 250 MHz | 128 us | 4 ms | 200 us | ~4.4 ms |
| OP2 | 1 MHz | N/A | N/A | N/A | Not supported |

**Note**: Secure Boot must complete in OP0 or OP1 before entering Deep Sleep (OP2).

## 7. Error Handling

### 7.1 Error Codes

| Code | Name | State | Description |
|------|------|-------|-------------|
| 0x0 | NONE | Any | No error |
| 0x1 | FW_LOAD_FAIL | LOAD_FW | Firmware load timeout/error |
| 0x2 | HASH_FAIL | COMPUTE_HASH | Hash computation error |
| 0x3 | OTP_READ_FAIL | READ_OTP | OTP read timeout/error |
| 0x4 | OTP_LOCKED_FAIL | READ_OTP | OTP not locked (security violation) |
| 0x5 | SIG_INVALID_R | VERIFY_SIG | Signature R out of range |
| 0x6 | SIG_INVALID_S | VERIFY_SIG | Signature S out of range |
| 0x7 | SIG_VERIFY_FAIL | VERIFY_SIG | Signature verification failed |
| 0x8 | KEY_INVALID | VERIFY_SIG | Public key invalid |
| 0x9 | VERSION_MISMATCH | VERIFY_SIG | Firmware version rollback |
| 0xA | TEST_MODE_FAIL | Any | TEST_MODE authentication failed |
| 0xB | LOCKOUT | FAILED | Max retry exceeded |
| 0xC | ABORT | Any | Operation aborted by user |

### 7.2 Error Recovery

| Error | Recovery Action |
|-------|-----------------|
| FW_LOAD_FAIL | Retry load (if retry < 3) |
| HASH_FAIL | Retry computation |
| OTP_READ_FAIL | Retry OTP read |
| SIG_VERIFY_FAIL | Retry verification (if retry < 3) |
| LOCKOUT | TEST_MODE unlock required |

## 8. Security Considerations

### 8.1 Secure State Guarantee

| Property | Implementation |
|----------|----------------|
| Immutable Keys | OTP/eFuse locked after production |
| No Remote Bypass | TEST_MODE requires physical JTAG access |
| Retry Limit | Max 3 attempts before lockout |
| Constant-Time | ECDSA operations constant-time (no timing leaks) |
| State Integrity | FSM state stored in protected registers |

### 8.2 Lockout Security

```
Lockout Behavior:
  - sec_lock = 1 (permanent)
  - isa_decoder_lock = 1 (M13 disabled)
  - SEC_STATUS pin = 1 (error indication)
  - All boot requests ignored
  - Only TEST_MODE authentication can unlock
  - Audit trail: boot_counter, fail_counter
```

## 9. Verification Checklist

| Check | Description |
|-------|-------------|
| FSM Coverage | All states and transitions exercised |
| Reset Behavior | Verify FSM resets to IDLE on POR |
| Bypass Logic | Verify sec_boot_en=0 and test_bypass paths |
| Retry Logic | Verify fail_counter and retry mechanism |
| Lockout Logic | Verify fail_counter >= 3 triggers LOCKED |
| Unlock Logic | Verify TEST_MODE unlock sequence |
| Timing | Verify state durations per DVFS OP |
| Error Codes | Verify all error codes generated correctly |
| Interrupts | Verify IRQ generation on failure |
| Security | Verify no bypass without authentication |