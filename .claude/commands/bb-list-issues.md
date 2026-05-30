---
description: List Babel handoff issues by label. Direct invocation of bb-list-issues.
argument-hint: [--label <label>] [--design-name <name>] [--limit N]
---

Run the `bb-list-issues` skill.

Optional arguments:
- `--label <label>`: filter issues by label
- `--design-name <name>`: filter by design project
- `--limit N`: limit number of results

See `.claude/skills/bb-list-issues/SKILL.md` for the full contract.

On failure: report the error summary from the skill/agent output. Do not retry automatically — let the user decide next steps.
