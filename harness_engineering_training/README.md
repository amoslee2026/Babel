# Harness Engineering 培训材料

> 面向芯片设计工程师的 Claude Code Harness Engineering 培训
>
> Generated: 2026-05-20 · 项目：Babel · 适用：IC / Chiplet / SoC 设计工程师
>
> v2.1：拆分为模块化章节文件 + 第 6 章方法论增强 + 第 10 章陷阱增强（基于知乎《Harness Engineering 深度解析》2026-03）

## 目录结构

```
harness_spec/training/
├── README.md                              ← 本文件（导航）
├── build.sh                               ← 构建脚本：拼章节 → 全文版
├── harness-engineering-training.md        ← 自动生成的全文版（3133 行 / 132 KB / 58 mermaid）
├── chapters/                              ★ 模块化章节
│   ├── _preamble.md                       前言（标题 + 培训目标 + 介绍）
│   ├── 00-why-ic-engineers.md             为什么 IC 工程师要学
│   ├── 01-paradigm-evolution.md           工程范式三次演进（Prompt → Context → Harness）
│   ├── 02-google-agent-taxonomy.md        Agent 总体分类（Google 2026 视角，L0-L5）
│   ├── 03-low-stack-tech.md               底层支撑（LLM/CLI/MCP/RAG/LSP）
│   ├── 04-coding-agent-principles.md      Coding Agent 运行原理
│   ├── 05-claude-code-extensions.md       Claude Code 四大扩展点（Tool/Hook/Skill/Sub-agent）
│   ├── 06-harness-methodology.md          ⭐ Harness 方法论（v2.1 新增 5 节：6.7-6.11）
│   ├── 07-persistent-memory.md            持久化记忆 SOTA
│   ├── 08-hands-on-labs.md                动手实验（引用 labs/ 目录）
│   ├── 09-advanced-patterns.md            高级模式
│   ├── 10-pitfalls-best-practices.md      ⭐ 陷阱与最佳实践（v2.1 新增 3 节：10.4-10.6）
│   ├── 11-summary.md                      总结与下一步
│   └── 99-references.md                   参考文献
├── appendices/                            ★ 附录
│   ├── A-glossary.md                      术语表
│   └── B-ask-claude.md                    不明白的问题：直接问 Claude Code
├── labs/                                  动手实验材料
│   ├── lab1-skill/  lab2-hook/  lab3-subagent/  lab4-pipeline/  lab5-mcp-server/
├── templates/                             即拷即用模板
│   ├── skill-skeleton/SKILL.md
│   ├── agent-skeleton.md
│   ├── hook-skeleton.sh
│   └── settings-hooks-snippet.json
├── sources/INDEX.md                       一手 + 二手来源索引
└── metadata.json                          研究元数据
```

## 工作流

**修改章节**：编辑 `chapters/<NN>-*.md` 或 `appendices/*.md` → 跑 `./build.sh` → 全文版自动更新。

**单章分发**：直接发对应的 `chapters/<NN>-*.md` 给团队成员。

**整体阅读**：`harness-engineering-training.md`（自动生成，请勿直接编辑）。

## 主报告章节

| 章 | 文件 | 重点 |
|----|------|------|
| 0 | 00-why-ic-engineers.md | 痛点驱动 |
| 1 | 01-paradigm-evolution.md | 行业演进 + 4 大支柱 + H0-H4 成熟度 + 6 共识 3 空白 |
| 2 | 02-google-agent-taxonomy.md | 三层架构 + L0-L5 六级 + 8 模式 + MCP/A2A |
| 3 | 03-low-stack-tech.md | 五件套全景 + 各自原理 + 协同范式 |
| 4 | 04-coding-agent-principles.md | Agentic loop + Context window + Tool use |
| 5 | 05-claude-code-extensions.md | Tool / Hook / Skill / **Sub-agent**（含任务编排/通信/同步） |
| **6** | **06-harness-methodology.md** | **+ AGENTS.md / 架构约束机械化 / 单一事实源 / Backpressure / 熵 GC** |
| 7 | 07-persistent-memory.md | Claude Code 自带 / claude-mem / Mem0 三大重点 |
| 8 | 08-hands-on-labs.md | 5 个 Lab 索引 |
| 9 | 09-advanced-patterns.md | Agent Team / Evolution / Plugin |
| **10** | **10-pitfalls-best-practices.md** | **+ Anthropic 4 大失败模式 / 三大空白 / 七大业界争议** |
| 11 | 11-summary.md | 一图流回顾 + 课后作业 |
| App A | A-glossary.md | 术语表 |
| App B | B-ask-claude.md | 五种问法 + 决策树 |

**加粗**为 v2.1 增强章节。

## 推荐学习路径

| 角色 | 顺序 | 时间 |
|------|------|------|
| 完全新手 | 0 → 1 → 4 → 5 → Lab 1 → 6 → Lab 2-3 → 7 | 2 天 |
| 用过 Claude Code | 1 → 5 → 6 → Lab 2-3 → 7 → 10 | 1 天 |
| 想串流水线 | 2 → 5.4 → Lab 4 → 9 | 半天 |
| 关心记忆/上下文 | 1 → 3 → 6.2 → 7 | 半天 |
| 关心方法论 | 1 → 6 → 10 | 半天 |

## 评估标准

- [ ] 能讲清 Prompt / Context / Harness Engineering 三层关系
- [ ] 能解释 Agent 三层架构和 L0-L5 自主性
- [ ] 能讲清 sub-agent / skill / hook / tool 的运行边界
- [ ] 能讲清 LLM / CLI / MCP / RAG / LSP 五件套各自职责
- [ ] 能解释 progressive disclosure 三级模型
- [ ] 能比较 Claude Code 自带 memory / claude-mem / Mem0 差异
- [ ] **能解释 Anthropic 4 大 agent 失败模式 + 对应修法**
- [ ] **能识别 Harness Engineering 七大业界争议中你团队的立场**
- [ ] 独立完成 Lab 1-3
- [ ] 完成第 10.3 节"IC 项目 Harness 检查清单"自评
- [ ] 提出至少 1 个本团队 EDA 流程的 harness 改造点

## 进阶资源

主报告 References + `sources/INDEX.md` 列出全部引用：
- Anthropic 一手官方文档（sub-agents / skills / hooks / memory tool）
- Google 2024-2026 系列白皮书（Agents / Companion / Introduction / ADK guides）
- **知乎《Harness Engineering 深度解析》（2026-03，第 6/10 章主参考）**
- Mem0 / Letta / Zep / Cognee / claude-mem 框架文档
- 学术论文（MemGPT / Agentic Memory / LoCoMo 系列）
- 本项目本地范例（Babel sub-agents / hooks / settings.json）

## 反馈与维护

- v2.1 重要变更（2026-05-20）：
  - **拆分主文件为 chapters/ + appendices/ 模块化目录结构**
  - **新增 build.sh 脚本自动拼接全文版**
  - **第 6 章新增 5 节**：6.7 AGENTS.md 活文档 / 6.8 架构约束机械化 / 6.9 单一事实源 / 6.10 Backpressure / 6.11 熵管理
  - **第 10 章新增 3 节**：10.4 Anthropic 4 大失败模式 / 10.5 三大空白 / 10.6 七大业界争议
  - **第 10.1 易踩坑扩充至 13 项**（新增 5 项 Anthropic / 知乎来源）
  - 全文版从 2648 行扩至 3133 行；mermaid 从 51 张增至 58 张
- 错误报告：在项目 GitHub repo 开 issue，label = `training-feedback`
- 内容更新追踪：随 Claude Code release notes 同步；Google ADK 季度更新；Mem0/Letta/Zep 框架更新
