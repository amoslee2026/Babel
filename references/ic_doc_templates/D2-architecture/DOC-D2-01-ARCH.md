---
doc_id: DOC-D2-01-ARCH
doc_type: ARCH
title: System Architecture Specification (Chiplet SoC)
version: 0.1-template
status: template
tier: 0
domain: Architecture
owner: TBD
approvers: [Chief Architect, CTO, Verification Lead]
parent: DOC-D1-01-PRD
children: [DOC-D2-02-ADR, DOC-D3-01-MAS, DOC-D3-02-IPXACT, DOC-D4-01-PKG, DOC-D4-02-THERM, DOC-D5-01-DFT, DOC-D7-01-SEC, DOC-D6-02-MDBOOT]
references: [UCIe 2.0/3.0, Arm CSA, OCP FCSA, IEEE 1685, IEEE 1801, JEDEC JESD235 (HBM), CXL 3.x]
generated: 2026-04-23T22:45:00+08:00
---

# System Architecture Specification — {{ Product Name }}

## 0. Document Control

| Version | Date | Author | Change |
|---|---|---|---|
| 0.1 | YYYY-MM-DD | {{ Architect }} | Initial draft |

**Freeze Point**: Tape-out Readiness Review

---

## 1. Executive Summary

- **Arch Theme**: {{ 多 die 架构简述 }}
- **Key Architectural Choices** (详见 DOC-D2-02-ADR)：
  1. {{ Die 分割策略 }}
  2. {{ D2D 协议选择 }}
  3. {{ Memory 层级 }}
  4. {{ Coherence protocol }}

## 2. Design Goals & Constraints

| Goal | Target | Source |
|---|---|---|
| Peak Compute | {{ N PFLOPS }} | REQ-COMPUTE-001 |
| TDP | ≤ {{ N }} W | REQ-PWR-001 |
| Area | ≤ {{ N }} mm² | REQ-AREA-001 |
| D2D Aggregate BW | ≥ {{ N }} TB/s | REQ-D2D-004 |

## 3. System Block Diagram

```
  ┌─────────────────────────────────────────────────────────┐
  │                    Package Substrate                     │
  │  ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────┐    │
  │  │  CCD 0  │◄─┤  IOD    ├─►│  CCD 1  │  │  MEMD   │    │
  │  │ N5      │  │ N6      │  │ N5      │  │(HBM3e)  │    │
  │  └─────────┘  └─────────┘  └─────────┘  └─────────┘    │
  │       ▲              ▲           ▲           ▲          │
  │       │              │           │           │          │
  │       └──── UCIe 2.0 D2D fabric ──────────────┘          │
  └───────────────────────��─────────────────────────────────┘
```

（实际文档应插入 SVG / visio / draw.io 块图）

## 4. Functional Partitioning

| Die | Functions | Die Area (mm²) | Power Envelope (W) |
|---|---|---|---|
| CCD 0 | {{ CPU / GPU cores, L2 cache }} | {{ N }} | {{ M }} |
| IOD | {{ D2D ctrl, PCIe, UCIe PHY, memory ctrl }} | {{ N }} | {{ M }} |
| MEMD | {{ HBM3e stack ×N }} | {{ N }} | {{ M }} |

→ Die partition 决策引用：ADR-001、ADR-002

## 5. Processing Elements

### 5.1 Compute Cores
- **ISA**: {{ x86-64 / ARMv9 / RISC-V RV64GCV }}
- **Core count per CCD**: {{ N }}
- **Pipeline depth**: {{ N }} stages
- **SIMD width**: {{ 512b / 1024b }}

### 5.2 Accelerators
- **Tensor Engine**: {{ MxN systolic array, FP16/BF16/FP8/INT8 }}
- **AI Matrix Unit**: {{ ... }}

## 6. Memory Architecture

### 6.1 Cache Hierarchy

| Level | Size | Latency (ns) | Scope |
|---|---|---|---|
| L1 I | {{ 32KB }} | 1 | per core |
| L1 D | {{ 64KB }} | 1 | per core |
| L2 | {{ 1MB }} | 10 | per core (private) |
| L3 (LLC) | {{ 64MB }} | 30 | per CCD (shared) |
| Remote L3 | - | 50-80 | across D2D |
| HBM | {{ 128GB × N stack }} | 100-150 | global |

### 6.2 Coherence Protocol
- **On-die**: {{ MOESI / MESI }}
- **Cross-die**: {{ CHI C2C / CXL.cache / Infinity Fabric }}
- **Home directory**: {{ distributed per CCD / centralized IOD }}
- **Coherence domain**: {{ scope }}

## 7. I/O & Peripherals

| Interface | Spec | Lanes / Ports | Location |
|---|---|---|---|
| PCIe | Gen5 / Gen6 | x16 × N | IOD |
| CXL | 3.0 / 3.1 | over PCIe PHY | IOD |
| UCIe | 2.0 Advanced | x64 × M modules | IOD |
| Ethernet | 400G / 800G | N ports | IOD |
| JTAG / IJTAG | IEEE 1149.1 / 1687 | 1 TAP + per-die wrapper | IOD (master) |

## 8. Debug & Test Infrastructure

- **UCIe UDA (Manageability System)**: {{ enabled / disabled }}; 覆盖 telemetry, debug, DFx
- **Multi-Die Debug**: IJTAG per die + cross-die TAP controller arbitration
- **Trace Export**: {{ ETM / MIPI STM / custom }} through IOD
- **Performance Counters**: {{ per-die counters federated via UCIe sideband }}

→ 详细 DFT 在 DOC-D5-01-DFT

## 9. Die-to-Die Interconnect

### 9.1 D2D Protocol Stack

| Layer | Choice | Spec Reference |
|---|---|---|
| Physical (PHY) | UCIe 2.0 Advanced @ {{ 32 GT/s }} | UCIe Spec §4 |
| Link | UCIe Link Layer with Retry | UCIe Spec §5 |
| Protocol | {{ CXL.cache / CXL.mem / Streaming Raw }} | UCIe Spec §6 |
| Transaction | {{ CXL Native / Custom }} | - |

### 9.2 D2D Physical Characteristics

| Parameter | Target |
|---|---|
| Bump pitch | {{ 36 μm (Advanced) / 25 μm (3D) }} |
| Lanes per module | {{ 64 }} |
| Modules per die | {{ N }} |
| Per-lane rate | {{ 32 GT/s }} |
| Module bandwidth | {{ 256 GB/s }} |
| Aggregate bandwidth (per die) | {{ M TB/s }} |
| Energy efficiency | {{ 0.15 pJ/bit (3D) / 0.3 (EMIB) / 0.56 (CoWoS) }} |
| BER target | ≤ 1e-27 |

### 9.3 D2D Latency Budget

| Path | Target (ns) |
|---|---|
| Local D2D round-trip | ≤ 10 |
| Remote cache access (coherent) | ≤ 30 |
| Memory access via remote die | ≤ 150 |

## 10. On-Chip Interconnect (per die)

- **NoC topology**: {{ mesh / ring / crossbar }}
- **Flit size**: {{ 128b }}
- **Arbitration**: {{ round-robin with QoS classes }}
- **QoS classes**: {{ real-time / best-effort / bulk }}

## 11. Clock Architecture

| Domain | Frequency | Source | Cross-Die? |
|---|---|---|---|
| clk_core | {{ 3 GHz }} | Local PLL per CCD | No |
| clk_d2d | {{ 16 GHz / 32 GHz }} | Reference from IOD PLL, forwarded over UCIe | Yes (source-synchronous) |
| clk_mem | {{ 4.8 GHz }} | HBM PHY PLL | No (internal) |
| clk_mgmt | {{ 100 MHz }} | Always-on oscillator | Yes |

### 11.1 CDC Strategy
- 源同步 forward with training-based deskew (UCIe recommended)
- Metastability resolvers: 2-FF synchronizer for control signals
- Async FIFO for data crossing

## 12. Power Architecture

### 12.1 Power Domains (UPF IEEE 1801)

| Domain | Voltage | Scope | Always-On? |
|---|---|---|---|
| VDD_CORE | 0.8V | Compute cores | No |
| VDD_IO | 0.9V | I/O ring, D2D PHY | No (except UCIe AO island) |
| VDD_HBM | 1.1V | HBM interface | No |
| VDD_AO | 0.8V | Management, wake logic | Yes |

### 12.2 Power Management
- **DVFS levels**: {{ 5 per core domain }}
- **Power gating**: per-die and per-cluster
- **Cross-die coordination**: {{ centralized PMU in IOD / distributed negotiation }}
- **Low-power states**: L0 / L0p / L1 / L2 / L3 (via UCIe)

## 13. Reset Architecture

| Reset | Scope | Source |
|---|---|---|
| Cold reset | All dies | PERST# from host |
| Warm reset | Compute cores only | Software |
| D2D link reset | Single UCIe module | LTSM |
| Per-die reset | Individual CCD | IOD management |

**Reset sequence** (详细在 DOC-D6-02-MDBOOT)：
1. Cold reset asserted
2. VDD_AO stable → clk_mgmt active
3. IOD PMU boots → brings up VDD_IO
4. UCIe link training (each module) → L0
5. IOD configures CCDs → CCD reset release
6. CCDs boot firmware → handshake with IOD

## 14. Physical Implementation

### 14.1 Floorplan Hints
（插入 floorplan 图）

### 14.2 Package Architecture
→ DOC-D4-01-PKG

### 14.3 Thermal Constraints
→ DOC-D4-02-THERM

## 15. Security Architecture Overview

- **Root of Trust**: {{ Management chiplet / TPM / dedicated security die }}
- **Secure boot chain**: ROM → BL1 → BL2 → OS
- **Key hierarchy**: {{ Hardware root key → platform keys → user keys }}
- **D2D link encryption**: {{ optional / required }}

→ 完整威胁模型：DOC-D7-01-SEC

## 16. Functional Safety Architecture (若适用)

- **ASIL level**: {{ from PRD }}
- **Safety mechanisms**:
  - Lockstep execution for ASIL-D cores
  - ECC on all memory interfaces
  - Cross-die parity on D2D
  - Watchdog per die
- **FMEDA**: 链接到 DOC-D7-01-SEC 附录

## 17. Performance Budgets

| Budget | Allocation | Check |
|---|---|---|
| Total power | {{ N W}} → CCD×2 ({{ M W }}) + IOD ({{ P W }}) + HBM ({{ Q W }}) | Sum ≤ TDP |
| Total area | {{ N mm² }} | Sum ≤ package cavity |
| D2D BW | {{ TB/s }} | ≥ Remote memory demand |
| Cross-die latency | Budget table in §9.3 | All paths ≤ target |

## 18. Open Issues & Risks

| Risk | Mitigation | Owner |
|---|---|---|
| {{ UCIe 2.0 ecosystem maturity }} | 备选 fallback 到 1.1 | arch |
| {{ 3D thermal validation }} | Early thermal prototype | thermal |

## 19. Quality Checklist

- [ ] Die 划分方案有 ≥3 个 ADR trade-off 记录
- [ ] UCIe 版本、bump pitch、速率参数与 PRD/PKG 一致
- [ ] 所有跨 die CDC 已识别 + 同步策略明确
- [ ] 功耗预算总和 ≤ PRD TDP（含 margin）
- [ ] 热路径图 + hotspot 分析已完成
- [ ] Coherence 协议与 memory 架构一致
- [ ] IP-XACT 1685 元数据生成就绪
- [ ] 所有 REQ-xxx 有对应 ARCH section
- [ ] 所有 ARCH section 有 MAS block 映射
- [ ] ADR 已批准
- [ ] Glossary 完整

## Appendix A: ADR Index
→ DOC-D2-02-ADR

## Appendix B: Standards Compliance Map
| Requirement | Standard | Section |
|---|---|---|
| D2D PHY | UCIe 2.0 | §4 |
| UPF | IEEE 1801 | §11 |

## Appendix C: Traceability
每条 section → REQ-xxx 的反向映射表
