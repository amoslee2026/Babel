---
description: Run bb-guru-verification on a ready-for-verification handoff. RTL + verif_plan_seed → 100% functional + code coverage.
argument-hint: <design-path-or-issue-number>
---

Spawn the `bb-guru-verification` sub-agent.

```
Agent(subagent_type="bb-guru-verification", prompt="$ARGUMENTS")
```

Expected `$ARGUMENTS`: a `designs/<name>` path or an issue number with the `ready-for-verification` label.

See `.claude/agents/bb-guru-verification.md`.
