---
description: Run bba-guru-rtl on a ready-for-rtl handoff. MAS → SystemVerilog + file_list.f + rtl_artifact.json.
argument-hint: <design-path-or-issue-number>
---

Spawn the bba-guru-rtl sub-agent with the user's arguments.

Expected `$ARGUMENTS`: a `designs/<name>` path or an issue number with the `ready-for-rtl` label.

See `.claude/agents/bba-guru-rtl.md`.

On failure: report the error summary from the skill/agent output. Do not retry automatically — let the user decide next steps.
