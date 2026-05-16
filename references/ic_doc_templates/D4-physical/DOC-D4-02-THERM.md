---
doc_id: DOC-D4-02-THERM
doc_type: THERM
title: Thermal Management Specification
version: 0.1-template
status: template
tier: 1
domain: Physical
owner: Thermal Engineer
approvers: [Chief Architect, Package Engineer, Reliability Lead]
parent: [DOC-D4-01-PKG, DOC-D2-01-ARCH]
children: [DOC-D8-01-BRINGUP]
references: [JEDEC JESD51 series, IEC 60747, Flotherm/Icepak/6SigmaET]
generated: 2026-04-23T22:45:00+08:00
---

# Thermal Management Specification — {{ Product Name }}

## 0. Document Control
| Version | Date | Author | Change |
|---|---|---|---|
| 0.1 | YYYY-MM-DD | {{ Thermal Eng }} | Initial |

---

## 1. Purpose

定义 chiplet 系统的热预算、冷却方案、热互操作性（die 间热耦合）、thermal throttling 策略，并给出验证模型与测试计划。

## 2. Thermal Budget

| Component | Peak Power (W) | TIM Rth (K/W) | Junction Temp Limit (°C) |
|---|---|---|---|
| CCD × N | {{ N × M }} = {{ total }} | {{ 0.05 }} | 95 |
| IOD | {{ P }} | {{ 0.08 }} | 105 |
| HBM stack × M | {{ M × Q }} | {{ 0.15 }} | 105 |
| **Total package** | {{ sum }} | — | — |

## 3. Cooling Envelope

| Parameter | Target | Acceptance |
|---|---|---|
| Max ambient | {{ 35 }} °C | System spec |
| Max cold-plate inlet | {{ 40 }} °C | Liquid cooling |
| Coolant flow | {{ 4 LPM }} | — |
| Thermal resistance θ_ja | {{ 0.08 }} K/W | — |
| Thermal resistance θ_jc (die to case) | {{ 0.05 }} K/W | — |

## 4. Thermal Model

### 4.1 Simulation Methodology
- Tool: {{ Icepak / 6SigmaET / Flotherm / COMSOL }}
- Granularity: per-die power maps; CFD for cold plate
- Correlation: within 5% of bench measurements

### 4.2 Power Maps (Key Workloads)

| Workload | CCD hot region | Power density hotspot |
|---|---|---|
| LLM training | Tensor engine @ (x,y) | {{ 5 W/mm² }} |
| All-reduce | D2D PHY @ edges | {{ 3 W/mm² }} |
| Idle | Always-on island | {{ 0.1 W/mm² }} |

### 4.3 Transient Thermal Model
- RC network (Cauer/Foster) for fast response modeling
- Validated against impulse response measurements

## 5. Die-to-Die Thermal Coupling

Chiplet 特有：相邻 die 通过 interposer / TIM / substrate 有热耦合。

| Coupling path | Resistance (K/W) |
|---|---|
| CCD0 → IOD (via interposer) | {{ 0.3 }} |
| CCD0 → CCD1 (adjacent, via substrate) | {{ 2 }} |
| CCD → HBM (via interposer) | {{ 0.5 }} |

**设计约束**: HBM Tj 不应因相邻 CCD 热量超过 5°C 额外升高。

## 6. Thermal Interface Materials (TIM)

### TIM1 (Die to lid/heat spreader)
- Material: {{ Indium / liquid metal / graphite TIM }}
- Bulk conductivity: {{ 50 W/m·K }}
- Application: {{ Reflowed indium }}
- Reliability: TC ≥ 1000 cycles @ -40~125°C without degradation

### TIM2 (Heat spreader to cold plate)
- Material: {{ Phase change / paste }}
- Re-workable: Yes (end-user application)

## 7. Thermal Sensors

### 7.1 Sensor Placement
每 die 至少 {{ 8 }} 个 thermal diodes，覆盖：
- Tensor engine hot cores
- D2D PHY
- Cache
- Edge (参考)

### 7.2 Sensor Readout
- Resolution: 0.5°C
- Response time: ≤ 1 ms
- Accuracy: ±2°C after calibration
- Access: MMIO + sideband (for management)

## 8. Dynamic Thermal Management

### 8.1 Throttle Triggers

| Tj | Action |
|---|---|
| ≥ 85°C | Clock throttle (5% per 1°C over) |
| ≥ 95°C | DVFS downshift to P2 |
| ≥ 100°C | Aggressive throttle to P4 |
| ≥ 105°C | Emergency shutdown (TjMAX protection) |

### 8.2 Control Loop
- Period: 1 ms
- Controller: PI on max-Tj of all sensors
- Firmware location: IOD PMU (→ DOC-D2-04-SWARCH)

## 9. Reliability & Aging

| Mechanism | Model | Target |
|---|---|---|
| BTI (NBTI/PBTI) | Black/Arrhenius | < 5% Vth shift @ 10 y |
| EM (Electromigration) | Black's law | FIT < {{ 10 }} @ Tj=85°C |
| TDDB | {{ E model }} | < 1 FIT |
| Thermal cycling | Coffin-Manson | 1000 cycles no fail |

## 10. Validation Plan

| Phase | Method | Acceptance |
|---|---|---|
| Pre-silicon | CFD + RC model | Within spec |
| Pre-production | IR camera on packaged part | Correlation ≤ 5% |
| Production | On-die sensor sanity check | All sensors ±2°C of mean |
| Field | Telemetry monitoring | Tj in spec under all workloads |

## 11. Quality Checklist

- [ ] Thermal budget per-die 与 PRD TDP 一致
- [ ] 所有 hotspot 在仿真中 Tj ≤ limit
- [ ] Die-die thermal coupling 已建模
- [ ] HBM 温升 ≤ 5°C from CCD 耦合
- [ ] Sensor 布局覆盖所有 hotspot
- [ ] Throttle 策略在 DVFS 与 performance 间有 ≤ 5% 折中
- [ ] TIM 选材通过 reliability qual
- [ ] 测试方法（IR camera / sensor）定义
- [ ] 与 PKG 的 Rth 数据一致
- [ ] Firmware 控制回路已与 SW Arch 对齐

## 12. References
- JEDEC JESD51-1 (Integrated Circuit Thermal Measurement)
- JEDEC JESD51-14 (Transient Dual Interface Test Method)
- IEC 60747-1
