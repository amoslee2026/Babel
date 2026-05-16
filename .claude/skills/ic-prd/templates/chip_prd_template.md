---
doc_id: DOC-D1-01-PRD
doc_type: PRD
title: Product Requirements Document (Chiplet)
version: 0.1-template
status: template
tier: 0
domain: Product
owner: TBD
approvers: [Product VP, CTO, Chief Architect]
parent: null
children: [DOC-D2-01-ARCH, DOC-D2-03-PERF, DOC-D2-04-SWARCH, DOC-D2-05-DIC, DOC-D7-01-SEC, DOC-D9-03-COMPLY]
references: [UCIe 2.0, JEDEC JEP30 + OCP CDXML, ISO 26262, AEC-Q100, Arm CSA, OCP FCSA]
generated: 2026-04-23T22:45:00+08:00
---

# Product Requirements Document — {{ Product Name }}

## 0. Document Control

| Version | Date | Author | Change |
|---|---|---|---|
| 0.1 | YYYY-MM-DD | {{ Owner }} | Initial draft |

**Sign-off required before**: Architecture Spec v1.0

---

## 1. Executive Summary

- **Product**: {{ 一句话产品定位 }}
- **Target Market**: {{ HPC / AI Training / AI Inference / Networking / Automotive / ... }}
- **Form Factor**: {{ OAM / SXM / standard PCIe / custom socket }}
- **Key Differentiators**: {{ 3 条 }}

## 2. Use Cases & User Stories

| UC ID | Use Case | Target Workload | KPI |
|---|---|---|---|
| UC-01 | {{ 场景 }} | {{ benchmark }} | {{ 定量目标 }} |

## 3. Functional Requirements

### 3.1 Compute

| REQ ID | Statement | Metric | Verification Method |
|---|---|---|---|
| REQ-COMPUTE-001 | FP16 peak throughput ≥ {{ N }} PFLOPS | PFLOPS @ TT/1.0V | Post-silicon benchmark |
| REQ-COMPUTE-002 | INT8 TOPS ≥ {{ M }} | TOPS | 同上 |

### 3.2 Memory

| REQ ID | Statement | Metric |
|---|---|---|
| REQ-MEM-001 | HBM3e capacity ≥ {{ N }} GB | GB total |
| REQ-MEM-002 | HBM aggregate BW ≥ {{ M }} TB/s | TB/s |

### 3.3 Connectivity / I/O

| REQ ID | Statement |
|---|---|
| REQ-IO-001 | {{ PCIe Gen5 x16, CXL 3.0, Ethernet 400G, ... }} |

## 4. Non-Functional Requirements

### 4.1 Performance

| REQ ID | Statement | Target |
|---|---|---|
| REQ-PERF-001 | Peak SoC clock ≥ {{ N }} GHz @ TT/1.0V | Fmax |
| REQ-PERF-002 | End-to-end inference latency ≤ {{ M }} μs for {{ model }} | μs |

### 4.2 Power & Thermal

| REQ ID | Statement | Target |
|---|---|---|
| REQ-PWR-001 | TDP ≤ {{ N }} W | Watts |
| REQ-PWR-002 | Idle power ≤ {{ M }} W | Watts |
| REQ-THERM-001 | Operating temperature {{ Tj_min }} to {{ Tj_max }} °C | °C |
| REQ-THERM-002 | Cooling envelope: {{ liquid / air / immersion }} | - |

### 4.3 Cost & Area

| REQ ID | Statement |
|---|---|
| REQ-COST-001 | BOM cost ≤ ${{ N }} @ volume {{ units/year }} |
| REQ-AREA-001 | Total die area ≤ {{ N }} mm² |

### 4.4 Reliability

| REQ ID | Statement |
|---|---|
| REQ-REL-001 | MTTF ≥ {{ N }} hours @ 85°C |
| REQ-REL-002 | Soft error rate ≤ {{ M }} FIT |
| REQ-REL-003 | ESD: HBM ≥ 2kV, CDM ≥ 500V |

## 5. Chiplet Composition

### 5.1 Die Inventory

| Die | Function | Process Node | Count | Vendor |
|---|---|---|---|---|
| CCD (Compute Chiplet Die) | {{ compute cores }} | {{ N5 / N3 }} | {{ N }} | In-house |
| IOD (I/O Die) | {{ PCIe, UCIe, memory ctrl }} | {{ N6 }} | 1 | In-house |
| MEMD | {{ HBM stack }} | (供应商 die) | {{ M }} | {{ SK Hynix / Micron }} |

### 5.2 Rationale (link to ADR)
- Process split 理由：→ DOC-D2-02-ADR-001
- Die count 理由：→ DOC-D2-02-ADR-002

## 6. Die-to-Die Interconnect Requirements

| REQ ID | Statement |
|---|---|
| REQ-D2D-001 | UCIe compliance level: {{ Standard / Advanced Retimer / Bridge }} |
| REQ-D2D-002 | UCIe version: {{ 1.1 / 2.0 / 3.0 }} |
| REQ-D2D-003 | Per-module bandwidth ≥ {{ N }} GT/s × {{ M }} lanes |
| REQ-D2D-004 | Aggregate D2D bandwidth ≥ {{ K }} TB/s |
| REQ-D2D-005 | D2D energy efficiency ≤ {{ N }} pJ/bit |
| REQ-D2D-006 | Coherent access latency ≤ {{ M }} ns (round-trip) |

## 7. Package Requirements

| REQ ID | Statement |
|---|---|
| REQ-PKG-001 | Package type: {{ CoWoS-L / EMIB / Foveros / I-Cube }} |
| REQ-PKG-002 | Bump pitch: {{ 36μm / 9μm / hybrid bonding <1μm }} |
| REQ-PKG-003 | Substrate area ≤ {{ N }} × {{ M }} mm² |
| REQ-PKG-004 | Max warpage ≤ {{ N }} μm |

## 8. Known-Good-Die (KGD) Requirements

| REQ ID | Statement |
|---|---|
| REQ-KGD-001 | Single-die test yield ≥ {{ N }}% post wafer-sort |
| REQ-KGD-002 | Structural test coverage (stuck-at) ≥ {{ 99 }}% |
| REQ-KGD-003 | Die wrapper compliant with IEEE 1838 |
| REQ-KGD-004 | Burn-in: {{ N }} hours @ {{ T }}°C, {{ V }} V |

## 9. 3rd-Party Chiplet Compatibility

| REQ ID | Statement |
|---|---|
| REQ-INTEROP-001 | UCIe Golden Die conformance documented |
| REQ-INTEROP-002 | 支持第三方 chiplet 类型：{{ Compute / Memory / I/O }} |
| REQ-INTEROP-003 | Reference design for interop 已定义（→ DOC-D2-05-DIC） |

## 10. Software & Programming Model

| REQ ID | Statement |
|---|---|
| REQ-SW-001 | ISA: {{ x86-64 / ARMv9 / RISC-V RV64GCV / 专有 }} |
| REQ-SW-002 | OS support: {{ Linux kernel ≥ 6.x, Windows Server, ESXi }} |
| REQ-SW-003 | Framework support: {{ PyTorch, TensorFlow, JAX, CUDA replacement }} |
| REQ-SW-004 | Driver stack: {{ open source / proprietary }} |

→ 详细内容见 DOC-D2-04-SWARCH

## 11. Functional Safety (若适用)

| REQ ID | Statement |
|---|---|
| REQ-FS-001 | ASIL level: {{ A / B / C / D / QM }} |
| REQ-FS-002 | Standard: ISO 26262 : 2018 / IEC 61508 |
| REQ-FS-003 | SPFM ≥ 99%, LFM ≥ 90%, PMHF ≤ 10 FIT (for ASIL D) |
| REQ-FS-004 | Safety mechanisms: {{ lockstep cores, ECC, dual-modular redundancy }} |
| REQ-FS-005 | 跨 die 级联故障分析已完成 → DOC-D7-01-SEC §N |

## 12. Security (若适用)

| REQ ID | Statement |
|---|---|
| REQ-SEC-001 | Root-of-Trust location: {{ management chiplet / boot die }} |
| REQ-SEC-002 | Secure boot: signed firmware with hardware key |
| REQ-SEC-003 | Side-channel resistance: {{ DPA / timing / EM level }} |
| REQ-SEC-004 | Supply-chain threat model documented → DOC-D7-01-SEC |

## 13. Standards Compliance Summary

本产品声明符合以下标准（完整清单见 DOC-D9-03-COMPLY）：

- [ ] UCIe {{ 2.0 / 3.0 }}
- [ ] JEDEC JEP30 + OCP CDXML
- [ ] JEDEC JESD235D (HBM3)
- [ ] IEEE 1685-2022 (IP-XACT)
- [ ] IEEE 1838 (Die Wrapper, if 3D/2.5D)
- [ ] ISO 26262:2018 (若汽车)
- [ ] AEC-Q100 (若汽车)
- [ ] Arm CSA / OCP FCSA (若生态)

## 14. Milestones & Timeline

| Milestone | Target Date | Deliverable |
|---|---|---|
| PRR (Product Readiness Review) | YYYY-MM-DD | PRD v1.0 frozen |
| Arch Sign-off | YYYY-MM-DD | ARCH v1.0 |
| RTL Freeze | YYYY-MM-DD | MAS v1.0 + RTL tag |
| Tape-out | YYYY-MM-DD | GDSII out |
| Silicon In | YYYY-MM-DD | First parts back |
| Alpha Sample | YYYY-MM-DD | Customer A |
| Production Release | YYYY-MM-DD | Datasheet v1.0 |

## 15. Change Management

- **Freeze Point**: PRD frozen at PRR; changes require ECN approval by CCB
- **ECN Log**: 附录 A

## 16. Quality Checklist (Review Gate)

- [ ] 所有 REQ-xxx 有唯一 ID
- [ ] 每条需求符合 SMART（Specific / Measurable / Achievable / Relevant / Time-bound）
- [ ] 所有性能指标有明确 min/typ/max + 测试条件
- [ ] Chiplet 级 vs system 级需求已分层
- [ ] UCIe 合规等级明确
- [ ] Package 选型与成本模型对齐
- [ ] Power budget 和 ≤ TDP（含 ≥ 10% margin）
- [ ] Area budget 和 ≤ target die size
- [ ] KGD 良率目标可测量
- [ ] 功能安全等级映射（若适用）
- [ ] 所有"约"、"大约"、"最好"等软指标已量化
- [ ] RTM 就绪（DOORS/Jama 导入）
- [ ] Variability 已标注（corner、temperature、voltage）
- [ ] Stakeholder sign-off 完成

## Appendix A: ECN Log
| ECN ID | Date | Change | Impact |
|---|---|---|---|

## Appendix B: Glossary
| Term | Definition |
|---|---|
| KGD | Known-Good-Die |
| UCIe | Universal Chiplet Interconnect Express |
| TDP | Thermal Design Power |
| ... | ... |

## Appendix C: Traceability Export
(生成 RTM 时的工具与格式：DOORS/Jama/CSV)
