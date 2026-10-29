---
description: 把 test_points.json 转成可执行 SV testcase + registry + 运行脚本。Direct invocation of the bb-generate-testcases skill.
argument-hint: "<design_name> [modules_csv]"
---

Run the `bb-generate-testcases` skill.

Required:
- `design_name`: directory slug under `designs/`

Optional:
- `modules_csv`: regenerate only these modules; other registry entries are preserved

Command:
```bash
uv run --no-project python .omp/skills/bb-generate-testcases/scripts/generate_testcases.py \
  --design-name <design_name> \
  --test-points designs/<design_name>/verif/test_points.json \
  --tb-dir designs/<design_name>/tb/generated \
  [--modules M00_Foo,M01_Bar]
```

Outputs `verif/test_registry.json`, `verif/test_cases.md`, `tb/generated/tc_*.sv`, `tb/generated/run_tests.sh`.
Run one point: `bash designs/<name>/tb/generated/run_tests.sh <module> <TP-ID>`.

See `.omp/skills/bb-generate-testcases/SKILL.md` for the full contract.
On failure: report `lint_errors`; fix the generator rather than editing `tc_*.sv`.
