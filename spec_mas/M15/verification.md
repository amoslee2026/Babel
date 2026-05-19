---
module: M15
type: verification
status: complete
parent: null
module_type: io
generated: "2026-05-17T16:30:00+08:00"
---

# M15: JTAG Interface Verification Plan

## 1. Overview

M15 JTAG Interface 验证计划覆盖 IEEE 1149.1 标准 TAP Controller、IR/DR Operations 和 Security Gating 功能验证，确保调试与测试访问接口的正确性和安全性。

### 1.1 Verification Scope

| Category | Description | Priority |
|----------|-------------|----------|
| TAP Controller FSM | IEEE 1149.1 状态机 | Critical |
| IR Operations | 指令寄存器操作 | Critical |
| DR Operations | 数据寄存器操作 | Critical |
| Security Gating | TEST_MODE 安全门控 | Critical |
| Scan Chain Access | Scan Chain 访问控制 | High |
| Debug Access | Debug 读写功能 | High |
| Boundary Scan | BSR 功能 | High |
| MBIST Control | MBIST 控制 | Medium |

### 1.2 Coverage Goals

| Metric | Target | Description |
|--------|--------|-------------|
| FSM State Coverage | 100% | 16个 TAP 状态 |
| FSM Transition Coverage | 100% | 所有状态转换 |
| Instruction Coverage | 100% | 所有14条指令 |
| DR Coverage | 100% | 所有数据寄存器 |
| Security Coverage | 100% | TEST_MODE 门控场景 |

---

## 2. Functional Coverage Points

### 2.1 TAP FSM Coverage

| Coverpoint | Values | Description |
|------------|--------|-------------|
| tap_state | 0x0-0xF | 16个 IEEE 1149.1 状态 |
| tap_state_dr_path | Test-Logic-Reset -> DR states | DR 路径状态 |
| tap_state_ir_path | Test-Logic-Reset -> IR states | IR 路径状态 |
| tms_sequence | All valid sequences | TMS 控制序列 |

### 2.2 Instruction Coverage

| Coverpoint | Values | Description |
|------------|--------|-------------|
| instruction_opcode | 0x0-0xF | 所有指令操作码 |
| instruction_allowed | BYPASS, IDCODE | 无条件允许指令 |
| instruction_blocked | EXTEST, INTEST, SCAN, DEBUG | TEST_MODE 保护指令 |
| instruction_effect | DR selection | 指令对应的 DR 选择 |

### 2.3 DR Coverage

| Coverpoint | Values | Description |
|------------|--------|-------------|
| dr_type | BYPASS, IDCODE, BSR, SCAN, DEBUG, MBIST | 所有 DR 类型 |
| dr_width | 1, 24, 32, variable | DR 宽度 |
| dr_shift_count | 1-N | DR 移位次数 |
| dr_capture | True/False | DR Capture 操作 |
| dr_update | True/False | DR Update 操作 |

### 2.4 Security Gating Coverage

| Coverpoint | Values | Description |
|------------|--------|-------------|
| test_mode_en | 0/1 | TEST_MODE 使能状态 |
| test_mode_valid | 0/1 | TEST_MODE 验证状态 |
| instruction_blocked_count | 0-N | 被阻止指令计数 |
| security_alarm | True/False | 安全告警触发 |
| test_timeout | True/False | TEST_MODE 超时 |

### 2.5 Scan Chain Coverage

| Coverpoint | Values | Description |
|------------|--------|-------------|
| chain_id | SC0-SC3 | 4条 Scan Chain |
| chain_select | 0-3 | Scan Chain 选择 |
| chain_shift_count | 0-N | Scan Chain 移位次数 |
| chain_capture | True/False | Scan Chain Capture |
| chain_update | True/False | Scan Chain Update |

### 2.6 Debug Coverage

| Coverpoint | Values | Description |
|------------|--------|-------------|
| debug_address | 0x0000-0x0FFF | Debug 地址范围 |
| debug_rw | Read/Write | 读/写操作 |
| debug_ack | True/False | Debug 确认 |
| debug_target | M00-M14 | Debug 目标模块 |

---

## 3. Assertion List

### 3.1 TAP FSM Assertions

| ID | Assertion | Description |
|----|-----------|-------------|
| A15-001 | `assert (tap_state == Test-Logic-Reset after TRST)` | TRST 后复位状态 |
| A15-002 | `assert (tap_state transitions follow TMS)` | TMS 控制状态转换 |
| A15-003 | `assert (tap_state == Run-Test/Idle after TMS=0 for 5 cycles)` | TMS=0 5周期进入 Idle |
| A15-004 | `assert (IR == BYPASS after Test-Logic-Reset)` | 复位后 IR 为 BYPASS |
| A15-005 | `assert (tap_state valid per IEEE 1149.1)` | 状态符合 IEEE 标准 |

### 3.2 IR Operations Assertions

| ID | Assertion | Description |
|----|-----------|-------------|
| A15-006 | `assert (IR captures 0x01 in Capture-IR)` | IR Capture 值正确 |
| A15-007 | `assert (IR updated in Update-IR)` | IR Update 正确生效 |
| A15-008 | `assert (IR parity correct)` | IR 奇偶校验正确 |
| A15-009 | `assert (IR width == 5 bits)` | IR 宽度正确 |

### 3.3 DR Operations Assertions

| ID | Assertion | Description |
|----|-----------|-------------|
| A15-010 | `assert (DR selected per IR value)` | DR 选择与 IR 对应 |
| A15-011 | `assert (DR shifts in Shift-DR)` | DR 移位正确 |
| A15-012 | `assert (DR captures in Capture-DR)` | DR Capture 正确 |
| A15-013 | `assert (DR updates in Update-DR)` | DR Update 正确 |
| A15-014 | `assert (TDO output in Shift-DR/Shift-IR)` | TDO 在移位状态输出 |

### 3.4 IDCODE Assertions

| ID | Assertion | Description |
|----|-----------|-------------|
| A15-015 | `assert (IDCODE == 0x1_12345_ABC)` | IDCODE 值正确 |
| A15-016 | `assert (IDCODE manufacturer == 0xABC)` | 制造商 ID 正确 |
| A15-017 | `assert (IDCODE part_number == 0x12345)` | 部件号正确 |
| A15-018 | `assert (IDCODE version == 0x1)` | 版本号正确 |

### 3.5 Security Gating Assertions

| ID | Assertion | Description |
|----|-----------|-------------|
| A15-019 | `assert (BYPASS allowed always)` | BYPASS 指令无条件允许 |
| A15-020 | `assert (IDCODE allowed always)` | IDCODE 指令无条件允许 |
| A15-021 | `assert (EXTEST blocked if test_mode_valid == 0)` | TEST_MODE 无效时阻止 EXTEST |
| A15-022 | `assert (blocked instruction returns BYPASS)` | 阻止指令返回 BYPASS |
| A15-023 | `assert (security_alarm if unauthorized access)` | 未授权访问触发告警 |
| A15-024 | `assert (test_timeout triggers disable)` | 超时禁用 TEST_MODE |

### 3.6 Scan Chain Assertions

| ID | Assertion | Description |
|----|-----------|-------------|
| A15-025 | `assert (chain_select valid 0-3)` | Scan Chain 选择有效 |
| A15-026 | `assert (scan_enable correct per chain_select)` | Scan Enable 正确 |
| A15-027 | `assert (scan_capture triggers capture)` | Scan Capture 正确触发 |
| A15-028 | `assert (scan_update triggers update)` | Scan Update 正确触发 |

### 3.7 Debug Access Assertions

| ID | Assertion | Description |
|----|-----------|-------------|
| A15-029 | `assert (debug_address valid 0x0000-0x0FFF)` | Debug 地址有效 |
| A15-030 | `assert (debug_rw correct operation)` | Debug 读/写操作正确 |
| A15-031 | `assert (debug_ack within 2 cycles)` | Debug 确认在2周期内 |
| A15-032 | `assert (M14 debug limited)` | M14 Debug 访问受限 |

### 3.8 Boundary Scan Assertions

| ID | Assertion | Description |
|----|-----------|-------------|
| A15-033 | `assert (BSR width == 24 bits)` | BSR 宽度正确 |
| A15-034 | `assert (BSR captures pin states)` | BSR 正确捕获引脚状态 |
| A15-035 | `assert (BSR updates pin outputs)` | BSR 正确更新引脚输出 |

---

## 4. Test Scenarios

### 4.1 TAP FSM Tests

| Test ID | Name | Description | Duration |
|---------|------|-------------|----------|
| T15-001 | tap_fsm_all_states | 所有16个状态测试 | 16 tests |
| T15-002 | tap_fsm_transitions | 所有状态转换测试 | 30 tests |
| T15-003 | tap_fsm_tms_sequences | TMS 序列测试 | 20 tests |
| T15-004 | tap_fsm_reset | TRST 复位测试 | 5 tests |
| T15-005 | tap_fsm_soft_reset | 软复位测试 | 5 tests |

### 4.2 IR Operations Tests

| Test ID | Name | Description | Duration |
|---------|------|-------------|----------|
| T15-006 | ir_capture | IR Capture 测试 | 5 tests |
| T15-007 | ir_shift | IR Shift 测试 | 10 tests |
| T15-008 | ir_update | IR Update 测试 | 5 tests |
| T15-009 | ir_parity | IR 奇偶校验测试 | 5 tests |

### 4.3 DR Operations Tests

| Test ID | Name | Description | Duration |
|---------|------|-------------|----------|
| T15-010 | dr_bypass | DR_BYPASS 测试 | 5 tests |
| T15-011 | dr_idcode | DR_IDCODE 测试 | 5 tests |
| T15-012 | dr_bsr | DR_BSR 测试 | 10 tests |
| T15-013 | dr_scan | DR_SCAN 测试 | 10 tests |
| T15-014 | dr_debug | DR_DEBUG 测试 | 10 tests |
| T15-015 | dr_mbist | DR_MBIST 测试 | 10 tests |

### 4.4 Security Gating Tests

| Test ID | Name | Description | Duration |
|---------|------|-------------|----------|
| T15-016 | sec_bypass_allowed | BYPASS 无条件允许测试 | 5 tests |
| T15-017 | sec_idcode_allowed | IDCODE 无条件允许测试 | 5 tests |
| T15-018 | sec_extest_blocked | EXTEST 阻止测试 | 10 tests |
| T15-019 | sec_scan_blocked | SCAN 阻止测试 | 10 tests |
| T15-020 | sec_debug_blocked | DEBUG 阻止测试 | 10 tests |
| T15-021 | sec_timeout | TEST_MODE 超时测试 | 5 tests |
| T15-022 | sec_alarm | 安全告警测试 | 5 tests |

### 4.5 Scan Chain Tests

| Test ID | Name | Description | Duration |
|---------|------|-------------|----------|
| T15-023 | scan_chain_select | Scan Chain 选择测试 | 4 tests |
| T15-024 | scan_chain_shift | Scan Chain 移位测试 | 10 tests |
| T15-025 | scan_chain_capture | Scan Chain Capture 测试 | 5 tests |
| T15-026 | scan_chain_update | Scan Chain Update 测试 | 5 tests |
| T15-027 | scan_chain_timing | Scan Chain 时序测试 | 5 tests |

### 4.6 Debug Access Tests

| Test ID | Name | Description | Duration |
|---------|------|-------------|----------|
| T15-028 | debug_read | Debug 读测试 | 10 tests |
| T15-029 | debug_write | Debug 写测试 | 10 tests |
| T15-030 | debug_address_range | Debug 地址范围测试 | 10 tests |
| T15-031 | debug_target_modules | Debug 目标模块测试 | 15 tests |
| T15-032 | debug_m14_limited | M14 受限访问测试 | 5 tests |

### 4.7 Boundary Scan Tests

| Test ID | Name | Description | Duration |
|---------|------|-------------|----------|
| T15-033 | bsr_capture | BSR Capture 测试 | 5 tests |
| T15-034 | bsr_update | BSR Update 测试 | 5 tests |
| T15-035 | bsr_extest | EXTEST 边界扫描测试 | 10 tests |
| T15-036 | bsr_intest | INTEST 边界扫描测试 | 10 tests |

### 4.8 MBIST Tests

| Test ID | Name | Description | Duration |
|---------|------|-------------|----------|
| T15-037 | mbist_control | MBIST 控制测试 | 5 tests |
| T15-038 | mbist_status | MBIST 状态测试 | 5 tests |
| T15-039 | mbist_algorithm | MBIST 算法选择测试 | 5 tests |

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
| tap_fsm_cg | 100% | TAP FSM 覆盖组 |
| instruction_cg | 100% | 指令覆盖组 |
| dr_cg | 100% | 数据寄存器覆盖组 |
| security_cg | 100% | 安全门控覆盖组 |
| scan_chain_cg | 100% | Scan Chain 覆盖组 |
| debug_cg | 100% | Debug 覆盖组 |

### 5.3 IEEE 1149.1 Compliance

| Requirement | Test | Description |
|-------------|------|-------------|
| State Machine | T15-001-005 | IEEE 1149.1 状态机 |
| Instructions | T15-006-009 | 指令寄存器 |
| DR Operations | T15-010-015 | 数据寄存器操作 |
| Boundary Scan | T15-033-036 | 边界扫描功能 |

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
| JasperGold | IEEE 1149.1 属性验证 |
| OneSpin | FSM 形式验证 |
| SymbiYosys | 开源形式验证 |

### 6.3 JTAG Compliance Tools

| Tool | Usage |
|------|-------|
| JTAG Compliance Suite | IEEE 1149.1 标准测试套件 |
| Boundary Scan Analyzer | 边界扫描分析工具 |

### 6.4 Testbench Framework

| Component | Description |
|-----------|-------------|
| UVM Testbench | SystemVerilog UVM 验证环境 |
| JTAG Sequencer | JTAG 指令序列生成器 |
| TAP Model | IEEE 1149.1 TAP 模型 |
| Security Monitor | TEST_MODE 安全监控 |

### 6.5 Test Sequence

| Phase | Tests | Duration |
|-------|-------|----------|
| Phase 1: TAP FSM | T15-001 to T15-005 | 1 day |
| Phase 2: IR Operations | T15-006 to T15-009 | 1 day |
| Phase 3: DR Operations | T15-010 to T15-015 | 2 days |
| Phase 4: Security | T15-016 to T15-022 | 1 day |
| Phase 5: Scan Chain | T15-023 to T15-027 | 1 day |
| Phase 6: Debug | T15-028 to T15-032 | 1 day |
| Phase 7: Boundary Scan | T15-033 to T15-036 | 1 day |
| Phase 8: MBIST | T15-037 to T15-039 | 1 day |

---

## 7. Regression Strategy

### 7.1 Daily Regression

| Test Set | Frequency | Duration |
|----------|-----------|----------|
| TAP FSM Basic | Daily | 15 min |
| IR/DR Basic | Daily | 20 min |
| Security Basic | Daily | 15 min |

### 7.2 Weekly Regression

| Test Set | Frequency | Duration |
|----------|-----------|----------|
| Full Test Suite | Weekly | 3 hours |
| Coverage Analysis | Weekly | 1 hour |
| IEEE Compliance | Weekly | 2 hours |

### 7.3 Release Regression

| Test Set | Frequency | Duration |
|----------|-----------|----------|
| All Tests | Pre-release | 6 hours |
| Formal Verification | Pre-release | 8 hours |
| IEEE 1149.1 Compliance | Pre-release | 4 hours |