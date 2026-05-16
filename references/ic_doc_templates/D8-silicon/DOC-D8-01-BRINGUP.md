---
doc-id: DOC-D8-01-BRINGUP
title: Silicon Bring-up & Post-Silicon Validation Plan
domain: D8-silicon
version: 0.1
status: draft
parent: DOC-D6-01-VPLAN
generated: 2026-04-24T06:15:00+08:00
---

# DOC-D8-01-BRINGUP — Silicon Bring-up & Post-Silicon Validation Plan

## Document Control

| Field | Value |
|---|---|
| Document ID | DOC-D8-01-BRINGUP |
| Version | 0.1 |
| Classification | CONFIDENTIAL |
| Authors | Silicon Validation Lead, Bring-up Eng |
| Reviewers | SoC Arch, DFT Lead, SW Arch, Reliability |
| Approvers | VP Silicon Engineering |

### Revision History

| Ver | Date | Author | Description |
|---|---|---|---|
| 0.1 | YYYY-MM-DD | — | Initial draft |
| 1.0 | YYYY-MM-DD | — | Baseline for A0 silicon |

---

## 1. Purpose & Scope

本文档定义 Chiplet SoC 从首片回板（First Silicon） 到量产 ready（Production Qualification，PQ） 的全流程验证计划，包括：
- 带电程序（Power-on sequence）
- 功能基本验证（Boot / hello-world）
- Multi-die 互联验证
- 性能基准测试（Benchmark）
- 硅特性测量（Silicon characterization）
- 硅蚀刻缺陷排查（Silicon bug triage）
- 量产测试相关性验证（ATE correlation）

不覆盖：前仿真闭合（pre-silicon sign-off）、量产 ATE 流程（见 DOC-D5-02-KGD）。

---

## 2. Silicon Revision Plan

| Rev | Fab Node | Package | Purpose | Expected Date |
|---|---|---|---|---|
| A0 | TSMC 3nm-class | Engineering sample (ES) | First metal, full function exploration | YYYY-MM |
| A1 | — | ES | Bug fixes from A0 triage | YYYY-MM |
| B0 | — | Pre-production | Performance characterization, ATE correlation | YYYY-MM |
| B1 | — | Pre-production | Final spec confirmation | YYYY-MM |
| C0 / MP | — | Production | Mass production | YYYY-MM |

---

## 3. Bring-up Infrastructure

### 3.1 Lab Equipment BOM

| Equipment | Model / Spec | Purpose |
|---|---|---|
| Power supply | Keysight E36312A × 4 | Multi-rail VDD supply |
| Oscilloscope | Keysight MSOX6004A (20 GHz) | Signal integrity, boot debug |
| Logic analyzer | Saleae Logic Pro 16 | Low-speed bus capture |
| Protocol analyzer | Teledyne LeCroy Summit Z3-16 (PCIe/UCIe) | Link-layer capture |
| Network analyzer | Keysight E5063A (ENA) | S-parameter, impedance |
| Current probe | Tektronix TCPA300 | Per-rail current measurement |
| Thermal camera | FLIR E96 | Die thermal map |
| EMI scanner | SIGLENT SSA3032X + near-field probe | EMI hotspot scan |
| JTAG debugger | Arm DSTREAM-PT | Debug / trace |
| Boundary scan | Corelis ScanExpress | Board-level test |

### 3.2 Bring-up Board Specifications

| Parameter | Spec |
|---|---|
| Form factor | Custom ATX-compatible bench board |
| VDD rails | VDDCORE (0.7 V, 20 A), VDDIO (1.8 V, 5 A), VDD_UCIe (0.9 V, 3 A), VDDPLL (1.2 V, 1 A) |
| Power sequencer | Programmable (I2C-controlled) |
| Clock source | External reference clock input (100 MHz, LVDS) + on-board TCXO |
| Debug connectors | JTAG 20-pin, UART 3.3 V TTL, SWD |
| Test points | 1 TP per VDD rail, all major buses |
| Die thermal | TIM + thermocouple on each die |

### 3.3 Software / Toolchain

| Tool | Version | Purpose |
|---|---|---|
| OpenOCD | ≥ 0.12 | JTAG debug server |
| GDB / arm-none-eabi | ≥ 13 | Debug client |
| Python bringup scripts | Internal | Power-on automation, register scripting |
| UART terminal | minicom / pyserial | Boot log capture |
| SCL (Signal Capture Library) | Internal | Waveform analysis |
| Silicon validation database (SVDB) | Internal | Bug tracking, test result logging |

---

## 4. Phase 1: Power-On & Basic Health (A0, Week 1–2)

### 4.1 Pre-Power Checklist

- [ ] Board visual inspection (solder joint, missing components)
- [ ] DUT continuity test (open/short per rail, no cross-talk)
- [ ] VDD rail isolation verify (all rails float before enable)
- [ ] Current limit set: VDDCORE ≤ 25 A, others per spec
- [ ] JTAG connectivity test (no DUT power, TDI→TDO chain)
- [ ] Serial port connectivity (loopback test)

### 4.2 Power-On Sequence

```
Step 1: Enable VDDPLL (1.2 V) → wait 1 ms
Step 2: Enable VDDIO (1.8 V) → wait 1 ms
Step 3: Enable VDD_UCIe (0.9 V) → wait 1 ms
Step 4: Enable VDDCORE (0.7 V ramp, 1 ms rise time) → wait 5 ms
Step 5: De-assert RESET_N (active low, 10 ms hold)
Step 6: Assert PORESET_N (hard reset release)
Step 7: Monitor UART for boot ROM messages (timeout: 500 ms)
Step 8: Monitor PWRGOOD output = 1

FAIL criteria:
  - Any rail deviation > ±5% from target
  - VDDCORE inrush > 30 A (peak)
  - No UART output within 500 ms
  - PWRGOOD = 0 after step 8
```

### 4.3 Basic Functionality Tests

| Test ID | Test | Pass Criteria | Tool |
|---|---|---|---|
| BU-001 | Boot ROM execution | UART "Boot ROM v1.x" message | UART |
| BU-002 | PLL lock | LOCK output = 1, CLK_OUT within ±50 ppm | Scope |
| BU-003 | JTAG halt | GDB attach, CPU halted at boot ROM | JTAG/GDB |
| BU-004 | Register read/write | CHIP_ID register matches golden | GDB |
| BU-005 | SRAM R/W | 0xAA55 pattern at all SRAM banks | GDB |
| BU-006 | Interrupt controller | Timer IRQ fires at 1 kHz, counts correctly | JTAG/GDB |
| BU-007 | UART loopback | 115200 baud, 0% BER over 1 MB | UART |
| BU-008 | I2C bus | Scan → all expected devices respond | Python |
| BU-009 | SPI flash | Read JEDEC ID, page read/write | Python |

---

## 5. Phase 2: Multi-Die Bring-up (A0, Week 2–4)

### 5.1 Die-to-Die (D2D) UCIe Link Bring-up

```
Step 1: Initialize Host Die (HD) alone (satellite dies in reset)
Step 2: Enable UCIe PHY on HD side
         - UCIe_PHY_CTRL.RESET_N = 1
         - Verify PHY_STATUS.READY = 1
Step 3: Release Satellite Die 0 (SD0) from reset
Step 4: Monitor UCIe LTSM state machine on HD:
         RESET → ACTIVE (nominal path)
         Timeout per state: 100 ms
Step 5: Verify LTSM.STATE == ACTIVE on both HD and SD0
Step 6: Run UCIe loopback test (flit layer)
Step 7: Repeat steps 3–6 for each satellite die
Step 8: Verify multi-die system boot to OS

State transition debug (if LTSM stalls):
  - Capture LTSM_STATE CSR at 1 ms intervals
  - Capture PHY eye diagram for all lanes
  - Check reference clock distribution (freq, jitter)
```

### 5.2 D2D Electrical Validation

| Measurement | Method | Acceptance Spec |
|---|---|---|
| Eye diagram (TX) | Scope at die TX bump | Eye width > 0.6 UI, height > 50 mV |
| Eye diagram (RX) | UCIe internal eye monitor | Eye width > 0.5 UI, height > 40 mV |
| Bit error rate | PRBS-31, 10^12 bits | BER < 10^-15 (after FEC) |
| Jitter (TJ) | Scope / BERT | TJ < 0.3 UI (peak-to-peak) |
| Lane skew | Time interval measurement | Skew < 10 ps within lane group |
| Insertion loss | VNA S21 | < -3 dB at Nyquist |

### 5.3 Multi-Die Coherence Validation

| Test | Scenario | Pass Criteria |
|---|---|---|
| Cache coherence | Producer-consumer cross-die | Data matches, no stale read |
| Atomic operation | Cross-die lock/unlock (LDAXR/STLXR) | Lock acquired exactly once |
| Memory ordering | Litmus test suite (LKMM) | All ordering guarantees maintained |
| Interrupt routing | Cross-die interrupt storm | No dropped interrupts over 10^6 events |

---

## 6. Phase 3: Functional Validation (A0/A1, Week 4–12)

### 6.1 Subsystem Validation Matrix

| Subsystem | Test Method | Coverage Target | Owner |
|---|---|---|---|
| CPU cluster | SPEC CPU 2017 subset, microarch tests | Functional 100% | CPU Val |
| Memory controller | Memory bandwidth, latency, ECC inject | 95% | Memory Val |
| UCIe PHY/Link | Protocol compliance suite, interop | Per UCIe 2.0 spec | IO Val |
| PCIe | PCIe CTS (Compliance Test Suite), gen4 | Gen4 full spec | IO Val |
| Ethernet | RFC 2544 throughput / latency | Wire-rate 100 GbE | Net Val |
| Security (HRoT) | Secure boot, DICE chain, crypto vectors | FIPS vectors 100% | Security Val |
| Thermal sensors | Sensor accuracy vs. reference thermocouple | ±3 °C accuracy | Thermal Val |
| Power management | Idle → active transitions, DVFS | All P-states functional | PM Val |

### 6.2 Firmware / Software Stack Bring-up

| Layer | Test | Pass Criteria |
|---|---|---|
| BL1 (boot ROM) | UART message + JTAG halt | Correct build string |
| BL2 (TF-A) | Trusted firmware version in UART | Correct hash |
| BL31 (EL3 runtime) | PSCI calls (SYSTEM_SUSPEND, CPU_ON) | PSCI_SUCCESS |
| BL32 (OP-TEE) | TA loading, crypto TA test vectors | Pass |
| UEFI | UEFI shell prompt, ACPI tables load | No BSOD |
| Linux kernel | Boot to bash, all drivers probe | No crash, no OOPS |
| Userspace | Target application run to completion | Correct output |

### 6.3 Silicon Bug Triage Process

```
Bug Discovery
     │
     ▼
Open SVDB ticket (severity: S1/S2/S3/S4)
     │
     ▼
Root cause investigation
  ├─ Pre-silicon simulation repro?
  │    Yes → likely logic bug → RTL fix
  │    No  → silicon-only issue → analog/physical analysis
     │
     ▼
Classification:
  [A] Functional silicon bug → RTL ECO / metal fix
  [B] Electrical / timing marginal → process / design fix
  [C] SW/FW workaround available → errata + workaround
  [D] Test coverage gap → new pre-silicon test
     │
     ▼
Fix decision:
  S1/S2 → must fix before next rev tape-out
  S3    → fix if mask-saving ECO available; else errata
  S4    → errata + SW workaround
```

---

## 7. Phase 4: Performance Characterization (B0, Week 12–20)

### 7.1 Performance Targets

| KPI | Target | Measurement Method |
|---|---|---|
| D2D aggregate bandwidth | ≥ 2 TB/s (per die pair) | UCIe bandwidth test |
| D2D latency (flit RTT) | ≤ 5 ns | HW timestamp counter |
| CPU SPEC_INT_Rate 2017 | ≥ [XX] | SPEC benchmark |
| Memory bandwidth | ≥ [XX] GB/s | Stream benchmark |
| Idle power | ≤ [XX] W | Current measurement |
| Max TDP | ≤ [XX] W | Stress workload |
| Startup time | ≤ [XX] s (cold boot to app) | UART timestamp |

### 7.2 Silicon Characterization Plan

| Characterization | Conditions | Sample Size |
|---|---|---|
| Fmax vs VDD vs Temperature | VDD ± 10%, T = -40/25/85/125 °C | 30 lots × 3 corners |
| Leakage current | VDD nominal, T = 25/85/125 °C | Same sample set |
| DVFS accuracy | Vmin per frequency point | 15 samples per corner |
| PVT sensor calibration | Vs. external reference | All dies in lot |
| Timing margin (STA correlation) | Per path group | Worst 5 critical paths |

### 7.3 Stress & Reliability Screening

| Test | Condition | Duration | Pass Criteria |
|---|---|---|---|
| HTOL (High Temp Operating Life) | 125 °C, max VDD, full workload | 1000 hours | 0 failures / 231 samples |
| LTOL (Low Temp) | -40 °C, nominal VDD, idle | 1000 hours | 0 failures |
| Power cycling | 1000 cycles 0→TDP | — | No degradation |
| ESD / Latch-up | HBM 2 kV, CDM 250 V | — | No damage |
| Electromigration | 10× rated current, 150 °C | — | MTTF > 10 years |

---

## 8. Phase 5: ATE Correlation (B0/B1, Week 18–24)

### 8.1 Correlation Goals

Ensure final ATE production test program:
1. Covers all functional failures observed in silicon validation
2. Achieves ≤ 1% over-kill rate (good parts called bad)
3. Achieves 0% under-kill rate (bad parts called good) for S1/S2 defects
4. Test time ≤ [XX] s per die at production throughput

### 8.2 Correlation Procedure

```
Step 1: Run characterization sample through silicon validation (SV) tests
Step 2: Run same sample through ATE program (candidate revision)
Step 3: Build Inking / Shmoo correlation table:
  ┌─────────────────────┬──────────┬──────────┐
  │                     │ ATE PASS │ ATE FAIL │
  ├─────────────────────┼──────────┼──────────┤
  │ SV PASS (good part) │   TP     │   FP     │  FP → over-kill
  │ SV FAIL (bad part)  │   FN     │   TN     │  FN → under-kill
  └─────────────────────┴──────────┴──────────┘
Step 4: Investigate FP and FN cases:
  FP: tighten ATE limits or add guard-band
  FN: add missing test coverage in ATE program
Step 5: Iterate until ATE metrics meet goals
Step 6: Freeze ATE program → production release
```

### 8.3 Shmoo Coverage Matrix

| Parameter | SV Shmoo | ATE Guard-band | Notes |
|---|---|---|---|
| VDDCORE Vmin @ Fmax | Measured per temp | SV_Vmin + 30 mV | Process spread |
| VDDCORE Vmax | Measured | SV_Vmax − 30 mV | Reliability |
| Fmax @ nominal VDD | Measured per corner | SV_Fmax − 100 MHz | Guard-band |
| UCIe BER | Measured (PRBS) | < 10^-12 (ATE limit) | FEC margin |

---

## 9. Bring-up Milestones & Exit Criteria

| Milestone | Phase | Exit Criteria |
|---|---|---|
| A0 Power-on | Phase 1 | All BU-00x tests pass |
| A0 D2D link up | Phase 2 | LTSM ACTIVE on all die pairs |
| A0 Functional complete | Phase 3 | No open S1/S2 bugs; S3 workaround documented |
| A1 Tape-out approval | — | All A0 S1/S2 bugs have confirmed RTL fix |
| B0 Performance sign-off | Phase 4 | All KPIs ≥ target at all PVT corners |
| B0 ATE correlation | Phase 5 | Over-kill ≤ 1%, under-kill = 0% |
| PQ (Production Qualification) | — | HTOL/LTOL pass + ATE correlation pass |

---

## 10. Issue Tracking

All silicon bugs tracked in SVDB (Silicon Validation Database).

| Severity | Definition | SLA |
|---|---|---|
| S1 | Chip is non-functional / no workaround | Fix in next rev |
| S2 | Major feature broken / SW workaround | Fix in next rev |
| S3 | Performance regression or workaround needed | Fix if possible; else errata |
| S4 | Minor deviation from spec | Errata + workaround |

Weekly bug review with SoC owners. S1/S2 bugs escalated to VP within 24 h.

---

## Appendix A — Glossary

| Term | Definition |
|---|---|
| ES | Engineering Sample |
| MP | Mass Production |
| PQ | Production Qualification |
| SVDB | Silicon Validation Database |
| HTOL | High Temperature Operating Life |
| LTOL | Low Temperature Operating Life |
| DVFS | Dynamic Voltage and Frequency Scaling |
| BER | Bit Error Rate |
| PRBS | Pseudorandom Binary Sequence |
| VNA | Vector Network Analyzer |
| BERT | Bit Error Rate Tester |
| TIM | Thermal Interface Material |

---

## Appendix B — Related Documents

| Doc ID | Title | Relationship |
|---|---|---|
| DOC-D5-01-DFT | DFT Plan | ATE test pattern source |
| DOC-D5-02-KGD | KGD Test Plan | Pre-assembly die qualification |
| DOC-D6-01-VPLAN | Verification Plan | Pre-silicon coverage baseline |
| DOC-D6-02-MDBOOT | Multi-Die Boot Spec | Boot sequence reference |
| DOC-D7-01-SEC | Security Architecture | Security validation procedures |
| DOC-D2-01-ARCH | System Architecture Spec | Performance targets source |
| DOC-D4-02-THERM | Thermal Management Spec | Thermal test limits |
| DOC-D9-02-ERRATA | Errata Document | Silicon bug workarounds |
