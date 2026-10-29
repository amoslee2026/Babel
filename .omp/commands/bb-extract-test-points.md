---
description: 从 MAS / verif_plan_seed / verification_plan 提取结构化测试点（test_points.json + test_points.md）。Direct invocation of the bb-extract-test-points skill.
argument-hint: "<design_name>"
---

Run the `bb-extract-test-points` skill.

Required:
- `design_name`: directory slug under `designs/`

Optional:
- `seed`, `plan`, `mas`, `out_dir` (defaults documented in the skill)

Command:
```bash
uv run --no-project python .omp/skills/bb-extract-test-points/scripts/extract_test_points.py \
  --design-name <design_name> \
  --seed designs/<design_name>/mas/verif_plan_seed.md \
  --plan designs/<design_name>/verif/verification_plan.md \
  --mas  designs/<design_name>/mas/mas.json \
  --out-dir designs/<design_name>/verif --strict
```

See `.omp/skills/bb-extract-test-points/SKILL.md` for the full contract.
On failure: report the JSON error and stop; do not fabricate test points.
