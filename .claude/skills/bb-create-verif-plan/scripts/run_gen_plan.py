#!/usr/bin/env python3
"""Execute verification plan generation."""
import json, sys
from pathlib import Path
from datetime import datetime, timezone

def run(config_path: str, output_path: str) -> dict:
    """Generate verification plan markdown from configuration."""
    with open(config_path) as f:
        config = json.load(f)

    output = Path(output_path)
    output.parent.mkdir(parents=True, exist_ok=True)

    ftps = config.get("ftps", [])
    fsm_states = config.get("fsm_states", [])
    interfaces = config.get("interfaces", [])

    lines = [
        "# Verification Plan",
        f"# Generated: {datetime.now(timezone.utc).isoformat()}",
        "",
        "## Functional Coverage Groups",
        "",
    ]

    # FSM coverage
    for fsm in fsm_states:
        mod = fsm.get("module", "unknown")
        state = fsm.get("state", "unknown")
        lines.append(f"- covergroup cg_{mod}_{state}: FSM state {state} in {mod}")
    if not fsm_states:
        lines.append("- (No FSM states found in MAS)")
    lines.append("")

    # Interface coverage
    for iface in interfaces:
        name = iface.get("name", iface) if isinstance(iface, dict) else str(iface)
        lines.append(f"- covergroup cg_{name}: Interface {name}")
    if not interfaces:
        lines.append("- (No interfaces found in MAS)")
    lines.append("")

    lines.extend([
        "## Code Coverage Targets",
        "",
        "- Line coverage: 100%",
        "- Branch coverage: 100%",
        "- Toggle coverage: 100%",
        "- Condition coverage: 100%",
        "",
        "## Functional Test Points",
        "",
    ])

    for ftp in ftps:
        lines.append(f"- {ftp['id']}: {ftp['description']}")
    if not ftps:
        lines.append("- (No FTPs defined in seed)")
    lines.append("")

    lines.extend([
        "## Corner Cases",
        "",
        "- Reset timing: assert/deassert at clock edge boundaries",
        "- Overflow: maximum data width values",
        "- Underflow: zero-length transfers",
        "- CDC crossing: data launched at clock domain boundary",
        "",
        "## Random Constraints",
        "",
        "- Constrained random stimulus within valid data ranges",
        "- Random inter-transaction delays (1-100 cycles)",
        "- Random reset assertion timing",
        "",
        "## Test Case List",
        "",
    ])

    for ftp in ftps:
        seq_name = f"seq_{ftp['id'].replace('-', '_').lower()}"
        lines.append(f"- {seq_name}: Implements {ftp['id']}")
    if not ftps:
        lines.append("- (No test cases -- no FTPs defined)")
    lines.append("")

    output.write_text("\n".join(lines))

    return {
        "status": "complete",
        "artifact_path": str(output),
        "ftp_count": len(ftps),
        "coverage_groups": len(fsm_states) + len(interfaces),
    }

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print(f"Usage: {sys.argv[0]} <config.json> <output_plan.md>", file=sys.stderr)
        sys.exit(1)
    print(json.dumps(run(sys.argv[1], sys.argv[2]), indent=2))
