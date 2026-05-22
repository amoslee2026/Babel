---
title: 面向芯片设计工程师的 Harness Engineering 培训
subtitle: 基于 Claude Code 的 Coding Agent 原理、扩展机制与方法论
version: 1.0
generated: 2026-05-20T11:55+08:00 (北京时间)
audience: 集成电路 / 芯粒 / SoC 设计工程师
prereq: 熟悉 RTL/综合/PD 流程；少量 Bash / Python 基础；首次接触 AI Coding Agent 亦可
duration_estimate: 4 学时讲授 + 4 学时实验
language: zh-CN（专业术语保留英文）
sources_dir: ./sources/
---

# 面向芯片设计工程师的 Harness Engineering 培训

> **本培训目标**
>
> 1. 让工程师理解 Coding Agent（以 Claude Code 为代表）的**运行原理**——它不是"魔法"，而是一个可被检视、可被约束、可被扩展的有限循环系统。
> 2. 掌握 **Tool / Hook / Skill / Sub-agent / Slash Command** 五个核心扩展点的概念、运行方式与边界。
> 3. 学会 **Harness Engineering 方法论**——把 LLM 的不确定性约束在确定的工程边界里。
> 4. 能**亲手创建** Skill、Sub-agent、Hook 用于自己的 EDA 工作流（RTL 生成、综合 QoR 监控、签核 gating 等）。
> 5. 建立**安全直觉**：知道哪些动作会越界、如何 fail-soft / fail-loud 选择、上下文预算如何排布。

本培训用 Babel 项目（`/home/lxx/wrk/Babel`）作为完整范例：5 个 sub-agent、10+ hook、80+ skill 共同把 `idea → PRD → arch → MAS → RTL → verify → synth → PD → GDSII` 自动化串起来。

---

