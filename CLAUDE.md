## Overview
开源 AI 原生 Chiplet 设计流程，基于开源 EDA 工具链和 AI Coding Agent。

## Quick Start
```
1. Place idea at: designs/<name>/idea/*.md
2. /bba-architect <name>     # PRD → ARCH → MAS
3. /bba-guru-rtl             # MAS → RTL
4. /bba-guru-verification    # RTL → test_report.json
5. /bba-guru-synthesis       # → synth_report.json
6. /bba-guru-pd              # → GDSII
```
Pipeline: `idea → PRD → ARCH → MAS → RTL → VERIF → SYNTH → PD → GDSII`

## Git Remotes
| Remote | URL | 用途 |
|--------|-----|------|
| origin | gitlink.org.cn/amoslee2011/Babel.git | 主仓库 |
| github | github.com/amoslee2026/Babel.git | 镜像 |

`git push origin` 会同步推送到两边。

## Directory
```
rtl/designs/      # RTL source      designs/       # Build outputs (GDSII, reports)
doc/              # Operators, ISA, EDA docs
wiki/             # CBB, coding style, protocols
spec/             # PRD, MAS, ARCH
libs/             # ASAP7 PDK (symlink)
.claude/agents/   # 5 bba-* orchestrators    .claude/skills/   # 35 bb-* tools
.claude/hooks/    # Enforcement hooks        .claude/schemas/  # Inter-stage JSON schemas
.claude/references/  # tool_versions.md, asap7_corners.md, conventions.md
```

## Agents vs Skills
- **Agents** (`.claude/agents/bba-*.md`): top-level orchestrators invoked
  via `/bba-architect`, `/bba-guru-rtl`, etc.
- **Skills** (`.claude/skills/bb-*.md`): single-purpose tools (e.g.
  `bb-invoke-yosys`, `bb-check-lint`, `bb-create-sdc`, `bb-gate-*`).
- **Commands** (`.claude/commands/*.md`): thin trampolines that spawn agents.

## EDA Toolchain
**Canonical versions**: `.claude/references/tool_versions.md`

| Tool | Version | Function |
|------|---------|----------|
| Yosys | 0.35 | RTL synthesis |
| OpenSTA | 2.5.0 | STA |
| Magic | 8.3.641 | Layout/DRC/LVS |
| Netgen | 1.5.275 | LVS comparison |
| QRouter | 1.4 | Detailed routing |
| KLayout | 0.30.8 | GDSII viewer/DRC |
| Verilator | 5.012 | Verilog sim |
| Babel-LSP | 0.2.0 | HDL LSP+MCP（SV 语法检查 / 诊断） |

Env: `source ~/wrk/eda_opensources/eda_env.sh` (override: `BB_EDA_ENV`)

## ASAP7
7nm PDK at `libs/asap7/`: asap7sc6t_26, asap7sc7p5t_27/28
Liberty (.lib), LEF layouts. Corners: `.claude/references/asap7_corners.md`
