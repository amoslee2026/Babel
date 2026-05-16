---
ip_id: IP-COMP-06-VERIFY
ip_type: compute
ip_class: verify
title: Compute IP Verification Plan Template
version: 0.1-template
status: template
tier: 0
domain: Verification
owner: TBD
parent_doc: IP-COMP-02-MAS
derived_from: []
references: [Accellera UVM, IEEE 1800 SystemVerilog]
generated: 2026-04-23T23:00:00+08:00
---

# 计算模块 IP 验证计划模板

## 0. Document Control

| Version | Date | Author | Change |
|---|---|---|---|
| 0.1 | YYYY-MM-DD | {{ Owner }} | Initial |

---

## 1. 验证概述

- **IP名称**: {{ IP_NAME }}
- **验证方法**: UVM + Formal + Emulation
- **覆盖率目标**: 100% Functional, ≥95% Code
- **Sign-off标准**: All testpoints PASSED or WAIVED

---

## 2. Testbench 架构

### 2.1 架构图

```mermaid
graph TB
    subgraph Testbench
        TOP[top_tb]
        ENV[uvm_env]
        AGENT_IN[Input Agent]
        AGENT_OUT[Output Agent]
        SCOREBOARD[Scoreboard]
        REF_MODEL[Reference Model]
        REG_MODEL[UVM Reg Model]
        COV[Coverage Collector]
        
        TOP --> ENV
        ENV --> AGENT_IN --> DUT
        ENV --> AGENT_OUT --> DUT
        DUT --> SCOREBOARD --> REF_MODEL
        ENV --> REG_MODEL --> DUT
        ENV --> COV
    end
    
    DUT[{{ IP_NAME }} DUT]
```

### 2.2 组件列表

| 组件 | 用途 |
|------|------|
| Input Agent | 驱动指令请求 |
| Output Agent | 监控执行结果 |
| Reference Model | Golden实现 |
| Scoreboard | 结果比对 |
| Coverage Collector | 覆盖率收集 |

---

## 3. Testpoint 清单

### 3.1 功能验证点

| TP ID | Feature | Scenario | Owner | Status | Method |
|-------|---------|----------|-------|--------|--------|
| TP-COMP-001 | 取指 | 基本取指 | {{ NAME }} | Draft | Sim |
| TP-COMP-002 | 取指 | 分支跳转 | {{ NAME }} | Draft | Sim |
| TP-COMP-003 | 译码 | 所有指令类型 | {{ NAME }} | Draft | Sim |
| TP-COMP-004 | ALU | 所有操作 | {{ NAME }} | Draft | Sim |
| TP-COMP-005 | ALU | 边界值 | {{ NAME }} | Draft | Sim |
| TP-COMP-006 | 乘法器 | 正确性 | {{ NAME }} | Draft | Sim |
| TP-COMP-007 | 乘法器 | 性能 | {{ NAME }} | Draft | Sim |
| TP-COMP-008 | 流水线 | 前递正确性 | {{ NAME }} | Draft | Sim |
| TP-COMP-009 | 流水线 | 背压处理 | {{ NAME }} | Draft | Sim |
| TP-COMP-010 | 分支预测 | 命中/误预测 | {{ NAME }} | Draft | Sim |
| {{ TP_ID }} | {{ FEAT }} | {{ SCEN }} | {{ NAME }} | {{ STAT }} | {{ METH }} |

### 3.2 边界验证点

| TP ID | Feature | Scenario | Owner | Status |
|-------|---------|----------|-------|--------|
| TP-BOUND-001 | 最大频率 | 频率扫描 | {{ NAME }} | Draft |
| TP-BOUND-002 | 最大负载 | 背压边界 | {{ NAME }} | Draft |
| {{ TP_ID }} | {{ FEAT }} | {{ SCEN }} | {{ NAME }} | {{ STAT }} |

### 3.3 异常验证点

| TP ID | Feature | Scenario | Owner | Status |
|-------|---------|----------|-------|--------|
| TP-ERR-001 | 错误处理 | Invalid opcode | {{ NAME }} | Draft |
| TP-ERR-002 | 错误处理 | ALU overflow | {{ NAME }} | Draft |
| TP-ERR-003 | 错误处理 | Watchdog timeout | {{ NAME }} | Draft |
| {{ TP_ID }} | {{ FEAT }} | {{ SCEN }} | {{ NAME }} | {{ STAT }} |

---

## 4. 验证方法矩阵

### 4.1 方法分配

| 验证层级 | Simulation | Formal | Emulation | FPGA |
|----------|------------|--------|-----------|------|
| Block-level | ★★★★★ | ★★★★ | ★★ | ★★ |
| IP-level | ★★★★ | ★★★ | ★★★ | ★★★ |
| Integration | ★★★ | ★★ | ★★★★ | ★★★★ |

### 4.2 Formal 验证目标

| 目标 | 属性 | Tool |
|------|------|------|
| FSM可达性 | 所有状态可达 | JasperGold |
| CDC稳定性 | 无metastability | VC Formal |
| 死锁检测 | 无死锁 | JasperGold |
| {{ TARGET }} | {{ PROP }} | {{ TOOL }} |

---

## 5. Coverage 模型

### 5.1 Code Coverage

| 类型 | 目标 | 说明 |
|------|------|------|
| Statement | ≥ 95% | 可waive不可达代码 |
| Branch | ≥ 90% | 条件分支 |
| FSM Arc | ≥ 95% | 状态转移 |
| Toggle | ≥ 80% | 可waive低活跃信号 |

### 5.2 Functional Coverage

| Covergroup | 目标 | 说明 |
|------------|------|------|
| CG_INSTR | 100% | 所有指令类型 |
| CG_OPCODE | 100% | 所有操作码 |
| CG_PIPELINE | 100% | 流水线状态组合 |
| CG_BRANCH | 100% | 分支预测结果 |
| CG_ADDR | 100% | 地址范围覆盖 |
| {{ CG }} | {{ TARGET }} | {{ DESC }} |

### 5.3 Assertion Coverage

| 类型 | 目标 | 说明 |
|------|------|------|
| Immediate | ≥ 95% | 立即断言 |
| Concurrent | ≥ 98% | 并发断言 |
| Cover | 100% | 覆盖断言 |

---

## 6. 测试用例

### 6.1 基础测试用例

| TC ID | 描述 | TP映射 | 状态 |
|-------|------|--------|------|
| TC-BASIC-001 | 单条指令执行 | TP-COMP-001 | Pending |
| TC-BASIC-002 | 连续指令执行 | TP-COMP-001 | Pending |
| TC-BASIC-003 | 所有ALU操作 | TP-COMP-004 | Pending |
| {{ TC_ID }} | {{ DESC }} | {{ TP }} | {{ STAT }} |

### 6.2 性能测试用例

| TC ID | 描述 | 目标 | 状态 |
|-------|------|------|------|
| TC-PERF-001 | IPC测试 | ≥ {{ N }} | Pending |
| TC-PERF-002 | 吞吐量测试 | ≥ {{ N }} | Pending |
| {{ TC_ID }} | {{ DESC }} | {{ TARGET }} | {{ STAT }} |

### 6.3 压力测试用例

| TC ID | 描述 | 条件 | 状态 |
|-------|------|------|------|
| TC-STRESS-001 | 长时间运行 | {{ N }} hours | Pending |
| TC-STRESS-002 | 最大负载 | 100% utilization | Pending |
| {{ TC_ID }} | {{ DESC }} | {{ COND }} | {{ STAT }} |

---

## 7. Regression 策略

### 7.1 Regression 类型

| 类型 | 频率 | 用例数 |
|------|------|--------|
| Nightly | 每日 | {{ N }} |
| Weekly | 每周 | {{ N }} |
| Full | Release前 | {{ N }} |

### 7.2 Regression 通过标准

| 标准 | 值 |
|------|---|
| Pass rate | 100% (除waived) |
| Coverage | ≥ 目标值 |
| New bug | 0 |

---

## 8. Bug 管理

### 8.1 Bug 分类

| 级别 | 定义 | 处理时限 |
|------|------|----------|
| Critical | 功能阻塞 | 24h |
| High | 影响功能 | 3d |
| Medium | 边界问题 | 1w |
| Low | 建议 | Backlog |

### 8.2 Bug 曲线目标

| 阶段 | Bug率目标 |
|------|-----------|
| 早期 (0-30%) | 高斜率 |
| 中期 (30-70%) | 线性下降 |
| 后期 (70-100%) | < 0.1/1K cycles |
| Sign-off | 0 new bug ≥ 2w |

---

## 9. Sign-off 标准

### 9.1 覆盖率达标

| 指标 | 目标 | 实际 |
|------|------|------|
| Functional | 100% | {{ ACT }} |
| Statement | ≥ 95% | {{ ACT }} |
| Branch | ≥ 90% | {{ ACT }} |
| FSM Arc | ≥ 95% | {{ ACT }} |
| Assertion | ≥ 98% | {{ ACT }} |

### 9.2 Testpoint 状态

| 状态 | 数量 |
|------|------|
| PASSED | {{ N }} |
| WAIVED | {{ N }} (有正当理由) |
| PENDING | 0 |

### 9.3 Bug 状态

| 状态 | 数量 |
|------|------|
| Closed | {{ N }} |
| Open | 0 |
| Waived | {{ N }} (有正当理由) |

---

## 10. Quality Checklist

- [ ] Testbench架构完整
- [ ] Testpoint清单完整
- [ ] 验证方法矩阵合理
- [ ] Coverage模型定义
- [ ] 测试用例映射Testpoint
- [ ] Regression策略定义
- [ ] Bug管理流程明确
- [ ] Sign-off标准量化