---
description: Run bba-guru-synthesis. Drafts SDC, runs CDC+RDC, yosys synthesis + opensta to timing closure.
argument-hint: <design-path-or-issue-number>
---

Spawn the `bba-guru-synthesis` sub-agent.

```
Agent(subagent_type="bba-guru-synthesis", prompt="$ARGUMENTS")
```

Expected `$ARGUMENTS`: a `designs/<name>` path or an issue number with the `ready-for-synth` label. Verification must have closed all 4 coverage axes to 100%.

See `.claude/agents/bba-guru-synthesis.md`.
