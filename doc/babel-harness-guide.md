# Babel AI-Native Chiplet 设计流程 — Harness 使用指南

> 版本：v1.3 MVP | 更新：2026-05-17

---

## 一、总览

Babel Harness 是一套运行在 Claude Code 之上的 AI 原生芯片设计自动化框架，由 **5 个 Agent**、**34 个 Skill** 和 **10 个 Hook** 组成，覆盖从自然语言设计想法到 GDSII 版图的完整流水线。

```
设计想法
   │
   ▼
[bb-architect] ──bb-prd/bb-arch/bb-mas──► MAS
   │
   ▼
[bb-guru-rtl] ──bb-rtl-coder──► SystemVerilog RTL
   │
   ▼
[bb-guru-verification] ──verilator──► 100% Coverage
   │
   ▼
[bb-guru-synthesis] ──yosys/opensta──► 时序收敛网表
   │
   ▼
[bb-guru-pd] ──magic/qrouter/klayout──► GDSII
```

---

## 二、Agents（流水线负责人）

每个 Agent 是流水线中某阶段的**唯一责任人**，拥有该阶段的完整工作流定义。

| Agent | 颜色 | 模型 | 职责 | 触发方式 |
|-------|------|------|------|---------|
| `bb-architect` | 品红 | Opus | 将自由格式设计想法转化为 PRD→arch→MAS，交棒 RTL | 用户输入新设计想法；`arch-needs-fix` issue；`/bb-architect` |
| `bb-guru-rtl` | 蓝 | Sonnet | 消费 MAS，产出层次化 lint-clean SystemVerilog | `ready-for-rtl` 存在；`rtl-needs-fix`；`/bb-guru-rtl` |
| `bb-guru-verification` | 绿 | Sonnet | 生成 TB，驱动覆盖率到 100%，门禁综合 | `ready-for-verification`；`/bb-guru-verification` |
| `bb-guru-synthesis` | 青 | Sonnet | 生成 SDC，运行 CDC/RDC，Yosys 综合 + OpenSTA 时序收敛 | 覆盖率 100% 且 `ready-for-synth`；`synth-needs-fix`；`/bb-guru-synthesis` |
| `bb-guru-pd` | 红 | Sonnet | Floorplan→Place→Route→DRC→LVS→post-STA→GDSII | `ready-for-pd`（WNS≥0）；DRC 超限；`/bb-guru-pd` |

### Agent 调用方式

```bash
# 直接调用（slash command）
/bb-architect
/bb-guru-rtl
/bb-guru-verification
/bb-guru-synthesis
/bb-guru-pd

# 带路径参数
/bb-architect designs/uart16550
/bb-guru-pd designs/axi_bridge
```

### 流水线交接（Handoff）协议

Agent 间通过 **labeled handoff** 传递控制权，v1.3 MVP 使用文件系统实现：

```
designs/<name>/.handoff/<label>.md
```

标准 labels（正向）：
`ready-for-rtl` → `ready-for-verification` → `ready-for-synth` → `ready-for-pd` → `signoff`

反向修复 labels：
`arch-needs-fix` | `rtl-needs-fix` | `synth-needs-fix` | `pd-rework` | `escalate-user`

> **v1.3 MVP 限制**：`pipeline-advance.sh` 只打印下一步命令提示，**不自动 dispatch**，需用户手动调用。

---

## 三、Skills（原子能力）

Skills 是 Agent 调用的原子工具，分为 8 大类。

### 3.1 规格设计类（ic-* 系列）

这四个 skill 构成 Babel 规格链，由 `bb-architect` 驱动，也可用户独立调用。

| Skill | 用户可调用 | 职责 | 输入 | 输出 |
|-------|-----------|------|------|------|
| `bb-prd` | ✅ | 生成芯片/IP 产品需求文档 | idea 目录 | `prd.md` |
| `bb-arch` | ✅ | 生成架构规格文档 | idea 目录 | `arch_spec/` |
| `bb-mas` | ✅ | 生成微架构文档（FSM/Datapath/验证计划/DFT） | `arch_spec/` | `mas.json` |
| `bb-rtl-coder` | ✅ | 根据 MAS 生成可综合 SystemVerilog | `mas.json` | `rtl/*.sv` |

```bash
/bb-prd input_dir=./harness_spec/idea
/bb-arch idea_dir=./harness_spec/idea
/bb-mas project_dir=./designs/uart
/bb-rtl-coder project_dir=./designs/uart module_id=M01
```

### 3.2 知识库检索类

| Skill | 职责 | 调用方 |
|-------|------|--------|
| `bb-search-protocol` | 在 `wiki/protocols/` 搜索协议文档（UART/AXI/UCIe 等） | `bb-architect` |
| `bb-search-cbb` | 在 `wiki/cbb/` 搜索可复用 CBB（sync-fifo/2ff-sync/clock-gate 等） | `bb-architect` |
| `bb-get-interface-template` | 解析 CBB/协议 wiki 的端口表，返回结构化 JSON 接口模板 | `bb-architect` |

### 3.3 RTL 静态分析类

| Skill | 职责 | 调用方 |
|-------|------|--------|
| `bb-parse-ast` | 用 pyverilog 解析 RTL → AST JSON（主解析器） | synthesis / cdc / trace / deps |
| `bb-parse-ast-fallback` | pyverilog 失败时切换 verible/slang，输出同 schema（对下游透明） | `bb-parse-ast` 失败时自动触发 |
| `bb-trace-signal-path` | AST 上 DFS 追踪 source→sink，标记 CDC 路径 | `bb-guru-synthesis`, `bb-check-cdc` |
| `bb-find-module-deps` | 扫 RTL 构建模块依赖图，Kahn 拓扑排序写 `file_list.f` | `bb-guru-rtl` |

### 3.4 EDA 工具调用类

| Skill | 工具 | 版本 | 职责 | 调用方 |
|-------|------|------|------|--------|
| `bb-invoke-yosys` | Yosys | 0.35 | RTL 综合 → ASAP7 门级网表 + QoR 报告 | `bb-guru-synthesis` |
| `bb-invoke-abc` | ABC | latest | 高难度逻辑优化（常规综合由 yosys 内嵌 ABC 完成，此 skill 用于 high-effort 调优） | `bb-guru-synthesis` |
| `bb-invoke-opensta` | OpenSTA | 2.5.0 | 综合后 STA；PD 后多 PVT corner + SPEF signoff | synthesis + pd |
| `bb-invoke-verilator` | Verilator | 5.012 | RTL+TB 编译仿真，产出 coverage.dat/sim log/VCD | `bb-guru-verification` |
| `bb-invoke-magic` | Magic | 8.3.641 | Floorplan / Place / DRC / Extract SPICE（四种 action） | `bb-guru-pd` |
| `bb-invoke-qrouter` | QRouter | 1.4 | Placed DEF 详细布线 → routed DEF | `bb-guru-pd` |
| `bb-invoke-klayout` | KLayout | 0.30.8 | DEF→GDSII 导出 / GDS 层 DRC | `bb-guru-pd` |
| `bb-invoke-netgen` | Netgen | 1.5.275 | LVS：综合网表 vs Magic 提取 SPICE，必须 match | `bb-guru-pd` |

### 3.5 验证与约束生成类

| Skill | 职责 | 调用方 |
|-------|------|--------|
| `bb-create-verif-plan` | 将 `verif_plan_seed.md` 扩展为完整验证计划（6 个必备 section） | `bb-guru-verification` |
| `bb-generate-tb` | 生成 SV UVM 或 cocotb TB + per-FTP sequence + covergroup | `bb-guru-verification` |
| `bb-collect-coverage` | 解析 coverage.dat + sim log，输出 line/branch/toggle/functional 数值 | `bb-guru-verification` |
| `bb-check-lint` | verible-verilog-lint，零 error 才通过，不允许 waive | `bb-guru-rtl` |
| `bb-check-cdc` | 对比 MAS clock_domains，检查跨域信号是否经 2ff-sync 保护 | `bb-guru-synthesis` |
| `bb-create-sdc` | 从 MAS clock_domains/io_timing/path_exceptions 生成 SDC，OpenSTA 校验 | `bb-guru-synthesis` |
| `bb-create-floorplan` | 从 MAS IO ring + clock plan 生成 Magic floorplan TCL | `bb-guru-pd` |

### 3.6 质量门禁类

这四个 skill 是各阶段的**强制通过点**，pass 才允许创建 handoff 推进流水线。

| Skill | 检查项 | 通过条件 | 调用方 |
|-------|--------|---------|--------|
| `bb-gate-rtl-quality` | lint 结果 + file_list 拓扑序 + rtl_artifact schema | lint 0 error，schema 合法 | `bb-guru-rtl` |
| `bb-gate-test-quality` | functional/line/branch/toggle coverage + assertion | 全部 100%，无断言失败 | `bb-guru-verification` |
| `bb-gate-synth-quality` | WNS + Area + CDC | WNS≥0，Area<1.2×baseline，CDC clean | `bb-guru-synthesis` |
| `bb-gate-pd-quality` | DRC + LVS + post-PD STA + GDS 文件存在 | 四项全部通过 | `bb-guru-pd` |

### 3.7 评审类

| Skill | 角色选项 | 职责 | 调用方 |
|-------|---------|------|--------|
| `bb-spec-review` | ruthless（默认）/ linus / balanced | PRD↔arch↔MAS 跨文档一致性、完整性、可实现性 | `bb-architect` |
| `bb-code-review` | — | RTL 质量/可维护性/时序风险/综合友好度/MAS 对齐 | `bb-guru-rtl` |
| `bb-challenge-code` | ruthless / linus / balanced | 通用对抗性评审（任何 agent 均可调用，压力测试重大改动） | 所有 agent |

### 3.8 Issue 管理类

| Skill | 职责 |
|-------|------|
| `bb-create-issue` | 写 `designs/<name>/.handoff/<label>.md`；`gh` 在 PATH 时同步创建 GitHub issue |
| `bb-list-issues` | 列出 `designs/*/.handoff/*.md`，可按 label 过滤 |
| `bb-close-issue` | 归档 handoff 文件，可选关闭 GitHub issue |

---

## 四、Hooks（自动化守护）

Hooks 在工具调用前后静默运行，分为警告（非阻断）和阻断两类。

| Hook | 类型 | 阻断性 | 触发条件 | 作用 |
|------|------|--------|---------|------|
| `validate-bash-cmd.sh` | PreToolUse/Bash | 警告 | 任何 bash 命令 | 检测 `rm -rf`/`sudo`/`chmod 777` 等危险模式 |
| `write-arch-freeze-check.sh` | PreToolUse/Write | 警告 | 写 `designs/*/rtl/*` 或 `mas/*` | MAS 已冻结时（存在 ready-for-rtl handoff）发出警告 |
| `instantiate-cbb-search.sh` | PreToolUse/Write | 警告 | 写入含 sync-fifo/2ff-sync/clock-gate 的代码 | 提示先调用 `bb-search-cbb` 获取标准接口 |
| `validate-wiki.sh` | PreToolUse/Read | 警告 | 读取 `wiki/**` 文件 | 校验 frontmatter content_hash，检测内容篡改 |
| `commit-quality-gate.sh` | PreToolUse/Bash | **阻断** | `git commit` | RTL/综合文件变更时，要求对应 `quality_gate_*.json` pass=true |
| `validate-input-schema.sh` | Agent 启动 | **阻断** | Agent 启动时 | 验证上游 artifact JSON schema，失败则创建 needs-fix handoff |
| `change-propagate.sh` | PostToolUse/Write | 通知 | 写 `mas.json`/`rtl_artifact.json`/`test_report.json` | 标记下游 artifact 为 stale，提醒重新生成 |
| `create-fix-issue.sh` | PostToolUse | 通知 | Agent 输出 `valid=false` 且含特定错误关键字 | 自动创建 `<upstream>-needs-fix` handoff |
| `pipeline-advance.sh` | PostToolUse/Write | 通知 | 写 `.handoff/<label>.md` | 打印下一阶段对应的 slash command |
| `session-summarize.sh` | SessionEnd | 通知 | 会话结束 | 生成本次涉及 design 和 handoff 的摘要到 `.claude/session_summaries/` |

---

## 五、相互依赖关系

```
bb-architect
  ├─ uses: bb-prd, bb-arch, bb-mas
  ├─ uses: bb-search-protocol, bb-search-cbb → bb-get-interface-template
  ├─ uses: bb-spec-review, bb-challenge-code
  └─ emits: ready-for-rtl ──────────────────────────────► bb-guru-rtl

bb-guru-rtl
  ├─ uses: bb-rtl-coder
  ├─ uses: bb-find-module-deps
  ├─ uses: bb-check-lint
  ├─ uses: bb-code-review, bb-challenge-code
  ├─ uses: bb-gate-rtl-quality
  └─ emits: ready-for-verification ────────────────────► bb-guru-verification

bb-guru-verification
  ├─ uses: bb-create-verif-plan
  ├─ uses: bb-generate-tb
  ├─ uses: bb-invoke-verilator → bb-collect-coverage
  ├─ uses: bb-gate-test-quality
  └─ emits: ready-for-synth ───────────────────────────► bb-guru-synthesis

bb-guru-synthesis
  ├─ uses: bb-parse-ast (→ fallback: bb-parse-ast-fallback)
  ├─ uses: bb-check-cdc → bb-trace-signal-path
  ├─ uses: bb-create-sdc
  ├─ uses: bb-invoke-yosys (→ high-effort: bb-invoke-abc)
  ├─ uses: bb-invoke-opensta
  ├─ uses: bb-gate-synth-quality
  └─ emits: ready-for-pd ──────────────────────────────► bb-guru-pd

bb-guru-pd
  ├─ uses: bb-create-floorplan
  ├─ uses: bb-invoke-magic (floorplan/place/drc/extract)
  ├─ uses: bb-invoke-qrouter
  ├─ uses: bb-invoke-klayout (export/drc)
  ├─ uses: bb-invoke-netgen (LVS)
  ├─ uses: bb-invoke-opensta (post-PD multi-corner + SPEF)
  ├─ uses: bb-gate-pd-quality
  └─ emits: signoff ───────────────────────────────────► 用户确认 GDS

共享 skills（任何 agent 可调用）:
  bb-create-issue / bb-list-issues / bb-close-issue
  bb-challenge-code
```

---

## 六、典型工作流程

### 场景 A：全流程新设计（Happy Path）

```bash
# Step 1: 架构设计
/bb-architect
# 用户描述: "设计 AXI4-Lite 到 APB 桥，500MHz，ASAP7"
# → designs/axi_apb/mas/mas.json + .handoff/ready-for-rtl.md
# → pipeline-advance.sh 提示: /bb-guru-rtl

# Step 2: RTL 生成
/bb-guru-rtl
# → designs/axi_apb/rtl/*.sv + file_list.f
# → lint clean → bb-gate-rtl-quality PASS
# → .handoff/ready-for-verification.md

# Step 3: 验证（覆盖率驱动）
/bb-guru-verification
# → 生成 TB → verilator 仿真 → 多轮迭代
# → bb-gate-test-quality PASS（100% coverage）
# → .handoff/ready-for-synth.md

# Step 4: 逻辑综合
/bb-guru-synthesis
# → CDC check → 生成 SDC → yosys 综合 → opensta STA → 时序收敛
# → bb-gate-synth-quality PASS
# → .handoff/ready-for-pd.md

# Step 5: 物理设计
/bb-guru-pd
# → floorplan → place → route → DRC → LVS → post-STA
# → bb-gate-pd-quality PASS
# → .handoff/signoff.md → 用户确认 GDS
```

### 场景 B：架构缺陷修复（回溯到 Architect）

```bash
# bb-guru-rtl 发现 MAS 中 FIFO depth 定义有误
# → 创建 .handoff/arch-needs-fix.md

/bb-architect designs/axi_apb
# → 读取 arch-needs-fix 内容，修订 MAS
# → 重新发布 ready-for-rtl
```

### 场景 C：覆盖率卡住（Verification 迭代）

```bash
# fc=98%，已经 7 次迭代
/bb-guru-verification designs/axi_apb
# iter 8: 尝试补 constrained-random seed
# 若仍无法达到 100% → 评估是否为 unreachable bin
# 若 unreachable → 创建 arch-needs-fix（存在不可达 FSM 分支）
```

### 场景 D：PD 时序回溯（回溯到 Synthesis）

```bash
# PD post-route WNS < 0 → bb-guru-pd 创建 synth-needs-fix

/bb-guru-synthesis designs/axi_apb
# → 修订 SDC（添加 false_path / multicycle_path）
# → 重新 yosys + opensta 收敛
# → 重新发布 ready-for-pd
```

### 场景 E：独立使用规格工具

```bash
# 只做规格设计，不跑完整流水线
/bb-prd input_dir=./harness_spec/idea
/bb-arch idea_dir=./harness_spec/idea
/bb-mas project_dir=./designs/myip
/bb-rtl-coder project_dir=./designs/myip module_id=all
```

---

## 七、设计目录结构

```
designs/<design_name>/
├── .handoff/               # Agent 间交接文件（流水线状态）
│   ├── ready-for-rtl.md
│   ├── ready-for-verification.md
│   └── signoff.md
├── mas/
│   ├── mas.json            # 规范化 MAS（bb-architect 产出）
│   └── verif_plan_seed.md
├── rtl/
│   ├── *.sv                # SystemVerilog 源码
│   └── file_list.f         # 拓扑排序的文件列表（叶模块在前）
├── tb/
│   └── tb_top.sv           # 测试平台顶层
├── synth/
│   ├── netlist.v           # 门级网表
│   └── design.sdc          # 时序约束
├── pd/
│   └── routed.def          # 布线后 DEF
├── gdsii/
│   └── *.gds               # 最终签核产物
├── rtl_artifact.json       # RTL 阶段 artifact（schema 校验用）
├── test_report.json        # 验证覆盖率报告
├── synth_report.json       # 综合 QoR 报告（含 WNS/TNS/Area）
└── quality_gate_*.json     # 各阶段质量门结果（pass/fail）
```

---

## 八、v1.3 MVP 已知限制

| 限制 | 说明 |
|------|------|
| 手动流水线推进 | `pipeline-advance.sh` 只提示命令，不自动 dispatch（v1.4 规划） |
| GitHub issue 为可选 | `bb-create-issue` 优先写文件系统 handoff，`gh` 可用时才同步 |
| AST 解析器 | pyverilog 为主，高级 SV 语法失败时自动切 verible/slang |
| 仅开源 EDA | 全流程依赖 Yosys/Magic/QRouter/KLayout/Netgen/OpenSTA/Verilator，无商业工具依赖 |
| 工艺库 | 固定 ASAP7 PDK（7nm 预测工艺） |
