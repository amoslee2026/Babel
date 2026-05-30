---
description: Verible lint check on file_list.f — fail on any error.
argument-hint: <rtl_dir> <file_list> <design_name>
---

Run the `bb-check-lint` skill.

Required parameters:
- `rtl_dir`: directory containing RTL files
- `file_list`: path to file_list.f
- `design_name`: design project name

See `.claude/skills/bb-check-lint/SKILL.md` for the full contract.

On failure: report the error summary from the skill/agent output. Do not retry automatically — let the user decide next steps.
