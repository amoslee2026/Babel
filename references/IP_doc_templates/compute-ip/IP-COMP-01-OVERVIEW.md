---
ip_id: IP-COMP-01-OVERVIEW
ip_type: compute
ip_class: overview
title: Compute IP Overview Template
version: 0.1-template
status: template
tier: 0
domain: Implementation
owner: TBD
approvers: [TBD]
parent_doc: DOC-D3-01-MAS
derived_from: []
references: [IEEE 1685, IEEE 1800, IEEE 1801]
generated: 2026-04-23T23:00:00+08:00
---

# 计算模块 IP 概览模板

> 本模板定义计算类 IP 的整体架构概览，作为具体 MAS 文档的前置文档。

## 0. Document Control

| Version | Date | Author | Change |
|---|---|---|---|
| 0.1 | YYYY-MM-DD | {{ Owner }} | Initial |

---

## 1. IP 基本信息

| 属性 | 值 |
|------|---|
| **IP名称** | {{ IP_NAME }} |
| **IP类型** | cpu_core / gpu_core / ai_accel / dsp / vector / crypto |
| **版本** | {{ VERSION }} |
| **工艺节点** | {{ PROCESS_NODE }} |
| **目标频率** | {{ TARGET_FREQ }} MHz |
| **面积预算** | {{ AREA }} mm² |
| **功耗预算** | {{ POWER }} mW (typ), {{ POWER_MAX }} mW (peak) |

---

## 2. IP 功能定位

### 2.1 核心功能

{{ 一句话描述 IP 的核心功能 }}

### 2.2 关键特性

| 特性 | 描述 | 优先级 |
|------|------|--------|
| {{ 特性1 }} | {{ 描述 }} | P0/P1/P2 |
| {{ 特性2 }} | {{ 描述 }} | P0/P1/P2 |

### 2.3 性能指标

| 指标 | 目标值 | 单位 | 来源 |
|------|--------|------|------|
| IPC/吞吐量 | {{ VALUE }} | ops/cycle | REQ-XXX |
| 延迟 | {{ VALUE }} | cycles | REQ-XXX |
| 频率 | {{ VALUE }} | MHz | REQ-XXX |
| 算力 | {{ VALUE }} | TOPS/FLOPS | REQ-XXX |

---

## 3. IP 架构总览

### 3.1 顶层架构图

```mermaid
graph TB
    subgraph {{ IP_NAME }}
        subgraph Frontend["前端模块"]
            FETCH[取指单元]
            DECODE[译码单元]
            DISPATCH[分发单元]
        end
        subgraph Execute["执行模块"]
            ALU[ALU]
            MUL[乘法器]
            {{ OTHER_UNIT }}[其他单元]
        end
        subgraph Memory["访存模块"]
            LSU[Load/Store Unit]
            RF[寄存器堆]
        end
        subgraph Control["控制模块"]
            FSM[控制FSM]
            CSR[CSR/配置寄存器]
        end
        FETCH --> DECODE
        DECODE --> DISPATCH
        DISPATCH --> Execute
        Execute --> RF
        LSU --> Memory
        FSM --> Control
    end
    
    BUS[系统总线] --> CSR
    MEM[存储器] --> LSU
```

### 3.2 模块划分

| 模块 | 功能 | 子文档 |
|------|------|--------|
| Frontend | 取指、译码、分发 | IP-COMP-03-PIPELINE |
| Execute | 执行单元集合 | IP-COMP-04-EXECUNIT |
| Register File | 通用寄存器堆 | IP-COMP-05-REGFILE |
| Control | 控制逻辑、CSR | IP-COMP-02-MAS §7 |

---

## 4. 流水线结构概览

### 4.1 流水线阶段

| Stage | 功能 | 关键延迟 |
|-------|------|----------|
| S1 | {{ 功能1 }} | {{ DELAY }} cycles |
| S2 | {{ 功能2 }} | {{ DELAY }} cycles |
| S3 | {{ 功能3 }} | {{ DELAY }} cycles |

### 4.2 流水线特性

| 特性 | 实现 |
|------|------|
| 分支预测 | {{ 预测策略 }} |
| 数据前递 | {{ 前递路径 }} |
| 流量控制 | {{ 背压策略 }} |

详见 [IP-COMP-03-PIPELINE.md](./IP-COMP-03-PIPELINE.md)

---

## 5. 执行单元概览

### 5.1 执行单元列表

| 单元 | 类型 | 操作数宽度 | 延迟 | 吞吐量 |
|------|------|------------|------|--------|
| ALU | 整数 | 32/64-bit | 1 cycle | 1 op/cycle |
| Multiplier | 整数乘 | 32/64-bit | 3 cycles | 1 op/3 cycles |
| Divider | 整数除 | 32/64-bit | {{ N }} cycles | 1 op/N cycles |
| FPU | 浮点 | 32/64-bit | {{ N }} cycles | {{ RATE }} |
| SIMD/Vector | 向量 | {{ WIDTH }} | {{ N }} cycles | {{ RATE }} |

详见 [IP-COMP-04-EXECUNIT.md](./IP-COMP-04-EXECUNIT.md)

---

## 6. 寄存器堆概览

### 6.1 寄存器组织

| 类型 | 数量 | 位宽 | 端口配置 |
|------|------|------|----------|
| 通用寄存器 (GPR) | {{ NUM }} | {{ WIDTH }} | {{ N }}R {{ M }}W |
| 特殊寄存器 | {{ NUM }} | {{ WIDTH }} | {{ CONFIG }} |
| CSR | {{ NUM }} | 32-bit | 1R1W |

详见 [IP-COMP-05-REGFILE.md](./IP-COMP-05-REGFILE.md)

---

## 7. 接口概览

### 7.1 总线接口

| 接口 | 协议 | 位宽 | 用途 |
|------|------|------|------|
| 指令总线 | {{ AXI4/TL-UL }} | {{ WIDTH }} | 取指 |
| 数据总线 | {{ AXI4/TL-UL }} | {{ WIDTH }} | Load/Store |
| 配置总线 | {{ APB/AXI-Lite }} | 32-bit | CSR访问 |

### 7.2 控制接口

| 信号 | 方向 | 功能 |
|------|------|------|
| {{ SIGNAL }} | {{ DIR }} | {{ FUNC }} |

详见 [IP-COMMON-01-INTERFACE.md](../common/IP-COMMON-01-INTERFACE.md)

---

## 8. 功耗管理概览

### 8.1 电源域划分

| 电源域 | 覆盖模块 | 工作电压 | 状态 |
|--------|----------|----------|------|
| PD_core | {{ 模块 }} | {{ V }} | Always-on |
| PD_exec | 执行单元 | {{ V }} | Clock-gated |
| PD_sleep | {{ 模块 }} | {{ V }} | Power-gated |

### 8.2 低功耗策略

| 策略 | 条件 | 响应延迟 |
|------|------|----------|
| Clock gating | Idle > {{ N }} cycles | 0 cycles |
| Power gating | Idle > {{ N }} us | {{ N }} us |

详见 [IP-COMMON-04-POWER.md](../common/IP-COMMON-04-POWER.md)

---

## 9. 时钟域概览

### 9.1 时钟域定义

| 时钟域 | 频率 | 来源 | 覆盖模块 |
|--------|------|------|----------|
| clk_core | {{ FREQ }} | PLL | 核心逻辑 |
| clk_mem | {{ FREQ }} | {{ SOURCE }} | 存储接口 |

### 9.2 CDC 概览

| 源域 | 目标域 | 同步方式 | 信号数 |
|------|--------|----------|--------|
| {{ SRC }} | {{ DST }} | {{ METHOD }} | {{ NUM }} |

详见 [IP-COMMON-03-TIMING.md](../common/IP-COMMON-03-TIMING.md)

---

## 10. Chiplet 特有要素（如适用）

### 10.1 D2D 接口

| 接口 | 协议 | 带宽 | 用途 |
|------|------|------|------|
| {{ D2D_IF }} | UCIe/BoW | {{ BW }} | {{ PURPOSE }} |

### 10.2 多 Die 协调

- {{ 协调需求 }}

---

## 11. 验证概览

### 11.1 关键验证场景

| 场景 | 类型 | 优先级 |
|------|------|--------|
| {{ SCENARIO }} | 功能/性能/边界 | P0/P1 |

详见 [IP-COMP-06-VERIFY.md](./IP-COMP-06-VERIFY.md)

---

## 12. 文档索引

| 文档 | 用途 | 状态 |
|------|------|------|
| IP-COMP-01-OVERVIEW | 概览（本文档） | template |
| IP-COMP-02-MAS | 微架构规范 | template |
| IP-COMP-03-PIPELINE | 流水线设计 | template |
| IP-COMP-04-EXECUNIT | 执行单元设计 | template |
| IP-COMP-05-REGFILE | 寄存器堆设计 | template |
| IP-COMP-06-VERIFY | 验证计划 | template |

---

## 13. Traceability

| 上游文档 | 本文档章节 |
|----------|------------|
| DOC-D2-01-ARCH §{{ N }} | §{{ N }} |
| DOC-D3-01-MAS §{{ N }} | §{{ N }} |

---

## 14. Quality Checklist

- [ ] IP 分类已明确
- [ ] 性能指标有明确来源（REQ/ADR）
- [ ] 模块划分完整
- [ ] 流水线结构已定义
- [ ] 执行单元列表完整
- [ ] 寄存器组织已定义
- [ ] 接口协议已明确
- [ ] 时钟域已定义
- [ ] CDC 概览已列出
- [ ] 功耗策略已定义
- [ ] Chiplet 特有要素已覆盖（如适用）
- [ ] 子文档链接完整