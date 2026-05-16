---
ip_id: IP-MEM-01-OVERVIEW
ip_type: memory
ip_class: overview
title: Memory IP Overview Template
version: 0.1-template
status: template
tier: 0
domain: Implementation
owner: TBD
approvers: [TBD]
parent_doc: DOC-D3-01-MAS
derived_from: []
references: [IEEE 1685, IEEE 1800, IEEE 1801, JEDEC JESD235]
generated: 2026-04-23T23:00:00+08:00
---

# 访存模块 IP 概览模板

> 本模板定义访存类 IP 的整体架构概览，作为具体 MAS 文档的前置文档。

## 0. Document Control

| Version | Date | Author | Change |
|---|---|---|---|
| 0.1 | YYYY-MM-DD | {{ Owner }} | Initial |

---

## 1. IP 基本信息

| 属性 | 值 |
|------|---|
| **IP名称** | {{ IP_NAME }} |
| **IP类型** | sram_ctrl / cache_ctrl / hbm_ctrl / ddr_ctrl / coherence / noc_router |
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
| 带宽 | {{ VALUE }} | GB/s | REQ-XXX |
| 延迟 | {{ VALUE }} | cycles | REQ-XXX |
| 容量 | {{ VALUE }} | KB/MB | REQ-XXX |
| 吞吐量 | {{ VALUE }} | req/cycle | REQ-XXX |

---

## 3. IP 架构总览

### 3.1 顶层架构图

```mermaid
graph TB
    subgraph {{ IP_NAME }}
        subgraph Request["请求处理"]
            ARBITER[仲裁器]
            SCHED[调度器]
            QUEUE[请求队列]
        end
        subgraph Control["控制逻辑"]
            FSM[控制FSM]
            CONFIG[配置寄存器]
        end
        subgraph DataPath["数据通路"]
            MUX[数据选择器]
            BUFFER[数据缓冲]
            ECC[ECC单元]
        end
        subgraph Storage["存储管理"]
            TAG[Tag存储]
            DATA[数据存储]
            DIR[目录（如适用）]
        end
        subgraph Coherence["一致性（如适用）"]
            PROTO[协议处理]
            MSG[消息生成]
        end
        
        ARBITER --> SCHED --> QUEUE
        QUEUE --> DataPath --> Storage
        FSM --> Control --> CONFIG
        Storage --> Coherence --> MSG
    end
    
    CLIENT[客户端请求] --> ARBITER
    MEM[存储器] --> Storage
    OTHER_DIE[其他Die] --> Coherence
```

### 3.2 模块划分

| 模块 | 功能 | 子文档 |
|------|------|--------|
| Request Processing | 仲裁、调度、排队 | IP-MEM-05-ARBITER |
| Control Logic | 状态机、配置 | IP-MEM-03-CTRLLOGIC |
| Cache/Storage | 存储管理 | IP-MEM-04-CACHE |
| Coherence | 一致性协议 | IP-MEM-02-MAS §10 |

---

## 4. 存储层次概览

### 4.1 存储参数

| 参数 | 值 | 说明 |
|------|---|------|
| 容量 | {{ CAPACITY }} | KB/MB |
| Line Size | {{ SIZE }} | Bytes |
| Associativity | {{ WAY }} | way |
| Bank数 | {{ BANK }} | 并行度 |
| 端口数 | {{ PORT }} | R/W端口 |

### 4.2 存储组织

| 层级 | 容量 | 延迟 | 带宽 |
|------|------|------|------|
| {{ LEVEL }} | {{ CAP }} | {{ LAT }} | {{ BW }} |

详见 [IP-MEM-04-CACHE.md](./IP-MEM-04-CACHE.md)

---

## 5. 仲裁与调度概览

### 5.1 仲裁策略

| 策略 | 描述 |
|------|------|
| {{ STRATEGY }} | {{ DESC }} |

### 5.2 调度算法

| 算法 | 条件 |
|------|------|
| {{ ALGO }} | {{ CONDITION }} |

详见 [IP-MEM-05-ARBITER.md](./IP-MEM-05-ARBITER.md)

---

## 6. 一致性协议概览（如适用）

### 6.1 协议类型

| 协议 | 状态集 | 适用场景 |
|------|--------|----------|
| MESI | M/E/S/I | 单die cache |
| MOESI | M/O/E/S/I | 多die共享 |
| CHI | {{ STATES }} | Arm互连 |
| CXL.cache | {{ STATES }} | CXL设备 |

### 6.2 关键操作

| 操作 | 触发条件 | 延迟 |
|------|----------|------|
| {{ OP }} | {{ COND }} | {{ N }} cycles |

---

## 7. 接口概览

### 7.1 客户端接口

| 接口 | 协议 | 位宽 | 数量 |
|------|------|------|------|
| {{ IF }} | AXI/CHI/TL-UL | {{ WIDTH }} | {{ NUM }} |

### 7.2 存储接口

| 接口 | 协议 | 位宽 | 用途 |
|------|------|------|------|
| {{ IF }} | {{ PROTO }} | {{ WIDTH }} | {{ PURPOSE }} |

### 7.3 Chiplet接口（如适用）

| 接口 | 协议 | 带宽 | 用途 |
|------|------|------|------|
| {{ IF }} | UCIe/CXL | {{ BW }} | 跨die通信 |

详见 [IP-COMMON-01-INTERFACE.md](../common/IP-COMMON-01-INTERFACE.md)

---

## 8. 功耗管理概览

### 8.1 电源域划分

| 电源域 | 覆盖模块 | 工作电压 | 状态 |
|--------|----------|----------|------|
| PD_ctrl | 控制逻辑 | {{ V }} | Always-on |
| PD_storage | 存储阵列 | {{ V }} | Retention支持 |
| PD_data | 数据通路 | {{ V }} | Clock-gated |

### 8.2 低功耗策略

| 策略 | 条件 | 响应延迟 |
|------|------|----------|
| Clock gating | Idle > {{ N }} cycles | 0 cycles |
| retention | Power-down | {{ N }} us |
| {{ STRATEGY }} | {{ CONDITION }} | {{ LAT }} |

详见 [IP-COMMON-04-POWER.md](../common/IP-COMMON-04-POWER.md)

---

## 9. 时钟域概览

### 9.1 时钟域定义

| 时钟域 | 频率 | 来源 | 覆盖模块 |
|--------|------|------|----------|
| clk_ctrl | {{ FREQ }} | PLL | 控制逻辑 |
| clk_mem | {{ FREQ }} | {{ SOURCE }} | 存储接口 |
| clk_d2d | {{ FREQ }} | Source-sync | D2D接口 |

### 9.2 CDC 概览

| 源域 | 目标域 | 同步方式 | 信号数 |
|------|--------|----------|--------|
| {{ SRC }} | {{ DST }} | {{ METHOD }} | {{ NUM }} |

详见 [IP-COMMON-03-TIMING.md](../common/IP-COMMON-03-TIMING.md)

---

## 10. ECC 与 RAS 概览

### 10.1 ECC 配置

| 保护对象 | 编码 | 粒度 |
|----------|------|------|
| 数据存储 | SEC-DED | Per-line |
| Tag存储 | Parity | Per-tag |
| 控制寄存器 | {{ CODE }} | {{ GRAN }} |

### 10.2 错误处理策略

| 错误类型 | 检测 | 响应 |
|----------|------|------|
| Single-bit | ECC纠正 | 计数记录 |
| Multi-bit | ECC检测 | 中断上报 |
| Parity error | Parity | 重读/上报 |

---

## 11. 验证概览

### 11.1 关键验证场景

| 场景 | 类型 | 优先级 |
|------|------|--------|
| {{ SCENARIO }} | 功能/性能/边界 | P0/P1 |

详见 [IP-MEM-06-VERIFY.md](./IP-MEM-06-VERIFY.md)

---

## 12. 文档索引

| 文档 | 用途 | 状态 |
|------|------|------|
| IP-MEM-01-OVERVIEW | 概览（本文档） | template |
| IP-MEM-02-MAS | 微架构规范 | template |
| IP-MEM-03-CTRLLOGIC | 控制逻辑设计 | template |
| IP-MEM-04-CACHE | Cache设计 | template |
| IP-MEM-05-ARBITER | 仲裁器设计 | template |
| IP-MEM-06-VERIFY | 验证计划 | template |

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
- [ ] 存储参数已定义
- [ ] 仲裁策略已明确
- [ ] 一致性协议已定义（如适用）
- [ ] 接口协议已明确
- [ ] 时钟域已定义
- [ ] CDC 概览已列出
- [ ] ECC配置已定义
- [ ] 功耗策略已定义
- [ ] Chiplet特有要素已覆盖（如适用）
- [ ] 子文档链接完整