---
name: bb-generate-testcases
description: "把 test_points.json 转成可执行 testcase（每 TP 一个 SV task，按 category 生成定向激励 + 选择/边界/复位/CDC 变体），并产出 test_registry.json、test_cases.md 与运行脚本。触发场景：(1) testbench harness 生成后；(2) 补测试点后重生成；(3) 显式 /bb-generate-testcases。"
user-invocable: true
---

# bb-generate-testcases

## 职责

为每个测试点生成一个**可编译、可单独选择执行**的 SV task，并把 TP → task → coverage bin 的映射固化成 registry，供 `bb-invoke-verilator` 按点跑、`bb-collect-coverage` 对账。

- 调用者：`bba-guru-verification`
- 上游：`bb-extract-test-points`（TP）、`bb-generate-testbench`（harness + `tb_manifest.json` 端口表）
- 下游：`bb-invoke-verilator`（`+TC=<id>` 选择单点）、`bb-collect-coverage`
- 文件所有权：`tc_<module>.sv` / `test_registry.json` / `test_cases.md` / `run_tests.sh` 归本 skill，每次重生成整体覆写

## Input Args

| arg | type | required | 默认 | 说明 |
|-----|------|----------|------|------|
| `design_name` | string | true | — | — |
| `test_points` | path | true | `designs/<name>/verif/test_points.json` | — |
| `tb_dir` | path | true | `designs/<name>/tb/generated` | 必须含 `tb_manifest.json` |
| `modules` | csv | false | manifest 全部 | 只重生成指定模块的 `tc_*.sv` |

## 激励生成规则（按 category，确定性）

| category | 生成的 task 主体 |
|----------|------------------|
| `functional` | `drive_defaults(); apply_reset();` + 所有 ≤16 bit 输入 `$urandom` + 等 8 拍 + `sb_check(idx)` |
| `branch` | 上述基础上只随机化 selector 类输入（名字含 `mode/sel/prec/format/enable/start/valid`），其余保持默认 |
| `boundary` | 最宽输入先 `'1` 再 `'0`，各等 4 拍，两次 `sb_check(idx)` |
| `reset` | `apply_reset()` 后直接 `sb_check(idx)`（复位值必须可观测、无 X） |
| `cdc` | 16 拍内每拍随机化输入，再 `sb_check(idx)` |

所有 task 只能通过 harness API（`drive_defaults` / `apply_reset` / `sb_check` / `check_tp` / `mark_tp`）访问 DUT 信号；见 `bb-generate-testbench/references/tb_harness_contract.md`。

## Output Contract

| field | 值 |
|-------|----|
| `artifact_path` | `designs/<name>/verif/test_registry.json` |
| `tc_files` | list[path] |
| `testcases` | int（生成的 task 数） |
| `markdown_path` | `designs/<name>/verif/test_cases.md` |
| `runner` | `designs/<name>/tb/generated/run_tests.sh` |
| `lint_clean` | bool（重跑一次 verilator lint） |
| `valid` | bool |
| `error` | string\|null |

`test_registry.json` 单条：

```json
{
  "id": "TP-M00-003",
  "module": "M00_SystolicArray",
  "task": "tc_TP_M00_003",
  "priority": "HIGH",
  "category": "functional",
  "coverage_bin": "cg_M00_SystolicArray.cp_tp.tp_2",
  "stimulus": "randomize narrow inputs + 8 cycles",
  "check": "scoreboard compares DUT output against the golden model"
}
```

## 4-Phase 执行

### Phase 1 — 前置校验

`test_points.json.valid == true`；`tb_manifest.json` 存在且 `modules` 覆盖 TP 的模块（缺模块 → `skipped`，`valid=false`）。

### Phase 2 — 生成

```bash
uv run --no-project python .omp/skills/bb-generate-testcases/scripts/generate_testcases.py \
  --design-name <name> \
  --test-points designs/<name>/verif/test_points.json \
  --tb-dir designs/<name>/tb/generated [--modules M00,M01]
```

### Phase 3 — lint

对受影响模块重跑 `verilator --lint-only`（`tc_<module>.sv` 被 `tb_<module>.sv` include）。任何 `%Error` → `lint_clean=false`。

### Phase 4 — 返回

`valid = (lint_clean and 每个 TP 都有 task)`；通过后交给 `bb-invoke-verilator` 逐点仿真。

## 运行方式

```bash
bash designs/<name>/tb/generated/run_tests.sh                 # 全部模块全部 TP
bash designs/<name>/tb/generated/run_tests.sh M13_ISADecoder  # 单模块
bash designs/<name>/tb/generated/run_tests.sh M13_ISADecoder TP-M13-001   # 单点
```

## 收敛 / 失败

| 状态 | 行动 |
|------|------|
| valid=true | 进 `bb-invoke-verilator` |
| TP 的模块无 harness | 先回 `bb-generate-testbench` 生成该模块，再重跑本 skill |
| 生成后 lint 失败 | 修生成器模板后重跑（不手改 `tc_*.sv`，会被覆写） |
| 仿真 `[FAIL]` | 单点复现命令已由 runner 给出：`run_tests.sh <module> <TP>` |

## 资源索引

- `scripts/generate_testcases.py` — 生成器（零第三方依赖）
- `references/case_patterns.md` — 各 category 的激励范式与常见坑
