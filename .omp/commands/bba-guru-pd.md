---
description: Run bba-guru-pd. floorplan → place → route → DRC → LVS → post-PD STA → GDSII export.
argument-hint: <design-path-or-issue-number>
---

Spawn the bba-guru-pd sub-agent with the user's arguments.

Expected `$ARGUMENTS`: a `designs/<name>` path or an issue number with the `ready-for-pd` label. Synthesis must have closed timing (WNS ≥ 0).

See `.claude/agents/bba-guru-pd.md`.

On failure: report the error summary from the skill/agent output. Do not retry automatically — let the user decide next steps.
