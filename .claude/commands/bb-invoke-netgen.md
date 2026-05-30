---
description: Netgen LVS wrapper — compare synth netlist vs Magic-extracted SPICE.
argument-hint: <schematic_netlist> <layout_netlist> <design_name>
---

Run the `bb-invoke-netgen` skill.

Required parameters:
- `schematic_netlist`: path to schematic netlist
- `layout_netlist`: path to layout-extracted netlist
- `design_name`: design project name

See `.claude/skills/bb-invoke-netgen/SKILL.md` for the full contract.

On failure: report the error summary from the skill/agent output. Do not retry automatically — let the user decide next steps.
