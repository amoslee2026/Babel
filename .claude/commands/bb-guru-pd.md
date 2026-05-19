---
description: Run bb-guru-pd. floorplan → place → route → DRC → LVS → post-PD STA → GDSII export.
argument-hint: <design-path-or-issue-number>
---

Spawn the `bb-guru-pd` sub-agent.

```
Agent(subagent_type="bb-guru-pd", prompt="$ARGUMENTS")
```

Expected `$ARGUMENTS`: a `designs/<name>` path or an issue number with the `ready-for-pd` label. Synthesis must have closed timing (WNS ≥ 0).

See `.claude/agents/bb-guru-pd.md`.
