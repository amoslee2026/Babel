---
doc_id: DOC-D2-05-DIC
doc_type: DIC
title: Die Interface Contract
version: 0.1-template
status: template
tier: 1
domain: Architecture
owner: System Integration Architect
approvers: [Chief Architect, IP Owners (all dies), Verification Lead]
parent: [DOC-D1-01-PRD, DOC-D2-01-ARCH]
children: [DOC-D3-01-MAS, DOC-D6-01-VPLAN]
references: [UCIe 2.0/3.0, OCP FCSA, Arm CSA, CXL 3.x]
generated: 2026-04-23T22:45:00+08:00
---

# Die Interface Contract — {{ Product Name }}

## 0. Document Control
| Version | Date | Author | Change |
|---|---|---|---|
| 0.1 | YYYY-MM-DD | {{ Integration Arch }} | Initial |

**Freeze Point**: RTL v1.0. Changes after freeze require CCB approval.

---

## 1. Purpose

本文件是**跨 die / 跨供应商的接口契约**。它精确定义每对 die 之间的 UCIe/D2D 接口、协议行为、时序、功耗、可靠性 SLA。类比软件的 API spec — 任何一方偏离此契约即为违约。

## 2. Scope

本合约覆盖以下 die 对：

| Pair ID | Die A | Die B | Interface Type |
|---|---|---|---|
| DIC-01 | CCD0 | IOD | UCIe 2.0 Advanced |
| DIC-02 | CCD1 | IOD | UCIe 2.0 Advanced |
| DIC-03 | IOD | MEMD (HBM) | HBM3e per JEDEC JESD235 |
| DIC-04 | IOD | 3rd-party chiplet | UCIe 2.0 + Golden Die |

---

## 3. Contract per Die Pair

### 3.1 DIC-01: CCD0 ↔ IOD

#### 3.1.1 Physical Layer

| Parameter | Value | Tolerance |
|---|---|---|
| UCIe version | 2.0 Advanced | - |
| Modules | {{ 4 }} | - |
| Lanes per module | 64 (TX) + 64 (RX) | - |
| Per-lane rate | 32 GT/s | ±1% |
| Bump pitch | 36 μm | per UCIe spec |
| Reference voltage | 0.9 V | ±5% |
| Max insertion loss | {{ 1.5 dB }} @ Nyquist | - |
| Max crosstalk (NEXT+FEXT) | {{ -35 dB }} | - |
| BER target | 1e-27 after FEC | - |

#### 3.1.2 Link Layer

- **Retry mechanism**: CRC-16 + Go-Back-N, max 8 retries
- **Max burst length**: 256 flits
- **Credit advertisement**: At link init, every {{ N }} flits
- **Training sequence**: UCIe LTSM 2.0 §5.3

#### 3.1.3 Protocol Layer

- **Protocols carried**: CXL.cache, CXL.mem, CXL.io, Streaming Raw
- **VC (Virtual Channel) mapping**:
  - VC0: CXL.cache
  - VC1: CXL.mem
  - VC2: CXL.io
  - VC3: Debug / management
- **Priority**: Strict VC0 > VC1 > VC2 > VC3

#### 3.1.4 Performance SLA

| Metric | Target |
|---|---|
| Effective BW (useful payload) | ≥ 1.6 TB/s per direction |
| RTT latency (cache miss to remote L3) | ≤ 25 ns typical, ≤ 35 ns max |
| Latency jitter | ≤ 2 ns |

#### 3.1.5 Power States

| State | Description | Entry Latency | Exit Latency |
|---|---|---|---|
| L0 | Active | - | - |
| L0p | Idle, clock on | — | {{ 10 ns }} |
| L1 | Low-power standby | {{ 100 ns }} | {{ 500 ns }} |
| L2 | Deep sleep | {{ 1 μs }} | {{ 5 μs }} |

#### 3.1.6 Error Handling

| Error | Detection | Recovery |
|---|---|---|
| Single-bit lane error | FEC | Corrected in hardware |
| Multi-bit CRC failure | CRC | Retry (link layer) |
| Persistent failure | Retry count exceeded | Lane degrade → container fallback |
| Link down | LTSM | Retrain; if fail, log + interrupt host |

#### 3.1.7 Debug Hooks

- UCIe Sideband: debug/status access
- Lane margining: per UCIe §10
- Trace export: {{ N lanes reserved }} for debug flits

---

### 3.2 DIC-03: IOD ↔ HBM3e

（使用 JEDEC JESD235 标准，此处列出项目特定参数）

| Parameter | Value |
|---|---|
| HBM speed grade | HBM3e 9.6 Gbps |
| Stacks per IOD | {{ 8 }} |
| Channels per stack | 16 |
| Per-channel BW | 76.8 GB/s |
| Aggregate BW | 9.8 TB/s |
| Refresh policy | Auto-refresh @ per-bank |
| ECC | SEC-DED inline |
| Training | Vendor BIST + IOD calibration sequence |

---

### 3.3 DIC-04: IOD ↔ 3rd-Party Chiplet

#### 3.3.1 Golden Die Reference
- Conformance test vectors: provided by IOD vendor
- Pass/fail criteria: per UCIe 2.0 Compliance §11

#### 3.3.2 Pin-out Contract
（列出 UCIe 标准 module 的 bump map + 任何 sideband 定义）

#### 3.3.3 Interop Test Plan
→ 详细在 DOC-D6-01-VPLAN §Chiplet Interop

#### 3.3.4 Liability & Change Control
- Any breaking change to this contract requires sign-off from **both** die owners + CCB
- Minor (backward-compatible) changes: notice within 30 days

---

## 4. Safety-Related Interface Agreement (若 ISO 26262)

遵循 **Safety Element out of Context (SEooC)** 模型：

| Element | Responsibility |
|---|---|
| Integrator (本项目) 提供 | Intended use、assumptions of use、integration verification |
| 3rd-party die 供应商 提供 | Safety Case、FMEDA、Safety Manual |
| 双方 共同 | Joint FMEDA at integration |

## 5. Compliance Mapping

| Contract Item | Standard Clause |
|---|---|
| PHY params | UCIe 2.0 §4.2 |
| Link layer | UCIe 2.0 §5 |
| CXL protocols | CXL 3.1 §3 |
| HBM | JEDEC JESD235D |
| Safety (if applicable) | ISO 26262-10 §7 (SEooC) |

## 6. Quality Checklist

- [ ] 每对 die 有独立 DIC-NN 条目
- [ ] 每条 DIC 的 PHY/Link/Protocol 三层完整
- [ ] 性能 SLA 可测量
- [ ] 错误场景完整枚举
- [ ] 电源状态转换矩阵完整
- [ ] 3rd-party DIC 有 Golden Die 对齐
- [ ] 每条契约与 UCIe / CXL / HBM 标准明确映射
- [ ] SEooC 协议（若 ISO 26262）明确
- [ ] 变更控制流程定义

## 7. References
- UCIe Spec 2.0: https://www.uciexpress.org/
- CXL Spec 3.x: https://computeexpresslink.org/
- JEDEC JESD235D (HBM3e)
- ISO 26262-10:2018 (SEooC)
