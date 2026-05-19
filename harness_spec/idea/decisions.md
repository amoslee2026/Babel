---
name: babel-decisions
description: Babel 项目 ADR（Architecture Decision Record）日志
type: project
created: 2026-05-16
updated: 2026-05-16
format: ADR (Architecture Decision Record)
related:
  - harness_spec/idea/design_doc.md
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

## ADR-002 — Agent 命名与描述：去人格化（v1.2 扩展 bb- 前缀；v1.3 扩展 bb-architect / bb-guru-*）

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

## ADR-004 — MVP 范围（v1.3 更新为 5 个 agent）

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

## ADR-010 — Bash 工具授权下 write_paths / read_denylist 为软边界：接受残留风险

- **Status**: Accepted (2026-05-16)
- **Context**:
  Spec-review v1.1（`harness_spec/idea/.review/issues_v1.1.md` C1 + H4）指出：5 个 agent
  (rtl-coder / test-architect / coordinator / yosys-synth-planner / clock-domain-guard)
  持有 `Bash` 工具时，`write_paths` 与 `read_denylist` 都可被 Bash 绕过：
  - `bash -c "echo X > /any/path"` 绕 write_paths glob
  - `cat $HOME/.ssh/id_rsa`、路径变形、symlink、临时脚本绕 read_denylist
  即 §13.1 三层 allowlist 在 Bash agent 面前是软声明而非硬边界。
- **Decision**:
  接受残留风险，**不**引入进程级 sandbox（bubblewrap / firejail / rootless docker）：
  - Babel 用例：agent 运行于用户自己开发机，用于本人芯片设计任务
  - 威胁模型：信任 agent 诚实但可能 buggy；不防御恶意 agent / prompt injection RCE
  - Sandbox 引入显著复杂度（EDA 工具 Linux 依赖图复杂、bind mount + ASAP7 PDK 路径难调）
  - 改造 ROI 与 MVP 目标不匹配
  - `tools` / `write_paths` / `read_denylist` 保留为**意图声明**与开发者错误防护，不作安全边界
- **Consequences**:
  - (+) Phase 1-2 实施保持简洁；不依赖 sandbox 基础设施
  - (+) EDA 工具调用不受 namespace 限制（ASAP7 PDK、yosys plugin 等正常访问）
  - (+) 与 ADR-009（skill = bash + CLI）一致 — 不在工具调用链上加沙箱层
  - (-) `write_paths` / `read_denylist` 仅是软提示；agent 若被 prompt injection / 自身漏洞攻陷会泄露
  - (-) Babel **不能**部署到不信任 agent 的环境（共享 server / 隔离 tenant / 公网 SaaS）
  - (-) Spec-review issue C1 / H4 不修复，标 `WONTFIX-ACCEPTED`
- **Affected**: design_doc.md §13.1（增加威胁模型说明）、§0.3 ADR 表；spec-review C1 / H4
- **Supersedes**: 无
- **Note**: 若未来 Babel 用例扩展到不信任环境（共享部署 / 公网 SaaS / 第三方 agent），
  新增 ADR supersede 本 ADR 并实施进程级 sandbox。
  Tracking trigger：(a) 多用户共享部署；(b) 公网 SaaS 化；(c) agent 来源不可信。

---

## ADR-011 — Inter-Agent Communication = GitHub Issues

- **Status**: Accepted (2026-05-16, v1.2)
- **Context**:
  v1.1.1 设计了 `babel_fix_request` schema + `events/*.jsonl` 协议作为 agent 间协作机制，
  由 `babel-cross-domain-coordinator` 统一仲裁。v1.2 取消 coordinator（见 ADR-012），
  需要新的 inter-agent comms 载体。
- **Decision**:
  使用 **GitHub issues**（通过 `gh` CLI）作为 agent 间通信通道：
  - Label 表示阶段：`ready-for-{rtl,verification,synth,pd}` / `signoff` / `{X}-needs-fix`
  - Issue body 结构化（yaml frontmatter + Markdown body）
  - 三个新 skill：`bb-create-issue` / `bb-list-issues` / `bb-close-issue`
  - 每条 fix-chain `max_fix_iteration: 3`；超出升级 `escalate-user`
- **Consequences**:
  - (+) 使用既有 GitHub 基础设施（无新组件）
  - (+) 天然 audit trail（issue 历史）
  - (+) 用户可直接观察 / 介入（issue 是 first-class UI）
  - (-) 依赖 `gh` CLI 可用 + 仓库已配置 issues
  - (-) 跨组织 / 离线场景需 fallback（Phase 5 评估 Linear / Jira 适配器）
- **Affected**: design_doc.md §2.1 / §7.3 / §4.5；arch_spec / impl_spec 未来产出
- **Supersedes**: 无（替代 v1.1.1 fix_request schema + jsonl events 协议）

---

## ADR-012 — Sequential Pipeline 作为 MVP 协作模型

- **Status**: Accepted (2026-05-16, v1.2)
- **Context**:
  v1.1.1 设计了 `babel-cross-domain-coordinator` agent + 单写者 `design_state.json` 作为
  中央协调器（ADR-003）。用户决策："不需要 cross-domain-coordinator，agents co-work
  with git issues。先实现一个 design flow pipeline，顺序执行即可"。
- **Decision**:
  采用 **sequential pipeline**：
  - 各 agent 按固定顺序执行（v1.2: arch→rtl→synth→verify；v1.3 ADR-015 调整为 arch→rtl→verify→synth→pd）
  - 无中央 coordinator 进程
  - 每个 agent 独立写自己的 schema-validated artifact 到 `designs/<name>/`
  - 上游完成 → 创建 git issue (label=ready-for-<next>)
  - 下游 agent 启动时 `bb-list-issues` 拾起 → 完成 → 关 issue + 开下一阶段
  - 用 `design_summary.json` (append-only) 作为整体进度可见快照
- **Consequences**:
  - (+) 大幅简化：取消 coordinator agent / state.json 单写者锁 / event log merge 协议
  - (+) ADR-003 (单写者 state) + 由其衍生的 watchdog / event offset 复杂度全部消除
  - (+) 用户可逐 step 介入（每个 issue 都可暂停 / 手动调整）
  - (-) 失去并行可能性（v1.1 设想的多 agent 同时跑被禁用；但 MVP 用例下不需要）
  - (-) issue 拾起需要轮询或人工触发（不像 coord 那样 push-based）
- **Affected**: design_doc.md §2.2；ADR-003 标 **Deprecated by ADR-012**；
  arch_spec/architecture_specification.md M004 / M301 / M302 设计被取消
- **Supersedes**: ADR-003（单写者 state.json）

---

## ADR-013 — Skill 执行范式：Write-Script → Run → Parse → Return

- **Status**: Accepted (2026-05-16, v1.2)
- **Context**:
  用户决策："typical workflow should be: sub-agents call skills to write a script to do some
  jobs, then run the scripts and check the output, maybe from eda tools. then do some
  optimization and re-run the workflow, until the goal achieved。"
  v1.1.1 把 skill 看作简单 CLI wrapper，但实际 EDA flow 需要写脚本（.ys / .tcl / .py），
  执行后解析输出，agent 根据结果决定是否调优 + 重调。
- **Decision**:
  每个 skill 实现 **四阶段**：
  1. **write_script** — 根据 args 生成可执行脚本到 `designs/<n>/<tool>/{stamp}.{ext}`
  2. **run_script** — Bash 执行（10min 默认超时；PD skill 30min）
  3. **parse_output** — 用正则 / json parser / pyverilog 解析；输出符合 skill output schema 的 JSON
  4. **return** — 把结构化 JSON 返回 agent

  **关键约束**：skill 不做"成功 / 失败"业务判断，只回传结果；optimization loop 在 **agent** 内。

  Agent 端实现 optimization loop：循环调 skill → 判结果 → 调 args → 重调，直到收敛或超 max_iter。
- **Consequences**:
  - (+) skill 可被独立单测（mock args，对脚本与 parse 做 snapshot 测试）
  - (+) Agent 与 skill 职责清晰（业务 vs 工具）
  - (+) 脚本是 first-class artifact（可被用户复现、改进、调试）
  - (-) skill 实现比 wrapper 复杂；template engine + parser 都要写
  - (-) 多阶段失败处理需要在 skill 内实现（如 parser fallback）
- **Affected**: design_doc.md §10；所有 bb-invoke-* skill 实现规范
- **Supersedes**: 无

---

## ADR-014 — 复用既有 ic-* skills（不重新实现 bb- 版本）

- **Status**: Accepted (2026-05-16, v1.3)
- **Context**:
  用户决策："bb-architect 负责输出 PRD/architecture spec/MAS 等文档（调用 bb-prd, bb-arch,
  bb-mas 等 skills）"、"bb-guru-rtl 调用 bb-rtl-coder"。
  用户既有 ECC skill 库已含 `bb-prd` / `bb-arch` / `bb-mas` / `bb-rtl-coder`，
  覆盖了 v1.2 中 `bb-plan-arch` / `bb-generate-rtl` 等 Babel 原生 skill 的设计意图。
- **Decision**:
  - bb-architect 直接调用既有 `bb-prd` / `bb-arch` / `bb-mas`（**不**重新实现 bb-* 版本）
  - bb-guru-rtl 直接调用 `bb-rtl-coder`
  - v1.2 设计的 `bb-plan-arch` / `bb-generate-rtl` skill **删除**（不再实现）
  - 命名规则扩展：`bb-{action}-{target}` 用于 Babel 原生 skill；`ic-{name}` 用于外部复用
- **Consequences**:
  - (+) 利用既有 skill 库，减少重复设计 / 实现 / 维护
  - (+) ic-* skill 已被多个项目验证，质量有保证
  - (+) Babel 专注于自己的"原生"能力（lint / cdc / sdc / floorplan / invoke / issue comms）
  - (-) 对 ic-* skill 的演进有外部依赖；版本变更需同步评估
  - (-) ic-* skill 的 input/output 契约可能与 Babel agent IO schema 不完全一致；
    Phase 1 实施时需写 adapter（如 bb-mas 输出 → mas.schema.json 校验）
- **Affected**: design_doc.md §3.1.1 / §3.1.2 / §4.1；ADR-013 skill 范式仍适用（ic-* skill 也应遵守）
- **Supersedes**: 无（v1.2 设想的 bb-plan-arch / bb-generate-rtl 不再实施）

---

## ADR-015 — Pipeline 顺序：architect → rtl → verification → synthesis → pd

- **Status**: Accepted (2026-05-16, v1.3)
- **Context**:
  v1.2 顺序为 `architect → rtl → synth → verify`。用户决策（v1.3）将其调整为
  `architect → rtl → **verify** → **synth** → **pd**`：先做 RTL 级 functional 验证，
  再做综合，最后 PD 输出 GDSII。
- **Decision**:
  采用 5 阶段顺序：
  1. **bb-architect** — PRD / arch / MAS
  2. **bb-guru-rtl** — 输入 MAS，输出 hierarchical SV + file_list.f
  3. **bb-guru-verification** — coverage-driven sim, target=**100%**（functional + code）
  4. **bb-guru-synthesis** — 从 MAS 派生 SDC（ADR-016），跑综合，迭代 timing/area
  5. **bb-guru-pd** — floorplan/place/route/DRC/LVS/timing closure/GDSII
  Signoff 在 PD 完成（GDSII 出炉 + DRC clean + LVS match + post-PD WNS ≥ 0）。
- **Consequences**:
  - (+) RTL-level functional 验证在综合前完成，符合业界标准 ASIC flow
  - (+) synth 拿到的 RTL 是 functionally verified，可避免 "综合通过但功能错"
  - (+) PD 输入是 timing-closed netlist，物理设计目标聚焦在 PD 自身问题（DRC / LVS / placement）
  - (+) Signoff 落在 PD GDSII，是真正的 tape-out 候选
  - (-) verification → synthesis 失败时（如发现 functional bug 需改 RTL）回退链较长
  - (-) 5 阶段串行总时长较 v1.2 4 阶段更长（estimated +1.5h on UART）
- **Affected**: design_doc.md §2.1 / §2.2 / §11；arch_spec 完整结构需重做
- **Supersedes**: 无（v1.2 4 阶段顺序虽未 ADR 化但被本 ADR 取代）

---

## ADR-016 — SDC 来源：bb-guru-synthesis 从 MAS 派生（不再由 RTL agent 起草）

- **Status**: Accepted (2026-05-16, v1.3)
- **Context**:
  v1.1 / v1.2 把 SDC 起草职责放在 `babel-rtl-coder` / `bb-guru-rtl`（产出 SDC 草稿，
  由 synth-planner 最终化）。但 SDC 的源头是 MAS 中的时钟规划、复位策略、IO timing —
  与 RTL 实现无关。在 RTL agent 内起草 SDC 等于让 RTL 假设时序约束，违反职责分离。
- **Decision**:
  - SDC 文件由 `bb-guru-synthesis` 从 MAS 直接派生
  - 新增 skill `bb-create-sdc`（Babel 原生）：input = mas/mas.json, output = constraints/*.sdc
  - `bb-guru-rtl` 输出中 **删除** SDC 草稿；仅输出 rtl/*.sv + file_list.f + rtl_artifact.json
- **Consequences**:
  - (+) 职责清晰：SDC 是 timing / IO domain 知识，归 synth agent
  - (+) RTL agent 输出更专注：纯 HDL + file list；无 timing 假设
  - (+) MAS 变更（时钟 / IO timing）→ 自动反映到 SDC 重生成（不需要改 RTL）
  - (-) bb-create-sdc skill 需要解析 mas.json 的 clock_domains / interfaces / timing_constraints 字段；
    schemas/mas.schema.json 需明确这些字段
  - (-) v1.2 已设计的 rtl-coder 输出 SDC 草稿的逻辑需要从 Phase 1 设计中拿掉
- **Affected**: design_doc.md §3.1.2 / §3.1.4 / §4.1；新 skill bb-create-sdc 实施
- **Supersedes**: 无

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
