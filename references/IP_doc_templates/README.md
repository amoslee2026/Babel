# IP Doc Templates — 高端芯片计算与访存模块 IP 设计文档模板库

**Version**: 1.0  
**Generated**: 2026-04-23 (GMT+8)  
**Scope**: 计算模块 IP + 访存模块 IP  
**Source**: `research_reports/chiplet-spec-docs/chiplet-spec-docs_2026-04-23_2205_report.md`

## 1. 模板定位

本模板库专注于高端芯片中两类核心 IP 的设计文档：
- **计算模块 IP**：CPU Core、GPU Core、NPU/TPU/AI 加速器、DSP、Vector Unit 等
- **访存模块 IP**：Memory Controller、Cache Controller、HBM Controller、SRAM Controller 等

模板设计遵循 MAS（Micro Architecture Specification）规范，满足：
- RTL 可实现性（无歧义描述）
- 四向追溯性（PRD → Arch → MAS → VPlan）
- Chiplet 特有章节（D2D 接口、多 Die 调试、RAS、热管理）

## 2. 目录结构

```
IP_doc_templates/
├── README.md                     ← 本文件
├── _meta/
│   ├── ip-categories.md          ← IP 分类与编号规则
│   └── traceability-model.md     ← 追溯模型定义
├── compute-ip/                   ← 计算模块 IP 模板
│   ├── IP-COMP-01-OVERVIEW.md    ← 计算IP概览
│   ├── IP-COMP-02-MAS.md         ← 微架构规范主模板
│   ├── IP-COMP-03-PIPELINE.md    ← 流水线设计
│   ├── IP-COMP-04-EXECUNIT.md    ← 执行单元设计
│   ├── IP-COMP-05-REGFILE.md     ← 寄存器堆设计
│   ├── IP-COMP-06-VERIFY.md      ← 验证计划
│   └── templates/                ← 子模块模板
│       ├── alu_template.md
│       ├── multiplier_template.md
│       ├── simd_unit_template.md
│       └── fpu_template.md
├── memory-ip/                    ← 访存模块 IP 模板
│   ├── IP-MEM-01-OVERVIEW.md     ← 访存IP概览
│   ├── IP-MEM-02-MAS.md          ← 微架构规范主模板
│   ├── IP-MEM-03-CTRLLOGIC.md    ← 控制逻辑设计
│   ├── IP-MEM-04-CACHE.md        ← Cache 设计
│   ├── IP-MEM-05-ARBITER.md      ← 仲裁器设计
│   ├── IP-MEM-06-VERIFY.md       ← 验证计划
│   └── templates/                ← 子模块模板
│       ├── sram_ctrl_template.md
│       ├── cache_ctrl_template.md
│       ├── hbm_ctrl_template.md
│       └── coherence_ctrl_template.md
└── common/                       ← 共用模板
    ├── IP-COMMON-01-INTERFACE.md ← 接口规范
    ├── IP-COMMON-02-REGISTER.md  ← 寄存器规范
    ├── IP-COMMON-03-TIMING.md    ← 时序规范
    ├── IP-COMMON-04-POWER.md     ← 功耗规范
    └── IP-COMMON-05-DFT.md       ← DFT 规范
```

## 3. IP 编号规则

采用 `IP-<Category>-<Serial>-<ShortCode>` 三段式编号：

| Category | 含义 | 示例 |
|----------|------|------|
| COMP | Compute IP | IP-COMP-01-OVERVIEW |
| MEM | Memory IP | IP-MEM-02-MAS |
| COMMON | 共用模板 | IP-COMMON-01-INTERFACE |

## 4. 计算模块 IP 特征

计算模块 IP 设计关注：
- **执行单元**：ALU、乘法器、除法器、FPU、SIMD/Vector Unit
- **流水线结构**：Stage划分、分支预测、指令调度
- **寄存器堆**：通用寄存器、特殊寄存器、CSR
- **指令处理**：取指、译码、执行、写回
- **性能指标**：IPC、吞吐量、延迟、频率

关键设计参数：
| 参数 | 典型范围 | 重要性 |
|------|----------|--------|
| 目标频率 | 1–3 GHz | Critical |
| IPC | 1–4 | Critical |
| ALU延迟 | 1–2 cycles | High |
| 乘法器延迟 | 3–8 cycles | High |
| 寄存器堆端口 | 2R1W ~ 6R4W | High |

## 5. 访存模块 IP 特征

访存模块 IP 设计关注：
- **存储层次**：L1/L2/L3 Cache、Main Memory、HBM
- **访问调度**：请求仲裁、优先级、Bank管理
- **一致性协议**：MESI/MOESI、CHI、CXL.cache
- **带宽管理**：吞吐量优化、QoS、背压处理
- **延迟优化**：预取、Write-back、Write-combine

关键设计参数：
| 参数 | 典型范围 | 重要性 |
|------|----------|--------|
| Cache容量 | 16KB–64MB | Critical |
| 访问延迟 | 1–20 cycles | Critical |
| 带宽 | 10–1000 GB/s | Critical |
| Line Size | 32–256 Bytes | High |
| Associativity | 2–16 way | High |

## 6. 统一 Frontmatter 规范

所有 IP 文档采用以下 frontmatter：

```yaml
---
ip_id: IP-<Category>-<Serial>-<ShortCode>
ip_type: compute | memory
ip_class: {{具体类别}}  # cpu_core | npu | cache_ctrl | hbm_ctrl ...
title: <完整标题>
version: 0.1-template
status: template          # template | draft | review | approved | frozen
parent_doc: <上游架构文档ID>
derived_from: [REQ-XXX, ADR-YYY]
owner: TBD
approvers: [TBD]
tier: 0 | 1
domain: Implementation
generated: 2026-04-23T23:00:00+08:00
---
```

## 7. 使用方式

### 7.1 文档实例化

```bash
# 复制模板，重命名为项目专属实例
cp IP_doc_templates/compute-ip/IP-COMP-02-MAS.md \
   my_project/docs/IP-COMP-02-MAS-npu_core-v0.1.md

# 填写 frontmatter（owner、version → 0.1、status → draft）
# 逐节填写占位符 {{ ... }}
```

### 7.2 追溯链维护

- `derived_from` 字段记录上游需求/决策
- `parent_doc` 字段链接系统架构文档
- 验证计划中 `testpoints` 反向引用 MAS 章节

### 7.3 质量检查

MAS 完成后必须通过：
- RTL 一致性检查（接口/寄存器与代码对应）
- FSM 可达性分析（formal tool）
- CDC 路径完整性检查
- 追溯矩阵覆盖率 ≥ 95%

## 8. 与 ic_doc_templates 的关系

- `ic_doc_templates`：芯片级文档（PRD → Arch → MAS → VPlan）
- `IP_doc_templates`：IP 级文档（细化 MAS 各子模块）

IP 文档作为 `ic_doc_templates/D3-implementation/DOC-D3-01-MAS.md` 的补充与细化。

## 9. 标准合规性

模板预置以下标准引用：
- **接口**：AXI4/CHI/CXL/UCIe/TL-UL
- **寄存器**：IEEE 1685 IP-XACT
- **测试**：IEEE 1149.1 (JTAG), IEEE 1687 (IJTAG)
- **验证**：IEEE 1800 SystemVerilog, Accellera UVM
- **功耗**：IEEE 1801 UPF
- **安全**：ISO 26262 (功能安全)

## 10. 许可

模板采用 CC-BY-4.0 释出，可自由用于商用芯片项目。