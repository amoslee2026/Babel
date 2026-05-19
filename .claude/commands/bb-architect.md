---
description: Run bb-architect on a design idea. Drives bb-prd → bb-arch → bb-mas → adapter → spec-review → ready-for-rtl handoff.
argument-hint: <design-name-or-free-form-idea>
---

Spawn the `bb-architect` sub-agent on the user-provided idea.

```
Agent(subagent_type="bb-architect", prompt="$ARGUMENTS")
```

If `$ARGUMENTS` is empty, ask the user for: design name, interface protocol(s), target frequency, clock/reset domains, target PDK (default ASAP7) — then dispatch.

See `.claude/agents/bb-architect.md` for full contract and acceptance criteria.
