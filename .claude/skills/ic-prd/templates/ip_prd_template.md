---
ip_id: IP-PRD-TEMPLATE
ip_type: generic
ip_class: prd
title: IP Product Requirements Document Template
version: 0.1-template
status: template
tier: 0
domain: Product
owner: TBD
approvers: [IP Lead, System Architect]
parent_doc: null
children: [IP-COMP-01-OVERVIEW, IP-MEM-01-OVERVIEW]
references: [IEEE 1685, IEEE 1800, IEEE 1801]
generated: 2026-04-24T08:00:00+08:00
---

# IP Product Requirements Document — {{ IP_NAME }}

> 本模板定义 IP 模块的产品需求文档，作为 IP 设计的前置文档。

## 0. Document Control

| Version | Date | Author | Change |
|---|---|---|---|
| 0.1 | YYYY-MM-DD | {{ Owner }} | Initial draft |

**Sign-off required before**: IP Overview v1.0, MAS v1.0

---

## 1. Executive Summary

- **IP名称**: {{ IP_NAME }}
- **IP类型**: cpu_core / gpu_core / ai_accel / dsp / memory_ctrl / interconnect / io / crypto
- **目标应用**: {{ 应用场景列表 }}
- **关键特性**: {{ 3 条核心特性 }}

## 2. Use Cases & Integration Context

### 2.1 集成场景

| UC ID | Use Case | Target System | KPI |
|---|---|---|---|
| UC-01 | {{ 集成场景 }} | {{ SoC/Chiplet名称 }} | {{ 定量目标 }} |

### 2.2 用户故事

| Story ID | Actor | Action | Benefit |
|---|---|---|---|
| US-01 | {{ 集成工程师 }} | {{ 集成动作 }} | {{ 获得的价值 }} |

---

## 3. Functional Requirements

### 3.1 核心功能

| REQ ID | Statement | Metric | Verification Method |
|---|---|---|---|
| REQ-FUNC-001 | {{ 功能描述 }} | {{ 定量指标 }} | Simulation/Formal |

### 3.2 操作模式

| REQ ID | Statement |
|---|---|
| REQ-MODE-001 | {{ 操作模式1 }} |
| REQ-MODE-002 | {{ 操作模式2 }} |

---

## 4. Interface Requirements

### 4.1 总线接口

| REQ ID | Statement |
|---|---|
| REQ-INTF-001 | 协议：{{ AXI4/APB/TileLink/自定义 }} |
| REQ-INTF-002 | 数据位宽：{{ N }} bits |
| REQ-INTF-003 | 地址位宽：{{ M }} bits |
| REQ-INTF-004 | 端口数量：{{ K }} |

### 4.2 信号规格

| REQ ID | Statement |
|---|---|
| REQ-SIG-001 | {{ 关键信号规格 }} |

详见 IP-COMMON-01-INTERFACE

---

## 5. Performance Requirements

### 5.1 吞吐量与延迟

| REQ ID | Statement | Target |
|---|---|---|
| REQ-PERF-001 | 最大吞吐量 ≥ {{ N }} ops/cycle | ops/cycle |
| REQ-PERF-002 | 平均延迟 ≤ {{ M }} cycles | cycles |
| REQ-PERF-003 | 最大频率 ≥ {{ F }} MHz @ TT/1.0V | MHz |

### 5.2 带宽与效率

| REQ ID | Statement |
|---|---|
| REQ-BW-001 | 接口带宽 ≥ {{ N }} GB/s |
| REQ-EFF-001 | 峰值效率 ≥ {{ M }}% |

---

## 6. Power & Area Requirements

### 6.1 功耗预算

| REQ ID | Statement | Target |
|---|---|---|
| REQ-PWR-001 | 典型功耗 ≤ {{ N }} mW | mW @ {{ V }} |
| REQ-PWR-002 | 峰值功耗 ≤ {{ M }} mW | mW @ {{ V }} |
| REQ-PWR-003 | 空闲功耗 ≤ {{ K }} mW | mW |

### 6.2 面积预算

| REQ ID | Statement |
|---|---|
| REQ-AREA-001 | 总面积 ≤ {{ N }} mm² @ {{ PROCESS_NODE }} |

详见 IP-COMMON-04-POWER

---

## 7. Timing & Clock Requirements

### 7.1 时钟规格

| REQ ID | Statement |
|---|---|
| REQ-CLK-001 | 主时钟频率：{{ F }} MHz |
| REQ-CLK-002 | 时钟域数量：{{ N }} |

### 7.2 CDC 要求

| REQ ID | Statement |
|---|---|
| REQ-CDC-001 | {{ CDC规格 }} |

详见 IP-COMMON-03-TIMING

---

## 8. Register Map Requirements

| REQ ID | Statement |
|---|---|
| REQ-REG-001 | 寄存器数量：{{ N }} |
| REQ-REG-002 | 寄存器地址空间：{{ BASE }} - {{ END }} |
| REQ-REG-003 | 访问权限定义：{{ R/W/RW }} |

详见 IP-COMMON-02-REGISTER

---

## 9. DFT Requirements

| REQ ID | Statement |
|---|---|
| REQ-DFT-001 | Scan chain coverage ≥ {{ N }}% |
| REQ-DFT-002 | {{ BIST要求 }} |
| REQ-DFT-003 | JTAG 接口支持 |

详见 IP-COMMON-05-DFT

---

## 10. Verification Requirements

| REQ ID | Statement |
|---|---|
| REQ-VERIFY-001 | 代码覆盖率 ≥ {{ N }}% |
| REQ-VERIFY-002 | 功能覆盖率 ≥ {{ M }}% |
| REQ-VERIFY-003 | {{ 关键验证场景 }} |

---

## 11. IP Quality Attributes

### 11.1 可配置性

| REQ ID | Statement |
|---|---|
| REQ-CONFIG-001 | {{ 可配置参数 }} |

### 11.2 可复用性

| REQ ID | Statement |
|---|---|
| REQ-REUSE-001 | {{ 复用要求 }} |

### 11.3 文档完整性

| REQ ID | Statement |
|---|---|
| REQ-DOC-001 | 文档集符合 IP-XACT 标准 |

---

## 12. Integration Constraints

| REQ ID | Statement |
|---|---|
| REQ-INTG-001 | {{ 集成约束 }} |
| REQ-INTG-002 | {{ 系统级依赖 }} |

---

## 13. Milestones & Timeline

| Milestone | Target Date | Deliverable |
|---|---|---|
| PRD Freeze | YYYY-MM-DD | PRD v1.0 |
| MAS Sign-off | YYYY-MM-DD | MAS v1.0 |
| RTL Freeze | YYYY-MM-DD | RTL tag |
| IP Validation | YYYY-MM-DD | Validation report |
| IP Release | YYYY-MM-DD | IP package |

---

## 14. Standards Compliance

- [ ] IEEE 1685-2022 (IP-XACT)
- [ ] IEEE 1800 (SystemVerilog)
- [ ] IEEE 1801 (UPF)
- [ ] {{ 其他标准 }}

---

## 15. Quality Checklist

- [ ] 所有 REQ-xxx 有唯一 ID
- [ ] 每条需求符合 SMART
- [ ] 性能指标有明确 min/typ/max
- [ ] Interface 规格完整
- [ ] Power/Area budget 已分配
- [ ] DFT 要求已定义
- [ ] Verification 目标已设定
- [ ] 文档引用完整
- [ ] Milestone 已规划

---

## Appendix A: Traceability Matrix

| REQ ID | ARCH Ref | MAS Ref | VPlan Ref |
|---|---|---|---|
| REQ-FUNC-001 | §{{ N }} | §{{ M }} | VP-{{ ID }} |

---

## Appendix B: Glossary

| Term | Definition |
|---|---|
| {{ TERM }} | {{ 定义 }} |