---
ip_id: IP-COMP-03-PIPELINE
ip_type: compute
ip_class: pipeline
title: Compute IP Pipeline Design Template
version: 0.1-template
status: template
tier: 0
domain: Implementation
owner: TBD
parent_doc: IP-COMP-02-MAS
derived_from: []
generated: 2026-04-23T23:00:00+08:00
---

# 计算模块 IP 流水线设计模板

## 0. Document Control

| Version | Date | Author | Change |
|---|---|---|---|
| 0.1 | YYYY-MM-DD | {{ Owner }} | Initial |

---

## 1. 流水线概述

- **流水线类型**: {{ Pipeline类型（如5-stage/7-stage/超标量） }}
- **总Stage数**: {{ N }}
- **目标吞吐量**: {{ N }} ops/cycle
- **最大延迟**: {{ N }} cycles

---

## 2. 流水线结构

### 2.1 整体架构图

```mermaid
graph LR
    subgraph Pipeline
        S1[Stage 1: {{ NAME }}]
        S2[Stage 2: {{ NAME }}]
        S3[Stage 3: {{ NAME }}]
        S4[Stage 4: {{ NAME }}]
        S5[Stage 5: {{ NAME }}]
        S1 --> S2 --> S3 --> S4 --> S5
    end
    
    subgraph Bypass["前递路径"]
        BP1[前递1]
        BP2[前递2]
    end
    
    S3 -.-> BP1 -.-> S2
    S5 -.-> BP2 -.-> S3
```

### 2.2 Stage 详细定义

| Stage | 名称 | 功能 | 输入 | 输出 | 延迟 |
|-------|------|------|------|------|------|
| S1 | {{ NAME }} | {{ FUNC }} | {{ IN }} | {{ OUT }} | {{ N }} cycles |
| S2 | {{ NAME }} | {{ FUNC }} | {{ IN }} | {{ OUT }} | {{ N }} cycles |
| S3 | {{ NAME }} | {{ FUNC }} | {{ IN }} | {{ OUT }} | {{ N }} cycles |
| S4 | {{ NAME }} | {{ FUNC }} | {{ IN }} | {{ OUT }} | {{ N }} cycles |
| S5 | {{ NAME }} | {{ FUNC }} | {{ IN }} | {{ OUT }} | {{ N }} cycles |

---

## 3. 流水线寄存器

### 3.1 Stage间寄存器定义

| 寄存器名 | 位宽 | Stage | 功能 |
|----------|------|-------|------|
| {{ REG }} | {{ WIDTH }} | {{ STAGE }} | {{ FUNC }} |
| {{ REG }} | {{ WIDTH }} | {{ STAGE }} | {{ FUNC }} |

### 3.2 关键控制信号

| 信号名 | 方向 | 功能 |
|--------|------|------|
| stall | IN | 流水线暂停 |
| flush | IN | 流水线冲刷 |
| {{ SIGNAL }} | {{ DIR }} | {{ FUNC }} |

---

## 4. 数据前递

### 4.1 前递路径定义

| 前递源 | 前递目标 | 数据类型 | 条件 |
|--------|----------|----------|------|
| {{ SOURCE }} | {{ TARGET }} | {{ TYPE }} | {{ COND }} |
| {{ SOURCE }} | {{ TARGET }} | {{ TYPE }} | {{ COND }} |

### 4.2 前递逻辑

```
forward_select:
  if (result_ready_from_S3 && dependency_on_S3_result)
    select_forward_path_1
  elif (result_ready_from_S5 && dependency_on_S5_result)
    select_forward_path_2
  else
    select_register_file
```

---

## 5. 流量控制

### 5.1 背压机制

| 场景 | 检测条件 | 响应动作 |
|------|----------|----------|
| 下级忙 | {{ COND }} | {{ ACTION }} |
| 资源满 | {{ COND }} | {{ ACTION }} |
| 冲刷请求 | {{ COND }} | {{ ACTION }} |

### 5.2 Stall 类型

| Stall类型 | 原因 | 恢复条件 |
|-----------|------|----------|
| 数据依赖 | RAW/WAR/WAW | 数据就绪 |
| 资源冲突 | {{ REASON }} | 资源可用 |
| Cache miss | {{ REASON }} | 数据返回 |

---

## 6. 分支预测

### 6.1 预测策略

| 策略 | 参数 | 准确率目标 |
|------|------|------------|
| {{ STRATEGY }} | {{ PARAM }} | {{ TARGET }} |

### 6.2 分支目标缓冲（BTB）

| 参数 | 值 |
|------|---|
| Entry数 | {{ N }} |
| 标签位宽 | {{ WIDTH }} |
| 目标位宽 | {{ WIDTH }} |

### 6.3 分支历史表（BHT）

| 参数 | 值 |
|------|---|
| Entry数 | {{ N }} |
| History位宽 | {{ N }} bits |
| 预测算法 | {{ ALGORITHM }} |

### 6.4 分支恢复流程

```
Branch Misprediction Recovery:
1. 检测到误预测
2. 冲刷错误路径指令
3. 恢复正确PC
4. 更新预测器状态
5. 重新取指
```

---

## 7. 指令分发

### 7.1 分发队列

| 参数 | 值 |
|------|---|
| 深度 | {{ N }} entries |
| 每周期分发数 | {{ N }} |

### 7.2 分发策略

| 策略 | 描述 |
|------|------|
| {{ STRATEGY }} | {{ DESC }} |

---

## 8. 完成与提交

### 8.1 完成队列（Reorder Buffer）

| 参数 | 值 |
|------|---|
| 深度 | {{ N }} entries |
| 完成宽度 | {{ N }} |

### 8.2 提交策略

| 策略 | 描述 |
|------|------|
| {{ STRATEGY }} | {{ DESC }} |

---

## 9. 关键时序

### 9.1 关键路径分析

| 路径 | 起点 | 终点 | 延迟约束 |
|------|------|------|----------|
| {{ PATH }} | {{ START }} | {{ END }} | {{ N }} ns |

### 9.2 流水线平衡

| Stage | 逻辑延迟 | 寄存器延迟 | 总延迟 |
|-------|----------|------------|--------|
| S1 | {{ N }} ns | {{ N }} ns | {{ N }} ns |
| S2 | {{ N }} ns | {{ N }} ns | {{ N }} ns |

---

## 10. 性能分析

### 10.1 IPC 分析

| 场景 | IPC |
|------|-----|
| 无Stall | {{ N }} |
| 有分支误预测 | {{ N }} |
| 有Cache miss | {{ N }} |

### 10.2 瓶颈分析

| Stage | 瓶颈原因 | 优化建议 |
|-------|----------|----------|
| {{ STAGE }} | {{ REASON }} | {{ SUGGESTION }} |

---

## 11. Quality Checklist

- [ ] 所有Stage定义完整
- [ ] Stage间寄存器定义完整
- [ ] 前递路径定义完整
- [ ] 背压机制明确
- [ ] 分支预测策略明确
- [ ] 关键路径分析完成
- [ ] 流水线平衡验证
- [ ] IPC 分析完成