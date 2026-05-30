---
description: OpenSTA static timing analysis wrapper — synth-stage or post-PD multi-corner signoff. Direct invocation of bb-invoke-opensta.
argument-hint: <netlist> <sdc> <liberty> <design_name>
---

Run the `bb-invoke-opensta` skill.

Required parameters:
- `netlist`: path to synthesized netlist
- `sdc`: path to constraints SDC
- `liberty`: Liberty library file path
- `design_name`: design project name

Use this when the user wants to debug timing analysis directly without going through the full bba-guru-synthesis pipeline.

See `.claude/skills/bb-invoke-opensta/SKILL.md` for the full contract.

On failure: report the error summary from the skill/agent output. Do not retry automatically — let the user decide next steps.
