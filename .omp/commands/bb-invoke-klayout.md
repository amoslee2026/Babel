---
description: KLayout GDSII export / DRC / verify wrapper.
argument-hint: <gds_file> <design_name>
---

Run the `bb-invoke-klayout` skill.

Required parameters:
- `gds_file`: GDSII file path to view or verify
- `design_name`: design project name

See `.claude/skills/bb-invoke-klayout/SKILL.md` for the full contract.

On failure: report the error summary from the skill/agent output. Do not retry automatically — let the user decide next steps.
