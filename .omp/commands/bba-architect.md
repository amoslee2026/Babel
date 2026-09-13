---
description: Run bba-architect on a design idea. Drives bb-prd → bb-arch → bb-mas → adapter → spec-review → ready-for-rtl handoff.
argument-hint: <design-name-or-free-form-idea>
---

Spawn the bba-architect sub-agent with the user's arguments.

If `$ARGUMENTS` is empty, ask the user for: design name, interface protocol(s), target frequency, clock/reset domains, target PDK (default ASAP7) — then dispatch.

See `.claude/agents/bba-architect.md` for full contract and acceptance criteria.

On failure: report the error summary from the skill/agent output. Do not retry automatically — let the user decide next steps.
