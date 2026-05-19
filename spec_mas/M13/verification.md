---
module: M13
type: verification
status: complete
parent: null
module_type: control
generated: "2026-05-17T16:30:00+08:00"
---

# M13: ISA Decoder Verification Plan

## 1. Overview

M13 ISA Decoder 验证计划覆盖自定义 NPU ISA 的指令解码、操作数提取和算子分发功能。验证重点包括 Instruction Decode 正确性、Micro-op Generation 准确性和 All ISA Formats 解析。

### 1.1 Verification Scope

| Category | Description | Priority |
|----------|-------------|----------|
| Instruction Decode | 32条指令正确解码 | High |
| Format Decode | 4种格式正确解析 | High |
| Operand Extract | 寄存器索引、立即数提取 | High |
| Micro-op Generation | 解码输出正确生成 | High |
| Dispatch Protocol | 正确分发至目标模块 | Medium |
| Branch Handling | BNZ taken/not taken | Medium |
| Secure Boot Integration | M14 验证集成 | Medium |
| Pipeline Behavior | Decode 流水线正确性 | Medium |

### 1.2 Coverage Goals

| Metric | Target | Description |
|--------|--------|-------------|
| Opcode Coverage | 100% | 所有32条指令 |
| Format Coverage | 100% | V/VI/M/S 四种格式 |
| Field Coverage | 100% | 所有字段提取 |
| FSM State Coverage | 100% | 8个状态全覆盖 |
| Transition Coverage | 100% | 所有状态转换 |

---

## 2. Functional Coverage Points

### 2.1 Opcode Coverage

| Coverpoint | Values | Description |
|------------|--------|-------------|
| opcode_all | 0x00-0x34 | 32条指令全覆盖 |
| opcode_vector_arith | 0x00-0x05 | VADD, VMUL, VSMUL, VMAC, VSUB, VCOPY |
| opcode_matmul | 0x08-0x0A | MLOAD, MMUL, MSET_DIM |
| opcode_special_func | 0x10-0x14 | VEXP, VSQRT_INV, VSIN, VCOS, VSIGMOID |
| opcode_reduction | 0x18-0x1B | VSUM, VMAX, VDOT, VARGMAX |
| opcode_memory | 0x20-0x25 | VLD, VST, SLD, SST, EMBED, ROPE_LD |
| opcode_kv_cache | 0x28-0x2A | KV_WRITE, KV_READ, KV_RESET |
| opcode_scalar_ctrl | 0x30-0x34 | SADD, SMUL, SDIV, BNZ, HALT |
| opcode_invalid | 0x06-0x07, 0x0B-0x0F, 0x15-0x17, etc. | 无效 opcode 测试 |

### 2.2 Format Coverage

| Coverpoint | Values | Description |
|------------|--------|-------------|
| format_type | 0-3 | V(00), VI(01), M(10), S(11) |
| format_v_fields | vd, vs1, vs2, vs3, func | V-Type 所有字段 |
| format_vi_fields | vd, vs1, imm16 | VI-Type 所有字段 |
| format_m_fields | vd, base, sd, offset11 | M-Type 所有字段 |
| format_s_fields | sd, imm21 | S-Type 所有字段 |

### 2.3 Register Field Coverage

| Coverpoint | Values | Description |
|------------|--------|-------------|
| vd_index | 0-31 | 目标向量寄存器索引 |
| vs1_index | 0-31 | 源向量寄存器1索引 |
| vs2_index | 0-31 | 源向量寄存器2索引 |
| vs3_index | 0-31 | 源向量寄存器3索引 |
| sd_index | 0-15 | 目标/源标量寄存器索引 |
| base_index | 0-15 | 基地址寄存器索引 |
| imm16_range | -32768 to 32767 | 16-bit 立即数范围 |
| imm21_range | -1048576 to 1048575 | 21-bit 立即数范围 |
| offset11_range | 0-2047 | 11-bit 偏移范围 |

### 2.4 FSM State Coverage

| Coverpoint | Values | Description |
|------------|--------|-------------|
| fsm_state | S0-S7 | IDLE, FETCH, OPCODE_DECODE, OPERAND_EXTRACT, DISPATCH, EXECUTE_WAIT, BRANCH_TAKEN, ERROR |
| fsm_transition | All transitions | 状态转换全覆盖 |
| fsm_error_entry | ERROR state entry | 错误状态进入 |

### 2.5 Dispatch Coverage

| Coverpoint | Values | Description |
|------------|--------|-------------|
| target_module | 0-4 | M00, M09, M10, M11, M12 |
| dispatch_handshake | valid/ready/ack | 分发握手协议 |
| dispatch_latency | 1-4 cycles | 分发延迟范围 |

---

## 3. Assertion List

### 3.1 Instruction Decode Assertions

| ID | Assertion | Description |
|----|-----------|-------------|
| A13-001 | `assert (dec_opcode_o == inst[31:26])` | Opcode 正确提取 |
| A13-002 | `assert (dec_format_o == format_decode(inst))` | Format 正确识别 |
| A13-003 | `assert (dec_vd_o == inst[25:21]) for V-Type` | VD 正确提取 (V-Type) |
| A13-004 | `assert (dec_vs1_o == inst[20:16]) for V-Type` | VS1 正确提取 (V-Type) |
| A13-005 | `assert (dec_vs2_o == inst[15:11]) for V-Type` | VS2 正确提取 (V-Type) |
| A13-006 | `assert (dec_vs3_o == inst[10:6]) for V-Type` | VS3 正确提取 (V-Type) |
| A13-007 | `assert (dec_func_o == inst[5:0]) for V-Type` | FUNC 正确提取 (V-Type) |
| A13-008 | `assert (dec_imm16_o == inst[15:0]) for VI-Type` | IMM16 正确提取 |
| A13-009 | `assert (dec_base_o == inst[15:11]) for M-Type` | BASE 正确提取 (M-Type) |
| A13-010 | `assert (dec_offset_o == inst[10:0]) for M-Type` | OFFSET 正确提取 (M-Type) |
| A13-011 | `assert (dec_sd_o == inst[25:21]) for S-Type` | SD 正确提取 (S-Type) |
| A13-012 | `assert (dec_imm21_o == inst[20:0]) for S-Type` | IMM21 正确提取 (S-Type) |

### 3.2 FSM Assertions

| ID | Assertion | Description |
|----|-----------|-------------|
| A13-013 | `assert (fsm_state != ERROR if valid_opcode)` | 有效 opcode 不进入错误状态 |
| A13-014 | `assert (fsm_state == ERROR if invalid_opcode)` | 无效 opcode 进入错误状态 |
| A13-015 | `assert (decode_latency == 4 cycles)` | 解码延迟固定4周期 |
| A13-016 | `assert (pipeline_flush == 2 cycles if BNZ taken)` | BNZ taken pipeline flush 2周期 |
| A13-017 | `assert (fsm_state transitions valid)` | FSM 状态转换合法 |

### 3.3 Dispatch Assertions

| ID | Assertion | Description |
|----|-----------|-------------|
| A13-018 | `assert (op_target_o == target_table(opcode))` | 目标模块选择正确 |
| A13-019 | `assert (op_valid_o && op_ready_i -> op_start_o)` | 分发握手协议正确 |
| A13-020 | `assert (op_done_i -> dec_done_o)` | 执行完成正确反馈 |

### 3.4 Branch Assertions

| ID | Assertion | Description |
|----|-----------|-------------|
| A13-021 | `assert (BNZ not taken if ss == 0)` | ss=0 时不分支 |
| A13-022 | `assert (BNZ taken if ss != 0)` | ss!=0 时分支 |
| A13-023 | `assert (branch_target == PC + IMM21)` | 分支目标正确计算 |
| A13-024 | `assert (PC update correct after branch)` | 分支后 PC 正确更新 |

### 3.5 Secure Boot Assertions

| ID | Assertion | Description |
|----|-----------|-------------|
| A13-025 | `assert (isa_decoder_en == 0 if sec_en_i == 0)` | Secure Boot 失败禁用解码器 |
| A13-026 | `assert (ISA_ERROR[3] == 1 if sec_en_i == 0)` | Secure Boot 失败设置错误位 |

---

## 4. Test Scenarios

### 4.1 Basic Decode Tests

| Test ID | Name | Description | Duration |
|---------|------|-------------|----------|
| T13-001 | opcode_decode_all | 测试所有32条指令解码 | 32 tests |
| T13-002 | format_decode_v | V-Type 格式解码测试 | 20 tests |
| T13-003 | format_decode_vi | VI-Type 格式解码测试 | 5 tests |
| T13-004 | format_decode_m | M-Type 格式解码测试 | 10 tests |
| T13-005 | format_decode_s | S-Type 格式解码测试 | 10 tests |

### 4.2 Operand Extraction Tests

| Test ID | Name | Description | Duration |
|---------|------|-------------|----------|
| T13-006 | reg_index_boundary | 寄存器索引边界测试 | 16 tests |
| T13-007 | imm16_range_test | IMM16 范围测试 | 10 tests |
| T13-008 | imm21_range_test | IMM21 范围测试 | 10 tests |
| T13-009 | offset11_range_test | OFFSET11 范围测试 | 10 tests |
| T13-010 | field_combination | 字段组合测试 | 50 tests |

### 4.3 Dispatch Tests

| Test ID | Name | Description | Duration |
|---------|------|-------------|----------|
| T13-011 | dispatch_m00 | 分发至 M00 Systolic Array | 5 tests |
| T13-012 | dispatch_m09 | 分发至 M09 Attention Unit | 5 tests |
| T13-013 | dispatch_m10 | 分发至 M10 FFN/MatMul Unit | 5 tests |
| T13-014 | dispatch_m11 | 分发至 M11 RMSNorm/RoPE Unit | 5 tests |
| T13-015 | dispatch_m12 | 分发至 M12 SoftMax Unit | 5 tests |
| T13-016 | dispatch_handshake | 分发握手协议测试 | 20 tests |

### 4.4 Branch Tests

| Test ID | Name | Description | Duration |
|---------|------|-------------|----------|
| T13-017 | bnz_not_taken | BNZ not taken 测试 | 5 tests |
| T13-018 | bnz_taken | BNZ taken 测试 | 5 tests |
| T13-019 | branch_target_calc | 分支目标计算测试 | 10 tests |
| T13-020 | branch_pipeline_flush | Pipeline flush 测试 | 5 tests |
| T13-021 | branch_backwards | 向后分支测试 | 5 tests |

### 4.5 Error Handling Tests

| Test ID | Name | Description | Duration |
|---------|------|-------------|----------|
| T13-022 | invalid_opcode | 无效 opcode 测试 | 10 tests |
| T13-023 | invalid_format | 无效格式测试 | 5 tests |
| T13-024 | invalid_register | 无效寄存器索引测试 | 5 tests |
| T13-025 | error_recovery | 错误恢复测试 | 10 tests |

### 4.6 Pipeline Tests

| Test ID | Name | Description | Duration |
|---------|------|-------------|----------|
| T13-026 | pipeline_stall | Pipeline stall 测试 | 10 tests |
| T13-027 | pipeline_latency | Pipeline 延迟测试 | 10 tests |
| T13-028 | pipeline_backpressure | Pipeline 反压测试 | 10 tests |

### 4.7 Integration Tests

| Test ID | Name | Description | Duration |
|---------|------|-------------|----------|
| T13-029 | secure_boot_integration | Secure Boot 集成测试 | 10 tests |
| T13-030 | m16_interface | M16 ISA Interface 集成测试 | 10 tests |
| T13-031 | scheduler_integration | M08 Scheduler 集成测试 | 10 tests |

### 4.8 Micro-op Generation Tests

| Test ID | Name | Description | Duration |
|---------|------|-------------|----------|
| T13-032 | micro_op_format | Micro-op 格式正确性 | 20 tests |
| T13-033 | micro_op_fields | Micro-op 字段正确性 | 20 tests |
| T13-034 | micro_op_timing | Micro-op 时序正确性 | 10 tests |

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
| opcode_cg | 100% | Opcode 覆盖组 |
| format_cg | 100% | Format 覆盖组 |
| register_cg | 100% | Register 索引覆盖组 |
| immediate_cg | 100% | 立即数覆盖组 |
| dispatch_cg | 100% | Dispatch 覆盖组 |
| fsm_cg | 100% | FSM 覆盖组 |

### 5.3 Assertion Coverage

| Type | Target | Description |
|------|--------|-------------|
| Assertion Fired | 100% | 所有断言至少触发一次 |
| Assertion Passed | 100% | 所有断言通过 |
| Assertion Failed | 0% | 无断言失败 |

---

## 6. Verification Tools

### 6.1 Simulation Tools

| Tool | Version | Usage |
|------|---------|-------|
| Verilator | 5.x | RTL 仿真 |
| ModelSim/Questa | 2024.x | RTL 仿真 + Coverage |
| VCS | 2024.x | Formal verification |

### 6.2 Coverage Tools

| Tool | Usage |
|------|-------|
| Verilator --coverage | 代码覆盖率 |
| ModelSim coverage | 功能覆盖率 |
| Urgent/Verdi | Coverage 分析 |

### 6.3 Formal Verification

| Tool | Usage |
|------|-------|
| OneSpin | FSM 形式验证 |
| JasperGold | 断言形式验证 |
| SymbiYosys | 开源形式验证 |

### 6.4 Testbench Framework

| Component | Description |
|-----------|-------------|
| UVM Testbench | SystemVerilog UVM 验证环境 |
| Instruction Generator | 随机指令生成器 |
| Scoreboard | 解码结果比对 |
| Coverage Collector | 覆盖率收集 |

### 6.5 Test Sequence

| Phase | Tests | Duration |
|-------|-------|----------|
| Phase 1: Basic | T13-001 to T13-010 | 1 day |
| Phase 2: Dispatch | T13-011 to T13-016 | 1 day |
| Phase 3: Branch | T13-017 to T13-021 | 1 day |
| Phase 4: Error | T13-022 to T13-025 | 1 day |
| Phase 5: Pipeline | T13-026 to T13-028 | 1 day |
| Phase 6: Integration | T13-029 to T13-031 | 2 days |
| Phase 7: Micro-op | T13-032 to T13-034 | 1 day |

---

## 7. Regression Strategy

### 7.1 Daily Regression

| Test Set | Frequency | Duration |
|----------|-----------|----------|
| Basic Decode | Daily | 30 min |
| Dispatch | Daily | 20 min |
| Branch | Daily | 15 min |

### 7.2 Weekly Regression

| Test Set | Frequency | Duration |
|----------|-----------|----------|
| Full Test Suite | Weekly | 2 hours |
| Coverage Analysis | Weekly | 1 hour |

### 7.3 Release Regression

| Test Set | Frequency | Duration |
|----------|-----------|----------|
| All Tests | Pre-release | 4 hours |
| Formal Verification | Pre-release | 8 hours |