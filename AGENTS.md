## Overview
开源 AI 原生 Chiplet 设计流程，基于开源 EDA 工具链和 omp（oh-my-pi）AI Coding Agent。

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

启动：在本仓根目录运行 `omp`。项目级配置全部在 `.omp/`，agents / skills / commands / hooks / MCP 自动加载。

## MCP（启动时自动连接）
| Server | 入口 | 用途 |
|--------|------|------|
| `babel-lsp` | `babel-lsp --mcp` | SV/VHDL/TCL 诊断、符号级编辑（`Babel-LSP.json` 为配置规格；0.2.0 运行时尚未读取） |
| `agentic-logger` | `agentic-logger-mcp --log-dir logs/agentic` | 结构化日志查询 `agentic_log_*` |

配置在 `.omp/mcp.json`。二进制缺失时：
`scripts/install-babel-lsp.sh`；`uv tool install --force "agentic-logger[mcp]" --with "mcp<2"`。

## Git Remotes
| Remote | URL | 用途 |
|--------|-----|------|
| github | github.com/amoslee2026/Babel.git | 主仓库 / 交付目标（凭据走 `git-credential-gh-account.sh`，走代理） |
| origin | gitlink.org.cn/amoslee2011/Babel.git | 历史镜像（需 gitlink 凭据，本机未配置；非交付目标） |

交付一律 `git push github master`。两个 remote 相互独立：`.git/config` 没有 `pushInsteadOf`，推一个不会同步另一个。

## Directory
```
rtl/designs/      # RTL source      designs/       # Build outputs (GDSII, reports)
doc/              # Operators, ISA, EDA docs
wiki/             # CBB, coding style, protocols
spec/             # PRD, MAS, ARCH
libs/             # ASAP7 PDK (symlink)
.omp/agents/      # 5 bba-* orchestrators   .omp/skills/<name>/SKILL.md  # bb-* tools
.omp/commands/    # slash trampolines      .omp/hooks/{pre,post}/       # Enforcement hooks
.omp/schemas/     # Inter-stage JSON schemas
.omp/references/  # tool_versions.md, asap7_corners.md, conventions.md
.omp/mcp.json     # project MCP servers (babel-lsp, agentic-logger)
```

## Agents vs Skills vs Commands
- **Agents** (`.omp/agents/bba-*.md`): task subagents，按名派发（`task` 工具）或
  `/bba-architect`、`/bba-guru-rtl` 等 slash 入口。frontmatter 为 omp 方言：
  `tools: [read, write, edit, grep, bash, todo]`；`model` 用 role alias（`"@slow"` / `"@default"`，
  由 `config.yml` 的 `modelRoles` 解析）。
- **Skills** (`.omp/skills/<name>/SKILL.md`): 单用途工具（如 `bb-invoke-yosys`、`bb-check-lint`、
  `bb-create-sdc`、`bb-gate`）。omp 无 `Skill` 工具，按 `read skill://<name>` 加载并执行其脚本。
- **Commands** (`.omp/commands/*.md`): 薄 trampoline，暴露 `/bba-*`、`/bb-*` slash。
- **Hooks** (`.omp/hooks/pre/*.js`): omp extension 形态（`pi.on(...)`），桥接 `hooks/scripts/bb-hook-*.sh`。

## EDA Toolchain
**Canonical versions**: `.omp/references/tool_versions.md`

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
Liberty (.lib), LEF layouts. Corners: `.omp/references/asap7_corners.md`
