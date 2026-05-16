---
doc_id: DOC-D2-03-PERF
doc_type: PERF
title: Performance Modeling Specification
version: 0.1-template
status: template
tier: 1
domain: Architecture
owner: Performance Architect
approvers: [Chief Architect, Verification Lead]
parent: DOC-D1-01-PRD
children: [DOC-D2-01-ARCH, DOC-D6-01-VPLAN]
references: [gem5, SystemC TLM 2.0, RapidChiplet, SimBricks]
generated: 2026-04-23T22:45:00+08:00
---

# Performance Modeling Specification — {{ Product Name }}

## 0. Document Control
| Version | Date | Author | Change |
|---|---|---|---|
| 0.1 | YYYY-MM-DD | {{ Perf Architect }} | Initial |

---

## 1. Purpose

验证 Arch Spec 中的性能承诺（REQ-PERF-*）可实现；为 RTL/VPlan 提供性能 oracle；在流片���做性能 "什么-if" 分析。

## 2. Modeling Methodology

| Level | Model Type | Tool | Accuracy | Speed |
|---|---|---|---|---|
| System-level (analytical) | Queuing / roofline | Python / spreadsheet | ±30% | Instant |
| Cycle-approximate | Transaction-level (TLM) | SystemC TLM 2.0 | ±10–15% | 10–100 MIPS |
| Cycle-accurate | gem5 / custom | gem5 SE/FS | ±5% | 100 KIPS |
| Chiplet-specific | RapidChiplet (ICI) | Python | — | 超快（100×-100kx vs cycle-acc） |
| RTL-based (golden) | RTL simulation | VCS / Xcelium | Exact (at RTL) | 1–10 KIPS |

## 3. Model Scope

### 3.1 Included
- Compute core performance (IPC, Fmax)
- Cache hierarchy (hit rates, latency)
- D2D fabric (bandwidth, contention, latency)
- HBM (bandwidth, row-buffer hit rate, refresh overhead)
- Power model (static + dynamic @ workload)

### 3.2 Excluded (or abstracted)
- RTL-level timing closure (ASIC P&R detail)
- Analog/PHY transient (eye diagrams — separate SI model)
- Package parasitics (separate thermal/SI models)

## 4. Key Metrics to Model

| Metric | Target (from PRD) | Model Output |
|---|---|---|
| FP16 peak | {{ N PFLOPS }} | Simulated peak |
| End-to-end LLM inference latency | ≤ {{ M ms }} | P50/P95/P99 |
| HBM BW utilization | ≥ 85% @ GEMM | Average |
| D2D fabric utilization | ≤ 70% (for headroom) | Average + peak |
| Power @ peak | ≤ {{ W }} | Total + breakdown |
| Thermal hotspot | ≤ {{ T }} °C | Max Tj |

## 5. Workload Suite

| ID | Workload | Purpose | Source |
|---|---|---|---|
| WL-01 | {{ GPT-4-class LLM training }} | Compute + HBM BW + D2D | Trace-based |
| WL-02 | {{ GPT-4-class inference }} | Latency tail | Trace |
| WL-03 | Stream triad | HBM BW ceiling | Synthetic |
| WL-04 | Cross-die all-reduce | D2D BW + coherence | Synthetic |
| WL-05 | Sparse graph | Memory random access | Real app |

## 6. Model Validation

| Phase | Validation Method | Acceptance |
|---|---|---|
| Pre-silicon | Compare TLM vs RTL on micro-benchmark | Δ ≤ 10% |
| Post-silicon | Compare model vs silicon | Δ ≤ 15% |
| Continuous | Per-commit regression | No perf regression > 3% unnoticed |

## 7. Deliverables

| Deliverable | Format | Owner |
|---|---|---|
| Analytical spreadsheet | `.xlsx` | Perf |
| SystemC TLM model | C++ source | Perf |
| gem5 config | Python | Perf |
| Validation report | Markdown + plots | Perf + DV |

## 8. Quality Checklist

- [ ] 每条 REQ-PERF-xxx 有对应模型输出
- [ ] 模型与 RTL 误差 ≤ 10%（pre-si）
- [ ] 模型与 silicon 误差 ≤ 15%（post-si）
- [ ] Workload 套件覆盖所有 PRD 场景
- [ ] 模型可复现（version-locked）
- [ ] Power + Perf 联合建模（不只 perf）
- [ ] Chiplet 特有的 D2D contention 已建模

## 9. References
- gem5 Simulator: https://www.gem5.org/
- RapidChiplet: arXiv:2311.06081
- SimBricks: https://simbricks.github.io/
