---
description: QRouter detail routing wrapper.
argument-hint: <def_file> <lef_file> <design_name>
---

Run the `bb-invoke-qrouter` skill.

Required parameters:
- `def_file`: placed DEF file path
- `lef_file`: LEF file path (technology + cell definitions)
- `design_name`: design project name

See `.claude/skills/bb-invoke-qrouter/SKILL.md` for the full contract.

On failure: report the error summary from the skill/agent output. Do not retry automatically — let the user decide next steps.
