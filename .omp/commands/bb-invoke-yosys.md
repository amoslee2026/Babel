---
description: Yosys synthesis wrapper — synthesize RTL to ASAP7 netlist + QoR. Direct invocation of the bb-invoke-yosys skill for debugging.
argument-hint: <file_list> <sdc_path> <tech_lib> <top_module> <design_name>
---

Run the `bb-invoke-yosys` skill.

Required parameters:
- `file_list`: path to file_list.f
- `sdc_path`: path to constraints SDC
- `tech_lib`: technology library path (e.g., asap7)
- `top_module`: top-level module name
- `design_name`: design project name

Use this when the user wants to debug yosys synthesis directly without going through the full bba-guru-synthesis pipeline.

See `.claude/skills/bb-invoke-yosys/SKILL.md` for the full 3-Phase contract.

On failure: report the error summary from the skill/agent output. Do not retry automatically — let the user decide next steps.
