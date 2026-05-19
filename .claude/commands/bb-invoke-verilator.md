---
description: "Verilator simulation wrapper — compile RTL + TB and run coverage-driven sim. Direct invocation of the bb-invoke-verilator skill for debugging."
---

Run the `bb-invoke-verilator` skill with the user's arguments.

Use this when the user wants to debug verilator directly. Expects `file_list`, `tb_top`, `design_name`. See `.claude/skills/bb-invoke-verilator/SKILL.md`.
