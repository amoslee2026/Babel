# Babel EDA Tool Versions — Single Source of Truth

This file is the **canonical version reference** for the Babel EDA toolchain.
Both `CLAUDE.md` (top-level) and `skills/bb-invoke-*/SKILL.md` (tool-specific)
must stay in sync with the versions listed here. If they drift, file a bug
against this file, not the other one.

Last verified: 2026-05-30 (Beijing time).

| Tool | Version | Install path | Version check command |
|------|---------|--------------|----------------------|
| Yosys | 0.35 | `~/wrk/eda_opensources/eda_env.sh` | `yosys -V` |
| OpenSTA | 2.5.0 | `~/wrk/eda_opensources/eda_env.sh` | `sta -version` |
| Magic | 8.3.641 | `~/wrk/eda_opensources/eda_env.sh` | `magic --version` |
| Netgen | 1.5.275 | `~/wrk/eda_opensources/eda_env.sh` | `netgen -batch lvs` |
| QRouter | 1.4 | `~/wrk/eda_opensources/eda_env.sh` | `qrouter --version` |
| KLayout | 0.30.8 | `~/wrk/eda_opensources/eda_env.sh` | `klayout -v` |
| Verilator | 5.012 | `~/wrk/eda_opensources/eda_env.sh` | `verilator --version` |
| ABC | (yosys-bundled) | via `yosys -m …` | `yosys -p "abc -v"` |

## Environment setup

All Babel EDA invocations must source the environment file first:

```bash
source ~/wrk/eda_opensources/eda_env.sh
```

The `BB_EDA_ENV` environment variable overrides this path (used by
`run_synthesis_first_run.py` and renderer scripts).

## Technology library

- **PDK**: ASAP7 (7nm predictive PDK)
- **Standard cell libs**: `libs/asap7/asap7sc6t_26`, `asap7sc7p5t_27`, `asap7sc7p5t_28`
- **Corners**: see [`asap7_corners.md`](./asap7_corners.md)

## Drift detection (CI recommendation)

```bash
# Run in CI: verify every skill agrees with this file
for f in .claude/skills/bb-invoke-*/SKILL.md; do
  grep -E 'version:|Version' "$f" | grep -v "$(grep -E '^[A-Z].*\| [0-9]' \
    .claude/references/tool_versions.md | awk '{print $3}' | head -1)"
done
```

## Update procedure

When upgrading a tool:
1. Install the new version in `~/wrk/eda_opensources/`.
2. Update this file.
3. Update the matching `bb-invoke-*/SKILL.md` version check.
4. Update `CLAUDE.md` EDA Toolchain table.
5. Run the drift-detection snippet above.
