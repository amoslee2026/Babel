---
name: babel-user-manual
description: Babel 用户使用手册 — 从环境准备到端到端流程
type: arch_spec
version: 1.0.0
created: 2026-05-16
related:
  - functional_specification.md
  - architecture_specification.md
  - ADR/ADR-A01.md
---

# Babel 用户手册

> 面向 Babel 终端用户（芯片设计工程师 / 学生）。覆盖从安装、启动、端到端设计、失败恢复全过程。

---

## 1. 环境准备

### 1.1 系统要求

| 项 | 版本 |
|----|------|
| OS | Linux (RHEL/CentOS 8 / Ubuntu 22.04+) |
| Python | 3.6.8+ |
| Claude Code | 已安装并配置 |
| claude-mem 插件 | 已启用（详见 ADR-007） |

### 1.2 EDA 工具链 (open-source)

```bash
source ~/wrk/eda_opensources/eda_env.sh
```

启动期 hook `babel-hook-session-sync-state` 自动验证版本（详见 design_doc §6.2）。

### 1.3 PDK

```bash
export ASAP7_LIB=~/wrk/Babel/libs/asap7
```

---

## 2. 启动 Babel（解决 v1.1-issue H1）

### 2.1 调用方式：Claude Code 斜杠命令

Babel 通过 Claude Code 的 **slash command** 启动，**无独立 CLI 二进制**（见 ADR-A01）。

```
/babel-design <design_name> "<requirements_prompt>"
```

**示例**：

```
/babel-design uart "UART tx/rx, 115200 baud, 8N1, AXI4-Lite slave config, single clock domain @100MHz"
```

斜杠命令实现位置：`commands/babel-design.md`（Phase 1 实施时落地）。

### 2.2 命令执行步骤

| 步骤 | 行为 |
|------|------|
| 1 | 校验 ASAP7 路径 / EDA 版本 / claude-mem 状态 |
| 2 | 获取 `${OUTPUT_DIR}/.babel_session.lock`（多实例排斥，ADR-A06） |
| 3 | 派发首个 subagent `babel-spec`（input = idea schema 包装的用户 prompt） |
| 4 | 初始化 `design_state.json`，分配 `design_id` (UUIDv7) |
| 5 | 进入 fix_request 闭环直至 signoff 或 max_iter |

---

## 3. 端到端流程示例（UART）

参见 `workflow_diagrams.md` §1 完整序列图。简略列表：

| Step | Agent | Skill | 产物 |
|------|-------|-------|------|
| 1 | babel-spec | babel-plan-spec | PRD.md, spec.json |
| 2 | babel-coord | — | state.json 更新 |
| 3 | babel-rtl | babel-generate-rtl, babel-check-lint | rtl/*.sv, constraints/*.sdc (草稿) |
| 4 | babel-cdc | babel-parse-ast, babel-check-cdc | cdc_report.json |
| 5 | babel-synth | babel-invoke-yosys | synth/netlist.v, qor.json |
| 6 | babel-test | babel-generate-tb, babel-invoke-verilator, babel-collect-coverage | tb/*.sv, coverage.json |
| 7 | babel-coord | — | fix_request 闭环（必要时） |
| 8 | babel-coord | — | final signoff |

---

## 4. 输出产物路径

```
<project_root>/
├── designs/<design_name>/         # 用户设计输出根目录
│   ├── PRD.md
│   ├── spec.json
│   ├── ADR-*.md
│   ├── rtl/                       # SV/Verilog + SDC
│   ├── tb/                        # Testbench
│   ├── sim_results/               # 仿真日志 + VCD/FST
│   ├── synth/                     # 网表 + QoR
│   ├── cdc_report.json
│   ├── coverage.json
│   └── design_state.json          # 实时状态（单写者）
├── ${OUTPUT_DIR}/events/<sid>-*.jsonl   # append-only event log
├── ${OUTPUT_DIR}/state/.babel_session.lock
└── halt_report.md                 # 仅 max_iter halt 时存在
```

---

## 5. 查看波形（解决 v1.1-issue 范围澄清）

Babel **不**封装波形查看（ADR-008）。仿真生成的 `*.vcd` / `*.fst` 用 VSCode 扩展查看：

| 推荐扩展 | 适用 |
|---------|------|
| WaveTrace | VCD/FST 通用 |
| Surfer-vscode | 大文件友好 |
| SystemVerilog by mshr-h | SV/UVM 项目导航 |

打开方式：在 VSCode 中 `Open File` 选择 `sim_results/*.vcd`。

---

## 6. 失败处理与升级（解决 v1.1-issue M8）

### 6.1 自动 fix_request 闭环

下游 agent 检测到失败（如 coverage < 95%）→ 自动写 fix_request → coord 重排上游 agent 重做。
用户无需干预，但可通过 tail state.json 观察：

```bash
watch -n 5 'jq ".cross_domain_iteration_count, .babel_fix_requests[].summary" designs/uart/design_state.json'
```

### 6.2 max_iter 升级（design_doc §10.4）

`on_max_iter_reached` 三种行为：

| 值 | 用户体验 |
|----|---------|
| `halt` | Babel 终止，写 `halt_report.md`；用户阅读后决定下一步 |
| `escalate_user` | Babel 暂停；`state.pending_approval` 写入决策需求；**stderr 横幅** 提示用户 |
| `force_signoff` | 仅 manual override，强制结束（高风险） |

默认 `escalate_user`。用户响应方式：

```
/babel-respond <design_name> --action retry        # 重启当前 fix_request 闭环
/babel-respond <design_name> --action abort        # 终止设计
/babel-respond <design_name> --action manual-fix   # 暂停 babel，用户手动改 RTL/TB，完成后 commit
```

### 6.3 stderr 横幅样例

```
================================================================
 ⚠ Babel: pending_approval (design=uart, design_id=01HW2K..., iter=5/3)
   Reason: coverage 87% < 95% after max iterations
   Respond with: /babel-respond uart --action {retry|abort|manual-fix}
================================================================
```

---

## 7. 中途手动修改 RTL（解决 v1.1-issue M10 / F016）

用户可在 fix_request 闭环外手工修改产物：

```bash
vim designs/uart/rtl/uart_tx.sv
```

Coordinator 在每次 Phase 重新启动前对 rtl/ 内文件做 SHA256 比对：
- **同 hash** → 沿用 state 中现有信号位
- **不同 hash** → 视为外部修改：(a) state.last_writer 标 `user`，(b) 重跑下游 (cdc/synth/test)，(c) 若同一 fix_request 反复手工改 → 触发 escalate_user

> **限制**：用户修改未通过 schema 验证的产物会被 schema_validator 阻断（详见 F009）。

---

## 8. 多会话冲突（解决 v1.1-issue H7）

同 design_id 同时启动两个 Babel 会话 → 第二实例检测到活跃 `.babel_session.lock` (含 PID + 启动 ts) → abort：

```
Error: Babel session already active for design "uart"
  Lock holder PID:    12345  (still running)
  Acquired at:        2026-05-16T17:00:00+08:00
  Lock file:          ${OUTPUT_DIR}/state/.babel_session.lock
  Action: wait for completion, or kill PID 12345 to release.
```

详见 ADR-A06。

---

## 9. 常见问题

### Q: 如何看 Babel 当前在执行哪个 agent？

```bash
jq '.last_writer, .updated_at' designs/uart/design_state.json
tail -f ${OUTPUT_DIR}/events/$(jq -r .babel_session_id designs/uart/design_state.json)-*.jsonl
```

### Q: claude-mem 出错怎么办？

(F011 / ADR-A04) Babel 降级 stateless 模式，stderr 警告：

```
⚠ claude-mem unavailable; cross-session memory disabled.
  Continuing in stateless mode. Past design experiences won't be referenced.
```

设计依然可完成，但 agent 不能从历史失败中学习。

### Q: NFS 上能跑吗？

(ADR-A03) 使用 sqlite-based state lock 替代 flock，**支持 NFS**。但建议本机 SSD 跑 EDA 工具以获得性能。

### Q: 如何卸下不想要的 agent / skill？

修改 `agents/<agent>.yaml` `tools:` 列表（移除 Bash → 软声明，参考 ADR-010 提示）；
或在 Claude Code settings 禁用对应 agent。系统不允许移除 P0 agent (spec/rtl/test/coord) — 启动会报错。

---

## 10. 关联文档

| 路径 | 用途 |
|------|------|
| `functional_specification.md` | F001-F016 完整需求 |
| `architecture_specification.md` | M-IDs 模块定义 |
| `workflow_diagrams.md` | 端到端 + 失败处理 Mermaid 序列图 |
| `ADR/ADR-A01.md` | CLI 入口选型 |
| `ADR/ADR-A06.md` | Multi-session 锁设计 |
| `../idea/design_doc.md` | 完整 idea spec |
