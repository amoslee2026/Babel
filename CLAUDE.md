## Project Overview
这是一个开源的AI原生Chiplet设计流程，基于开源EDA工具链和AI Coding Agent

清华大学集成电路学院芯粒设计实践课开发环境 (Tsinghua University School of Integrated Circuits, Chiplet Design Practice Course Development Environment).

## System Environment

| Item | Version |
|------|---------|
| OS | Linux (RHEL/CentOS 8) |
| Python | 3.6.8 |
| GCC | 8.5.0 |
| Make | 4.2.1 |

## Directory Structure

```
sjk2026/
  CLAUDE.md           # 项目指导文档
  .claude/            # Claude Code 配置
  doc/                # 文档
    operators/        # 算子文档 (attention, matmul, rmsnorm, rope, etc.)
    isa/              # NPU指令集
    eda/              # Open source EDA tools chain and documents
  llama2.c/           # llama2.c 子项目 (LLM inference in C)
    ARCHITECTURE.md
    model.py / main.py / export.py
    Makefile
  scripts/            # 安装脚本
    install-uv-system.sh
    install-rust-system.sh
    configure-rust-env.sh
  temp/               # 临时文件
    deleted/          # 已删除文件备份 (可恢复)
  utils/              # 工具目录
```

## Chiplet Design Context

### Open-Source EDA Toolchain

| Tool | Version | Function |
|------|---------|----------|
| Yosys | 0.35 | RTL synthesis |
| ABC | latest | Logic optimization |
| OpenSTA | 2.2.0 | Static timing analysis |
| Magic | 8.3.641 | Layout/DRC/LVS |
| Netgen | 1.5 | LVS netlist comparison |
| QRouter | 1.4 | Detailed routing |
| KLayout | 0.30.8 | GDSII viewer/DRC |
| Verilator | latest | Verilog simulation |

Environment setup:
```bash
source ~/wrk/eda_opensources/eda_env.sh
```

### Technology Library: ASAP7

ASAP7 (Arizona State University 7nm PDK) - Open-source predictive 7nm process design kit.

Location: `libs/asap7/`

| Library | Description |
|---------|-------------|
| asap7sc6t_26 | 6-track standard cell library |
| asap7sc7p5t_27 | 7.5-track standard cell library (r27) |
| asap7sc7p5t_28 | 7.5-track standard cell library (r28) |
| asap7_sram | SRAM models |

Key features:
- Standard cells with multiple drive strengths
- Metal stack: 7 layers (M1-M7)
- Liberty timing files (.lib), LEF layouts
- Synopsys enablement in `libs/ASAP7-Synopsys-Enablement/`

### Commercial Tools (Reference)

| Category | Tools |
|----------|-------|
| HDL | Verilog, SystemVerilog, VHDL |
| Simulation | VCS, Questa, ModelSim |
| Synthesis | Design Compiler, Vivado |
| Place & Route | Innovus, ICC2 |
| Verification | JasperGold, Formality |
| Interconnect | UCIe, AXI, AMBA |

## Notes

- 使用国内镜像源安装依赖
- 输出格式: 标准 Markdown 表格，避免 Unicode 特殊字符
