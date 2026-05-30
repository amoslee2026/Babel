---
description: Magic layout tool wrapper — floorplan/place/drc/extract. Direct invocation of bb-invoke-magic.
argument-hint: <lef_file> <def_file> <design_name>
---

Run the `bb-invoke-magic` skill.

Required parameters:
- `lef_file`: LEF file path (technology + cell definitions)
- `def_file`: DEF file path (placed design)
- `design_name`: design project name

See `.claude/skills/bb-invoke-magic/SKILL.md` for the full contract.

On failure: report the error summary from the skill/agent output. Do not retry automatically — let the user decide next steps.
