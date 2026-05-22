## Project Overview
开源 AI 原生 Chiplet 设计流程，基于开源 EDA 工具链和 AI Coding Agent。


## Git Remotes

| Remote | URL | 用途 |
|--------|-----|------|
| origin | gitlink.org.cn/amoslee2011/Babel.git | 主仓库 |
| github | github.com/amoslee2026/Babel.git | 镜像 |

`git push origin` 会同步推送到两边。

## Directory Structure

```
Babel/
  rtl/                # RTL 设计源码
    designs/          # 设计项目 (NPU_top, tinystories_npu)
  designs/            # 设计输出 (GDSII, 报告)
  doc/                # 文档
    operators/        # 箔子文档 (attention, matmul, rmsnorm, rope)
    isa/              # NPU 指令集
    eda/              # EDA 工具文档
  wiki/               # 知识库
    cbb/              # Common Building Blocks
    codingstyle/      # 编码规范
    protocols/        # 协议文档
  spec/               # 规范文档 (PRD, MAS, ARCH)
  harness_spec/       # Agent harness 规范
  libs/               # 技术库 (ASAP7) - symlink
  llama2.c/           # llama2.c 子项目
  .claude/            # Claude Code 配置
    skills/           # 自定义 Skills (bb-* 系列)
```

## EDA Toolchain

| Tool | Version | Function |
|------|---------|----------|
| Yosys | 0.35 | RTL synthesis |
| OpenSTA | 2.2.0 | Static timing analysis |
| Magic | 8.3.641 | Layout/DRC/LVS |
| Netgen | 1.5 | LVS netlist comparison |
| QRouter | 1.4 | Detailed routing |
| KLayout | 0.30.8 | GDSII viewer/DRC |
| Verilator | latest | Verilog simulation |

Environment: `source ~/wrk/eda_opensources/eda_env.sh`

## Technology Library: ASAP7

7nm PDK at `libs/asap7/`:
- asap7sc6t_26 (6-track)
- asap7sc7p5t_27/28 (7.5-track)
- Liberty (.lib), LEF layouts

## Skills

Babel Skills (`.claude/skills/bb-*`):
- `/bba-architect` - 架构设计流程 (PRD → ARCH → MAS)
- `/bba-guru-rtl` - RTL 生成
- `/bba-guru-verification` - 验证流程
- `/bba-guru-synthesis` - 综合流程
- `/bba-guru-pd` - Physical Design 流程

