---
description: Run bba-guru-verification on a ready-for-verification handoff. RTL + verif_plan_seed → 100% functional + code coverage.
argument-hint: <design-path-or-issue-number>
---

Spawn the bba-guru-verification sub-agent with the user's arguments.

Expected `$ARGUMENTS`: a `designs/<name>` path or an issue number with the `ready-for-verification` label.

See `.claude/agents/bba-guru-verification.md`.

On failure: report the error summary from the skill/agent output. Do not retry automatically — let the user decide next steps.
