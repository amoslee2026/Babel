---
doc_id: DOC-D6-01-VPLAN
doc_type: VPLAN
title: Verification Plan (Chiplet SoC)
version: 0.1-template
status: template
tier: 0
domain: Verification
owner: Verification Lead
approvers: [Chief Architect, IP Owners, Design Lead]
parent: [DOC-D2-01-ARCH, DOC-D3-01-MAS, DOC-D2-05-DIC]
children: [DOC-D8-01-BRINGUP]
references: [Accellera UVM 1.2, IEEE 1800, IEEE 1801 (UPF), UCIe 2.0 Compliance, Cadence vManager, Synopsys Verdi Planner]
generated: 2026-04-23T22:45:00+08:00
---

# Verification Plan — {{ Product Name }}

## 0. Document Control
| Version | Date | Author | Change |
|---|---|---|---|
| 0.1 | YYYY-MM-DD | {{ V-Lead }} | Initial |

**Sign-off Gate**: Tape-out Readiness Review.

---

## 1. Scope & Goals

- **DUT**: {{ Full SoC + per-block IP }}
- **Scope**: block-level, subsystem, chip-level, system-level, post-silicon readiness
- **Goals**:
  1. 所有 PRD/ARCH/MAS/DIC 需求的可验证性闭环
  2. Coverage 目标达标（见 §8）
  3. Bug 曲线平台 ≥ 2 周无新 bug
  4. UCIe D2D compliance 100%
  5. 3rd-party chiplet interop 通过

## 2. Methodology & Languages

- **Methodology**: Accellera UVM 1.2
- **Languages**: SystemVerilog (IEEE 1800-2017/2024), UPF (IEEE 1801-2024), SVA
- **Coverage**: functional + code + assertion + toggle
- **Reference model**: SystemC TLM + Golden RTL

## 3. Testbench Architecture

```
                      ┌─────────────────────────┐
                      │    UVM Test (top)       │
                      └──────────┬──────────────┘
                                 │
            ┌────────────────────┼────────────────────┐
            ▼                    ▼                    ▼
       ┌─────────┐         ┌─────────┐          ┌─────────┐
       │ AXI Agent│        │UCIe VIP │          │ CXL VIP │
       └─────────┘         └─────────┘          └─────────┘
                                 │
                          ┌──────▼──────┐
                          │ Scoreboard  │◄── Reference Model
                          └──────┬──────┘
                                 │
                          ┌──────▼──────┐
                          │   DUT RTL   │
                          └─────────────┘
```

## 4. Verification Hierarchy

| Level | Scope | Testbench | Method |
|---|---|---|---|
| Block | Single IP | Block UVM TB | Sim + Formal |
| Subsystem | 2-3 integrated IPs | Subsystem TB | Sim |
| Die | Single die (CCD / IOD) | Die UVM TB | Sim + Emulation |
| Chip | Full multi-die package (RTL) | SoC TB | Emulation + FPGA |
| System | SoC + firmware + OS | Platform | FPGA + Post-silicon |

## 5. Testpoint List (Sample Template)

每条 testpoint 采用以下格式（需覆盖 PRD + ARCH + MAS + DIC 的每条条款）：

| ID | Feature | Description | Verif Type | Coverage Method | Owner | Status | Test Cases | Expected Cov | Completed |
|---|---|---|---|---|---|---|---|---|---|
| TP_D2D_LINK_UP_01 | UCIe LTSM | Link comes up after reset | Sim | Functional + Assertion | alice@ | In-Prog | tc_link_up_001-010 | 100% func | - |
| TP_D2D_RETRY_01 | UCIe retry | Retry on single-bit CRC fail | Sim | Functional | bob@ | Ready | tc_retry_001-005 | 100% func | - |
| TP_D2D_MARGIN_01 | UCIe lane margin | Per-lane margin calibration | Formal + Post-Si | Assertion + BER test | carol@ | Draft | — | proof | - |
| TP_MEM_COHERENCE_01 | Cross-die coherence | MESI transitions across CCDs | Sim | Functional + Cross | dave@ | Ready | ... | ... | - |

**完整 testpoint list** 维护在 vManager / Verdi Planner 工具中，本文件仅列 template。

## 6. Coverage Model

### 6.1 Functional Coverage
```systemverilog
covergroup cg_d2d_ltsm @(posedge clk);
  cp_state: coverpoint ltsm_state {
    bins detect = {DETECT};
    bins training = {TRAINING};
    bins l0 = {L0};
    bins retrain = {RETRAIN};
  }
  cp_transition: coverpoint ltsm_state_trans {
    bins valid_trans[] = (RESET => DETECT), (DETECT => TRAINING), ...;
  }
  cross cp_state, vc_id;
endgroup
```

### 6.2 Code Coverage
- Statement ≥ 95%
- Branch ≥ 90%
- FSM arc ≥ 95%
- Toggle ≥ 80%

### 6.3 Assertion Coverage
- All protocol assertions proven (formal) or covered (simulation)
- Target ≥ 98% at chip level

## 7. Verification Methods Matrix

| Technique | Scope | Tool |
|---|---|---|
| Simulation (RTL) | Block + subsystem | Xcelium / VCS |
| Simulation (multi-die distributed) | Chip | Xcelium Virtual Channels / Questa multi-process |
| Formal | Protocol properties, FSM | JasperGold / VC Formal / Questa Formal |
| Emulation | Chip + firmware | Palladium / ZeBu / Veloce |
| FPGA Prototype | System-level regression | S2C / Synopsys HAPS |
| Post-Silicon | Bring-up + characterization | → DOC-D8-01-BRINGUP |

## 8. Sign-off Criteria

| Criterion | Block | Subsystem | Chip | System |
|---|---|---|---|---|
| Functional Coverage | 100% | 100% | 100% | 100% |
| Statement | ≥ 90% | ≥ 95% | ≥ 95% | N/A |
| Branch | ≥ 80% | ≥ 90% | ≥ 90% | N/A |
| FSM Arc | ≥ 90% | ≥ 95% | ≥ 95% | N/A |
| Toggle | ≥ 70% | ≥ 75% | ≥ 80% | N/A |
| Assertion Proof | ≥ 95% | ≥ 95% | ≥ 98% | N/A |
| Mutation ratio | ≥ 80% | ≥ 80% | ≥ 80% | - |
| Bug Rate | < 0.1 / 1K cycles | 同 | 同 | - |
| Bug Plateau | ≥ 2 weeks no new | 同 | 同 | - |
| Regression Pass Rate | 100% | 100% | 100% | 100% |

## 9. Chiplet-Specific Verification

### 9.1 UCIe D2D Compliance
- VIP: Synopsys VC UCIe VIP / Cadence D2D VIP / Avery
- Scope: PHY (eye, margin), Link (retry, credit), Protocol (CXL mapping)
- Acceptance: 100% of UCIe 2.0 Compliance test list pass

### 9.2 Multi-Die Verification Strategy
- **Approach**: Distributed simulation (Xcelium VC) for chip-level
- **Mixed level**: RTL for die-under-focus, transactor for peer dies
- **3×** speedup target vs monolithic simulation

### 9.3 Inter-Chiplet Interop (若含 3rd-party)
- Golden Die reference behavior
- Scenario matrix: config A/B/C × workload 1-N
- Compliance to DOC-D2-05-DIC

### 9.4 System-Level Multi-Die Scenarios
- Cross-die cache coherence
- Cross-die interrupt delivery
- Cross-die power-state transitions
- Cross-die debug trace
- Fault containment

### 9.5 Power Verification (IEEE 1801 UPF)
- Power-up / down sequences
- Isolation cell correctness
- Retention cell integrity
- Always-on domain coverage

### 9.6 Functional Safety (若适用)
- FMEDA-driven fault injection
- Diagnostic Coverage (DC) measurement
- Lockstep verification
- Common Cause Failure (CCF) analysis

## 10. Regression Strategy

- **Smoke**: 30 min, per commit, CI-triggered
- **Nightly**: 4 hours, full TB
- **Weekly**: 24 hours, gate-level, cross-die, stress
- **Pre-tape-out**: 1 week, formal + emulation + coverage closure

## 11. Bug Management

- **Tool**: JIRA / Bugzilla / Mantis
- **Severity**: S1 (showstopper) / S2 (major) / S3 (minor) / S4 (cosmetic)
- **SLA**: S1 fix within 48h; S2 within 1 week
- **Root cause**: mandatory for S1/S2
- **Regression**: new test mandatory for every S1/S2 fix

## 12. Tools & Environment

- Simulator: {{ Xcelium / VCS }} v{{ N.M }}
- Formal: {{ JasperGold }} v{{ N.M }}
- Coverage: {{ vManager / Verdi Planner }}
- CI: Jenkins / GitLab CI
- Compute: {{ N }} cores peak, {{ M TB }} disk
- License peak: {{ K }} seats

## 13. Quality Checklist

- [ ] 所有 PRD/ARCH/MAS/DIC 需求有 testpoint 映射
- [ ] 每 testpoint 有 owner + test ID + 状态
- [ ] Coverage 目标在每层级定义
- [ ] Chiplet 特有要素已纳入（D2D / multi-die / interop / UPF / RAS）
- [ ] Regression 策略 CI 集成
- [ ] Bug 管理流程定义
- [ ] Sign-off 标准量化
- [ ] 工具许可证预留充足
- [ ] Risk & Waiver 已评审
- [ ] Stakeholder 签字

## 14. References
- Accellera UVM 1.2 Reference
- IEEE 1800-2017/2024
- IEEE 1801-2024 UPF
- UCIe 2.0 Compliance
- DVCon Best Practices 2024
