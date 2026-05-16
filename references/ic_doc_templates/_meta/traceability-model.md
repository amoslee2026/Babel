---
doc_id: META-TRACEABILITY
title: 跨文档追溯模型
version: 1.0
generated: 2026-04-23T22:45:00+08:00
---

# 跨文档追溯模型 (Traceability Model)

## 1. 核心原则

高端 chiplet 文档体系的**工程骨架**是四向双向追溯链：

```
PRD Req ──► Arch Decision (ADR) ──► MAS Section ──► VPlan Testpoint ──► Test Case ──► Coverage Point
   │            │                      │                 │                   │
   └────────────┴──────────────────────┴─────────────────┴───────────────────┘
                 双向可追溯（forward + backward 缺一不可）
```

**Forward 追溯**：每条需求 → 哪些决策/实现/验证项覆盖它  
**Backward 追溯**：每条实现/验证 → 源自哪条需求

## 2. 文档依赖 DAG

```
                          DOC-D1-01-PRD
                                │
                                ▼
         ┌──────────────┬──────┼───────┬─────────────┐
         ▼              ▼      ▼       ▼             ▼
    DOC-D2-01-ARCH  D2-03-PERF D2-04-SWARCH  D2-05-DIC  D9-03-COMPLY
         │
         ├──► DOC-D2-02-ADR (记录架构决策)
         ▼
    ┌────┼─────┬─────────┬──────────┬──────────┐
    ▼    ▼     ▼         ▼          ▼          ▼
  D3-01 D3-02 D4-01   D4-02      D7-01      D5-01
  MAS   IPXACT PKG    THERM      SEC        DFT
   │     │    │         │                    │
   │     │    └────► D5-02-KGD                │
   ▼     ▼                                    ▼
  D6-01-VPLAN ◄────────────────────────── D6-02-MDBOOT
   │
   ▼
  D8-01-BRINGUP
   │
   ▼
  ┌─────────┬─────────────┐
  ▼         ▼             ▼
 D9-01-DS  D9-02-ERRATA  D9-03-COMPLY
```

## 3. Frontmatter 追溯字段

每份文档 frontmatter 必须声明：

```yaml
parent: <上游 doc_id>     # 驱动本文档的上游文档（可多个：parent: [id1, id2]）
children: [<下游 ids>]    # 本文档驱动的下游文档
references: [标准, ...]   # 引用的行业标准
```

## 4. 文档内追溯标记

### 4.1 需求引用（在下游文档中）

在下游文档的相关章节末尾添加：

```markdown
> **Traces to**: REQ-PERF-001 (PRD §3.2), ARCH-D2D-002 (Arch §4.1), ADR-042
```

### 4.2 需求标签（在 PRD 中）

每条需求采用如下格式：

```markdown
### REQ-PERF-001: D2D Link Bandwidth
- **Statement**: 单向 D2D 聚合带宽 ≥ 2 TB/s @ TT/1.0V
- **Verification Method**: Post-silicon BER test + RTL bandwidth assertion
- **ASIL**: QM (non-safety)
- **Owner**: <name>
- **Traces forward**: ARCH §4.1, MAS-D2DCTRL §3, TP_D2D_BW_01
```

## 5. 追溯矩阵 (RTM) 生成

### 5.1 RTM 结构

```
| Req ID | Description | Arch Section | MAS Section | Testpoint | Test Case | Coverage | Status |
|--------|-------------|--------------|-------------|-----------|-----------|----------|--------|
| REQ-PERF-001 | D2D BW ≥ 2TB/s | ARCH §4.1 | MAS-D2DCTRL §3 | TP_D2D_BW_01 | tc_d2d_bw_001 | 100% | Complete |
```

### 5.2 生成脚本（建议）

```bash
# 伪代码：扫描所有文档 frontmatter + "Traces to:" 行
scripts/gen_rtm.py --docs ic_doc_templates/ --out rtm.csv
```

推荐工具：
- **DOORS** (IBM Rational) — 企业级需求管理
- **Jama Connect** — 现代化需求+测试追溯
- **Polarion** (Siemens) — ALM 集成
- **ReqView** — 轻量级 ReqIF 工具
- **codeBeamer** — 支持 ISO 26262 / DO-254

## 6. 追溯覆盖率目标

| 阶段 | Forward 覆盖率 | Backward 覆盖率 | 工具自动化 |
|---|---|---|---|
| PRD Sign-off | 95% (每条 Req 至少映射到 1 个 Arch) | N/A | DOORS/Jama |
| Arch Sign-off | 100% | 95% | 同上 |
| RTL Freeze | 100% | 100% | MAS + IP-XACT 自动导出 |
| Tape-out | 100% | 100% | VPlan vManager |
| Post-Si | 100% + Coverage 100% func | 100% | vManager + yield tool |

## 7. 变更传播规则

当上游文档变更时，下游文档必须触发影响评估：

```
PRD 修改 ──► 触发 Arch impact analysis ──► 触发 MAS impact ──► 触发 VPlan impact
   │                  │                         │                    │
   ▼                  ▼                         ▼                    ▼
 ECN-###            ADR 补充                 MAS CR              Testpoint 补充
```

**变更管理原则**：
1. PRD 变更必须同步 ADR 条目
2. Arch Spec 变更需回归所有 MAS 的依赖段
3. MAS 变更必须同步 VPlan（新 testpoint 或修改覆盖目标）
4. 任何冻结后的变更必须通过 CCB (Change Control Board)

## 8. Chiplet 特有追溯要求

### 8.1 跨 Die 追溯

多 die 设计中，每条 Die Interface Contract (DIC, DOC-D2-05) 的条款必须：
- 在每个涉及的 die Arch Spec 中有对应条款
- 在 D2D Link Controller MAS 中有实现
- 在 VPlan 中有 compliance testpoint

### 8.2 跨供应商追溯（ISO 26262）

若采用 3rd-party chiplet，必须维护：
- Vendor 的 Safety Case → 本项目 PRD 安全需求映射
- Vendor 的 FMEA → 本项目 FMEDA 条目
- Vendor 的 Verification evidence → 本项目 VPlan 引用

**建议格式**：Safety Element out of Context (SEooC) Interface Agreement，作为 DIC 的附录。

### 8.3 标准合规追溯

`DOC-D9-03-COMPLY` 明确列出每项标准（UCIe、JEDEC、IEEE、ISO）的合规条款 → 本项目哪份文档证明，形成 compliance RTM。

## 9. 追溯质量检查清单

- [ ] 每条 PRD 需求有唯一 ID 且符合 SMART
- [ ] 每条需求至少映射到 1 条 ADR 或 Arch section
- [ ] 每条 Arch section 至少映射到 1 个 MAS block
- [ ] 每条 MAS section 至少映射到 1 个 VPlan testpoint
- [ ] 每个 testpoint 有 owner + test case ID + 状态
- [ ] RTM 双向覆盖率 100%（RTL freeze 时）
- [ ] 所有 waiver 有正当性说明 + 批准人
- [ ] 变更影响分析 (CIA) 对冻结文档的修改已完成

## 10. 参考

- IEEE Std 829 (Test Documentation)
- ISO/IEC/IEEE 29148:2018 (Requirements Engineering)
- ISO 26262-8:2018 §6 (Interfaces within distributed developments) — 跨供应商追溯
- DO-254 (airborne electronic hardware) — 最严格的追溯参考
