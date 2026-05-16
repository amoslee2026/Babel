---
name: babel-decisions
description: Babel 项目 ADR（Architecture Decision Record）日志
type: project
created: 2026-05-16
updated: 2026-05-16
format: ADR (Architecture Decision Record)
related:
  - idea/design_doc.md
---

# Babel 决策日志 (ADR Log)

> 关键设计决策的 ADR 记录。每条决策格式：Context → Decision → Consequences → Status。
> 决策一经 "Accepted"，不可隐式修改；变更需新增 ADR 并标注 supersedes。

---

## ADR-001 — EDA 工具集成方式：Bash + CLI（非 MCP server）

- **Status**: Accepted (2026-05-16)
- **Context**:
  v1.0 design_doc.md §6.1 设计了 `babel-eda` MCP server 暴露 6 个 EDA tool。
  会话中明确决策："EDA tool 不要用 mcp server，改成 bash scripts + eda cli"、
  "参考 open source tools chain，为每个 EDA tool 建立专用 skill"。
- **Decision**:
  EDA 工具全部通过 Claude Code 的 Bash 工具 + CLI 调用，封装为 skill（命名 `babel-invoke-{tool}`）。
  不为任何 EDA 工具创建 MCP server。原 v1.0 §6.2 babel-ast 与 §6.3 babel-knowledge 同样改 skill+bash。
- **Consequences**:
  - (+) 维护成本低；EDA 工具天然 CLI 设计，无需额外抽象层
  - (+) 调试更直观（bash 命令可在终端复现）
  - (+) 版本控制简单（skill 是 markdown，可 diff）
  - (-) 跨 agent 共享 EDA 工具状态需通过文件而非内存 API
  - (-) 部分高级特性（如 yosys 的 interactive session）需要 wrapper 脚本
- **Affected**: design_doc.md §6, §4.2-4.4；spec-review issue C001 / H009
- **Supersedes**: 无
- **See also**: ADR-009 (agent vs skill 分离)

---

## ADR-002 — Agent 命名与描述：去人格化

- **Status**: Accepted (2026-05-16)
- **Context**:
  v1.0 design_doc.md §3.1/3.2 给每个 agent 配中文人格化角色名："规格规划师"、
  "RTL 编码师"、"测试架构师"、"时钟域卫士"、"时序路径分析师" 等。
  会话中明确决策："update spec: 不要人格化设计，把 agent 当成冰冷的机器人"。
- **Decision**:
  所有 agent 描述使用功能短语（"模块" / "flow owner"），废弃"师"、"卫士"、"分析师" 等拟人词。
  agent ID 简化为 `babel-{name}`（去掉冗余的 `{domain}-{role}` 双层修饰）。
- **Consequences**:
  - (+) 降低用户对 agent 输出的情感投射，保持批判性
  - (+) 命名更短，便于 CLI 输入与日志检索
  - (-) v1.0 已存在的人格化命名材料需重写
- **Affected**: design_doc.md §3, §15.1；spec-review issue C002
- **Supersedes**: 无

---

## ADR-003 — 状态管理：单写者模式（Single Writer）

- **Status**: Accepted (2026-05-16)
- **Context**:
  v1.0 §7.1 定义 `design_state.json` 由 coordinator 和多个域 agent 共同读写。
  Spec review C003：并发 read-modify-write 会导致 fix_request 丢失或 signoff 状态错乱。
- **Decision**:
  1. **仅** `babel-cross-domain-coordinator` 可写 `design_state.json`
  2. 其他 agent 通过 `events/*.jsonl`（append-only）提交状态变更请求
  3. coordinator 周期性合并 events → state
  4. coordinator 写时 `flock(state.json)` + 写入 `lock_token` + `last_writer` 做乐观锁
- **Consequences**:
  - (+) 完全避免并发覆盖
  - (+) 事件流可追溯（events/*.jsonl 是 append-only 审计日志）
  - (-) 状态更新有延迟（events 合并周期）
  - (-) coordinator 成为单点；需补 watchdog hook（Phase 3）
- **Affected**: design_doc.md §2.3, §7.1, §7.3, §13.2；spec-review issue C003
- **Supersedes**: 无

---

## ADR-004 — MVP 范围：4 个 agent，其余转 Future

- **Status**: Accepted (2026-05-16)
- **Context**:
  v1.0 §3 定义 12 agent（6 core + 6 specialist）。Spec review H008：
  参考项目 MAGE=4、VerilogCoder=3；Babel 直接上 12 agent 引入大量职责重叠与协调开销。
- **Decision**:
  MVP（Phase 1-2）4 agent：spec-planner / rtl-coder / test-architect / cross-domain-coordinator。
  Phase 3 增 2：yosys-synth-planner / clock-domain-guard。
  其余 5（power-optimizer / property-prover / layout-planner / scan-chain-planner /
  top-integration-planner）推迟至 Phase 4+，按实际 bug 类别按需引入。
- **Consequences**:
  - (+) Phase 1-2 可控（5w + 1w buffer 现实可行）
  - (+) 职责重叠（rtl-coder vs clock-domain-guard、rtl-coder vs synth-planner）一并消除
  - (+) MVP 用户更早看到端到端结果
  - (-) 部分功能（功耗、形式验证）推迟
- **Affected**: design_doc.md §3, §16, §17.A；spec-review issue H008 / H010 / H011
- **Supersedes**: 无

---

## ADR-005 — Pyverilog 不支持的 SV 子集使用 verible/slang fallback

- **Status**: Accepted (2026-05-16)
- **Context**:
  v1.0 §6.2 babel-ast MCP 假定 Pyverilog 可解析所有 RTL。Spec review H007：
  Pyverilog 对 SV interface / class / coverage / bind 支持有限。
- **Decision**:
  - 主 skill `babel-parse-ast` 用 pyverilog
  - Fallback skill `babel-parse-ast-fallback` 用 `verible-verilog-syntax` 或 `slang`
  - skill 实现时先尝试 pyverilog；解析失败自动回落到 fallback
- **Consequences**:
  - (+) 真实项目兼容性提升；两套工具互为校验
  - (-) 环境维护双工具；解析结果结构需要统一抽象层
- **Affected**: design_doc.md §4.3；spec-review issue H007
- **Supersedes**: 无

---

## ADR-006 (Placeholder) — design_state.json schema 迁移 v1.0 → v1.1

- **Status**: Proposed（待 Phase 1 实施时落档）
- **Context**:
  v1.1 在 state schema 中新增 lock_token / last_writer / history_capacity /
  babel_session_id (UUIDv7) / on_max_iter_reached enum 等字段。
- **Decision (Proposed)**:
  - `scripts/migrate_state_1.0_to_1.1.py`：读取 v1.0 state，补默认值，写回 v1.1
  - 启动期 hook 自动迁移并备份到 `.state_backup_v1.0/`
  - 1.0 state 写入时强制升级
- **Affected**: design_doc.md §7.1；spec-review issue M014

---

## ADR-007 — Memory 复用 claude-mem 插件

- **Status**: Accepted (2026-05-16)
- **Context**:
  v1.0 §8 自建 Two-tier Memory（experiences.jsonl + knowledge.md）+ 自定义目录结构。
  用户决策："简化设计：memory system 复用 claude-mem"。
  现有 Claude Code 生态已有 `claude-mem` 插件提供跨会话记忆，重复造轮子无意义。
- **Decision**:
  - Babel **不**自建 memory 子系统
  - 所有跨会话记忆委托给 `claude-mem` 插件（在 `~/.claude/settings.json` 已默认启用）
  - 删除 v1.0 §8 自定义结构、删除 `babel_memory/` 目录设计、删除
    `babel_experiences.jsonl` / `babel_knowledge.md` / rotation policy / quarantine 设计
  - spec-review 原 issue M003 (rotation)、H015 (integrity)、L004 (rtl-coding naming)
    都因 claude-mem 复用而消解
- **Consequences**:
  - (+) 大幅简化设计，Phase 1 工作量减少 ~1 周
  - (+) 与 Claude Code 生态对齐；用户已熟悉的工具
  - (-) Babel 对 claude-mem 的能力上限有外部依赖
  - (-) 若 claude-mem 行为不满足 chip 场景特殊需求，需要新增 ADR 评估
    (a) 提 PR；(b) 局部 wrapper；(c) 必要时仍可自建（需 supersede ADR-007）
- **Affected**: design_doc.md §8（重写）, §1.2, §13.3；spec-review issue M003 / H015 / L004
- **Supersedes**: 无

---

## ADR-008 — Waveform 查看：VSCode 扩展，不在 Babel 范围

- **Status**: Accepted (2026-05-16)
- **Context**:
  v1.0 §4.2 列了 `babel-trace-waveform` skill 做 VCD 波形分析。
  用户决策："waveform 使用 vscode 的扩展查看，不需要特别设计"。
- **Decision**:
  - 仿真生成的 VCD / FST 文件由用户在 VSCode 中通过现有扩展查看
    （如 WaveTrace、Surfer-vscode、SystemVerilog by mshr-h 等）
  - Babel **不**封装波形查看 skill
  - Babel agent **不**在内部分析波形 — 失败信号由覆盖率 / 断言失败 / fix_request 表达
- **Consequences**:
  - (+) 用户已熟悉的工具；省去 agent 波形解析的成本
  - (+) 大型波形（GB 级 FST）由 VSCode 处理，不进入 agent context
  - (-) 自动化迭代时无法用波形做精细错因定位（依赖断言 + 覆盖率作为信号）
  - (-) 若后续需要 agent-level 波形 trace，需新 ADR 评估
- **Affected**: design_doc.md §1.2, §3.1.3, §4.3, §11.2 备注；spec-review 无对应 issue（用户新增）
- **Supersedes**: 无（替代 v1.0 §4.2 中的 babel-trace-waveform）

---

## ADR-009 — EDA 工具 = skill；flow owner = agent（严格分离）

- **Status**: Accepted (2026-05-16)
- **Context**:
  用户决策："开源工具链的使用，只用 skill，不用 agents"、
  "EDA 工具的操作以 skills 实现，flow owner 以 agent 实现"。
  v1.0 隐含将"工具"与"flow"两层混在一起；需要明确分离。
- **Decision**:
  - **Skill = Tool operation**：单一 EDA CLI 包装，输出结构化结果，**无业务判断**
  - **Agent = Flow ownership**：决定何时调用哪些 skill、解读输出、生成 fix_request
  - EDA 工具（yosys / verilator / opensta / magic / netgen / klayout / abc / qrouter / pyverilog 等）
    **仅以 skill 实现**；**不存在**"yosys agent" 之类的工具级 agent
  - flow owner agent（如 `babel-yosys-synth-planner` 是综合 flow owner、`babel-clock-domain-guard`
    是 CDC flow owner）调用对应 skill 完成具体执行
  - Skill **不允许**调用 Agent 工具或派发 subagent（保持单向依赖：agent → skill）
- **Consequences**:
  - (+) 清晰的两层架构；职责单一
  - (+) Skill 可独立测试（单元测试只测 CLI 包装）
  - (+) Agent 实现专注于业务逻辑，不混入 CLI 细节
  - (-) 部分跨工具的低层优化（如 yosys+ABC 组合调用）需要 skill 链或在 agent 层组合
- **Affected**: design_doc.md §3.0, §4.2, §6, §11.2；spec-review issue C001 (强化)
- **Supersedes**: 无（与 ADR-001 互补：ADR-001 说"用 bash 不用 MCP"，ADR-009 说"工具是 skill 不是 agent"）

---

## 决策模板（供未来 ADR 使用）

```markdown
## ADR-NNN — <标题>

- **Status**: Proposed | Accepted | Superseded by ADR-MMM | Deprecated
- **Context**: 触发该决策的背景与约束
- **Decision**: 明确的决策内容
- **Consequences**:
  - (+) 优点
  - (-) 缺点 / 风险
- **Affected**: 影响的文档/代码位置
- **Supersedes**: 被本 ADR 替代的旧 ADR（若有）
```
