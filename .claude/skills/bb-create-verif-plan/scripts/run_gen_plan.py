#!/usr/bin/env python3
"""Generate verification plan document and return JSON status."""
import sys
import json
from pathlib import Path

def generate_verif_plan(mas_spec_file: str, output_dir: str) -> dict:
    """Generate verification plan from MAS spec."""
    try:
        with open(mas_spec_file, 'r') as f:
            mas_spec = json.load(f)

        sys.path.insert(0, str(Path(__file__).parent))
        from render_plan_py import render_verif_plan
        plan_md = render_verif_plan(mas_spec)

        output_path = Path(output_dir)
        output_path.mkdir(parents=True, exist_ok=True)
        top_module = mas_spec.get('top_module', 'unknown')
        plan_file = output_path / f'{top_module}_verif_plan.md'
        with open(plan_file, 'w') as f:
            f.write(plan_md)

        from parse_plan import parse_verif_plan
        plan_data = parse_verif_plan(str(plan_file))

        return {'status': 'pass', 'top_module': top_module, 'plan_file': str(plan_file),
                'test_scenarios': plan_data['total_scenarios'],
                'coverage_goals': plan_data['total_coverage_goals']}
    except FileNotFoundError:
        return {'status': 'error', 'message': f'MAS spec not found: {mas_spec_file}'}
    except Exception as e:
        return {'status': 'error', 'message': str(e)}

if __name__ == '__main__':
    if len(sys.argv) < 3:
        print("Usage: run_gen_plan.py <mas_spec.json> <output_dir>", file=sys.stderr)
        sys.exit(1)
    print(json.dumps(generate_verif_plan(sys.argv[1], sys.argv[2]), indent=2))
