---
doc_id: DOC-D2-02-ADR
doc_type: ADR
title: Architecture Decision Records
version: 0.1-template
status: template
tier: 0
domain: Architecture
owner: Chief Architect
approvers: [CTO, Architecture Review Board]
parent: DOC-D2-01-ARCH
children: []
references: [Michael Nygard ADR format, IEEE 29148]
generated: 2026-04-23T22:45:00+08:00
---

# Architecture Decision Records — {{ Product Name }}

本文件记录所有重大架构决策。每条 ADR 一旦批准即冻结；修改需新建 superseding ADR，并在原 ADR 的 `status` 字段标注 `Superseded by ADR-XXX`。

## 目录

| ADR ID | Title | Status | Date |
|---|---|---|---|
| ADR-001 | Die partitioning strategy | Proposed | YYYY-MM-DD |
| ADR-002 | D2D protocol selection | Proposed | YYYY-MM-DD |
| ADR-003 | Coherence protocol | Proposed | YYYY-MM-DD |
| ADR-004 | Memory topology | Proposed | YYYY-MM-DD |
| ADR-005 | Process node assignment | Proposed | YYYY-MM-DD |
| ADR-006 | Packaging technology | Proposed | YYYY-MM-DD |
| ADR-007 | Clock distribution | Proposed | YYYY-MM-DD |
| ADR-008 | RAS strategy | Proposed | YYYY-MM-DD |
| ADR-009 | Security / RoT location | Proposed | YYYY-MM-DD |

---

## ADR Template (Michael Nygard format)

```markdown
## ADR-NNN: <Short Title>

**Status**: Proposed | Accepted | Deprecated | Superseded by ADR-XXX
**Date**: YYYY-MM-DD
**Deciders**: [Name1, Name2]
**Tags**: [die-partition, d2d, memory, ...]

### Context
<What is the problem? What forces are at play?>

### Decision
<What did we choose?>

### Consequences
- **Positive**: <benefits>
- **Negative**: <costs / trade-offs>
- **Neutral**: <other effects>

### Alternatives Considered
1. **Alternative A**: <description> — rejected because <reason>
2. **Alternative B**: <description> — rejected because <reason>

### Links
- PRD requirements: REQ-xxx
- Impacts: DOC-D2-01-ARCH §N, DOC-D3-01-MAS-XXX
- Related ADRs: ADR-YYY
```

---

## ADR-001: Die Partitioning Strategy

**Status**: Proposed  
**Date**: YYYY-MM-DD  
**Deciders**: [Chief Architect, VP Engineering]  
**Tags**: [die-partition]

### Context
We must decide how to partition functionality across dies in a chiplet-based SoC. The product targets {{ HPC / AI / Networking }} workloads with {{ N }} PFLOPS peak and {{ M }} TB/s memory bandwidth. Reticle limit at target process is {{ 858 mm² }}, but we need ~{{ N × K }} mm² of compute area. Yield at full-reticle in {{ N5 }} is {{ Y% }}. Cost per mm² is ${{ A }} in N5 vs ${{ B }} in N6.

Key forces:
- Need massive compute → exceeds single-die limit
- Fast time-to-market → reuse IP across products
- Mixed process need: compute benefits from N5, I/O does not
- KGD/yield: smaller dies improve yield multiplicatively

### Decision
Partition into:
- {{ N }} × Compute Chiplet Die (CCD) in {{ N5 }}
- 1 × I/O Die (IOD) in {{ N6 }} (cheaper, analog-friendly process)
- {{ M }} × HBM3e stacks (外购 die)

### Consequences
- **Positive**: Higher yield; process-optimized compute; lower cost (I/O on older node); IP reuse across product line
- **Negative**: D2D power/latency overhead (~{{ 0.3 pJ/bit }}); 更复杂的封装与测试；KGD 测试流程
- **Neutral**: 架构与 AMD MI300、Intel GPU Max 类似

### Alternatives Considered
1. **Monolithic die in N5**: rejected — exceeds reticle, yield too low at full area
2. **All-same-process chiplets (all N5)**: rejected — I/O area waste, unnecessary cost on advanced node
3. **3D stacking compute on memory (SoIC)**: rejected (for now) — thermal risk, yield risk on new package

### Links
- REQ-COMPUTE-001, REQ-AREA-001, REQ-COST-001
- DOC-D2-01-ARCH §4, §5
- Related: ADR-005 (process node), ADR-006 (package)

---

## ADR-002: D2D Protocol Selection

**Status**: Proposed  
**Date**: YYYY-MM-DD  
**Deciders**: [Chief Architect, D2D IP Lead]  
**Tags**: [d2d, interconnect]

### Context
Chiplet requires a die-to-die interconnect with high bandwidth (≥{{ N }} TB/s aggregate), low latency (<{{ 10 ns }} RTT for coherent), low power, and ecosystem compatibility for potential 3rd-party chiplet integration.

Candidates:
- **UCIe 2.0 Advanced**: 32 GT/s, 0.3 pJ/bit, 36μm bump pitch, broad ecosystem
- **UCIe 2.0 3D**: 4–16 GT/s, 0.15 pJ/bit, <10μm pitch (hybrid bonding)
- **OCP BoW 2.0**: parallel, organic-substrate friendly
- **NVIDIA NV-HBI**: proprietary, highest BW density
- **AMD Infinity Fabric**: proprietary, mature

### Decision
Use **UCIe 2.0 Advanced** for 2.5D CoWoS connections between CCDs/IOD.  
Use **UCIe 2.0 3D variant** for any hybrid-bonded stacks (future ADR if applicable).

### Consequences
- **Positive**: Open standard, 3rd-party interop possible, mature EDA/VIP ecosystem
- **Negative**: Lower density than hybrid bonding, higher power than 3D variant
- **Neutral**: Industry consensus; fallback UCIe 1.1 possible

### Alternatives Considered
1. Proprietary fabric: rejected — ecosystem risk
2. OCP BoW 2.0: rejected — less momentum than UCIe as of 2025

### Links
- REQ-D2D-001 through REQ-D2D-006
- DOC-D2-01-ARCH §9, DOC-D2-05-DIC
- UCIe Spec 2.0

---

## ADR-003: Coherence Protocol

**Status**: Proposed  
**Date**: YYYY-MM-DD  
**Deciders**: [Memory Architect, Chief Architect]  
**Tags**: [coherence, memory]

### Context
{{ ... }}

### Decision
Use **CXL 3.0 cache/mem semantics over UCIe Streaming** for cross-die; local MOESI within each CCD; distributed directory.

### Consequences
- **Positive**: Enables future CXL-attached external accelerators; open; scalable
- **Negative**: Protocol translation overhead at IOD

### Alternatives Considered
- Proprietary coherence (CHI C2C variant): rejected — ecosystem lock-in
- Snoop-only: rejected — scalability limit

### Links
- REQ-MEM-*, DOC-D2-01-ARCH §6

---

## ADR-004 ~ ADR-009
(留待项目团队填写，使用相同模板)

---

## Quality Checklist (per ADR)

- [ ] Context 清晰陈述问题与 forces
- [ ] Decision 明确可测试
- [ ] ≥ 2 个 Alternatives 列出且给出拒绝理由
- [ ] Consequences 正负都有
- [ ] Links 到具体 REQ-xxx / 其他 ADR / 下游文档
- [ ] Deciders 包含至少一位 approver
- [ ] Status 及时更新（Proposed → Accepted → 最终）
