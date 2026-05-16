---
doc_id: META-NUMBERING
title: 编号规则与命名约定
version: 1.0
generated: 2026-04-23T22:45:00+08:00
---

# 编号规则 (Numbering Scheme)

## 1. 顶层格式

```
DOC-<Domain>-<Serial>-<ShortCode>
│   │        │        └─ 文档类型缩写（英文大写，3–8 字符）
│   │        └────────── 域内序号（两位数字，01 起）
│   └─────────────────── 域号（D1–D9，可扩展至 D99）
└──────────────────────── 固定前缀，标识"文档"
```

示例：
- `DOC-D1-01-PRD` — Product Requirements Document，域 1 内第 1 号
- `DOC-D2-02-ADR` — Architecture Decision Records，域 2 内第 2 号
- `DOC-D3-01-MAS` — Micro Architecture Spec，域 3 内第 1 号

## 2. 域分配表

| 域号 | 名称 | 涵盖范围 | 保留位 |
|---|---|---|---|
| D1 | Product | 产品需求、市场、商业 | 01–10 |
| D2 | Architecture | 系统架构、ADR、性能模型、软件架构、接口契约 | 01–20 |
| D3 | Implementation | 微架构（MAS）、IP-XACT、RTL 实现规范 | 01–30（MAS per block 占多个序号） |
| D4 | Physical | 封装、物理设计、热管理、应力、封装可靠性 | 01–15 |
| D5 | Test | DFT、KGD、量产测试程序、burn-in | 01–15 |
| D6 | Verification | VPlan、boot sequence、formal、emulation | 01–20 |
| D7 | Security | 威胁模型、安全架构、密钥管理 | 01–10 |
| D8 | Silicon | Bring-up、post-si validation、yield ramp | 01–10 |
| D9 | Release | Datasheet、errata、compliance、release notes | 01–10 |

预留 D10–D19 用于项目管理/财务/供应链（如 MRD、business case、schedule、risk register）。

## 3. 子模块编号（MAS/Arch 专用）

当一份文档需要按 block 或模块拆分时，使用扩展格式：

```
DOC-D3-01-MAS-<Block>
```

示例：
- `DOC-D3-01-MAS-D2DCTRL` — D2D Link Controller 的 MAS
- `DOC-D3-01-MAS-ROCC` — RoC Coherence Bridge 的 MAS
- `DOC-D3-01-MAS-HBM3PHY` — HBM3 PHY 的 MAS

或对 chiplet 级拆分：

```
DOC-D2-01-ARCH-<DieName>
```

示例：
- `DOC-D2-01-ARCH-CCD` — Compute Die 架构
- `DOC-D2-01-ARCH-IOD` — I/O Die 架构
- `DOC-D2-01-ARCH-MEMD` — Memory Die 架构

## 4. 版本号

采用简化 SemVer：`<Major>.<Minor>[-<Stage>]`

| 版本 | 含义 |
|---|---|
| `0.1-template` | 模板初稿 |
| `0.1-draft` | 项目首次 draft |
| `0.9-review` | 评审中 |
| `1.0-approved` | 正式批准 |
| `1.0-frozen` | 冻结（不可修改，只能发 errata） |
| `1.1` | 微调（不影响下游文档） |
| `2.0` | 重大修订（需回归影响分析） |

## 5. 文件命名规则

```
<doc_id>[-<variant>]-v<version>.md

例：
DOC-D1-01-PRD-v1.0.md
DOC-D3-01-MAS-D2DCTRL-v0.9.md
DOC-D2-01-ARCH-CCD-v1.1.md
```

模板库中文件名省略版本（均为 `0.1-template`）。

## 6. 关联 ID（跨文档引用）

需求 ID / testpoint ID / ADR ID 使用独立短前缀：

| 前缀 | 含义 | 示例 |
|---|---|---|
| REQ- | PRD 需求 ID | REQ-PERF-001, REQ-SAFETY-A3 |
| ARCH- | 架构决策点 | ARCH-D2D-002 |
| ADR- | Architecture Decision Record | ADR-042 |
| MAS- | MAS 功能点 | MAS-D2DCTRL-FSM-01 |
| TP- | Testpoint | TP_D2DCTRL_CRC_ERR_01 |
| BUG- | Bug ID | BUG-1234 |
| ERR- | Errata ID | ERR-07 |
| CR- | Change Request | CR-2026-042 |

## 7. 扩展规则

- 新增 doc type：在域内取下一个可用序号
- 新增 domain：D10 起，更新本文件与 `document-index.md`
- 短代码（ShortCode）应唯一，建议 3–8 字符大写字母
