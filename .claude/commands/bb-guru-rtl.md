---
description: Run bb-guru-rtl on a ready-for-rtl handoff. MAS → SystemVerilog + file_list.f + rtl_artifact.json.
argument-hint: <design-path-or-issue-number>
---

Spawn the `bb-guru-rtl` sub-agent.

```
Agent(subagent_type="bb-guru-rtl", prompt="$ARGUMENTS")
```

Expected `$ARGUMENTS`: a `designs/<name>` path or an issue number with the `ready-for-rtl` label.

See `.claude/agents/bb-guru-rtl.md`.
