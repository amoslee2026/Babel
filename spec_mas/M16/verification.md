---
module: M16
type: verification
status: complete
parent: null
module_type: io
generated: "2026-05-17T16:30:00+08:00"
---

# M16: ISA Interface Verification Plan

## 1. Overview

M16 ISA Interface 验证计划覆盖跨时钟域 (CDC) Handshake、Instruction Parser 和 Access Control FSM 功能验证，确保 16-bit NPU 指令接口的正确性和可靠性。

### 1.1 Verification Scope

| Category | Description | Priority |
|----------|-------------|----------|
| CDC Handshake | CLK_IO -> CLK_SYS 同步 | Critical |
| Instruction Parser | 16-bit 指令解析 | Critical |
| Access Control FSM | 接口访问控制 | Critical |
| Direction Control | IO 方向切换 | High |
| Timing Protocol | Setup/Hold 时序 | High |
| Metastability | 2-stage synchronizer | High |
| Protocol FSM | 收发状态机 | Medium |
| Integration | M15 ISA Decoder 集成 | Medium |

### 1.2 Coverage Goals

| Metric | Target | Description |
|--------|--------|-------------|
| CDC Coverage | 100% | 所有 CDC 路径 |
| FSM Coverage | 100% | 收发状态机 |
| Timing Coverage | 100% | Setup/Hold 时序 |
| Metastability Coverage | 100% | 所有 synchronizer |

---

## 2. Functional Coverage Points

### 2.1 CDC Coverage

| Coverpoint | Values | Description |
|------------|--------|-------------|
| cdc_direction | Input/Output | CDC 方向 |
| cdc_latency | 1-3 cycles | CDC 延迟范围 |
| cdc_stages | 2 | 2-stage synchronizer |
| cdc_gray_encoding | True/False | Gray 编码使用 |
| cdc_handshake | Request/Ack | CDC 握手协议 |

### 2.2 Instruction Transfer Coverage

| Coverpoint | Values | Description |
|------------|--------|-------------|
| transfer_mode | Receive/Transmit/Bidir | 传输模式 |
| isa_data_value | 0x0000-0xFFFF | 16-bit 数据范围 |
| isa_valid_timing | 1 cycle | VALID 持续时间 |
| isa_ready_response | Ready/Not Ready | READY 响应 |

### 2.3 Protocol FSM Coverage

| Coverpoint | Values | Description |
|------------|--------|-------------|
| rx_fsm_state | IDLE, WAIT_READY, SAMPLE_DATA, VALID_ASSERT, CDC_SYNC, COMPLETE | 接收状态机 |
| tx_fsm_state | IDLE, WAIT_DATA, CDC_SYNC, DRIVE_BUS, VALID_ASSERT, WAIT_READY, COMPLETE | 发送状态机 |
| fsm_transition | All transitions | 所有状态转换 |

### 2.4 Timing Coverage

| Coverpoint | Values | Description |
|------------|--------|-------------|
| setup_time | >= 2 ns | Setup 时间满足 |
| hold_time | >= 0.5 ns | Hold 时间满足 |
| clock_to_output | <= 3 ns | Clock to Output |
| turnaround_time | 1 cycle | 方向切换时间 |

### 2.5 Direction Control Coverage

| Coverpoint | Values | Description |
|------------|--------|-------------|
| direction | Input/Output | IO 方向 |
| direction_switch | Input->Output, Output->Input | 方向切换 |
| tristate_control | Enable/Disable | 三态控制 |
| bus_conflict | None | 无总线冲突 |

### 2.6 Access Control Coverage

| Coverpoint | Values | Description |
|------------|--------|-------------|
| access_grant | True/False | 访问授权 |
| access_mode | 00/01/10 | 操作模式 |
| access_enable | True/False | 模块使能 |

---

## 3. Assertion List

### 3.1 CDC Assertions

| ID | Assertion | Description |
|----|-----------|-------------|
| A16-001 | `assert (cdc_latency <= 3 cycles)` | CDC 延迟 <= 3周期 |
| A16-002 | `assert (2-stage synchronizer used)` | 使用2级同步器 |
| A16-003 | `assert (gray_encoding for multi-bit counters)` | 多位计数器使用 Gray 编码 |
| A16-004 | `assert (handshake protocol for data buses)` | 数据总线使用握手协议 |
| A16-005 | `assert (no combinational logic in sync path)` | 同步路径无组合逻辑 |
| A16-006 | `assert (reset synchronized to both domains)` | 复位同步到两个时钟域 |
| A16-007 | `assert (metastability_protected)` | 亚稳态保护有效 |

### 3.2 Instruction Transfer Assertions

| ID | Assertion | Description |
|----|-----------|-------------|
| A16-008 | `assert (isa_data_sys == isa_data_io after CDC)` | CDC 后数据一致 |
| A16-009 | `assert (isa_valid_sys == isa_valid_io_sync)` | VALID 信号同步正确 |
| A16-010 | `assert (isa_data_stable during valid window)` | VALID 窗口内数据稳定 |
| A16-011 | `assert (transfer_complete after valid)` | VALID 后传输完成 |

### 3.3 Protocol FSM Assertions

| ID | Assertion | Description |
|----|-----------|-------------|
| A16-012 | `assert (rx_fsm transitions valid)` | 接收 FSM 状态转换合法 |
| A16-013 | `assert (tx_fsm transitions valid)` | 发送 FSM 状态转换合法 |
| A16-014 | `assert (rx_fsm == IDLE after reset)` | 复位后进入 IDLE |
| A16-015 | `assert (tx_fsm == IDLE after reset)` | 复位后进入 IDLE |
| A16-016 | `assert (SAMPLE_DATA occurs after ISA_READY)` | READY 后采样数据 |
| A16-017 | `assert (DRIVE_BUS occurs after CDC_SYNC)` | CDC 同步后驱动总线 |

### 3.4 Timing Assertions

| ID | Assertion | Description |
|----|-----------|-------------|
| A16-018 | `assert (setup_time >= 2 ns)` | Setup 时间 >= 2 ns |
| A16-019 | `assert (hold_time >= 0.5 ns)` | Hold 时间 >= 0.5 ns |
| A16-020 | `assert (clock_to_output <= 3 ns)` | Clock to Output <= 3 ns |
| A16-021 | `assert (turnaround_time == 1 cycle)` | Turnaround 时间 = 1周期 |

### 3.5 Direction Control Assertions

| ID | Assertion | Description |
|----|-----------|-------------|
| A16-022 | `assert (ISA_DIR == 0 for receive)` | 接收模式方向正确 |
| A16-023 | `assert (ISA_DIR == 1 for transmit)` | 发送模式方向正确 |
| A16-024 | `assert (no_bus_conflict)` | 无总线冲突 |
| A16-025 | `assert (tristate_correct)` | 三态控制正确 |

### 3.6 Access Control Assertions

| ID | Assertion | Description |
|----|-----------|-------------|
| A16-026 | `assert (access_grant if m16_enable)` | 使能时授权访问 |
| A16-027 | `assert (access_blocked if !m16_enable)` | 禁用时阻止访问 |
| A16-028 | `assert (mode_correct)` | 操作模式正确 |

---

## 4. Test Scenarios

### 4.1 CDC Tests

| Test ID | Name | Description | Duration |
|---------|------|-------------|----------|
| T16-001 | cdc_input_sync | 输入 CDC 同步测试 | 10 tests |
| T16-002 | cdc_output_sync | 输出 CDC 同步测试 | 10 tests |
| T16-003 | cdc_latency_measure | CDC 延迟测量测试 | 5 tests |
| T16-004 | cdc_gray_encoding | Gray 编码测试 | 5 tests |
| T16-005 | cdc_handshake | CDC 握手协议测试 | 10 tests |
| T16-006 | cdc_metastability | 亚稳态测试 | 5 tests |
| T16-007 | cdc_reset_sync | 复位同步测试 | 5 tests |

### 4.2 Instruction Transfer Tests

| Test ID | Name | Description | Duration |
|---------|------|-------------|----------|
| T16-008 | receive_mode | 接收模式测试 | 10 tests |
| T16-009 | transmit_mode | 发送模式测试 | 10 tests |
| T16-010 | bidirectional_mode | 双向模式测试 | 10 tests |
| T16-011 | data_value_range | 数据值范围测试 | 20 tests |
| T16-012 | valid_timing | VALID 时序测试 | 5 tests |
| T16-013 | ready_response | READY 响应测试 | 5 tests |

### 4.3 Protocol FSM Tests

| Test ID | Name | Description | Duration |
|---------|------|-------------|----------|
| T16-014 | rx_fsm_states | 接收 FSM 状态测试 | 6 tests |
| T16-015 | rx_fsm_transitions | 接收 FSM 转换测试 | 10 tests |
| T16-016 | tx_fsm_states | 发送 FSM 状态测试 | 7 tests |
| T16-017 | tx_fsm_transitions | 发送 FSM 转换测试 | 12 tests |
| T16-018 | fsm_reset | FSM 复位测试 | 5 tests |

### 4.4 Timing Tests

| Test ID | Name | Description | Duration |
|---------|------|-------------|----------|
| T16-019 | setup_time_test | Setup 时间测试 | 5 tests |
| T16-020 | hold_time_test | Hold 时间测试 | 5 tests |
| T16-021 | clock_to_output_test | Clock to Output 测试 | 5 tests |
| T16-022 | turnaround_time_test | Turnaround 时间测试 | 5 tests |
| T16-023 | timing_corners | 时序 corner 测试 | 10 tests |

### 4.5 Direction Control Tests

| Test ID | Name | Description | Duration |
|---------|------|-------------|----------|
| T16-024 | direction_switch_rx_tx | RX->TX 方向切换 | 10 tests |
| T16-025 | direction_switch_tx_rx | TX->RX 方向切换 | 10 tests |
| T16-026 | tristate_control | 三态控制测试 | 5 tests |
| T16-027 | bus_conflict_check | 总线冲突检查 | 5 tests |

### 4.6 Access Control Tests

| Test ID | Name | Description | Duration |
|---------|------|-------------|----------|
| T16-028 | access_grant_test | 访问授权测试 | 5 tests |
| T16-029 | access_block_test | 访问阻止测试 | 5 tests |
| T16-030 | mode_selection | 模式选择测试 | 10 tests |
| T16-031 | enable_disable | 使能/禁用测试 | 5 tests |

### 4.7 Integration Tests

| Test ID | Name | Description | Duration |
|---------|------|-------------|----------|
| T16-032 | m15_integration | M15 ISA Decoder 集成测试 | 10 tests |
| T16-033 | power_domain_crossing | PD_IO -> PD_MAIN 测试 | 5 tests |
| T16-034 | level_shifter | Level Shifter 测试 | 5 tests |

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
| cdc_cg | 100% | CDC 覆盖组 |
| transfer_cg | 100% | 传输覆盖组 |
| fsm_cg | 100% | FSM 覆盖组 |
| timing_cg | 100% | 时序覆盖组 |
| direction_cg | 100% | 方向控制覆盖组 |
| access_cg | 100% | 访问控制覆盖组 |

### 5.3 CDC Verification Protocol

| Check | Tool | Target |
|-------|------|--------|
| CDC Protocol | SpyGlass CDC | 100% |
| Metastability | Formal | MTBF > 10^6 |
| Timing Analysis | OpenSTA | All corners |

---

## 6. Verification Tools

### 6.1 Simulation Tools

| Tool | Version | Usage |
|------|---------|-------|
| Verilator | 5.x | RTL 仿真 |
| ModelSim/Questa | 2024.x | RTL 仿真 + Coverage |
| VCS | 2024.x | 形式验证支持 |

### 6.2 CDC Analysis Tools

| Tool | Usage |
|------|-------|
| SpyGlass CDC | CDC 协议检查 |
| Meridian CDC | CDC 形式验证 |
| CDC Analyzer | CDC 路径分析 |

### 6.3 Timing Analysis Tools

| Tool | Usage |
|------|-------|
| OpenSTA | Setup/Hold 时序分析 |
| Timing Analyzer | Corner 时序验证 |

### 6.4 Formal Verification

| Tool | Usage |
|------|-------|
| JasperGold | CDC 属性验证 |
| OneSpin | FSM 形式验证 |
| SymbiYosys | 开源形式验证 |

### 6.5 Testbench Framework

| Component | Description |
|-----------|-------------|
| UVM Testbench | SystemVerilog UVM 验证环境 |
| CDC Checker | CDC 协议检查器 |
| Timing Monitor | 时序监控 |
| Instruction Generator | 指令数据生成器 |

### 6.6 Test Sequence

| Phase | Tests | Duration |
|-------|-------|----------|
| Phase 1: CDC | T16-001 to T16-007 | 2 days |
| Phase 2: Transfer | T16-008 to T16-013 | 1 day |
| Phase 3: FSM | T16-014 to T16-018 | 1 day |
| Phase 4: Timing | T16-019 to T16-023 | 1 day |
| Phase 5: Direction | T16-024 to T16-027 | 1 day |
| Phase 6: Access | T16-028 to T16-031 | 1 day |
| Phase 7: Integration | T16-032 to T16-034 | 1 day |

---

## 7. Regression Strategy

### 7.1 Daily Regression

| Test Set | Frequency | Duration |
|----------|-----------|----------|
| CDC Basic | Daily | 20 min |
| Transfer Basic | Daily | 15 min |
| FSM Basic | Daily | 15 min |

### 7.2 Weekly Regression

| Test Set | Frequency | Duration |
|----------|-----------|----------|
| Full Test Suite | Weekly | 3 hours |
| Coverage Analysis | Weekly | 1 hour |
| CDC Analysis | Weekly | 2 hours |

### 7.3 Release Regression

| Test Set | Frequency | Duration |
|----------|-----------|----------|
| All Tests | Pre-release | 6 hours |
| CDC Formal Verification | Pre-release | 8 hours |
| Timing Analysis | Pre-release | 4 hours |