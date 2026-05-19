---
description: Run bba-guru-rtl on a ready-for-rtl handoff. MAS → SystemVerilog + file_list.f + rtl_artifact.json.
argument-hint: <design-path-or-issue-number>
---

Spawn the `bba-guru-rtl` sub-agent.

```
Agent(subagent_type="bba-guru-rtl", prompt="$ARGUMENTS")
```

Expected `$ARGUMENTS`: a `designs/<name>` path or an issue number with the `ready-for-rtl` label.

See `.claude/agents/bba-guru-rtl.md`.
