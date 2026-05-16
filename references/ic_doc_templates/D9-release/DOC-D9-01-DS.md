---
doc-id: DOC-D9-01-DS
title: Datasheet
domain: D9-release
version: 0.1
status: draft
parent: DOC-D1-01-PRD
generated: 2026-04-24T06:15:00+08:00
---

# DOC-D9-01-DS — Datasheet

## Document Control

| Field | Value |
|---|---|
| Document ID | DOC-D9-01-DS |
| Version | 0.1 |
| Classification | PUBLIC (after release) |
| Authors | Product Marketing Eng, Silicon Validation Lead |
| Reviewers | SoC Arch, Reliability, Legal, Compliance |
| Approvers | VP Product, VP Engineering |

### Revision History

| Ver | Date | Description |
|---|---|---|
| 0.1 | YYYY-MM-DD | Draft — internal only |
| 1.0 | YYYY-MM-DD | Preliminary — release with A0 silicon |
| 2.0 | YYYY-MM-DD | Final — production release |

---

## 1. Product Overview

### 1.1 Description

[Product Name] is a high-performance Chiplet System-on-Chip (SoC) fabricated in [Fab Node] process technology. The device integrates [N] chiplet dies interconnected via UCIe 2.0, delivering [bandwidth] aggregate die-to-die bandwidth in a single package.

**Key Features:**
- [N]× high-performance CPU cores ([ISA/uArch])
- [X] TB/s Die-to-Die (D2D) aggregate bandwidth via UCIe 2.0
- [N] GB on-package memory (HBM3 / LPDDR5X)
- PCIe Gen5 × 16 host interface
- Hardware Root of Trust with FIPS 140-3 Level 2 cryptographic subsystem
- [Package type]: [N] × [N] mm, [pin count]-ball [package technology]
- Power: TDP [XX] W, idle [XX] W

### 1.2 Applications

- High-Performance Computing (HPC) and AI training
- Network infrastructure (line card, smart NIC)
- Automotive ADAS (functional safety — ISO 26262 ASIL-[X])
- Cloud computing infrastructure

### 1.3 Part Number Structure

```
[PREFIX]-[SPEED]-[TEMP]-[PACKAGE]
  │         │       │       │
  │         │       │       └─ Package code (e.g., BGA1156)
  │         │       └─────── Temp range (C: 0–85°C, I: −40–125°C)
  │         └─────────────── Speed grade (1, 2, 3)
  └───────────────────────── Product family prefix
```

### 1.4 Ordering Information

| Part Number | Speed Grade | Temp Range | Package | Status |
|---|---|---|---|---|
| [PN]-1-C-BGA1156 | Grade 1 | 0 to 85 °C | FC-BGA 1156 | Sampling |
| [PN]-2-I-BGA1156 | Grade 2 | −40 to 125 °C | FC-BGA 1156 | TBD |

---

## 2. Block Diagram

```
┌──────────────────────────────────────────────────────────────────┐
│ Package Boundary                                                 │
│                                                                  │
│  ┌─────────────────────────┐  ┌──────────────────────────────┐  │
│  │  Host Die               │  │  Memory Die(s)               │  │
│  │  ┌─────────────────┐   │  │  ┌────────────────────────┐  │  │
│  │  │ CPU Cluster     │   │  │  │ HBM3 Stack × N         │  │  │
│  │  │ N × Big Core    │   │  │  └────────────────────────┘  │  │
│  │  │ M × Small Core  │   │  └──────────────────────────────┘  │
│  │  └────────┬────────┘   │           │ UCIe 2.0               │
│  │           │ NoC         │  ┌────────┴─────────────────────┐  │
│  │  ┌────────┴────────┐   │  │  Accelerator Die              │  │
│  │  │ Memory Ctrl     │   │  │  (AI / Network / Crypto)      │  │
│  │  │ UCIe PHY/Link   ├───┼──┤                               │  │
│  │  │ PCIe Gen5 ×16   │   │  └──────────────────────────────┘  │
│  │  │ HRoT / Security │   │                                    │
│  │  │ PMU             │   │                                    │
│  │  └─────────────────┘   │                                    │
│  └─────────────────────────┘                                    │
└──────────────────────────────────────────────────────────────────┘
         │                    │
      PCIe ×16 edge        Power / I2C / JTAG
```

---

## 3. Pin Description

### 3.1 Pin Count Summary

| Interface | Signal Count | I/O Direction | Voltage |
|---|---|---|---|
| PCIe Gen5 × 16 | 32 (TX+RX) | Differential I/O | 0.8 V AC |
| Management (I2C) | 2 (SDA, SCL) | Bidirectional | 1.8 V |
| Reset | 2 (PORESET_N, RESET_N) | Input | 1.8 V |
| Power Good | 1 (PWRGOOD) | Output | 1.8 V |
| JTAG / Debug | 5 (TCK, TMS, TDI, TDO, TRST_N) | Mixed | 1.8 V |
| Reference Clock | 4 (REFCLK_P/N × 2) | Differential Input | LVDS |
| Power (VDD) | [N] balls | Supply | 0.7 V |
| Power (VDDIO) | [N] balls | Supply | 1.8 V |
| Ground | [N] balls | — | GND |

### 3.2 Critical Signal Descriptions

| Signal Name | Type | Description |
|---|---|---|
| PORESET_N | Input | Power-on reset, active low. Hold ≥ 1 ms after all rails stable. |
| RESET_N | Input | Warm reset, active low. |
| PWRGOOD | Output | Asserts high when all internal regulators are within spec. |
| REFCLK_P/N | Input | 100 MHz differential reference clock for PCIe / UCIe PLLs. |
| TCK | Input | JTAG clock, max 50 MHz. Pull-down 10 kΩ. |

---

## 4. Absolute Maximum Ratings

> **CAUTION:** Exposure beyond these limits may permanently damage the device.

| Parameter | Symbol | Min | Max | Unit |
|---|---|---|---|---|
| Core supply voltage | VDDCORE | −0.3 | 1.2 | V |
| IO supply voltage | VDDIO | −0.3 | 2.2 | V |
| Storage temperature | Tstg | −65 | 150 | °C |
| Junction temperature | TJ | −40 | 130 | °C |
| Input voltage (digital IO) | VIN | −0.3 | VDDIO + 0.3 | V |
| ESD (HBM, any pin) | — | — | ±2000 | V |
| ESD (CDM) | — | — | ±250 | V |
| Latch-up trigger current | — | — | ±100 | mA |

---

## 5. Recommended Operating Conditions

| Parameter | Symbol | Min | Typical | Max | Unit | Notes |
|---|---|---|---|---|---|---|
| Core supply voltage | VDDCORE | 0.68 | 0.72 | 0.76 | V | DVFS range: [0.65, 0.90] V |
| IO supply voltage | VDDIO | 1.71 | 1.80 | 1.89 | V | — |
| UCIe PHY supply | VDD_UCIe | 0.87 | 0.90 | 0.93 | V | — |
| Ambient temperature | TA | 0 | 25 | 85 | °C | Commercial; see ordering info |
| Junction temperature | TJ | — | — | 105 | °C | Throttle at 95 °C |
| Reference clock freq | FREFCLK | 99.99 | 100 | 100.01 | MHz | ±100 ppm |
| Reference clock jitter | — | — | — | 1 | ps RMS | Integrated 12 kHz–20 MHz |

---

## 6. DC Electrical Characteristics

### 6.1 Power Consumption

| Mode | VDDCORE | VDDIO | VDD_UCIe | Total Package | Conditions |
|---|---|---|---|---|---|
| Active (typical) | [XX] A | [XX] A | [XX] A | [XX] W | Typical workload, TJ = 85 °C |
| Active (maximum) | [XX] A | [XX] A | [XX] A | [XX] W | Worst-case workload, TJ = 105 °C |
| Idle (clock gated) | [XX] A | [XX] mA | [XX] mA | [XX] W | All subsystems idle |
| Deep sleep | [XX] mA | [XX] mA | — | [XX] W | DRAMPDN + core power gated |

### 6.2 IO Electrical Specifications (1.8 V LVCMOS)

| Parameter | Symbol | Min | Max | Unit |
|---|---|---|---|---|
| Input high voltage | VIH | 0.65 × VDDIO | — | V |
| Input low voltage | VIL | — | 0.35 × VDDIO | V |
| Output high voltage (IOH = −4 mA) | VOH | 0.80 × VDDIO | — | V |
| Output low voltage (IOL = 4 mA) | VOL | — | 0.20 × VDDIO | V |
| Input leakage | ILI | −10 | 10 | µA |

---

## 7. AC Electrical Characteristics

### 7.1 PCIe Gen5 Interface

| Parameter | Symbol | Min | Typical | Max | Unit |
|---|---|---|---|---|---|
| Data rate | — | — | 32 | — | Gbps/lane |
| TX output voltage swing (differential) | VTX-DIFF-PP | 800 | 1000 | 1200 | mV |
| TX de-emphasis | — | −6 | — | 0 | dB |
| RX sensitivity (differential) | VRX-DIFF-PP-MIN | 15 | — | — | mV |
| Reference clock | FREFCLK | 100 MHz ± 100 ppm |
| Jitter (TX RMS, integrated) | JTXRMS | — | — | 1.0 | ps |

### 7.2 UCIe 2.0 Interface

| Parameter | Min | Typical | Max | Unit |
|---|---|---|---|---|
| UI (unit interval) | — | 50 | — | ps (20 Gbps/lane) |
| TX eye width | 0.55 UI | — | — | UI |
| RX eye width (internal monitor) | 0.50 UI | — | — | UI |
| TX-RX lane-to-lane skew | — | — | 20 | ps |
| D2D latency (protocol flit RTT) | — | — | 10 | ns |
| Aggregate bandwidth (per die pair) | — | — (see product brief) | — | TB/s |

### 7.3 Clock Requirements

| Clock | Frequency | Accuracy | Jitter |
|---|---|---|---|
| REFCLK | 100 MHz | ±100 ppm | < 1 ps RMS |
| CPU core clock (internal PLL) | [XX] GHz | ± 0.01% | < 2 ps RMS |
| UCIe PHY clock | [XX] GHz | — | < 0.5 ps RMS |

---

## 8. Thermal Characteristics

| Parameter | Symbol | Value | Unit | Conditions |
|---|---|---|---|---|
| Junction-to-ambient (natural conv.) | θJA | [XX] | °C/W | JEDEC JESD51-2 |
| Junction-to-case (top) | θJC | [XX] | °C/W | — |
| Junction-to-board | θJB | [XX] | °C/W | — |
| Maximum junction temperature | TJ_MAX | 105 | °C | Throttle triggered at TJ = 95 °C |
| Thermal throttle policy | — | Auto DVFS step-down | — | — |

**Cooling Requirement:** Heat sink with Rθ_HS ≤ [XX] °C/W required at TDP and 25 °C ambient.

---

## 9. Reset and Boot Timing

| Parameter | Symbol | Min | Max | Unit |
|---|---|---|---|---|
| PORESET_N pulse width | tPOR | 1 | — | ms |
| VDD to PORESET_N assertion delay | tVDD_RST | 10 | — | ms |
| PORESET_N release to PWRGOOD | tRST_PG | — | 10 | ms |
| PWRGOOD to first UART output | tPG_UART | — | 500 | ms |
| Cold boot to OS | tCOLD_BOOT | — | [XX] | s |
| Warm reset pulse width | tWRST | 100 | — | µs |

---

## 10. Mechanical Specifications

| Parameter | Value |
|---|---|
| Package type | Flip-Chip Ball Grid Array (FC-BGA) |
| Package size | [N] × [N] mm |
| Ball count | [XXXX] |
| Ball pitch | [X.XX] mm |
| Ball diameter | [X.XX] mm |
| Package height (from board) | [X.XX] mm |
| Package mass | [X.X] g |
| PCB requirement | [N]-layer, min trace/space [X/X] mil |

### 10.1 Package Drawing Reference

See package mechanical drawing: `[PN]-PKG-DWG-vX.X.pdf`

---

## 11. Reliability Specifications

| Test | Standard | Condition | Qualification Level |
|---|---|---|---|
| HTOL | JEDEC JESD22-A108 | 125 °C, 1000 h | Grade 1 |
| LTOL | JEDEC JESD22-A119 | −40 °C, 1000 h | Grade 1 |
| Temperature cycling | JEDEC JESD22-A104 | −40 to 125 °C, 1000 cycles | Grade 1 |
| Moisture sensitivity | JEDEC J-STD-020 | MSL 3 | — |
| Drop test | JEDEC JESD22-B111 | — | Consumer only |
| MTTF target | — | > 10^6 hours @ 70 °C | — |

---

## 12. Regulatory & Environmental Compliance

| Regulation | Status |
|---|---|
| RoHS 3 (EU 2015/863) | Compliant |
| REACH | Compliant |
| WEEE | Compliant |
| TSCA | Compliant |
| Conflict Minerals (Dodd-Frank) | Compliant |
| FCC Part 15 Class B | [Pending / Compliant] |
| CE (EU declaration) | [Pending / Compliant] |

---

## 13. Register Map Summary

Detailed register description: DOC-D3-01-MAS Appendix, IP-XACT bundle DOC-D3-02-IPXACT.

| Block | Base Address | Size | Access |
|---|---|---|---|
| CHIP_ID / Version | 0x0000_0000 | 4 KB | RO |
| Clock / PLL control | 0x0000_1000 | 4 KB | RW |
| Power management | 0x0000_2000 | 4 KB | RW |
| UCIe PHY control | 0x0010_0000 | 64 KB | RW |
| PCIe config space | 0x0100_0000 | 4 MB | RW |
| Security / HRoT | 0x8000_0000 | 4 MB | Secure access only |

---

## 14. Known Limitations / Errata Summary

> Refer to current errata document DOC-D9-02-ERRATA for complete list.

| Errata ID | Brief Description | Affected Versions | Workaround |
|---|---|---|---|
| ERR-001 | [Summary] | A0 only | Yes — see DOC-D9-02-ERRATA |
| ERR-002 | [Summary] | A0, A1 | Firmware patch |

---

## Appendix A — Glossary

| Term | Definition |
|---|---|
| HRoT | Hardware Root of Trust |
| DVFS | Dynamic Voltage and Frequency Scaling |
| TDP | Thermal Design Power |
| FC-BGA | Flip-Chip Ball Grid Array |
| MSL | Moisture Sensitivity Level |
| MTTF | Mean Time to Failure |
| UI | Unit Interval |

---

## Appendix B — Related Documents

| Doc ID | Title |
|---|---|
| DOC-D1-01-PRD | Product Requirements Document |
| DOC-D3-01-MAS | Module Architecture Spec (register details) |
| DOC-D3-02-IPXACT | IP-XACT metadata bundle |
| DOC-D4-01-PKG | Package Design Spec |
| DOC-D4-02-THERM | Thermal Management Spec |
| DOC-D9-02-ERRATA | Errata Document |
| DOC-D9-03-COMPLY | Compliance Matrix |

---

*This document is subject to change without notice. Always refer to the latest revision on the product portal.*
