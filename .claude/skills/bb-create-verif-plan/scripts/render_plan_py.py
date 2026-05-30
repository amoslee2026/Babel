#!/usr/bin/env python3
"""Render verification plan markdown from MAS spec."""
import sys
import json

def render_verif_plan(mas_spec: dict) -> str:
    """Generate verification plan markdown from MAS spec."""
    top = mas_spec.get('top_module', 'unknown')
    features = mas_spec.get('features', [])
    interfaces = mas_spec.get('interfaces', [])

    md = f"# Verification Plan for {top}\n\n"
    md += f"- **Top Module:** {top}\n- **Features:** {len(features)}\n- **Interfaces:** {len(interfaces)}\n\n"

    for feat in features:
        md += f"## Test Scenario: {feat['name']}\n\n"
        md += f"**Description:** Verify {feat['name']} functionality\n\n"
        md += "**Stimulus:** Apply valid inputs, test boundary and error conditions\n\n"
        md += "**Check:** Output matches expected, no assertion violations, coverage goals met\n\n"

    md += "## Interface Tests\n\n"
    for iface in interfaces:
        md += f"### {iface['name']}\n- Protocol compliance\n- Handshake timing\n- Backpressure\n\n"

    md += "## Coverage Goals\n- Line: >= 90%\n- Branch: >= 85%\n- Toggle: >= 80%\n- FSM: 100%\n\n"
    md += "## Regression Matrix\n\n| Test | Priority | Runtime |\n|------|----------|--------|\n"
    for feat in features:
        md += f"| {feat['name']}_test | HIGH | 1m |\n"
    return md

if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("Usage: render_plan_py.py <mas_spec.json>", file=sys.stderr)
        sys.exit(1)
    with open(sys.argv[1], 'r') as f:
        print(render_verif_plan(json.load(f)))
