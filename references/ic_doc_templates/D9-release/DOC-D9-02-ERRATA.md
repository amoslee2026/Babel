---
doc-id: DOC-D9-02-ERRATA
title: Errata Document
domain: D9-release
version: 0.1
status: draft
parent: DOC-D9-01-DS
generated: 2026-04-24T06:15:00+08:00
---

# DOC-D9-02-ERRATA — Errata Document

## Document Control

| Field | Value |
|---|---|
| Document ID | DOC-D9-02-ERRATA |
| Version | 0.1 |
| Classification | PUBLIC (after release) |
| Authors | Silicon Validation Team |
| Reviewers | SoC Arch, SW Arch, Reliability |
| Approvers | VP Engineering, VP Product |

### Revision History

| Ver | Date | Description |
|---|---|---|
| 0.1 | YYYY-MM-DD | A0 silicon triage — initial errata list |
| 1.0 | YYYY-MM-DD | A1 silicon update |
| 2.0 | YYYY-MM-DD | Production (B1/MP) errata baseline |

---

## 1. Introduction

本文档记录 [Product Name] 各 silicon revision 中已知的功能偏差、限制和推荐 workaround。每条 errata 条目均包含：
- 问题描述和触发条件
- 受影响的 silicon revision
- 软件/硬件 workaround（如适用）
- 计划修复的 revision（如适用）

**使用须知：**
- 本文档随每次 silicon revision 或 FW/SW release 更新
- 每条 errata 状态：`Open`（未修复）、`Fixed in RX`（已在 RX 修复）、`Closed-WA`（workaround 可用，不计划硬件修复）
- 对于 Open 状态的 errata，所有用户必须实施对应 workaround

---

## 2. Errata Summary Table

| Errata ID | Title | Affected Rev | Severity | Status | Workaround Available |
|---|---|---|---|---|---|
| ERR-001 | [Short title] | A0 | S2 | Fixed in A1 | Yes |
| ERR-002 | [Short title] | A0, A1 | S3 | Open | Yes (FW patch) |
| ERR-003 | [Short title] | A0 | S1 | Fixed in A1 | No |
| ERR-004 | [Short title] | A0, A1, B0 | S4 | Closed-WA | Yes |
| *(add rows as discovered)* | | | | | |

**Severity Definitions:**
- **S1** — Chip non-functional for primary use case, no workaround
- **S2** — Major feature broken; SW/FW workaround available
- **S3** — Performance or capability degraded; workaround available
- **S4** — Minor deviation from spec; workaround trivial

---

## 3. Errata Detail Entries

### ERR-001 — [Errata Short Title]

**Silicon Revisions Affected:** A0

**Severity:** S2

**Status:** Fixed in A1

---

#### 3.1.1 Problem Description

[Describe the problem in 1–3 sentences. State the observed incorrect behavior vs. the specified behavior.]

**Example:** When UCIe link partner enters L1 power state during active streaming, the Host Die LTSM occasionally fails to exit L1 within the specified timeout of 200 µs, causing the link to reset.

#### 3.1.2 Trigger Conditions

[Enumerate specific conditions required to trigger the bug.]

| Condition | Value |
|---|---|
| Traffic pattern | Burst followed by idle > 10 µs |
| Link partner P-state | L1 entry enabled |
| Frequency | Observed ~1 per 10^8 flits |
| Temperature dependency | More frequent at TJ > 95 °C |

#### 3.1.3 Root Cause

[Brief root cause description — logic bug, timing marginal, etc.]

RTL bug in UCIe LTSM timeout counter: counter reload path missing one cycle in the L1-exit handshake state.

#### 3.1.4 Impact

[State customer impact clearly.]

In affected configurations, D2D link may reset unexpectedly, causing:
- Packet loss requiring re-transmission
- Potential application crash if driver does not handle link-reset event

#### 3.1.5 Workaround

**Option A (Recommended):** Disable UCIe L1 link state via register write at initialization:

```
# Disable L1 on all UCIe ports
write32(UCIe_PORT0_PM_CTRL, read32(UCIe_PORT0_PM_CTRL) & ~BIT(4))
write32(UCIe_PORT1_PM_CTRL, read32(UCIe_PORT1_PM_CTRL) & ~BIT(4))
# Repeat for all active ports
```

**Power impact:** Disabling L1 increases idle power by approximately [XX] W per die pair. Apply only if power budget allows.

**Option B:** Apply FW patch [FW-PATCH-0001] which implements polling-based L1 exit detection. Performance impact < 0.1% on typical workload.

#### 3.1.6 Fix Status

Fixed in A1 tape-out (2024-XX-XX) by adding missing register-load in LTSM RTL. A0 users must apply workaround.

---

### ERR-002 — [Errata Short Title]

**Silicon Revisions Affected:** A0, A1

**Severity:** S3

**Status:** Open (hardware fix deferred to next major revision)

---

#### 3.2.1 Problem Description

[Describe the problem.]

#### 3.2.2 Trigger Conditions

| Condition | Value |
|---|---|
| [Condition 1] | [Value] |
| [Condition 2] | [Value] |

#### 3.2.3 Root Cause

[Root cause summary.]

#### 3.2.4 Impact

[Impact description.]

#### 3.2.5 Workaround

[Workaround steps — code snippets, register settings, configuration changes.]

```python
# Example workaround script
def apply_err002_workaround(device):
    # Step 1: ...
    reg = device.read_reg(REG_ADDR)
    reg = (reg & ~MASK) | NEW_VALUE
    device.write_reg(REG_ADDR, reg)
    # Step 2: ...
```

#### 3.2.6 Fix Status

Hardware fix scheduled for next major silicon revision. Until then, apply workaround on all A0/A1 parts.

---

### ERR-003 — [Errata Short Title]

**Silicon Revisions Affected:** A0

**Severity:** S1

**Status:** Fixed in A1

---

#### 3.3.1 Problem Description

[Describe problem.]

#### 3.3.2 Trigger Conditions

[Trigger conditions.]

#### 3.3.3 Root Cause

[Root cause.]

#### 3.3.4 Impact

[Impact.]

#### 3.3.5 Workaround

**No workaround available.** Parts exhibiting this failure should be returned for replacement. Contact [support email/portal].

#### 3.3.6 Fix Status

Fixed in A1.

---

### ERR-004 — [Errata Short Title]

**Silicon Revisions Affected:** A0, A1, B0

**Severity:** S4

**Status:** Closed-WA (no planned hardware fix)

---

#### 3.4.1 Problem Description

[Describe minor deviation.]

#### 3.4.2 Workaround

[Simple workaround steps.]

---

## 4. Errata Template (for new entries)

When adding a new errata entry, copy and fill the following template:

```markdown
### ERR-XXX — [Short Title]

**Silicon Revisions Affected:** [list]
**Severity:** [S1/S2/S3/S4]
**Status:** [Open / Fixed in RX / Closed-WA]

#### Problem Description
[1–3 sentences: observed behavior vs. specified behavior]

#### Trigger Conditions
| Condition | Value |
|---|---|
| [condition] | [value] |

#### Root Cause
[Brief root cause]

#### Impact
[Customer impact]

#### Workaround
[Step-by-step workaround; include code snippets / register values]

#### Fix Status
[Fixed revision or "No hardware fix planned"]
```

---

## 5. Closed / Resolved Errata

Errata resolved in production silicon that no longer require workaround:

| Errata ID | Title | Fixed in Rev | Closure Date |
|---|---|---|---|
| ERR-003 | [Title] | A1 | YYYY-MM-DD |
| *(add as applicable)* | | | |

---

## 6. Contact & Support

For technical questions related to this errata document:

| Channel | Contact |
|---|---|
| Customer support portal | [URL] |
| FAE (field application engineer) | Contact your regional FAE |
| Silicon validation team | [internal alias] |

**Document updates:** Subscribe to product notification at [URL] to receive email when this document is updated.

---

## Appendix A — Silicon Revision History

| Rev | Tape-out Date | First Sample Date | Key Changes from Previous Rev |
|---|---|---|---|
| A0 | YYYY-MM-DD | YYYY-MM-DD | First silicon |
| A1 | YYYY-MM-DD | YYYY-MM-DD | ERR-001, ERR-003 fixes |
| B0 | YYYY-MM-DD | YYYY-MM-DD | Performance characterization |
| B1 | YYYY-MM-DD | YYYY-MM-DD | Production qualification baseline |
| MP | YYYY-MM-DD | YYYY-MM-DD | Mass production |

---

## Appendix B — Related Documents

| Doc ID | Title |
|---|---|
| DOC-D9-01-DS | Datasheet |
| DOC-D8-01-BRINGUP | Bring-up & Post-Silicon Validation Plan |
| DOC-D9-03-COMPLY | Compliance Matrix |
