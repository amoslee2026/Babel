---
description: Run bba-guru-verification on a ready-for-verification handoff. RTL + verif_plan_seed → 100% functional + code coverage.
argument-hint: <design-path-or-issue-number>
---

Spawn the `bba-guru-verification` sub-agent.

```
Agent(subagent_type="bba-guru-verification", prompt="$ARGUMENTS")
```

Expected `$ARGUMENTS`: a `designs/<name>` path or an issue number with the `ready-for-verification` label.

See `.claude/agents/bba-guru-verification.md`.
