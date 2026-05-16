---
doc_id: DOC-D6-02-MDBOOT
doc_type: MDBOOT
title: Multi-Die Boot & Reset Sequence Specification
version: 0.1-template
status: template
tier: 1
domain: Verification
owner: System Integration Architect
approvers: [Chief Architect, SW Architect, Verification Lead]
parent: [DOC-D2-01-ARCH, DOC-D2-04-SWARCH]
children: [DOC-D6-01-VPLAN, DOC-D8-01-BRINGUP]
references: [UCIe 2.0 LTSM, Arm PSCI, ACPI OSPM]
generated: 2026-04-23T22:45:00+08:00
---

# Multi-Die Boot & Reset Sequence — {{ Product Name }}

## 0. Document Control
| Version | Date | Author | Change |
|---|---|---|---|
| 0.1 | YYYY-MM-DD | {{ Integration Arch }} | Initial |

---

## 1. Purpose

定义多 die chiplet SoC 的 cold boot、warm reset、per-die reset、D2D link retrain、fault containment during bring-up 序列。**任何 die 的偏离此序列都可能导致整芯片无法启动或产生静默错误。**

## 2. Reset Classes

| Reset | Scope | Triggered by |
|---|---|---|
| Cold Reset (global) | All dies | PERST# from host / power cycle |
| Warm Reset | Compute state only, D2D links preserved | Software write to CSR |
| Die Reset | Individual die | IOD PMU command |
| UCIe Link Reset | Single UCIe module | LTSM |
| Functional Reset | Internal block | IP controller |

## 3. Cold Boot Sequence

```
T=0: Power applied
├── VDD_AO rails stabilize (≤ 10 ms)
├── VREF, VDDQ stabilize
│
T=t1: PERST# deasserted (by host/BMC)
├── Clock oscillators start
├── clk_mgmt PLL lock (≤ 100 μs)
│
T=t2: IOD PMU boots (from on-die ROM)
├── BL1 loads from SPI-NOR
├── BL1 verifies secure boot signature
├── BL1 brings up VDD_IO, VDD_MEM
│
T=t3: HBM training
├── HBM controller configured
├── Per-channel DDR training (read/write eye)
├── HBM ready flag set
│
T=t4: UCIe link training (all modules in parallel)
├── LTSM: RESET → DETECT → TRAINING → L0
├── Lane deskew, CRC alignment
├── Credit exchange
├── Target: ≤ 1 ms per module
│
T=t5: CCD power-up (sequential or parallel)
├── IOD asserts CCD reset
├── VDD_CORE per CCD enabled
├── CCD PLL lock
├── CCD reset deasserted
├── CCD boot ROM executes, handshakes with IOD over UCIe
│
T=t6: System ready
├── All dies ready flag set
├── IOD notifies host via PCIe (link up + BAR enabled)
├── Host reads CAP registers, loads full FW/OS
```

Target total cold boot time: ≤ **100 ms** from PERST# deassert.

## 4. Warm Reset Sequence

Preserves D2D link state, HBM training, telemetry; resets compute caches and state.

```
1. Software writes CTRL.WARM_RESET = 1 (on each CCD)
2. CCD flushes cache, pipelines, in-flight AXI
3. Handshake with IOD: "ready for warm reset"
4. IOD acknowledges → CCD asserts local reset
5. CCD boot ROM re-execute (skip HBM training, D2D training)
6. CCD resumes operation
```

Target: ≤ **10 ms**.

## 5. Per-Die Reset (Hot Swap / Fault Recovery)

```
1. Fault detected on CCD X (corrected or uncorrected)
2. IOD quiesces traffic to CCD X
3. IOD flushes directory entries cached on CCD X
4. IOD asserts die-level reset to CCD X
5. CCD X re-trains its local UCIe module (LTSM to L0)
6. CCD X boot ROM; join fabric
7. IOD re-enables traffic
```

## 6. UCIe Link Retrain

```
1. LTSM detects persistent error (retry exhausted / lane fail)
2. LTSM transitions to RETRAIN
3. Pause upstream traffic (credit = 0)
4. Re-training sequence (lane deskew, CRC align)
5. On success → L0; on fail → LINK_DOWN + IRQ
6. Firmware: log event, attempt degraded-mode (lane degrade)
```

## 7. Fault Containment During Bring-up

- A failing die should **not** prevent others from booting
- Escalation rules:
  - If CCD boot fails (3 retries) → IOD reports to host; other CCDs continue
  - If IOD fails → entire package cannot boot (IOD is critical)
  - If HBM stack fails training → downgrade capacity; report to host

## 8. Dependency Graph

```
PERST# deassert ──► VDD_AO ──► clk_mgmt ──► IOD PMU boot
                                                │
                                                ├──► VDD_IO / VDD_MEM
                                                │        │
                                                │        └──► HBM training
                                                │
                                                ├──► UCIe training (parallel modules)
                                                │
                                                └──► CCD reset release (after UCIe L0)
                                                         │
                                                         └──► CCD boot → ready
```

## 9. Timing Budget

| Phase | Budget | Max |
|---|---|---|
| Power good → IOD boot | 10 ms | 20 |
| IOD boot → HBM training start | 5 ms | 10 |
| HBM training | 30 ms | 50 |
| UCIe training (all modules parallel) | 1 ms | 5 |
| CCD boot | 20 ms | 40 |
| Total | **66 ms** | **≤ 100** |

## 10. Error Scenarios & Recovery

| Scenario | Detection | Recovery |
|---|---|---|
| UCIe training timeout | LTSM watchdog | Re-try (3×); if fail, mark module dead, continue with degraded D2D |
| HBM training fail | HBM controller status | Re-try; if fail on specific channel, disable that channel (capacity impact) |
| CCD boot timeout | IOD watchdog | Reset CCD; if 3 failures, disable die |
| Secure boot signature fail | BL1 | Halt + error log, no execution allowed |

## 11. Verification

| Scenario | Method | Link to VPlan testpoint |
|---|---|---|
| Clean cold boot | Sim + emulation | TP_BOOT_COLD_01 |
| UCIe training stress | Sim with error injection | TP_BOOT_UCIE_RETRY_01 |
| HBM channel fail | Sim with fault injection | TP_BOOT_HBM_DEGRADE_01 |
| Per-die hot swap | Emulation | TP_RESET_DIE_HOTSWAP_01 |
| Warm reset | Sim | TP_RESET_WARM_01 |

## 12. Quality Checklist

- [ ] 每类 reset 都有明确定义 scope
- [ ] Cold boot 时间预算合理且可测量
- [ ] 依赖关系图无循环 / race
- [ ] Fault containment 策略定义
- [ ] 每个阶段有 timeout watchdog
- [ ] 错误场景全枚举 + 恢复策略
- [ ] 验证 testpoint 已创建
- [ ] Post-silicon debug hooks 已保留（→ DOC-D8-01-BRINGUP）
- [ ] 与 SW Arch (DOC-D2-04) 同步

## 13. References
- UCIe 2.0 §5 (Link Layer, LTSM)
- Arm PSCI v1.1
- ACPI Specification (OSPM)
