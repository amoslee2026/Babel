---
description: Verilator simulation wrapper — compile RTL + TB and run coverage-driven sim. Direct invocation of the bb-invoke-verilator skill for debugging.
argument-hint: <file_list> <top_module> <design_name> [testbench]
---

Run the `bb-invoke-verilator` skill.

Required parameters:
- `file_list`: path to file_list.f
- `top_module`: top-level module name
- `design_name`: design project name

Optional parameters:
- `testbench`: testbench file path

Use this when the user wants to debug verilator directly without going through the full bba-guru-verification pipeline.

See `.claude/skills/bb-invoke-verilator/SKILL.md` for the full contract.

On failure: report the error summary from the skill/agent output. Do not retry automatically — let the user decide next steps.
