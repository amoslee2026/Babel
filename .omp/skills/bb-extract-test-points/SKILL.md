---
name: bb-extract-test-points
description: "从 MAS / verif_plan_seed / verification_plan 提取结构化测试点（test_points.json + test_points.md），供 bb-generate-testbench 与 bb-generate-testcases 消费。触发场景：(1) bba-guru-verification 生成验证计划后；(2) 显式 /bb-extract-test-points。"
user-invocable: true
---

# bb-extract-test-points

## 职责

把散落在 `verif_plan_seed.md`、`verification_plan.md`、`mas.json` 的验证意图归一成**机器可消费的测试点清单**，每个测试点带唯一 ID、模块、类别、优先级、激励与检查方式。

- 调用者：`bba-guru-verification`
- 上游：`bb-create-verif-plan`（或直接使用 MAS 阶段 seed）
- 下游：`bb-generate-testbench`、`bb-generate-testcases`
- 不产出任何设计代码；不改 RTL

## Input Args

| arg | type | required | 默认 | 说明 |
|-----|------|----------|------|------|
| `design_name` | string | true | — | `designs/<name>/` 的 slug |
| `seed` | path | false | `designs/<name>/mas/verif_plan_seed.md` | MAS 阶段的 seed 表 |
| `plan` | path | false | `designs/<name>/verif/verification_plan.md` | 完整计划（存在则合并） |
| `mas` | path | false | `designs/<name>/mas/mas.json` | 用于派生 CDC / 复位 / 边界点 |
| `out_dir` | path | false | `designs/<name>/verif` | — |

## 提取规则（确定性，不依赖 LLM）

| 来源 | 匹配 | 产出 category |
|------|------|---------------|
| seed `### <Module>` + 表头含 `ID / Test / Priority / Method` | 每行一个点 | `functional` |
| plan `**Functional Coverage Points**` 表（`F-<code>-NNN`） | 每行一个点 | `functional` |
| plan `**Branch Coverage Points**` 表（`B-<code>-NNN`） | 每行一个点 | `branch` |
| MAS `clock_domains` ≥ 2 | 每个 (from,to) 组合一个点 | `cdc` |
| MAS 模块存在 `rst*` 输入 | 每模块一个点 | `reset` |
| MAS 模块有 ≥8 bit 输入端口 | 每模块一个点 | `boundary` |

去重键：`(module_code, normalized(title))`；同键保留先出现者（seed 优先），并记录 `also_in` 来源列表。

## Output Contract

| field | 值 |
|-------|----|
| `artifact_path` | `designs/<name>/verif/test_points.json` |
| `markdown_path` | `designs/<name>/verif/test_points.md` |
| `total` | int |
| `by_category` | map（functional/branch/cdc/reset/boundary） |
| `by_priority` | map（HIGH/MEDIUM/LOW） |
| `valid` | bool（ID 唯一、字段齐全、至少 1 点） |
| `error` | string\|null |

单点 schema：

```json
{
  "id": "TP-M00-003",
  "module": "M00_SystolicArray",
  "module_code": "M00",
  "title": "FP8 precision (E4M3)",
  "priority": "HIGH",
  "category": "functional",
  "method": "Directed test",
  "stimulus": "drive fp8 operand pair, latch output",
  "check": "scoreboard compares against golden model",
  "coverage_bin": "cg_M00.cp_tp_m00_003",
  "source": "plan",
  "also_in": ["seed"]
}
```

## 4-Phase 执行

### Phase 1 — 收集输入

确认 seed / plan / mas 至少一个存在；缺 plan 时仅用 seed+MAS 派生，并在输出 `sources_missing` 中记录。

### Phase 2 — 提取

```bash
python3 .omp/skills/bb-extract-test-points/scripts/extract_test_points.py \
  --design-name <name> \
  --seed  designs/<name>/mas/verif_plan_seed.md \
  --plan  designs/<name>/verif/verification_plan.md \
  --mas   designs/<name>/mas/mas.json \
  --out-dir designs/<name>/verif
```

### Phase 3 — 校验

脚本自检（`--strict` 返回码 2 表示不合格）：

- ID 形如 `TP-[A-Z0-9]+-\d{3}` 且全局唯一
- 每点 `module/title/priority/category/check` 非空
- `priority ∈ {HIGH, MEDIUM, LOW}`
- 至少 1 个测试点，且每模块至少 1 点（MAS 模块全覆盖；缺失写入 `modules_without_points`）

### Phase 4 — 返回

返回 Output Contract 的 JSON 字段；`valid=false` 时不进入下游，按 *收敛 / 失败* 处理。

## 收敛 / 失败

| 状态 | 行动 |
|------|------|
| valid=true | 进 `bb-generate-testbench` |
| seed 与 plan 都缺失 | `error="no verification source"`，回退 `bb-create-verif-plan` |
| 模块无测试点 | 用 MAS 派生点补齐一次（category=functional, source=mas-derived） |
| 仍为空模块 | 记入 `modules_without_points` 并 `valid=false`，人工确认 |

## 资源索引

- `scripts/extract_test_points.py` — 解析 + 去重 + 渲染，零外部依赖
- `references/test_point_taxonomy.md` — category 定义与命名规则
