---
name: bb-generate-testbench
description: "按 test_points.json + RTL 端口生成可编译的 per-module SystemVerilog testbench harness（时钟/复位、DUT 实例化、check/scoreboard 钩子、覆盖率骨架、Verilator lint）。触发场景：(1) 测试点提取完成；(2) 显式 /bb-generate-testbench。"
user-invocable: true
---

# bb-generate-testbench

## 职责

只为**验证基础设施**负责：每个被测模块一份自包含 SV harness，能被 Verilator 直接 lint/编译；不含具体 testcase 激励（那是 `bb-generate-testcases` 的产物，会覆写 `tc_<module>.sv`）。

- 调用者：`bba-guru-verification`
- 上游：`bb-extract-test-points`（必需）、RTL 源（端口来源）、MAS（可选，仅 `clock_domains` 频率）
- 下游：`bb-generate-testcases`、`bb-invoke-verilator`
- 文件所有权：本 skill 拥有 `tb_*.sv` / `cov_*.sv` / `file_list.f` / `lint.sh`；`tc_*.sv` 只是首次占位，归 `bb-generate-testcases` 覆写

## Input Args

| arg | type | required | 默认 | 说明 |
|-----|------|----------|------|------|
| `design_name` | string | true | — | — |
| `mas` | path | true | `designs/<name>/mas/mas.json` | 端口/时钟来源 |
| `test_points` | path | true | `designs/<name>/verif/test_points.json` | 决定生成哪些模块 |
| `out_dir` | path | false | `designs/<name>/tb/generated` | 不覆盖手写 TB |
| `modules` | csv | false | 全部 | 仅生成指定模块 |
| `lint` | flag | false | on | 生成后跑 Verilator lint |

## Output Contract

| field | 值 |
|-------|----|
| `artifact_path` | `designs/<name>/tb/generated/` |
| `tb_files` | list[path] |
| `modules` | list[str] |
| `file_list` | path |
| `lint_clean` | bool |
| `lint_errors` | list[str]（前 20 条 `%Error` / `%Warning-PINMISSING`） |
| `valid` | bool |
| `error` | string\|null |

单模块产物：

```
tb/generated/
├── tb_<Module>.sv     # 时钟/复位、DUT 实例化、drive_defaults/apply_reset/check_tp、run_all() 调用
├── cov_<Module>.sv    # covergroup cg_<M>：仅 tp_hit 位图 bins（TP 是唯一对账单位）
├── tc_<Module>.sv     # 占位 run_all()（由 bb-generate-testcases 覆写）
├── rtl.f              # 仅设计 RTL（逐模块 lint/编译用）
├── file_list.f        # rtl.f + 全部 tb_<Module>.sv
├── lint.sh            # 逐模块 verilator --lint-only（含 PINMISSING 检查）
└── tb_manifest.json   # 文件/模块/端口/时钟/TP 映射清单
```

## 4-Phase 执行

### Phase 1 — 前置校验

`test_points.json.valid == true`；端口以 **RTL 源为准**（`file_list.f` 或 `rtl_artifact.json` 列出的文件），MAS 只提供时钟频率。MAS 与 RTL 模块名不一致时按 `Mxx` code 做 alias（如 `M11_RMSNormUnit` → `M11_RMSNormRoPE`），TB 文件仍用测试点里的模块名、DUT 实例用 RTL 真名。RTL 解析不到端口的模块记入 `skipped`（top wrapper 缺失属设计级缺口）；MAS 端口回退仅 `--allow-mas-ports` 显式开启，且不计入 signoff。

### Phase 2 — 生成

```bash
uv run --no-project python .omp/skills/bb-generate-testbench/scripts/generate_testbench.py \
  --design-name <name> --mas designs/<name>/mas/mas.json \
  --test-points designs/<name>/verif/test_points.json \
  --out-dir designs/<name>/tb/generated [--modules M00,M01] [--no-lint]
```

端口映射规则（确定性）：

| RTL port | TB 声明 | 驱动 |
|----------|---------|------|
| `dir=input` 且匹配 `clk` | `logic = 0` + `always #(T/2)` | MAS `clock_domains.freq_mhz`，未匹配 100 MHz |
| `dir=input` 且匹配 `rst` | `logic` | `apply_reset()`：低有效拉 0 两拍后置 1 |
| 其他 `dir=input` | `logic [W-1:0]` | `drive_defaults()` 置 0 |
| `dir=output/inout` | `logic [W-1:0]` | DUT 驱动（inout 由用例驱动） |

### Phase 3 — lint

`bash <out_dir>/lint.sh` → 逐模块 `verilator --lint-only -sv --timing -Wno-fatal -Werror-PINMISSING`。任何 `%Error` 或 `PINMISSING`（含 pin 名对不上、漏连）→ `lint_clean=false`，原样返回前 20 条。

### Phase 4 — 返回

`valid = (lint_clean and 生成文件齐全)`；通过则进 `bb-generate-testcases`。

## 收敛 / 失败

| 状态 | 行动 |
|------|------|
| lint_clean=true | 进 `bb-generate-testcases` |
| 端口缺失/空接口 | 输出 `skipped`，不生成该模块；`valid=false` |
| lint 报 `%Error` | 修正生成器映射后重跑 1 次（不手改产物，避免被下次覆盖） |
| 仍失败 | `error="tb lint failed: <first error>"`，人工介入 |

## 资源索引

- `scripts/generate_testbench.py` — 生成器（零第三方依赖）
- `references/tb_harness_contract.md` — harness API（`drive_defaults` / `apply_reset` / `check_tp` / `mark_tp`）契约，testcase 生成器必须遵守
- `wiki/codingstyle/systemverilog_styleguide.md` — SV 风格
