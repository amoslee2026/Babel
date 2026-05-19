---
description: "Yosys synthesis wrapper — synthesize RTL to ASAP7 netlist + QoR. Direct invocation of the bb-invoke-yosys skill for debugging."
---

Run the `bb-invoke-yosys` skill with the user's arguments.

Use this when the user wants to debug yosys synthesis directly without going through the full bb-guru-synthesis pipeline. The skill expects `file_list`, `sdc_path`, `tech_lib`, `top_module`, `design_name`. See `.claude/skills/bb-invoke-yosys/SKILL.md` for the full 4-Phase contract.
