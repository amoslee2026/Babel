---
description: 按 test_points.json + RTL 端口生成 per-module SV testbench harness（时钟/复位、DUT 实例化、覆盖率骨架、lint）。Direct invocation of the bb-generate-testbench skill.
argument-hint: "<design_name> [modules_csv]"
---

Run the `bb-generate-testbench` skill.

Required:
- `design_name`: directory slug under `designs/`

Optional:
- `modules_csv`: comma-separated MAS module names; default = every module with test points

Command:
```bash
uv run --no-project python .omp/skills/bb-generate-testbench/scripts/generate_testbench.py \
  --design-name <design_name> \
  --mas designs/<design_name>/mas/mas.json \
  --test-points designs/<design_name>/verif/test_points.json \
  --out-dir designs/<design_name>/tb/generated \
  [--modules M00_Foo,M01_Bar]
```

Ports are parsed from RTL (`file_list.f` / `rtl_artifact.json`); module-name drift between MAS and RTL is resolved by the `Mxx` code alias. `port_source` must be `rtl` — a MAS-only fallback is opt-in (`--allow-mas-ports`) and is not accepted for signoff.

See `.omp/skills/bb-generate-testbench/SKILL.md` for the full contract.
On failure: report `lint_errors` verbatim; fix the generator, do not hand-edit generated files.
