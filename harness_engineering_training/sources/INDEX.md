# Sources（一手与二手来源追溯）— v2.0

> 本培训材料引用的所有来源 + 本地范例索引。Generated: 2026-05-20 (北京时间)
>
> **v2.0 新增**：Google 2026 Agent 系列白皮书、Harness Engineering 时代文献、记忆框架文档（Mem0/Letta/Zep/Cognee/claude-mem/Anthropic Memory Tool）

## A. Anthropic 一手来源（原 v1.0 基础）

### A.1 通过 Exa MCP `web_fetch_exa` 抓取的完整文档

| URL | 大小 | 内容 |
|-----|-----|------|
| https://docs.claude.com/en/docs/claude-code/sub-agents | 含 subagents/skills/hooks 三页 | 227KB 官方完整规范 |

### A.2 Anthropic 官方 GitHub（通过 Context7）

Library ID: `/anthropics/claude-code`（80.1 分，740 代码片段）

抓取的 SKILL.md：
- `plugins/plugin-dev/skills/agent-development/SKILL.md`
- `plugins/plugin-dev/skills/hook-development/SKILL.md`
- `plugins/plugin-dev/skills/skill-development/SKILL.md`
- `plugins/plugin-dev/skills/plugin-structure/SKILL.md`
- `plugins/plugin-dev/skills/mcp-integration/references/tool-usage.md`

### A.3 Anthropic 官方 Blog

- https://claude.com/blog/how-to-configure-hooks（2025-12-11）
- https://platform.claude.com/docs/en/agents-and-tools/tool-use/memory-tool（2025-10 Memory Tool 发布）
- https://www.shloked.com/writing/claude-memory-tool（2025-10 深度分析）

## B. Google Agent 系列白皮书 ⭐ v2.0 新增

| # | 标题 | 作者 | 时间 | 用途 |
|---|------|------|------|------|
| B1 | **Agents** | Julia Wiesinger, Patrick Marlow, Vladimir Vuskovic | 2024-09 | 三层架构经典模型；第 2 章 2.3 节基础 |
| B2 | **Agents Companion** | Antonio Gulli, Lavi Nigam et al. | 2025-04 | 多智能体进阶；第 2 章 2.6 节 multi-agent |
| B3 | **Introduction to Agents** | Alan Blount, Antonio Gulli, Shubham Saboo, Michael Zimmermann, Vladimir Vuskovic | 2025-11 | L0-L4 五级 taxonomy 来源；第 2 章 2.4 节 |
| B4 | **Developer's guide to multi-agent patterns in ADK** | Google Developers | 2025-12 | 8 大设计模式；第 2 章 2.6 节 |
| B5 | **Build Long-running AI agents with ADK** | Google Developers | 2026-05 | pause/resume + dormancy gate；第 2 章 2.8 节 |
| B6 | **Multi-agent AI system in Google Cloud** | Google Cloud Architecture Center | 2025 | A2A 协议 + ADK 架构 |
| B7 | **Building Collaborative AI: Multi-Agent Systems with ADK** | Google Cloud Blog | 2025-11 | 三类 agent + 通信机制 |
| B8 | **Multi-Agent Systems with Agent2Agent (Codelab)** | Google Codelabs | 2026 | A2A 协议实战教程 |

## C. Harness Engineering 时代文献 ⭐ v2.0 新增

| # | 标题 | 作者 | 时间 | 用途 |
|---|------|------|------|------|
| C1 | **Harness Engineering 深度解析（中文综述）** | 知乎用户 | 2026-03-08 | **第 1 章主参考**：https://zhuanlan.zhihu.com/p/2014014859164026634 |
| C2 | Harness engineering: leveraging Codex in an agent-first world | OpenAI | 2026-02 | 百万行代码 5 月实验报告 |
| C3 | Effective harnesses for long-running agents | Anthropic Engineering | 2025 | 4 大失败模式 + 双阶段 Agent 方案 |
| C4 | Building a C Compiler with Claude | Nicholas Carlini (Anthropic) | 2025 | 16 个并行 Agent，Rust 10 万行 |
| C5 | My AI Adoption Journey | Mitchell Hashimoto (HashiCorp) | 2026-02 | Harness Engineering 术语早期命名者 |
| C6 | Harness Engineering | Martin Fowler | 2026-02 | 三分类框架（Context/Architecture/GC）|
| C7 | The Emerging Harness Engineering Playbook | Charlie Guo (Artificial Ignorance) | 2026 | Playbook 级综述 |
| C8 | How to Harness Coding Agents with the Right Infrastructure | Alex Lavaee | 2026 | 四大支柱框架 |
| C9 | Advanced Context Engineering for Coding Agents | Dex Horthy | 2026 | Smart Zone / Dumb Zone 概念 |
| C10 | Ralph Methodology | Geoffrey Huntley | 2026 | Ralph Wiggum Loop + Backpressure |
| C11 | Minions: Stripe's one-shot, end-to-end coding agents | Stripe | 2026 | 千 PR 无人值守系统 |

## D. Agent 自主性分级 ⭐ v2.0 新增

| # | 框架 | 来源 | 时间 | 级数 | 用途 |
|---|------|------|------|------|------|
| D1 | Levels of AGI | Google DeepMind (arxiv 2311.02462) | 2023 | 5×5 矩阵 | 能力 × 自主性正交 |
| D2 | Levels of Autonomy for AI Agents | Knight First Amendment Institute | 2025-07 | 5 级（L1-L5）| 用户角色：Operator → Observer |
| D3 | Agentic Trust Framework | Cloud Security Alliance | 2026-01 | **6 级（L0-L5）** | 第 2 章 2.4 节 L5 来源 |
| D4 | NIST AI Agent Standards Initiative | NIST | 2026-02 | 风险驱动 | maturity model 演进中 |
| D5 | AI Agent Autonomy Levels Taxonomy | Zylos Research | 2026-03 | 综述 | 多框架对比 |

## E. 持久化记忆框架 ⭐ v2.0 新增（第 7 章核心）

| # | 框架 | URL / 仓库 | 时间 | 类别 |
|---|------|-----------|------|------|
| E1 | **Mem0** | github.com/mem0ai/mem0 | 47K+ stars, $24M Series A | Memory-as-a-Layer |
| E2 | **Letta**（前 MemGPT） | github.com/letta-ai/letta | 21K stars, Felicis $10M | Memory-as-the-Runtime |
| E3 | **Zep / Graphiti** | github.com/getzep/zep | 24K stars | Temporal KG |
| E4 | **Cognee** | github.com/topoteretes/cognee | 12K stars, $7.5M seed | KG + connectors |
| E5 | **LangMem** | github.com/langchain-ai/langmem | LangChain 生态 | 模块化 |
| E6 | **claude-mem** | github.com/thedotmack/claude-mem | 2025-08 创建 | Claude Code 插件 |
| E7 | **Anthropic Memory Tool** | platform.claude.com/docs | 2025-10 | 官方 file-based |
| E8 | Supermemory | supermemory.dev | 2026 | coding agent 优化 |
| E9 | MS Semantic Kernel | github.com/microsoft/semantic-kernel | - | Azure 生态 |
| E10 | Redis Agent Memory Server | redis.io/products | - | 低延迟 backend |

## F. 学术论文与基准 ⭐ v2.0 新增

| # | 论文 | 作者 | 时间 | 主题 |
|---|------|------|------|------|
| F1 | MemGPT: Towards LLMs as OS | Packer et al. (UC Berkeley) | 2024 | OS-inspired virtual memory |
| F2 | LoCoMo: Long-term Conversational Memory | Maharana et al. (Snap) | 2024 | 35 sessions × 9K tokens benchmark |
| F3 | Agentic Memory | Yu et al. | 2026 | RL/GRPO 训练记忆操作策略 |
| F4 | LoCoMo-Plus | xjtuleeyf | 2026 | cue-trigger 语义脱节 |
| F5 | MemoryAgentBench | Hu et al. | 2025 | 多 session 任务 |
| F6 | MemoryArena | He et al. | 2026 | agentic 任务（揭示 LoCoMo SOTA 跌至 40-60%）|
| F7 | Codified Context: Three-Tier Context Infrastructure | Vasilopoulos et al. | 2026 | 283 个开发会话验证 |
| F8 | Memory for Autonomous LLM Agents (Survey) | - | 2026 | 综述 |
| F9 | Levels of Autonomy for AI Agents | Feng, McDonald, Zhang | 2025 (Knight) | 五级 taxonomy |

## G. Sub-agent 与社区参考（v1.0 基础）

| # | 来源 | URL |
|---|------|-----|
| G1 | claude-code-best-practice (sub-agents) | github.com/JuanMaPerals/claude-code-best-practice |
| G2 | Claude Codex (创建 sub-agent) | claude-codex.fr/en/agents/create-subagent/ |
| G3 | Tinker AI (hooks 系统) | tinker-ai.com/guides/claude-code-hooks-system/ |
| G4 | AgentPatterns.ai (sub-agents) | agentpatterns.ai/tools/claude/sub-agents/ |
| G5 | claudelint (hooks schema) | claudelint.com/api/schemas/hooks |
| G6 | GitHub Issue #14882 (progressive disclosure 实测) | github.com/anthropics/claude-code/issues/14882 |

## H. 本地范例（Babel 项目）

### H.1 Sub-agents

| 文件 | 演示要点 |
|------|---------|
| `.claude/agents/bba-architect.md` | 完整 sub-agent：role / policies / IO contract / workflow / escalate protocol |
| `.claude/agents/bba-guru-rtl.md` | 下游 agent + handoff drift check (sha256) |
| `.claude/agents/bba-guru-synthesis.md` | 工具白名单 + 模型选择 |
| `.claude/agents/bba-guru-verification.md` | coverage gate 强制 |
| `.claude/agents/bba-guru-pd.md` | 签核门禁 |

### H.2 Hooks（10 个完整示例）

| 文件 | 事件 | 演示要点 |
|------|------|---------|
| `.claude/hooks/bb-hook-validate-bash-cmd.sh` | PreToolUse:Bash | fail-soft 软警告 |
| `.claude/hooks/bb-hook-commit-quality-gate.sh` | PreToolUse:Bash | git commit 前门禁 |
| `.claude/hooks/bb-hook-write-arch-freeze-check.sh` | PreToolUse:Write\|Edit | 按路径策略 deny |
| `.claude/hooks/bb-hook-pipeline-advance.sh` | PostToolUse:Write\|Edit | handoff → next agent 提示 |
| ...（其他见 v1.0 索引） | | |

### H.3 Settings + Skills

- `.claude/settings.json` — 5 类 hook event × 多 matcher
- `.claude/skills/bb-*` 80+ 个 skill（生成类、工具适配、检查类、门禁类、协议类、搜索类）

## I. 研究方法说明

| Phase | 方法 |
|-------|------|
| Phase 1 | 任务分解（TaskCreate） |
| Phase 2 | 多源搜索（Exa MCP web_search_exa）|
| Phase 3 | 深度抓取（Exa MCP web_fetch_exa + Context7）|
| Phase 3.5 | 本地范例采样 |
| Phase 4 | 交叉验证（关键事实 3+ 源）|
| Phase 5 | 撰写 + Mermaid 验证（mermaid 11 + jsdom 全部 51 块通过）|

## J. 已知限制

1. **WebFetch 工具被本机策略阻断** docs.claude.com，已用 Exa MCP `web_fetch_exa` 绕过成功
2. **代理 SSL 握手失败**（jina/curl 直连均不通），但 Exa MCP 可达
3. Claude Code 演进快，建议每季度对比 release notes 更新
4. **L5 自主级别**非 Google 原文（Google *Introduction to Agents* 只到 L4），第 2 章 2.4 节 L5 来源标注为 CSA Agentic Trust Framework (2026-01)

## K. 时效性检查

| 信息类型 | 最新时间 | 验证 |
|---------|---------|------|
| Claude Code v2.1+ 特性 | 2026-05-20 | ✓ |
| Hooks event 全集 | 官方文档 latest | ✓ |
| Skill frontmatter 字段 | 官方文档 latest | ✓ |
| Sub-agent frontmatter 字段 | 三源交叉，2026-Q1 | ✓ |
| Google ADK 多智能体模式 | 2025-12 + 2026-05 | ✓ |
| 持久化记忆框架数据 | 2026-Q1～Q2 | ✓（LongMemEval 分数有可能更新）|
| Babel 项目本地状态 | 当前 working tree | ✓ |
