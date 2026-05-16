---
name: babel-arch-summary-report
description: it.arch Phase 6 总结报告 + 下一步 (handoff to it.mas)
type: arch_spec
version: 1.0.0
created: 2026-05-16
upstream: harness_spec/idea/design_doc.md v1.1.1
downstream: harness_spec/impl_spec/
---

# Babel Architecture — Summary Report

> it.arch Phase 1-6 输出汇总。本文档同时是 it.mas handoff 触发点。

---

## 1. 交付物清单

| 文件 | Phase | 行数估计 | 用途 |
|------|-------|---------|------|
| `functional_specification.md` | 3 | ~180 | F001-F016 需求 |
| `user_manual.md` | 3 | ~180 | 用户视角 + 失败处理 |
| `architecture_specification.md` | 4 | ~400 | M00X 模块 + IO 契约 + 内部协议 |
| `data_flow_diagrams.md` | 4 | ~120 | 数据流 Mermaid |
| `workflow_diagrams.md` | 4 | ~200 | 业务流程 Mermaid |
| `schemas_seed.md` | 4 | ~280 | 10 JSON Schema 字段骨架 |
| `ADR/ADR-A01.md` | 5 | ~50 | babel CLI = slash command |
| `ADR/ADR-A02.md` | 5 | ~50 | JSON Schema Draft 2020-12 |
| `ADR/ADR-A03.md` | 5 | ~50 | sqlite state lock (NFS-safe) |
| `ADR/ADR-A04.md` | 5 | ~50 | claude-mem fallback |
| `ADR/ADR-A05.md` | 5 | ~50 | history eviction FIFO+pin |
| `ADR/ADR-A06.md` | 5 | ~50 | multi-session 锁 |
| `ADR/ADR-A07.md` | 5 | ~50 | agent 命名单 token |
| `ADR/ADR-A08.md` | 5 | ~50 | skill 单向依赖 CI |
| `summary_report.md`（本文档） | 6 | ~150 | 汇总 + handoff |

---

## 2. v1.1 Spec Review Issue 处置矩阵

来源：`harness_spec/idea/.review/issues_v1.1.md`（v1.1 review，34 issues）。

| ID | Severity | 处置 | 位置 |
|----|----------|------|------|
| C1 | CRITICAL | WONTFIX (ADR-010, 已接受) | idea/decisions.md ADR-010 |
| C2 | CRITICAL | RESOLVED in arch_spec | schemas_seed.md §5 (synth_input composite) |
| C3 | CRITICAL | RESOLVED in design_doc v1.1.1 | idea/design_doc.md line 108 |
| H1 (babel CLI) | HIGH | RESOLVED | ADR-A01, user_manual.md §2 |
| H2 (schemas seed) | HIGH | RESOLVED | schemas_seed.md (10 schema 骨架) |
| H3 (NFS flock) | HIGH | RESOLVED | ADR-A03 (sqlite mutex) |
| H4 (read_denylist Bash bypass) | HIGH | WONTFIX (subsumed by ADR-010) | ADR-010 (idea/) |
| H5 (claude-mem fallback) | HIGH | RESOLVED | ADR-A04, M304 |
| H6 (history eviction) | HIGH | RESOLVED | ADR-A05, schemas_seed event.pinned |
| H7 (multi-session lock) | HIGH | RESOLVED | ADR-A06, M303 |
| H8 (flow owner glossary) | HIGH | RESOLVED | architecture_specification.md §0 |
| H9 (agent naming) | HIGH | RESOLVED | ADR-A07 (单 token rename) |
| H10 (skill purity) | HIGH | RESOLVED | ADR-A08, M201 |
| M1 (abc unpinned) | MEDIUM | RESOLVED | M107 (Phase 1 lock_references.sh) |
| M2 (yosys prefix grep) | MEDIUM | RESOLVED | architecture_specification.md M101 |
| M3 (ADR-006 placeholder) | MEDIUM | RESOLVED | 删除决策见 §3 |
| M4 (coord watchdog) | MEDIUM | DEFERRED (Phase 3 仍保留) | 仍是 design_doc 决策 |
| M5 (EDA SHA256) | MEDIUM | DEFERRED to it.mas | Phase 1 hook 增 SHA256 verify |
| M6 (wiki hash self-ref) | MEDIUM | RESOLVED | M501 external hashes.txt |
| M7 (schema fail-mode) | MEDIUM | RESOLVED | M201 spec |
| M8 (escalate_user UX) | MEDIUM | RESOLVED | user_manual.md §6, workflow_diagrams §3 |
| M9 (event offset commit) | MEDIUM | RESOLVED | M302 spec (atomic rename) |
| M10 (mid-flow override) | MEDIUM | RESOLVED | F016, user_manual §7, workflow_diagrams §4 |
| M11 (event merge conflict) | MEDIUM | RESOLVED | architecture_specification §6.3 |
| M12 (schemas effort) | MEDIUM | ADDRESSED | schemas_seed.md (字段骨架 + Phase 1 checklist) |
| M13 (synth RTL source) | MEDIUM | RESOLVED | synth_input composite schema |
| M14 (UCIe wiki scope) | MEDIUM | RESOLVED | M501 ucie split |
| L1 (issue mapping bookkeeping) | LOW | NOT FIXED (设计选择保留追溯) | n/a |
| L2 (claude-mem version pin) | LOW | DEFERRED to it.mas | scripts/lock_references.sh |
| L3 (rerun agent name) | LOW | RESOLVED | workflow_diagrams §2 |
| L4 (mermaid event→coord edge) | LOW | RESOLVED | data_flow_diagrams §4 |
| L5 (fix_request sample) | LOW | RESOLVED | schemas_seed.md §10 |
| L6 (coord 3-token) | LOW | RESOLVED | ADR-A07 |
| L7 (ADR-006 in §0.3 table) | LOW | RESOLVED (M3 删除) | 同 M3 |

**统计**：34 issues 中，RESOLVED = 27，WONTFIX = 2 (C1/H4)，DEFERRED-it.mas = 3 (M4 watchdog, M5 SHA256, L2 claude-mem pin)，NOT_FIXED = 1 (L1)。
即 v1.1 review issue 全部得到明确处置（不再 DEFERRED-it.arch 状态）。

---

## 3. ADR-006 删除决议

idea/decisions.md ADR-006 是 "design_state v1.0→v1.1 migration" placeholder。但 v1.0 从未实施部署 → 无真实 state 需迁移。
按 v1.1-issue M3 建议 YAGNI：**Phase 1 实施时删除 ADR-006**（标 Deprecated）；如未来 v1.1 部署后需 v1.1→v1.2 迁移，再立新 ADR。

---

## 4. 新增 8 个 ADR 摘要

| ADR | Topic | 一句话 |
|-----|-------|--------|
| ADR-A01 | Babel CLI 入口 | Claude Code slash command `/babel-design` |
| ADR-A02 | Schema 规范 | JSON Schema Draft 2020-12 in `schemas/` |
| ADR-A03 | State lock | sqlite mutex（NFS-safe）替代 flock |
| ADR-A04 | claude-mem fallback | Stateless 降级 + 警告横幅 |
| ADR-A05 | History eviction | FIFO + priority-pin（max_iter / signoff 等不 evict） |
| ADR-A06 | Multi-session lock | `.babel_session.lock` + PID alive 校验 |
| ADR-A07 | Agent 命名 | 单 token (`babel-coord` 等)，扩展 ADR-002 |
| ADR-A08 | Skill 单向依赖 | `forbidden_tools` frontmatter + CI scanner |

---

## 5. Phase 6: 对抗评审 (待执行)

按 it.arch 流程，Phase 6 应调用 `it.spec-review` 评审 arch_spec/，预期结果：
- CRITICAL = 0
- HIGH ≤ 3（schema 内 ref 路径、composite schema 边界、Phase 1 任务粒度）
- MEDIUM ≤ 10

**建议下一步**：用户决定是否运行 `/it.spec-review harness_spec/arch_spec/` 后再 handoff 至 `it.mas`。

---

## 6. 风险清单

| 风险 | 缓解 | 责任阶段 |
|------|------|---------|
| schemas_seed.md 字段骨架可能仍有边界 case 未覆盖 | Phase 0.5 / Phase 1 落地时反馈到 arch_spec | it.mas |
| sqlite mutex 在某些 NFS 实现下仍有问题 | Phase 1 必跑 NFS smoke test | it.mas |
| 单 token agent 命名 (ADR-A07) 与 idea/ 文档不一致 | 选择性 sync 或保留 idea 文档为 "原始决策快照" | 由用户决定 |
| skill purity CI 检测可被刻意混淆 | ADR-010 威胁模型已说明：不防恶意 agent | (已接受) |
| claude-mem stateless 降级时 agent 性能下降 | 在 banner 中明示；Phase 2 衡量影响 | it.mas |
| EDA 工具 SHA256 校验推迟 (M5) | Phase 1 hook 实施时补 | it.mas |

---

## 7. it.mas Handoff 触发条件

按 it.arch 铁律：
- [x] arch_spec 所有 Phase 产物文件均存在且非空
- [x] 每个模块（M00X）有完整接口定义（无 TBD 信号名）
- [x] 每个关键架构决策有 ADR
- [x] 输出文档无 "TODO" / "TBD" / "待定" 占位（schema_seed.md 提到的 "Phase 1 实施时落地" 是实施步骤说明，不是 TBD 占位）
- [ ] **it.spec-review 评审无 CRITICAL**（待运行）

**结论**：可手动运行 `/it.spec-review harness_spec/arch_spec/` 评审 arch_spec；若 CRITICAL=0 → 进入 `/it.mas harness_spec/arch_spec/` 生成 impl_spec。

---

## 8. 关联文档

| 路径 | 用途 |
|------|------|
| `../idea/design_doc.md` v1.1.1 | 上游 idea spec |
| `../idea/decisions.md` ADR-001~010 | 上游决策日志 |
| `../idea/.review/issues_v1.1.md` | 已处置的 v1.1 review |
| `functional_specification.md` | F00X 完整需求 |
| `architecture_specification.md` | M00X 完整模块定义 |
| `schemas_seed.md` | 10 schema 字段骨架 |
| `data_flow_diagrams.md` / `workflow_diagrams.md` | 视觉化 |
| `ADR/ADR-A01..A08.md` | 8 项 architecture 决策 |
