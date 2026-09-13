#!/usr/bin/env python3
"""Parse verification plan and generate JSON report."""
import sys
import json

def parse_verif_plan(plan_file: str) -> dict:
    """Parse verification plan markdown file."""
    with open(plan_file, 'r') as f:
        lines = f.readlines()

    scenarios, coverage_goals, in_coverage = [], [], False
    current = None

    for line in lines:
        line = line.rstrip()
        if line.startswith('## Test Scenario:'):
            if current:
                scenarios.append(current)
            current = {'name': line.split(':', 1)[1].strip(), 'description': '', 'stimulus': '', 'check': ''}
        elif current:
            if line.startswith('**Description:**'):
                current['description'] = line.split(':', 1)[1].strip()
            elif line.startswith('**Stimulus:**'):
                current['stimulus'] = line.split(':', 1)[1].strip()
            elif line.startswith('**Check:**'):
                current['check'] = line.split(':', 1)[1].strip()
        if line.startswith('## Coverage Goals'):
            in_coverage = True
        elif in_coverage and line.startswith('- '):
            goal = line[2:].strip()
            if goal:
                coverage_goals.append(goal)
        elif in_coverage and line.startswith('##'):
            break

    if current:
        scenarios.append(current)

    return {'test_scenarios': scenarios, 'coverage_goals': coverage_goals,
            'total_scenarios': len(scenarios), 'total_coverage_goals': len(coverage_goals)}

if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("Usage: parse_plan.py <verif_plan.md>", file=sys.stderr)
        sys.exit(1)
    print(json.dumps(parse_verif_plan(sys.argv[1]), indent=2))
