---
module: M14
type: verification
status: complete
parent: null
module_type: control
generated: "2026-05-17T16:30:00+08:00"
---

# M14: Secure Boot Verification Plan

## 1. Overview

M14 Secure Boot 验证计划覆盖安全启动流程的完整验证，重点包括 ECDSA-P256 签名验证、SHA-256 Hash 计算、OTP/eFuse Key 存储访问和 TEST_MODE 安全控制。

### 1.1 Verification Scope

| Category | Description | Priority |
|----------|-------------|----------|
| ECDSA-P256 Verification | 签名验证正确性 | Critical |
| SHA-256 Hash | 哈希计算正确性 | Critical |
| OTP/eFuse Access | 密钥存储接口 | Critical |
| TEST_MODE Security | 测试模式安全门控 | Critical |
| Boot FSM | 启动状态机流程 | High |
| Retry/Lockout | 重试和锁定机制 | High |
| Rollback Protection | 回滚保护功能 | Medium |
| DVFS Impact | DVFS 对验证时间影响 | Medium |

### 1.2 Coverage Goals

| Metric | Target | Description |
|--------|--------|-------------|
| ECDSA Coverage | 100% | 所有验证路径 |
| SHA-256 Coverage | 100% | 所有哈希计算 |
| FSM Coverage | 100% | 8个状态全覆盖 |
| OTP Access Coverage | 100% | 所有地址访问 |
| Security Pin Coverage | 100% | SEC_BOOT_EN, SEC_STATUS |

---

## 2. Functional Coverage Points

### 2.1 Boot FSM Coverage

| Coverpoint | Values | Description |
|------------|--------|-------------|
| boot_state | 0-7 | IDLE, LOAD_FW, COMPUTE_HASH, READ_OTP, VERIFY_SIG, COMPLETE, FAILED, LOCKED |
| boot_state_transition | All transitions | 所有状态转换 |
| boot_complete | True/False | 启动完成 |
| boot_fail | True/False | 启动失败 |
| sec_locked | True/False | 安全锁定状态 |

### 2.2 SHA-256 Coverage

| Coverpoint | Values | Description |
|------------|--------|-------------|
| hash_block_count | 1-N | 哈希块数量 |
| hash_padding | Normal/Last | 填充处理 |
| hash_output | 256-bit | 哈希输出值 |
| hash_throughput | 1 block/64 cycles | 吞吐率验证 |

### 2.3 ECDSA-P256 Coverage

| Coverpoint | Values | Description |
|------------|--------|-------------|
| sig_r_valid | Valid/Invalid | R分量有效性 |
| sig_s_valid | Valid/Invalid | S分量有效性 |
| sig_verify_result | Pass/Fail | 验证结果 |
| pubkey_valid | Valid/Invalid | 公钥有效性 |
| curve_operation | All ops | P-256曲线操作 |

### 2.4 OTP/eFuse Coverage

| Coverpoint | Values | Description |
|------------|--------|-------------|
| otp_address | 0x00-0x0F | OTP 地址范围 |
| otp_read_success | True/False | 读取成功 |
| otp_locked | True/False | OTP 锁定状态 |
| otp_key_valid | True/False | 密钥有效 |

### 2.5 TEST_MODE Coverage

| Coverpoint | Values | Description |
|------------|--------|-------------|
| test_mode_level | 0-7 | TEST_MODE 级别 |
| test_bypass_enabled | True/False | 绕过使能 |
| test_auth_success | True/False | 认证成功 |
| test_timeout | Hit/Miss | 超时触发 |

### 2.6 Retry/Lockout Coverage

| Coverpoint | Values | Description |
|------------|--------|-------------|
| fail_count | 0-3+ | 失败计数 |
| retry_count | 0-3 | 重试计数 |
| lockout_triggered | True/False | 锁定触发 |
| unlock_success | True/False | 解锁成功 |

---

## 3. Assertion List

### 3.1 Boot FSM Assertions

| ID | Assertion | Description |
|----|-----------|-------------|
| A14-001 | `assert (boot_state == IDLE after reset)` | 复位后进入 IDLE |
| A14-002 | `assert (boot_state == LOAD_FW after boot_start if sec_boot_en)` | 启动信号触发固件加载 |
| A14-003 | `assert (boot_state == COMPLETE if sec_boot_en == 0)` | Secure Boot 禁用时直接完成 |
| A14-004 | `assert (boot_state == FAILED if verify_failed)` | 验证失败进入 FAILED |
| A14-005 | `assert (boot_state == LOCKED if fail_count >= 3)` | 失败计数达阈值锁定 |
| A14-006 | `assert (isa_decoder_en == 1 after boot_complete)` | 启动完成使能解码器 |
| A14-007 | `assert (isa_decoder_lock == 1 if boot_state == LOCKED)` | 锁定状态禁用解码器 |

### 3.2 SHA-256 Assertions

| ID | Assertion | Description |
|----|-----------|-------------|
| A14-008 | `assert (hash_output == expected_hash(test_vector))` | 哈希输出正确（已知测试向量） |
| A14-009 | `assert (hash_complete after fw_data_last)` | 固件加载完成触发哈希计算 |
| A14-010 | `assert (hash_latency == fw_size/64 * 64 cycles)` | 哈希延迟正确 |

### 3.3 ECDSA-P256 Assertions

| ID | Assertion | Description |
|----|-----------|-------------|
| A14-011 | `assert (verify_pass if valid_signature(test_vector))` | 有效签名验证通过 |
| A14-012 | `assert (verify_fail if invalid_signature(test_vector))` | 无效签名验证失败 |
| A14-013 | `assert (sig_r_in_range if r in [1, n-1])` | R分量范围检查 |
| A14-014 | `assert (sig_s_in_range if s in [1, n-1])` | S分量范围检查 |
| A14-015 | `assert (ecdsa_latency <= 50K cycles)` | ECDSA 验证延迟 |

### 3.4 OTP/eFuse Assertions

| ID | Assertion | Description |
|----|-----------|-------------|
| A14-016 | `assert (otp_key_valid after otp_read_ack)` | OTP 读取后密钥有效 |
| A14-017 | `assert (otp_locked after otp_lock_force)` | OTP 强制锁定生效 |
| A14-018 | `assert (otp_key_readonly if otp_locked)` | 锁定后密钥只读 |

### 3.5 TEST_MODE Assertions

| ID | Assertion | Description |
|----|-----------|-------------|
| A14-019 | `assert (test_bypass disabled if test_mode_en == 0)` | TEST_MODE 禁用时绕过无效 |
| A14-020 | `assert (test_bypass enabled if test_auth_success)` | 认证成功后绕过使能 |
| A14-021 | `assert (test_timeout triggers disable)` | 超时自动禁用 TEST_MODE |
| A14-022 | `assert (physical_access_required for TEST_MODE)` | TEST_MODE 需物理访问 |

### 3.6 Security Pin Assertions

| ID | Assertion | Description |
|----|-----------|-------------|
| A14-023 | `assert (SEC_STATUS == 0 if boot_complete)` | 启动完成输出状态0 |
| A14-024 | `assert (SEC_STATUS == 1 if boot_fail OR sec_lock)` | 失败/锁定输出状态1 |
| A14-025 | `assert (SEC_BOOT_EN triggers secure boot)` | SEC_BOOT_EN 启用安全启动 |

### 3.7 Rollback Protection Assertions

| ID | Assertion | Description |
|----|-----------|-------------|
| A14-026 | `assert (version_check if rollback_protect)` | 回滚保护启用版本检查 |
| A14-027 | `assert (reject_older if fw_version < otp_version)` | 拒绝旧版本固件 |

---

## 4. Test Scenarios

### 4.1 SHA-256 Tests

| Test ID | Name | Description | Duration |
|---------|------|-------------|----------|
| T14-001 | sha256_known_vectors | 已知测试向量验证 | 10 tests |
| T14-002 | sha256_empty_input | 空输入哈希测试 | 1 test |
| T14-003 | sha256_large_input | 大固件哈希测试 | 5 tests |
| T14-004 | sha256_padding | 填充处理测试 | 5 tests |
| T14-005 | sha256_throughput | 吞吐率测试 | 3 tests |

### 4.2 ECDSA-P256 Tests

| Test ID | Name | Description | Duration |
|---------|------|-------------|----------|
| T14-006 | ecdsa_valid_signature | 有效签名验证测试 | 10 tests |
| T14-007 | ecdsa_invalid_signature | 无效签名验证测试 | 10 tests |
| T14-008 | ecdsa_r_out_of_range | R分量范围外测试 | 5 tests |
| T14-009 | ecdsa_s_out_of_range | S分量范围外测试 | 5 tests |
| T14-010 | ecdsa_invalid_pubkey | 无效公钥测试 | 5 tests |
| T14-011 | ecdsa_timing | 验证时间测试 | 5 tests |

### 4.3 OTP/eFuse Tests

| Test ID | Name | Description | Duration |
|---------|------|-------------|----------|
| T14-012 | otp_read_all_addresses | 所有地址读取测试 | 16 tests |
| T14-013 | otp_key_valid_check | 密钥有效性检查 | 5 tests |
| T14-014 | otp_lock_sequence | OTP 锁定序列测试 | 5 tests |
| T14-015 | otp_anti_tamper | 防篡改检测测试 | 3 tests |

### 4.4 TEST_MODE Tests

| Test ID | Name | Description | Duration |
|---------|------|-------------|----------|
| T14-016 | test_mode_activation | TEST_MODE 激活测试 | 5 tests |
| T14-017 | test_mode_bypass_levels | 绕过级别测试 | 8 tests |
| T14-018 | test_mode_auth | 认证流程测试 | 10 tests |
| T14-019 | test_mode_timeout | 超时机制测试 | 5 tests |
| T14-020 | test_mode_physical_access | 物理访问要求测试 | 5 tests |

### 4.5 Boot FSM Tests

| Test ID | Name | Description | Duration |
|---------|------|-------------|----------|
| T14-021 | boot_fsm_states | FSM 状态测试 | 8 tests |
| T14-022 | boot_fsm_transitions | FSM 转换测试 | 15 tests |
| T14-023 | boot_success_flow | 成功启动流程 | 5 tests |
| T14-024 | boot_fail_flow | 失败启动流程 | 5 tests |
| T14-025 | boot_bypass_flow | 绕过启动流程 | 5 tests |

### 4.6 Retry/Lockout Tests

| Test ID | Name | Description | Duration |
|---------|------|-------------|----------|
| T14-026 | retry_count_test | 重试计数测试 | 5 tests |
| T14-027 | lockout_trigger | 锁定触发测试 | 5 tests |
| T14-028 | unlock_sequence | 解锁序列测试 | 5 tests |
| T14-029 | lockout_persistence | 锁定持久性测试 | 5 tests |

### 4.7 Security Pin Tests

| Test ID | Name | Description | Duration |
|---------|------|-------------|----------|
| T14-030 | sec_boot_en_test | SEC_BOOT_EN 测试 | 5 tests |
| T14-031 | sec_status_test | SEC_STATUS 输出测试 | 10 tests |
| T14-032 | sec_pin_combinations | 安全引脚组合测试 | 10 tests |

### 4.8 Integration Tests

| Test ID | Name | Description | Duration |
|---------|------|-------------|----------|
| T14-033 | full_boot_cycle | 完整启动周期测试 | 10 tests |
| T14-034 | dvfs_impact | DVFS 对验证时间影响 | 5 tests |
| T14-035 | power_gate_impact | Power Gate 影响测试 | 5 tests |

---

## 5. Coverage Targets

### 5.1 Code Coverage

| Type | Target | Description |
|------|--------|-------------|
| Line Coverage | 100% | 所有 RTL 行 |
| Branch Coverage | 100% | 所有分支 |
| Condition Coverage | 100% | 所有条件表达式 |
| FSM Coverage | 100% | 所有 FSM 状态和转换 |
| Toggle Coverage | 100% | 所有信号翻转 |

### 5.2 Functional Coverage

| Covergroup | Target | Description |
|------------|--------|-------------|
| boot_fsm_cg | 100% | Boot FSM 覆盖组 |
| sha256_cg | 100% | SHA-256 覆盖组 |
| ecdsa_cg | 100% | ECDSA 覆盖组 |
| otp_cg | 100% | OTP/eFuse 覆盖组 |
| test_mode_cg | 100% | TEST_MODE 覆盖组 |
| security_cg | 100% | Security Pin 覆盖组 |

### 5.3 Security Test Vectors

| Test Vector | Source | Description |
|-------------|--------|-------------|
| SHA-256 TV | NIST FIPS 180-2 | 标准测试向量 |
| ECDSA-P256 TV | NIST FIPS 186-4 | 标准签名测试向量 |
| P-256 Curve TV | secp256r1 | 曲线参数验证 |

---

## 6. Verification Tools

### 6.1 Simulation Tools

| Tool | Version | Usage |
|------|---------|-------|
| Verilator | 5.x | RTL 仿真 |
| ModelSim/Questa | 2024.x | RTL 仿真 + Coverage |
| VCS | 2024.x | 形式验证支持 |

### 6.2 Formal Verification

| Tool | Usage |
|------|-------|
| JasperGold | Security 属性形式验证 |
| OneSpin | FSM 形式验证 |
| SymbiYosys | 开源形式验证 |

### 6.3 Security Analysis

| Tool | Usage |
|------|-------|
| Security Lint | 代码安全扫描 |
| Constant-Time Check | 时序侧信道检查 |
| Fault Injection | 故障注入测试 |

### 6.4 Testbench Framework

| Component | Description |
|-----------|-------------|
| UVM Testbench | SystemVerilog UVM 验证环境 |
| Firmware Generator | 测试固件生成器 |
| Signature Generator | 测试签名生成器 |
| OTP Emulator | OTP/eFuse 仿真模型 |

### 6.5 Test Sequence

| Phase | Tests | Duration |
|-------|-------|----------|
| Phase 1: SHA-256 | T14-001 to T14-005 | 1 day |
| Phase 2: ECDSA | T14-006 to T14-011 | 2 days |
| Phase 3: OTP | T14-012 to T14-015 | 1 day |
| Phase 4: TEST_MODE | T14-016 to T14-020 | 1 day |
| Phase 5: FSM | T14-021 to T14-025 | 1 day |
| Phase 6: Retry/Lockout | T14-026 to T14-029 | 1 day |
| Phase 7: Integration | T14-033 to T14-035 | 1 day |

---

## 7. Regression Strategy

### 7.1 Daily Regression

| Test Set | Frequency | Duration |
|----------|-----------|----------|
| SHA-256 Basic | Daily | 15 min |
| ECDSA Basic | Daily | 30 min |
| FSM Basic | Daily | 15 min |

### 7.2 Weekly Regression

| Test Set | Frequency | Duration |
|----------|-----------|----------|
| Full Test Suite | Weekly | 3 hours |
| Coverage Analysis | Weekly | 1 hour |
| Security Analysis | Weekly | 2 hours |

### 7.3 Release Regression

| Test Set | Frequency | Duration |
|----------|-----------|----------|
| All Tests | Pre-release | 6 hours |
| Formal Verification | Pre-release | 12 hours |
| Security Audit | Pre-release | 4 hours |