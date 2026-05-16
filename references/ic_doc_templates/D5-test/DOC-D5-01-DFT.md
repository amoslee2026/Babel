---
doc_id: DOC-D5-01-DFT
doc_type: DFT
title: Design-for-Test (DFT) Plan
version: 0.1-template
status: template
tier: 0
domain: Test
owner: DFT Lead
approvers: [Chief Architect, Test Engineering Lead]
parent: [DOC-D2-01-ARCH, DOC-D3-01-MAS]
children: [DOC-D5-02-KGD, DOC-D6-01-VPLAN, DOC-D8-01-BRINGUP]
references: [IEEE 1149.1 (JTAG), IEEE 1149.6 (AC Boundary Scan), IEEE 1687 (IJTAG), IEEE 1838 (3D-SIC Die Wrapper), IEEE 1500]
generated: 2026-04-23T22:45:00+08:00
---

# DFT Plan — {{ Product Name }}

## 0. Document Control
| Version | Date | Author | Change |
|---|---|---|---|
| 0.1 | YYYY-MM-DD | {{ DFT Lead }} | Initial |

**Freeze Point**: RTL v1.0 + DFT insertion.

---

## 1. Purpose

规定 chiplet 系统的 DFT 插入策略，覆盖 structural test、BIST、boundary scan、3D die wrapper、测试访问机制，确保生产测试覆盖率目标达成并支撑 KGD 与 post-silicon bring-up。

## 2. DFT Strategy Overview

| Technique | Scope | Coverage Target |
|---|---|---|
| Scan + ATPG | All logic per die | ≥ 99% stuck-at, ≥ 95% transition |
| MBIST | All on-die SRAM / registers | 100% |
| LBIST | Logic self-test (safety product) | ≥ 95% |
| Boundary Scan (JTAG 1149.1) | I/O pins | 100% |
| IJTAG (IEEE 1687) | Embedded instruments (PLL/PHY/sensors) | Discovery + access |
| 3D Die Wrapper (IEEE 1838) | All die, pre-assembly test | 100% isolation |
| UCIe Lane Margining | UCIe PHY | Per lane calibration |

## 3. Test Access Architecture

```
Host Tester ──► JTAG pin on BGA
                     │
                     ▼
                 Top TAP (IOD)
                 │
         ┌───────┴──────────────┐
         │                      │
         ▼                      ▼
    Die Wrapper (IEEE 1838)    Sideband (UCIe UDA)
         │
   ┌─────┼─────┬──────┐
   ▼     ▼     ▼      ▼
  CCD0  CCD1  CCD2   MEMD (passthrough)
  TAP   TAP   TAP
   │
   ▼
  IJTAG Network (internal)
   ├── SCAN chains
   ├── MBIST controllers
   ├── Thermal sensors
   ├── PLL/PHY instruments
   └── Lane margin controllers
```

## 4. Per-Die Scan Architecture

### 4.1 Scan Chains
- Chain count: {{ 256 }} per CCD, {{ 128 }} per IOD
- Max chain length: {{ 500 flops }} for at-speed test
- Scan compression: {{ 100× }} (EDT / STM)
- Scan clock source: dedicated `clk_scan`

### 4.2 Scan Test Modes
- Stuck-at (slow clock)
- Transition delay (at-speed, launch-on-capture)
- Path delay (timing-critical paths)
- Cell-aware (for cells with internal defect models)

## 5. MBIST (Memory BIST)

| Memory | Algorithm | March test | Coverage |
|---|---|---|---|
| L1 I/D | March C+ | Yes | 100% |
| L2 | March SS | Yes | 100% |
| L3 (LLC) | March SR+ | Yes | 100% |
| Register files | March C- | Yes | 100% |

## 6. BISR (Built-In Self-Repair)
- Row/column redundancy for L3 and HBM 控制器缓冲区
- Fuse-based repair map
- Self-test + repair @ cold boot

## 7. Chiplet-Specific DFT

### 7.1 Die Wrapper (IEEE 1838)
Each die has 1838-compliant wrapper providing:
- **Die-level test access** pre-assembly (wafer sort + KGD)
- **Inter-die test** post-assembly (TSV/micro-bump connectivity)
- **Isolation mode** for system bring-up debug

Mandatory 1838 registers:
- SC_WIR (Wrapper Instruction Register)
- SC_WBR (Wrapper Bypass Register)
- SC_WCDR (Wrapper Core Data Register)
- ST_WBY (Test bypass)

### 7.2 UCIe Compliance DFT
- Lane margining per UCIe §10
- Retry path observation
- LTSM state machine probing via sideband

### 7.3 Inter-Die Test
Post-assembly connectivity test:
- Each micro-bump tested via boundary-scan-like pattern
- TSV continuity + leakage
- Crosstalk to adjacent lanes

### 7.4 Power & Thermal Instruments
- Thermal diodes: IJTAG-accessible
- VR sensors: IJTAG-accessible
- On-chip voltage monitors (OCV)

## 8. Production Test Flow

```
Wafer (post fab) ──► Wafer Sort (WS) ──► Structural + Parametric
                                            │ pass
                                            ▼
                                      Dicing
                                            │
                                            ▼
                                      KGD Burn-in (→ DOC-D5-02)
                                            │
                                            ▼
                                      Assembly (2.5D/3D)
                                            │
                                            ▼
                                      Post-assembly test (1838 + boundary scan)
                                            │
                                            ▼
                                      Final Test (FT)
                                            │
                                            ▼
                                      System-Level Test (SLT)
                                            │
                                            ▼
                                      Pack & Ship
```

## 9. Tester Platform
- WS: {{ Advantest V93000 / Teradyne J750 }}
- FT: {{ Advantest T6391 / Teradyne UltraFLEX }}
- SLT: Custom platform matching real system

## 10. Test Program Structure
- Config: IP-XACT → test program generator (Cadence / Synopsys)
- Regression: per silicon revision
- Data logging: YieldHUB / exensio

## 11. Quality Checklist

- [ ] 每 die 达到 ≥ 99% stuck-at coverage
- [ ] Scan chain 长度 ≤ 500 flop（至速度测试约束）
- [ ] MBIST 覆盖所有 on-die 存储 100%
- [ ] Boundary scan 覆盖所有 I/O 100%
- [ ] IEEE 1838 wrapper 在每 die 上实现
- [ ] UCIe lane margining 在 PHY 中实现
- [ ] Thermal + voltage 传感器 IJTAG 可访问
- [ ] 3D inter-die test 策略定义
- [ ] Test program 生成流程自动化
- [ ] 与 KGD plan (D5-02) 一致
- [ ] 与 bring-up plan (D8-01) 的 debug hooks 对齐

## 12. References
- IEEE 1149.1-2013 (JTAG)
- IEEE 1149.6 (AC Boundary Scan)
- IEEE 1687-2014 (IJTAG)
- IEEE 1838-2019 (Die Wrapper for 3D-SIC Test)
- IEEE 1500 (Embedded Core Test)
- UCIe 2.0 §10 (Lane Margining)
