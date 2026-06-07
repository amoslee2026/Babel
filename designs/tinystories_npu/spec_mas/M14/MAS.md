---
module: M14
type: MAS
status: complete
parent: null
module_type: control
generated: "2026-05-17T15:07:00+08:00"
---

# M14: Secure Boot

## 1. Overview

M14 Secure Boot 是 TinyStories NPU 的安全启动核心模块，位于 Main Power Domain (PD_MAIN)，负责固件完整性验证和安全启动流程控制。该模块实现 ECDSA-P256 数字签名验证、SHA-256 哈希计算、OTP/eFuse 密钥存储接口和 TEST_MODE 控制四大功能，确保系统仅加载经授权签名的固件，满足 REQ-SEC-001 规定的 secure boot 安全要求。

### 1.1 Key Features

| Feature | Description | REQ Reference |
|---------|-------------|---------------|
| Signature Verification | ECDSA-P256 数字签名验证，配合 SHA-256 哈希 | REQ-SEC-001 |
| OTP/eFuse Key Storage | 公钥/根密钥安全存储接口 | REQ-SEC-001 |
| TEST_MODE Control | 测试模式安全控制，绕过验证需物理访问 | - |
| Boot State Machine | 安全启动状态机，管理验证流程 | REQ-SEC-001 |

### 1.2 Clock & Power Domain

| Parameter | Value | Description |
|-----------|-------|-------------|
| Clock Domain | CLK_SYS | 250-500 MHz，DVFS 支持 |
| Power Domain | PD_MAIN | 0.7-0.9 V，可 Power Gate |
| Target Power | <= 50 mW | 验证阶段峰值功耗 |

## 2. Interface

### 2.1 Signal List

#### 2.1.1 Clock & Reset

| Signal | Direction | Width | Description |
|--------|-----------|-------|-------------|
| clk_sys | Input | 1 | System 时钟，250-500 MHz |
| rst_sys_n | Input | 1 | System 异步复位，低有效 |
| rst_por_n | Input | 1 | Power-On Reset，低有效 |

#### 2.1.2 Firmware Input Interface (from M03 DRAM / M02 SRAM)

| Signal | Direction | Width | Description |
|--------|-----------|-------|-------------|
| fw_addr | Input | 32 | 固件起始地址 (DRAM/SRAM) |
| fw_size | Input | 32 | 固件大小 (bytes，最大 1 MB) |
| fw_data_req | Output | 1 | 固件数据读取请求 |
| fw_data_addr | Output | 32 | 固件数据读取地址 |
| fw_data_valid | Input | 1 | 固件数据有效标志 |
| fw_data | Input | 256 | 固件数据 (32 bytes per cycle) |
| fw_data_last | Input | 1 | 固件数据最后一包标志 |

#### 2.1.3 Signature Input Interface

| Signal | Direction | Width | Description |
|--------|-----------|-------|-------------|
| sig_r | Input | 256 | ECDSA 签名 R 分量 (256-bit) |
| sig_s | Input | 256 | ECDSA 签名 S 分量 (256-bit) |
| sig_valid | Input | 1 | 签名数据有效标志 |
| sig_addr | Input | 32 | 签名存储地址 (可选) |

#### 2.1.4 OTP/eFuse Key Storage Interface

| Signal | Direction | Width | Description |
|--------|-----------|-------|-------------|
| otp_key_addr | Output | 8 | OTP/eFuse 密钥地址选择 |
| otp_key_data | Input | 512 | OTP/eFuse 公钥数据 (P-256 Qx + Qy) |
| otp_key_valid | Input | 1 | OTP/eFuse 数据有效标志 |
| otp_read_req | Output | 1 | OTP/eFuse 读取请求 |
| otp_read_ack | Input | 1 | OTP/eFuse 读取确认 |
| otp_locked | Input | 1 | OTP/eFuse 锁定状态 (不可修改) |

#### 2.1.5 Security Control Interface (External Pins)

| Signal | Direction | Width | Description |
|--------|-----------|-------|-------------|
| sec_boot_en | Input | 1 | Secure Boot 启用 (Pin #20, SEC_BOOT_EN) |
| sec_status | Output | 1 | 安全状态输出 (Pin #21, SEC_STATUS) |
| sec_lock | Output | 1 | 安全锁定状态 (内部使用) |
| sec_unlock_req | Input | 1 | 安全解锁请求 (需 TEST_MODE) |

#### 2.1.6 TEST_MODE Interface (JTAG Controlled)

| Signal | Direction | Width | Description |
|--------|-----------|-------|-------------|
| test_mode_en | Input | 1 | TEST_MODE 启用 (来自 M15 JTAG) |
| test_mode_key | Input | 256 | TEST_MODE 认证密钥 (物理访问) |
| test_mode_valid | Input | 1 | TEST_MODE 密钥有效标志 |
| test_bypass | Output | 1 | TEST_MODE 绕过验证标志 |

#### 2.1.7 Boot Control Interface (to M13 ISA Decoder)

| Signal | Direction | Width | Description |
|--------|-----------|-------|-------------|
| boot_start | Input | 1 | 启动开始信号 |
| boot_complete | Output | 1 | 启动完成信号 |
| boot_fail | Output | 1 | 启动失败信号 |
| boot_fw_valid | Output | 1 | 固件验证通过标志 |
| boot_state | Output | 3 | 启动状态机当前状态 |
| boot_abort | Input | 1 | 启动中止请求 |

#### 2.1.8 ISA Decoder Enable (to M13)

| Signal | Direction | Width | Description |
|--------|-----------|-------|-------------|
| isa_decoder_en | Output | 1 | ISA Decoder 使能 (验证通过后) |
| isa_decoder_lock | Output | 1 | ISA Decoder 锁定 (验证失败) |

#### 2.1.9 System Bus Interface (TileLink/AXI via M04)

| Signal | Direction | Width | Description |
|--------|-----------|-------|-------------|
| bus_cmd_valid | Input | 1 | 总线命令有效 |
| bus_cmd_ready | Output | 1 | 总线命令就绪 |
| bus_cmd_addr | Input | 16 | 命令地址（寄存器访问） |
| bus_cmd_rw | Input | 1 | 读/写命令标识 |
| bus_cmd_data | Input | 32 | 写数据 |
| bus_rsp_valid | Output | 1 | 响应有效 |
| bus_rsp_data | Output | 32 | 读响应数据 |
| bus_rsp_error | Output | 1 | 响应错误标志 |

#### 2.1.10 Interrupt Interface

| Signal | Direction | Width | Description |
|--------|-----------|-------|-------------|
| sec_irq | Output | 1 | 安全中断请求 |
| sec_irq_type | Output | 4 | 中断类型编码 |

### 2.2 Register Map

| Offset | Name | R/W | Width | Description |
|--------|------|-----|-------|-------------|
| 0x0000 | SEC_CTRL | RW | 32 | Secure Boot 控制寄存器 |
| 0x0004 | SEC_STATUS | R | 32 | Secure Boot 状态寄存器 |
| 0x0008 | SEC_CONFIG | RW | 32 | 安全配置寄存器 |
| 0x000C | FW_ADDR | RW | 32 | 固件起始地址 |
| 0x0010 | FW_SIZE | RW | 32 | 固件大小 |
| 0x0014 | FW_HASH | R | 32 | 固件 SHA-256 哈希值 (低位) |
| 0x0018 | FW_HASH_HI | R | 32 | 固件 SHA-256 哈希值 (高位) |
| 0x001C | SIG_R_LO | RW | 32 | 签名 R 分量 (低位) |
| 0x0020 | SIG_R_HI | RW | 32 | 签名 R 分量 (高位) |
| 0x0024 | SIG_S_LO | RW | 32 | 签名 S 分量 (低位) |
| 0x0028 | SIG_S_HI | RW | 32 | 签名 S 分量 (高位) |
| 0x002C | OTP_CTRL | RW | 32 | OTP/eFuse 控制寄存器 |
| 0x0030 | OTP_STATUS | R | 32 | OTP/eFuse 状态寄存器 |
| 0x0034 | OTP_KEY_LO | R | 32 | OTP 公钥 Qx (低位) |
| 0x0038 | OTP_KEY_M1 | R | 32 | OTP 公钥 Qx (中1) |
| 0x003C | OTP_KEY_M2 | R | 32 | OTP 公钥 Qx (中2) |
| 0x0040 | OTP_KEY_HI | R | 32 | OTP 公钥 Qx (高位) |
| 0x0044 | OTP_KEYY_LO | R | 32 | OTP 公钥 Qy (低位) |
| 0x0048 | OTP_KEYY_M1 | R | 32 | OTP 公钥 Qy (中1) |
| 0x004C | OTP_KEYY_M2 | R | 32 | OTP 公钥 Qy (中2) |
| 0x0050 | OTP_KEYY_HI | R | 32 | OTP 公钥 Qy (高位) |
| 0x0054 | TEST_CTRL | RW | 32 | TEST_MODE 控制寄存器 |
| 0x0058 | TEST_STATUS | R | 32 | TEST_MODE 状态寄存器 |
| 0x005C | BOOT_STATE | R | 32 | 启动状态机寄存器 |
| 0x0060 | BOOT_COUNTER | R | 32 | 启动计数器 |
| 0x0064 | FAIL_COUNTER | R | 32 | 验证失败计数器 |
| 0x0068 | IRQ_ENABLE | RW | 32 | 中断使能寄存器 |
| 0x006C | IRQ_STATUS | R | 32 | 中断状态寄存器 |
| 0x0070 | IRQ_CLEAR | RW | 32 | 中断清除寄存器 |
| 0x0074 | SEC_VERSION | R | 32 | Secure Boot 版本寄存器 |

#### 2.2.1 Register Bit Definitions

**SEC_CTRL (0x0000)**

| Bit | Name | Description |
|-----|------|-------------|
| [0] | enable | Secure Boot 使能 |
| [1] | fw_load_start | 固件加载开始 |
| [2] | verify_start | 验证开始 |
| [3] | verify_force | 强制验证（忽略 TEST_MODE） |
| [4] | otp_read_start | OTP 读取开始 |
| [5] | sec_lock_set | 设置安全锁定 |
| [6] | sec_unlock_req | 安全解锁请求 |
| [7] | abort | 中止当前操作 |
| [8:15] | reserved | 保留 |
| [16:31] | reserved | 保留 |

**SEC_STATUS (0x0004)**

| Bit | Name | Description |
|-----|------|-------------|
| [0] | ready | Secure Boot 就绪 |
| [1] | busy | 操作进行中 |
| [2] | fw_loaded | 固件已加载 |
| [3] | hash computed | SHA-256 哈希已计算 |
| [4] | verify_passed | 签名验证通过 |
| [5] | verify_failed | 签名验证失败 |
| [6] | otp_valid | OTP 公钥有效 |
| [7] | otp_locked | OTP 已锁定 |
| [8] | test_mode | TEST_MODE 激活 |
| [9] | test_bypass | TEST_MODE 绕过激活 |
| [10] | sec_locked | 安全锁定状态 |
| [11] | boot_complete | 启动完成 |
| [12] | boot_failed | 启动失败 |
| [13] | fw_valid | 固件有效 |
| [14:15] | reserved | 保留 |
| [16:23] | boot_state | 启动状态机当前状态 |
| [24:31] | reserved | 保留 |

**SEC_CONFIG (0x0008)**

| Bit | Name | Description |
|-----|------|-------------|
| [0] | secure_boot_en | Secure Boot 启用（映射 Pin #20） |
| [1] | test_mode_allowed | 允许 TEST_MODE 绕过 |
| [2] | otp_auto_read | 自动读取 OTP 公钥 |
| [3] | hash_only | 仅计算哈希，不验证签名 |
| [4] | sig_embedded | 签名嵌入固件尾部 |
| [5] | sig_external | 签名存储在外部地址 |
| [6] | dual_hash | 双哈希模式（固件 + 配置） |
| [7] | rollback_protect | 回滚保护启用 |
| [8:15] | hash_algorithm | 哈希算法选择 (0=SHA-256) |
| [16:23] | sig_algorithm | 签名算法选择 (0=ECDSA-P256) |
| [24:31] | reserved | 保留 |

**OTP_CTRL (0x002C)**

| Bit | Name | Description |
|-----|------|-------------|
| [0] | read_req | OTP 读取请求 |
| [1] | read_auto | 自动读取模式 |
| [2] | lock_req | OTP 锁定请求 |
| [3] | lock_force | 强制锁定（不可逆） |
| [4:7] | key_addr | 密钥地址选择 (0-15) |
| [8:15] | reserved | 保留 |
| [16:31] | reserved | 保留 |

**TEST_CTRL (0x0054)**

| Bit | Name | Description |
|-----|------|-------------|
| [0] | test_mode_en | TEST_MODE 使能 |
| [1] | test_bypass_en | TEST_MODE 绕过使能 |
| [2] | test_key_valid | TEST_MODE 密钥有效 |
| [3] | test_auth_req | TEST_MODE 认证请求 |
| [4] | test_auth_done | TEST_MODE 认证完成 |
| [5:7] | test_mode_level | TEST_MODE 级别 (0-7) |
| [8:15] | reserved | 保留 |
| [16:31] | reserved | 保留 |

**BOOT_STATE (0x005C)**

| Bit | Name | Description |
|-----|------|-------------|
| [0:2] | state | 启动状态 (0=IDLE, 1=LOAD_FW, 2=COMPUTE_HASH, 3=READ_OTP, 4=VERIFY_SIG, 5=COMPLETE, 6=FAILED, 7=LOCKED) |
| [3] | error | 错误标志 |
| [4:7] | error_code | 错误代码 |
| [8:15] | retry_count | 重试计数 |
| [16:31] | reserved | 保留 |

## 3. Functional Description

### 3.1 Boot State Machine

Boot State Machine 管理 Secure Boot 的完整验证流程。

#### 3.1.1 State Diagram

```
      +-------+
      | RESET |
      +---+---+
          |
          | (boot_start)
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
    |           | (sec_lock=1)             |
    |           v                          |
    |       +-------+                      |
    |       | LOCKED |--------------------+
    |       +-------+
    |
    | (isa_decoder_en=1)
    v
 Boot Complete (M13 enabled)
```

#### 3.1.2 State Definitions

| State | Code | Description | Actions | Duration |
|-------|------|-------------|---------|----------|
| IDLE | 0x0 | 等待启动命令 | 无 | - |
| LOAD_FW | 0x1 | 加载固件到验证缓冲区 | fw_data_req, 地址计数 | 固件大小 / 32B per cycle |
| COMPUTE_HASH | 0x2 | 计算 SHA-256 哈希 | SHA-256 engine active | 固件大小 / 哈希吞吐 |
| READ_OTP | 0x3 | 读取 OTP/eFuse 公钥 | otp_read_req, key_addr | OTP 访问时间 |
| VERIFY_SIG | 0x4 | ECDSA-P256 签名验证 | ECDSA engine active | ~50K cycles @ 500 MHz |
| COMPLETE | 0x5 | 验证通过，启动完成 | isa_decoder_en=1, boot_complete=1 | - |
| FAILED | 0x6 | 验证失败 | boot_fail=1, sec_irq | - |
| LOCKED | 0x7 | 安全锁定状态 | sec_lock=1, isa_decoder_lock=1 | 持续 |

#### 3.1.3 State Transitions

| From | To | Trigger | Actions |
|------|----|---------|---------|
| RESET | IDLE | rst_por_n release | 初始化状态机，清除计数器 |
| IDLE | LOAD_FW | boot_start AND sec_boot_en=1 | fw_load_start=1, fw_addr/fw_size 加载 |
| IDLE | COMPLETE | boot_start AND sec_boot_en=0 | 直接跳过验证，isa_decoder_en=1 |
| IDLE | COMPLETE | boot_start AND test_bypass=1 | TEST_MODE 绕过验证 |
| LOAD_FW | COMPUTE_HASH | fw_data_last=1 | 启动 SHA-256 engine |
| COMPUTE_HASH | READ_OTP | hash_complete=1 | otp_read_req=1 |
| READ_OTP | VERIFY_SIG | otp_key_valid=1 | 启动 ECDSA engine |
| VERIFY_SIG | COMPLETE | verify_passed=1 | isa_decoder_en=1, boot_complete=1 |
| VERIFY_SIG | FAILED | verify_failed=1 | boot_fail=1, fail_counter++ |
| FAILED | LOCKED | fail_counter >= 3 OR sec_lock_set=1 | sec_lock=1, isa_decoder_lock=1 |
| FAILED | IDLE | retry AND fail_counter < 3 | 状态重置，等待重试 |
| LOCKED | IDLE | sec_unlock_req AND test_mode_en AND test_auth | 解除锁定（需 TEST_MODE 认证） |

### 3.2 SHA-256 Hash Computation

SHA-256 engine 计算固件的 256-bit 哈希值，用于签名验证的输入。

#### 3.2.1 Hash Engine Architecture

```
SHA-256 Engine:
  - Input: fw_data (256-bit, 32 bytes per cycle)
  - Processing: 64-round compression function
  - Output: fw_hash (256-bit)
  - Throughput: 1 block (64 bytes) per 64 cycles
  - Latency: 64 cycles per block + padding overhead
```

#### 3.2.2 Hash Computation Flow

```
Start Hash Computation:
  1. Initialize H[0..7] with SHA-256 initial values
  2. Set message length = fw_size
  3. For each fw_data packet:
     - Buffer 32 bytes
     - When buffer full (64 bytes), process one block
  4. Process final block with padding
  5. Output fw_hash
  6. Set hash_computed=1
```

#### 3.2.3 Hash Register Interface

| Register | Content | Description |
|----------|---------|-------------|
| FW_HASH (0x0014) | hash[0:31] | SHA-256 输出低位 |
| FW_HASH_HI (0x0018) | hash[32:63] | SHA-256 输出高位 |

### 3.3 ECDSA-P256 Signature Verification

ECDSA-P256 engine 验证数字签名，确保固件来自授权源。

#### 3.3.1 ECDSA Algorithm

ECDSA signature verification algorithm (P-256 curve):

```
Input:
  - Message hash: e = fw_hash (256-bit)
  - Signature: (r, s) where r, s are 256-bit integers
  - Public key: Q = (Qx, Qy) from OTP/eFuse

Algorithm:
  1. Verify r, s in [1, n-1] where n is curve order
  2. Compute w = s^-1 mod n
  3. Compute u1 = e * w mod n
  4. Compute u2 = r * w mod n
  5. Compute (x1, y1) = u1 * G + u2 * Q (point multiplication)
  6. Verify r == x1 mod n
     - If true: signature valid
     - If false: signature invalid
```

#### 3.3.2 ECDSA Engine Architecture

```
ECDSA-P256 Engine:
  - Modular Arithmetic Unit: 256-bit modular operations
  - Point Multiplication Unit: Scalar multiplication on P-256
  - Verification Logic: Final comparison
  - Cycle Count: ~50,000 cycles @ 500 MHz (optimized implementation)
```

#### 3.3.3 ECDSA Parameters (P-256 Curve)

| Parameter | Value | Description |
|-----------|-------|-------------|
| Curve | secp256r1 (P-256) | NIST standard curve |
| Prime p | FFFFFFFF00000001000000000000000000000000FFFFFFFFFFFFFFFFFFFFFFFF | 256-bit prime |
| Order n | FFFFFFFF00000000FFFFFFFFFFFFFFFFBCE6FAADA7179E84F3B9CAC2FC632551 | Curve order |
| Generator G.x | 6B17D1F2E12C4247F8BCE6E563A440F277037D812DEB33A0F4A13945D898C296 | Base point x |
| Generator G.y | 4FE342E2FE1A7F9B8EE7EB4A7C0F9E162BCE33576B315ECECBB6406837BF51F5 | Base point y |

### 3.4 OTP/eFuse Key Storage Interface

OTP/eFuse 接口提供安全的公钥存储和读取机制。

#### 3.4.1 OTP/eFuse Memory Map

| Address | Content | Size | Description |
|---------|---------|------|-------------|
| 0x00 | Qx[0:31] | 32 bits | Public key X 低32位 |
| 0x01 | Qx[32:63] | 32 bits | Public key X 高32位 |
| 0x02 | Qx[64:95] | 32 bits | Public key X 扩展 (reserved) |
| 0x03 | Qx[96:127] | 32 bits | Public key X 扩展 (reserved) |
| 0x04 | Qy[0:31] | 32 bits | Public key Y 低32位 |
| 0x05 | Qy[32:63] | 32 bits | Public key Y 高32位 |
| 0x06 | Qy[64:95] | 32 bits | Public key Y 扩展 (reserved) |
| 0x07 | Qy[96:127] | 32 bits | Public key Y 扩展 (reserved) |
| 0x08 | Key_ID | 32 bits | 密钥标识符 |
| 0x09 | Key_Version | 32 bits | 密钥版本 (rollback protect) |
| 0x0A | Lock_Status | 32 bits | 锁定状态标志 |
| 0x0B-0x0F | Reserved | - | 预留扩展 |

#### 3.4.2 OTP/eFuse Access Sequence

```
OTP/eFuse Read Sequence:
  1. Set otp_key_addr = desired address
  2. Set otp_read_req = 1
  3. Wait for otp_read_ack = 1
  4. Read otp_key_data (512-bit)
  5. Check otp_key_valid = 1
  6. Check otp_locked = 1 (key cannot be modified)

OTP/eFuse Lock Sequence (One-Time):
  1. Set otp_lock_req = 1
  2. Set otp_lock_force = 1 ( irreversible)
  3. Wait for otp_locked = 1
  4. OTP/eFuse permanently locked
```

#### 3.4.3 OTP/eFuse Security Properties

| Property | Description |
|----------|-------------|
| Read-Only | otp_locked=1 后不可修改 |
| Anti-Tamper | 物理攻击检测 (集成在 OTP/eFuse 模块) |
| Secure Storage | 密钥存储区域隔离，防止侧信道攻击 |
| One-Time Lock | otp_lock_force=1 后永久锁定，不可逆转 |

### 3.5 TEST_MODE Control

TEST_MODE 提供安全测试和调试入口，需要物理访问认证。

#### 3.5.1 TEST_MODE Security Model

```
TEST_MODE Activation:
  1. Physical access required (JTAG interface)
  2. test_mode_en = 1 (from M15 JTAG TAP)
  3. test_mode_key authentication
  4. test_auth_req -> test_auth_done
  5. test_bypass = 1 enabled

TEST_MODE Bypass Levels:
  - Level 0: No bypass (normal operation)
  - Level 1: Hash-only mode (skip signature verification)
  - Level 2: Full bypass (skip all verification)
  - Level 3: OTP write access (development only)
  - Level 4-7: Reserved
```

#### 3.5.2 TEST_MODE Authentication

| Authentication Step | Description |
|---------------------|-------------|
| Physical Access | JTAG 连接，test_mode_en 激活 |
| Key Authentication | test_mode_key 输入，验证物理访问授权 |
| Level Selection | test_mode_level 选择绕过级别 |
| Audit Log | test_status 记录 TEST_MODE 使用 |

#### 3.5.3 TEST_MODE Constraints

| Constraint | Description |
|------------|-------------|
| Physical Access Only | TEST_MODE 需要 JTAG 物理连接，无法远程激活 |
| Audit Required | 所有 TEST_MODE 使用记录在 boot_counter 和 fail_counter |
| Production Lock | 生产环境建议禁用 test_mode_allowed=0 |
| Timeout | TEST_MODE 认证超时自动返回 IDLE |

### 3.6 Boot Retry and Lockout

Boot retry 和 lockout 机制防止暴力破解攻击。

#### 3.6.1 Retry Policy

| Parameter | Value | Description |
|-----------|-------|-------------|
| Max Retry | 3 | 最大重试次数 |
| Retry Delay | 100 ms | 重试间隔 |
| Lockout Trigger | fail_counter >= 3 | 进入 LOCKED 状态 |
| Unlock Condition | TEST_MODE + authentication | 解除锁定 |

#### 3.6.2 Lockout Behavior

```
Lockout (LOCKED state):
  - sec_lock = 1 (永久锁定)
  - isa_decoder_lock = 1 (M13 禁用)
  - sec_status = 1 (Pin #21 输出失败状态)
  - All boot requests ignored
  - Only TEST_MODE unlock can resume
```

## 4. Security Model

### 4.1 Threat Model

| Threat | Mitigation | Implementation |
|--------|------------|----------------|
| Firmware Tampering | ECDSA-P256 签名验证 | REQ-SEC-001 |
| Key Extraction | OTP/eFuse 安全存储 | Read-only after lock |
| Signature Replay | Hash binding + version check | rollback_protect |
| Brute Force Attack | Retry limit + lockout | fail_counter >= 3 -> LOCKED |
| Remote Exploit | TEST_MODE requires physical access | JTAG only |
| Side Channel | Constant-time crypto operations | ECDSA engine optimized |

### 4.2 Security States

| State | SEC_BOOT_EN | TEST_MODE | Boot Result | ISA Decoder |
|-------|-------------|-----------|-------------|-------------|
| Normal Boot | 1 | 0 | Pass | Enabled |
| Normal Boot Fail | 1 | 0 | Fail | Locked |
| Secure Boot Disabled | 0 | 0 | Bypass | Enabled |
| TEST_MODE Bypass | 1 | 1 (auth) | Bypass | Enabled |
| Locked | - | - | No boot | Locked |

### 4.3 Security Pin Behavior

| Pin | Name | Behavior |
|-----|------|----------|
| #20 | SEC_BOOT_EN | 1=Secure Boot 启用，0=直接启动 |
| #21 | SEC_STATUS | 0=验证通过，1=验证失败/锁定 |

#### 4.3.1 SEC_STATUS Output Logic

```
SEC_STATUS Output:
  - 0: boot_complete AND NOT boot_fail (normal operation)
  - 1: boot_fail OR sec_lock OR boot_failed (error state)
  - Holds value after boot complete
```

### 4.4 Rollback Protection

| Feature | Description |
|---------|-------------|
| Version Check | OTP Key_Version vs firmware version |
| Reject Older | rollback_protect=1 时拒绝旧版本固件 |
| Version Register | Firmware version embedded in signature metadata |

## 5. Timing

### 5.1 Boot Timing

| Parameter | Value | Description |
|-----------|-------|-------------|
| t_fw_load | fw_size / throughput | 固件加载时间 (32B/cycle) |
| t_hash_compute | fw_size / 64 * 64 cycles | SHA-256 计算时间 |
| t_otp_read | 10 us | OTP/eFuse 读取时间 |
| t_ecdsa_verify | 50K cycles (~100 us @ 500 MHz) | ECDSA-P256 验证时间 |
| t_boot_total | ~1-5 ms (取决于固件大小) | 完整启动时间 (1 MB firmware) |

### 5.2 Operation Timing Breakdown (1 MB Firmware)

| Operation | Cycles | Time @ 500 MHz | Percentage |
|-----------|--------|----------------|------------|
| FW Load | 32K cycles | 64 us | ~1% |
| SHA-256 | 16K blocks * 64 = 1M cycles | 2 ms | ~80% |
| OTP Read | 5K cycles | 10 us | ~0.4% |
| ECDSA Verify | 50K cycles | 100 us | ~4% |
| Total | ~1.1M cycles | ~2.2 ms | 100% |

### 5.3 Clock Domain Crossing

| Crossing | From | To | Method |
|----------|------|----|----|
| JTAG TEST_MODE | CLK_IO (50 MHz) | CLK_SYS (500 MHz) | Handshake synchronizer |
| OTP Interface | OTP Clock (slow) | CLK_SYS (500 MHz) | Async FIFO |

### 5.4 Register Access Timing

| Parameter | Value | Description |
|-----------|-------|-------------|
| t_reg_read | 1 cycle | 寄存器读访问时间 |
| t_reg_write | 1 cycle | 寄存器写访问时间 |
| t_hash_update | 64 cycles | 哈希值更新延迟 |
| t_status_update | 2 cycles | 状态寄存器更新延迟 |

### 5.5 DVFS Impact on Verification

| DVFS OP | Frequency | ECDSA Verify Time | Total Boot Time |
|---------|-----------|-------------------|-----------------|
| OP0 | 500 MHz | 100 us | ~2.2 ms |
| OP1 | 250 MHz | 200 us | ~4.4 ms |
| OP2 | 1 MHz (AON) | Not supported | Secure Boot in OP0/OP1 only |

**Note**: Secure Boot 建议在 OP0 或 OP1 完成，进入 Deep Sleep (OP2) 前需确保 boot_complete=1。

## 6. Implementation Notes

### 6.1 Design Considerations

1. **Crypto Acceleration**: SHA-256 和 ECDSA-P256 使用硬件加速，不依赖外部软件。

2. **OTP/eFuse Integration**: 公钥存储在 OTP/eFuse，生产时一次性写入并锁定。

3. **TEST_MODE Security**: TEST_MODE 需要 JTAG 物理访问和认证密钥，防止远程攻击。

4. **Lockout Persistence**: LOCKED 状态需 TEST_MODE 认证才能解除，防止暴力破解。

5. **Constant-Time Operations**: ECDSA 验证使用 constant-time 实现，防止时序侧信道攻击。

### 6.2 Integration Requirements

| Interface | Target Module | Protocol |
|-----------|---------------|----------|
| Firmware Load | M03 DRAM / M02 SRAM | Custom handshake |
| OTP/eFuse | External OTP Module | Custom interface |
| ISA Decoder Enable | M13 ISA Decoder | Direct control |
| TEST_MODE | M15 JTAG Interface | JTAG TAP control |
| System Bus | M04 System Bus | TileLink/AXI |

### 6.3 Verification Requirements

| Test Category | Description |
|---------------|-------------|
| Boot FSM | 验证所有状态转换 |
| SHA-256 | 验证哈希计算正确性（已知 test vectors） |
| ECDSA-P256 | 题签名验证正确性（已知 test vectors） |
| OTP Interface | 验证 OTP 读取和锁定 |
| TEST_MODE | 验证 TEST_MODE 绕过和认证 |
| Retry/Lockout | 验证重试计数和锁定机制 |
| Security Pin | 验证 SEC_STATUS 输出逻辑 |
| DVFS | 验证 DVFS 对验证时间的影响 |

### 6.4 Power Budget Allocation

| Domain | Budget | Allocation |
|--------|--------|------------|
| M14 Logic | 40 mW | SHA-256 + ECDSA engines |
| M14 IO | 10 mW | OTP Interface + Control Signals |
| **Total** | **50 mW** | Peak during verification |

### 6.5 Reset Strategy

| Reset | Source | Effect |
|-------|--------|--------|
| rst_por_n | Power-On | 全部寄存器复位，FSM 进入 IDLE |
| rst_sys_n | System | 状态寄存器复位，配置保留 |
| Soft Reset | Register | SEC_CTRL[7]=1 中止当前操作 |

### 6.6 Error Codes

| Code | Name | Description |
|------|------|-------------|
| 0x0 | NONE | 无错误 |
| 0x1 | FW_LOAD_FAIL | 固件加载失败 |
| 0x2 | HASH_FAIL | 哈希计算失败 |
| 0x3 | OTP_READ_FAIL | OTP 读取失败 |
| 0x4 | OTP_LOCKED_FAIL | OTP 未锁定状态异常 |
| 0x5 | SIG_INVALID_R | 签名 R 分量无效 |
| 0x6 | SIG_INVALID_S | 签名 S 分量无效 |
| 0x7 | SIG_VERIFY_FAIL | 签名验证失败 |
| 0x8 | KEY_INVALID | 公钥无效 |
| 0x9 | VERSION_MISMATCH | 固件版本低于 OTP 版本 |
| 0xA | TEST_MODE_FAIL | TEST_MODE 认证失败 |
| 0xB | LOCKOUT | 达到最大重试次数 |
| 0xC | ABORT | 操作中止 |
| 0xD-0xF | Reserved | 预留 |