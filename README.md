# Babel

这是一个开源的AI原生Chiplet设计流程，基于开源EDA工具链和AI Coding Agent

清华大学集成电路学院芯粒设计实践课开发环境 (Tsinghua University School of Integrated Circuits, Chiplet Design Practice Course Environment).

## 项目级 Agent / Skill 系统

Babel 采用 5-agent 流水线架构，每个 agent 专注于特定设计阶段，通过 issue handoff 协作。

### Agent 流水线

```
用户需求 → [bba-architect] → bba-guru-rtl → bba-guru-verification → bba-guru-synthesis → bba-guru-pd → signoff
              ↑_________________________*-needs-fix 回流__________________________|
```

| Agent | 触发方式 | 职责 |
|-------|----------|------|
| `/bba-architect` | 新设计想法 / `arch-needs-fix` | PRD → arch_spec → MAS，架构设计流程负责人 |
| `/bba-guru-rtl` | `ready-for-rtl` / `rtl-needs-fix` | MAS → lint-clean SystemVerilog，RTL生成专家 |
| `/bba-guru-verification` | `ready-for-verification` | 100% 覆盖率验证，验证专家 |
| `/bba-guru-synthesis` | `ready-for-synth` / `synth-needs-fix` | SDC + CDC + 并行综合 → timing closure |
| `/bba-guru-pd` | `ready-for-pd` / `pd-rework` | Floorplan → Place → Route → DRC/LVS → GDSII |

### 使用方法

**启动新设计**：
```bash
# 在 Claude Code 中描述设计需求
/bba-architect
# 例如: "设计一个 UART16550 控制器，目标频率 100MHz，使用 ASAP7 PDK"
```

**继续现有设计**：
```bash
# 查看当前状态
/bb-list-issues

# 触发特定阶段
/bba-guru-rtl      # RTL 生成
/bba-guru-verification  # 验证
/bba-guru-synthesis     # 综合
/bba-guru-pd      # 物理设计
```

### 关键 Skill 分类

| 类别 | Skill | 用途 |
|------|-------|------|
| **EDA 工具** | `/bb-invoke-yosys` | 并行综合 (LLM驱动5-Phase) |
| | `/bb-invoke-verilator` | 仿真 + 覆盖率收集 |
| | `/bb-invoke-opensta` | 静态时序分析 |
| | `/bb-invoke-magic` | Placement + DRC |
| | `/bb-invoke-netgen` | LVS 比对 |
| | `/bb-invoke-qrouter` | 详细布线 |
| | `/bb-invoke-klayout` | GDSII 导出/验证 |
| | `/bb-invoke-abc` | 逻辑优化 |
| **质量检查** | `/bb-check-lint` | verible lint (含修复迭代) |
| | `/bb-check-cdc` | CDC + RDC 检查 |
| | `/bb-spec-review` | MAS 对抗评审 |
| | `/bb-code-review` | RTL 代码审查 |
| **流程生成** | `/bb-rtl-coder` | MAS → SV 代码生成 |
| | `/bb-create-sdc` | MAS → SDC 约束 |
| | `/bb-generate-tb` | 测试平台生成 |
| | `/bb-create-verif-plan` | 验证计划 |
| | `/bb-create-floorplan` | Floorplan TCL |
| **质量门控** | `/bb-gate-rtl-quality` | RTL 交付检查 |
| | `/bb-gate-test-quality` | 验证交付检查 |
| | `/bb-gate-synth-quality` | 综合交付检查 |
| | `/bb-gate-pd-quality` | PD 交付检查 |
| **辅助工具** | `/bb-find-module-deps` | 模块依赖拓扑排序 |
| | `/bb-trace-signal-path` | 信号路径追踪 |
| | `/bb-collect-coverage` | 覆盖率数据收集 |
| | `/bb-search-protocol` / `/bb-search-cbb` | 协议/CBB 复用搜索 |
| **问题管理** | `/bb-create-issue` / `/bb-list-issues` / `/bb-close-issue` | Issue 协议 |

### 设计产物目录结构

```
designs/<name>/
├── idea/
│   └── parsed_idea.json      # 解析后的设计需求
├── PRD.md                    # 产品需求文档
├── arch_spec/
│   ├── arch_doc.md           # 架构文档
│   ├── data_flow.md          # 数据流
│   └── workflow.md           # 工作流
├── mas/
│   ├── mas.json              # 微架构规范 (schema-valid)
│   ├── fsm/                  # FSM 定义
│   ├── datapath/             # 数据通路
│   └── verif_plan_seed.md    # 验证计划种子
├── rtl/
│   ├── *.sv                  # SystemVerilog 源码
│   ├── file_list.f           # 拓扑排序文件列表
│   └── rtl_artifact.json     # RTL 交付产物
├── tb/
│   ├── *.sv / *.py           # 测试平台 / cocotb
├── verif/
│   ├── verification_plan.md  # 完整验证计划
│   └── test_cases.md         # 测试用例列表
├── sim_results/
│   ├── *.log / *.vcd         # 仿真结果
├── coverage.json             # 覆盖率数据
├── test_report.json          # 验证报告
├── constraints/
│   └ *.sdc                   # 时序约束
├── synth_parallel/
│   ├── synthesis_summary.json # 并行综合结果
│   └ <module>/netlist.v      # 网表
├── synth_report.json         # 综合报告
├── pd/
│   ├── floorplan.def         # Floorplan
│   ├── placed.def / routed.def
│   ├── drc_report.txt / lvs_report.txt
│   └── timing_signoff.json   # Post-PD STA
├── gdsii/
│   └ *.gds                   # 最终布局
├── pd_report.json            # PD 交付报告
├── .handoff/
│   ├── ready-for-*.md        # 各阶段 handoff
│   ├── fix_iter.json         # 修复迭代计数
│   └── global_fix_iter.json  # 全局计数
└── ADR/
    └ *.md                    # 架构决策记录
```

### Issue Handoff 协议

Agent 间通过 labeled issue 协作：

| Label | 含义 |
|-------|------|
| `ready-for-rtl` | MAS 完成，等待 RTL 生成 |
| `ready-for-verification` | RTL lint-clean，等待验证 |
| `ready-for-synth` | 100% 覆盖率通过，等待综合 |
| `ready-for-pd` | Timing closed，等待物理设计 |
| `signoff` | GDSII 完成，用户审核 |
| `arch-needs-fix` | MAS 问题，回流 architect |
| `rtl-needs-fix` | RTL 问题，回流 rtl guru |
| `synth-needs-fix` | 综合问题，回流 synthesis guru |
| `escalate-user` | 超出迭代限制，需用户决策 |

### 收敛与迭代限制

| Agent | 单阶段迭代限制 | 全局限制 |
|-------|----------------|----------|
| architect | — | 10 |
| rtl | lint 3 次 | 10 |
| verification | coverage 8 次 | 10 |
| synthesis | timing 6 次 | 10 |
| pd | total 8 次 (DRC 3 / LVS 2 / STA 3) | 10 |

超过限制时，agent 自动触发 `escalate-user` issue，停止并等待用户决策。

### 快速开始示例

```bash
# 1. 启动 Claude Code
claude-code

# 2. 描述设计需求
> 设计一个简化版 UART 控制器，支持 9600 baud，目标频率 50MHz，使用 ASAP7

# 3. 或显式触发 architect
> /bba-architect

# 4. architect 会依次生成 PRD → arch_spec → MAS
#    每阶段完成后暂停，等待用户确认

# 5. 确认后继续，直到 ready-for-rtl 开启

# 6. 触发 RTL 生成
> /bba-guru-rtl

# 7. 依次触发后续阶段...
```

## 环境设置

```bash
# 加载 EDA 环境
source ~/wrk/eda_opensources/eda_env.sh
```

## 技术栈

| 工具 | 版本 | 用途 |
|------|------|------|
| Yosys | 0.35 | RTL 综合 |
| ABC | latest | 逻辑优化 |
| OpenSTA | 2.2.0 | 静态时序分析 |
| Magic | 8.3.641 | Layout/DRC/LVS |
| Netgen | 1.5 | LVS 网表比对 |
| QRouter | 1.4 | 详细布线 |
| KLayout | 0.30.8 | GDSII 查看/DRC |
| Verilator | latest | Verilog 仿真 |
| verible | latest | SV lint |

## PDK

ASAP7 (Arizona State University 7nm PDK) — 开源预测性 7nm 工艺设计套件。

位置：`libs/asap7/`

| Library | 描述 |
|---------|------|
| asap7sc6t_26 | 6-track 标准单元库 |
| asap7sc7p5t_27 | 7.5-track 标准单元库 (r27) |
| asap7sc7p5t_28 | 7.5-track 标准单元库 (r28) |
| asap7_sram | SRAM 模型 |

