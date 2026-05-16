---
doc_id: DOC-D4-01-PKG
doc_type: PKG
title: Package Design Specification
version: 0.1-template
status: template
tier: 0
domain: Physical
owner: Package Engineer
approvers: [Chief Architect, Thermal Lead, OSAT Partner]
parent: DOC-D2-01-ARCH
children: [DOC-D4-02-THERM, DOC-D5-02-KGD, DOC-D8-01-BRINGUP]
references: [JEDEC JEP30, OCP CDXML, JEDEC JESD22 (reliability), TSMC/Samsung/Intel OSAT design rules]
generated: 2026-04-23T22:45:00+08:00
---

# Package Design Specification — {{ Product Name }}

## 0. Document Control
| Version | Date | Author | Change |
|---|---|---|---|
| 0.1 | YYYY-MM-DD | {{ PKG Eng }} | Initial |

**Freeze Point**: Tape-out Readiness Review. Post-freeze changes require CCB.

---

## 1. Package Summary

| Attribute | Value |
|---|---|
| Package type | {{ CoWoS-L / EMIB / Foveros / Foveros Direct / SoIC / I-Cube }} |
| Substrate dim | {{ 65 × 75 mm }} |
| Substrate material | {{ Organic / Si interposer / Glass }} |
| Interposer type | {{ Passive Si / Active / RDL only }} |
| Die count | {{ N }} |
| Total bumps | ~{{ 100,000 }} ({{ 75k micro-bump + 25k C4 }}) |
| Pin count (socket/BGA) | {{ 6000 }} |
| OSAT partner | {{ TSMC BE / ASE / Amkor }} |

## 2. Die Placement Plan

```
Package top view (substrate 65 × 75 mm):

  ┌─────────────────────────────────────────┐
  │   ┌───┐   ┌───┐ ┌───┐ ┌───┐   ┌───┐   │
  │   │HBM│   │CCD│ │IOD│ │CCD│   │HBM│   │
  │   │ 0 │   │ 0 │ │   │ │ 1 │   │ 1 │   │
  │   └───┘   └───┘ └───┘ └───┘   └───┘   │
  │                                        │
  │   ┌───┐   ┌───┐ ┌───┐ ┌───┐   ┌───┐   │
  │   │HBM│   │CCD│ │CCD│ │CCD│   │HBM│   │
  │   │ 2 │   │ 2 │ │ 3 │ │ 4 │   │ 3 │   │
  │   └───┘   └───┘ └───┘ └───┘   └───┘   │
  └─────────────────────────────────────────┘
```

（实际文档须插入 DXF/SVG 物理布局图）

### 2.1 Die Dimensions

| Die | Dim (mm) | Area (mm²) | Thickness (μm) | Orientation |
|---|---|---|---|---|
| CCD | {{ 20×25 }} | 500 | 775 / 100 (thinned) | F-up / F-down |
| IOD | {{ 25×30 }} | 750 | 775 | F-up |
| HBM3e | {{ 11×11 }} | 121 | stacked 12-Hi | F-up |

## 3. Interconnect Architecture

### 3.1 Bump Hierarchy

| Level | Pitch | Count | Function |
|---|---|---|---|
| Micro-bump (die to interposer) | {{ 36 μm }} | 75,000 | D2D + HBM + power/gnd |
| C4 (interposer to substrate) | {{ 80 μm }} | 25,000 | To substrate |
| BGA (substrate to socket) | {{ 1 mm }} | 6000 | To system |

### 3.2 Interposer RDL

| Layer | Metal | Thickness | Line/Space |
|---|---|---|---|
| M1 | Cu | 0.5 μm | 0.4 / 0.4 μm |
| M2 | Cu | 0.5 μm | 0.4 / 0.4 μm |
| TSV | Cu | — | 10 μm diameter, 100 μm deep |

### 3.3 D2D Routing
- UCIe modules between CCDs/IOD: routed on M1–M2 of interposer
- Trace length per UCIe module: ≤ {{ 2 mm }}
- Trace impedance: 85 Ω diff ±10%

## 4. Power Delivery (PDN)

### 4.1 Power Rails

| Rail | Voltage | Peak Current | VRM location |
|---|---|---|---|
| VDD_CORE (per CCD) | 0.8 V | {{ 300 A }} | VRM on motherboard + on-substrate caps |
| VDD_IO | 0.9 V | {{ 100 A }} | - |
| VDD_HBM | 1.1 V | {{ 50 A × N stacks }} | - |
| VDD_AO | 0.8 V | {{ 5 A }} | Always on |

### 4.2 Decoupling Capacitors
- On-die: ~10 nF/mm²
- On-interposer (deep trench): ~100 nF
- On-substrate (MLCC): ~10 μF per rail
- On-motherboard: bulk bank

### 4.3 PDN Impedance Target
- Target: Z(f) ≤ {{ 0.5 mΩ }} from DC to 100 MHz

## 5. Signal Integrity

- D2D UCIe: eye mask per UCIe §4
- High-speed I/O (PCIe Gen6 @ 64 GT/s): per PCIe spec
- Package trace modeling: HFSS 3D extraction; S-parameters archived

## 6. Mechanical

| Attribute | Target | Limit |
|---|---|---|
| Total height | {{ 7.5 mm }} | {{ 8.0 }} |
| Substrate warpage @ RT | ≤ 150 μm | ≤ 200 |
| Warpage @ reflow | ≤ 200 μm | ≤ 300 |
| CTE mismatch (die-substrate) | ≤ 3 ppm/K |  |
| Drop test | 1 m onto concrete | pass per JESD22-B104 |

## 7. Thermal (summary; full spec in DOC-D4-02-THERM)

- Target Tj: ≤ 95°C under max workload
- TIM: {{ indium / liquid metal / phase-change }}
- Cold plate contact area: {{ N × M mm² }}

## 8. Assembly Process Flow

```
Wafer ──► Dicing ──► Die sort (wafer test, KGD)
                              │
                              ▼
Bumping (micro-bump) ──► Die attach onto interposer (D2W)
                              │
                              ▼
Interposer to substrate (C4 reflow) ──► Underfill
                              │
                              ▼
Lid attach (TIM1 + heat spreader) ──► BGA ball attach
                              │
                              ▼
Final test (FT) ──► Burn-in ──► System-level test (SLT) ──► Pack & ship
```

### 8.1 OSAT Handoff Files (CDXML per JEDEC JEP30)

所有 die 必须提供 CDXML 文件，覆盖：
- Structure / Mechanical
- Thermal (JEP30-T181)
- Electrical (JEP30-E100)
- Power & SI
- Behavioral (ESL / IBIS)
- Test model
- Security / safety

## 9. Known-Good-Die Requirements
→ 完整 KGD 测试在 DOC-D5-02-KGD

## 10. Reliability Qualification

| Test | Standard | Target |
|---|---|---|
| TC (Temperature Cycle) | JEDEC JESD22-A104 | 1000 cycles -40~125°C, no fail |
| HTOL | JEDEC JESD22-A108 | 1000 hrs @ 125°C/Vop |
| HAST | JEDEC JESD22-A110 | 264 hrs @ 130°C/85%RH |
| ESD HBM | JEDEC JS-001 | ≥ 2 kV |
| ESD CDM | JEDEC JS-002 | ≥ 500 V |
| Latch-up | JEDEC JESD78E | ≥ 100 mA |

## 11. Quality Checklist

- [ ] Die 布局与 floorplan hints (ARCH §14) 一致
- [ ] Bump pitch 与 UCIe spec 要求匹配
- [ ] PDN 阻抗仿真通过
- [ ] SI HFSS 模型提取完成
- [ ] Warpage 仿真 + 经验数据在限制内
- [ ] CDXML 文件已生成并通过 schema 验证
- [ ] OSAT 设计规则检查（DRC）通过
- [ ] Thermal 分析（DOC-D4-02）一致
- [ ] Reliability 测试矩阵全覆盖
- [ ] Rework 策略已定义

## 12. References
- JEDEC JEP30 PartModel Guidelines
- OCP CDXML
- JEDEC JESD22-A 系列（可靠性）
- TSMC 3DFabric design manual (NDA)
