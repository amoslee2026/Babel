---
doc_id: DOC-D5-02-KGD
doc_type: KGD
title: Known-Good-Die Test Plan
version: 0.1-template
status: template
tier: 0
domain: Test
owner: Test Engineering Lead
approvers: [Package Engineer, DFT Lead, Quality Lead]
parent: [DOC-D5-01-DFT, DOC-D4-01-PKG]
children: [DOC-D8-01-BRINGUP]
references: [IEEE 1838, AEC-Q100, JEDEC JESD22-A108 (HTOL), JEDEC JESD47 (qualification)]
generated: 2026-04-23T22:45:00+08:00
---

# KGD Test Plan — {{ Product Name }}

## 0. Document Control
| Version | Date | Author | Change |
|---|---|---|---|
| 0.1 | YYYY-MM-DD | {{ Test Eng }} | Initial |

---

## 1. Purpose

定义 chiplet 单 die 在封装前的测试流程，确保每颗 die 进入 2.5D/3D 集成前达到"known-good"质量等级，降低装配后 rework 成本（每 reject 可能影响整个包 10×+ 成本）。

## 2. KGD Quality Level Target

| Tier | Application | Target DPM |
|---|---|---|
| Tier-A (highest) | High-end HPC/AI, 汽车 ASIL-B+ | < 50 DPM |
| Tier-B | General enterprise | < 200 DPM |
| Tier-C | Consumer | < 1000 DPM |

本产品：Tier-{{ A/B }}

## 3. KGD Test Flow (Per Die)

```
Wafer ──► Wafer Probe (WS1) ──► Structural + Parametric
                                      │
                                      ▼
                                  Wafer Burn-in (可选)
                                      │
                                      ▼
                               Wafer Probe (WS2) ──► Post-BI test
                                      │
                                      ▼
                                  Dicing
                                      │
                                      ▼
                               Die Stress (ELTOL 若要求)
                                      │
                                      ▼
                               Singulated Die Screening (optional)
                                      │
                                      ▼
                               Pass → KGD bin
                                      │
                                      ▼
                               Die tray for assembly
```

## 4. Test Steps Detail

### 4.1 Wafer Probe (WS1 — at temperature + cold corners)

| Test | Coverage | Target |
|---|---|---|
| Continuity | All pads | 100% |
| IDDQ | Leakage static | < {{ spec limit }} |
| Structural (scan stuck-at) | Logic | ≥ 99% |
| Structural (at-speed transition) | Logic | ≥ 95% |
| MBIST | Memories | 100% |
| Parametric (Vmin shmoo) | Fmax @ Vmin, Imax @ Vmax | binning |
| D2D PHY BIST | UCIe PHY + lane margin | pass/fail |
| Thermal diode cal | On-die sensors | Within ±2°C |

### 4.2 Wafer Burn-in (若 Tier-A)
- Duration: {{ 24 }} hrs
- Temperature: {{ 125 }}°C
- Voltage: {{ Vmax + 10% }}
- Purpose: infant mortality screening

### 4.3 WS2 (Post-BI)
- Repeat subset of WS1 to catch latent defects
- Delta analysis: any parameter shift > threshold → fail

### 4.4 Dicing
- Laser groove + blade, or stealth laser
- Edge defect inspection optical

### 4.5 Singulated Die Screening (若 Tier-A)
- Electrical re-test at probe station on singulated die
- Cost vs yield trade-off analysis (→ see section 8)

## 5. Pre-Assembly Acceptance Criteria

All dies must pass:
- [ ] Structural coverage ≥ 99%
- [ ] All memory BIST clean
- [ ] D2D PHY margining within spec on all lanes
- [ ] No parametric outlier (>3σ from lot mean)
- [ ] No visual defect on die edges
- [ ] Burn-in pass (若执行)

## 6. Per-Die Traceability

Every die carries a traceability record:

```yaml
die_id: CCD-W24A3-R12C8       # wafer-row-col
lot: LOT2026042301
fab_date: 2026-03-15
probe_ws1: pass, {{ bin 1 }}
probe_ws2: pass
burn_in: pass
dicing: pass
singulated_screen: pass
assigned_to: package SN {{ PKG001234 }}
```

Format: JSON per die, archived in traceability DB.

## 7. Multi-Die Matching (for Assembled Packages)

Since multi-die package yield = ∏(die yield), matching strategy:

- **Speed binning**: match Fmax within {{ 100 MHz }} across CCDs in same package
- **Voltage binning**: Vmin within {{ 20 mV }}
- **Thermal characteristic**: Tj shift within {{ 2 °C }} at reference workload

## 8. Cost Model

| Scenario | Yield loss | Cost impact |
|---|---|---|
| Skip KGD (assemble then test) | Package assembly loss @ 1 bad die | 10×+ per reject |
| Full KGD (WS + singulated screen) | Minimal | Extra test time |
| Partial KGD (WS only) | Moderate | Balance |

**Decision**: {{ Full KGD / Partial / Skip }} — justified in DOC-D2-02-ADR.

## 9. Inter-Die Test (Post-Assembly)
→ DOC-D5-01-DFT §7.3 (boundary-scan + IEEE 1838)

## 10. Reliability Qualification (from wafer → post-package)

| Test | Standard | Sample | Target |
|---|---|---|---|
| HTOL | JESD22-A108 | ≥ 77 parts | 1000 hrs @ 125°C |
| TC | JESD22-A104 | ≥ 77 | 1000 cy -40 to 125°C |
| HAST | JESD22-A110 | ≥ 77 | 264 hrs @ 130°C/85%RH |
| ESD HBM | JS-001 | ≥ 3 | ≥ 2 kV |
| Latch-up | JESD78E | ≥ 6 | ≥ 100 mA |

## 11. Quality Checklist

- [ ] Structural test coverage ≥ 99%
- [ ] All memory BIST in KGD flow
- [ ] D2D PHY lane margining in KGD flow
- [ ] Burn-in policy decided (Tier-A: yes; Tier-B/C: optional)
- [ ] Per-die traceability DB operational
- [ ] Multi-die matching rules defined
- [ ] Cost model justified in ADR
- [ ] Qualification lot plan approved
- [ ] Tester capacity planned
- [ ] Yield learning feedback loop defined

## 12. References
- IEEE 1838-2019
- AEC-Q100 (汽车)
- JEDEC JESD22 series (qualification)
- JEDEC JEP30 (part model + CDXML)
