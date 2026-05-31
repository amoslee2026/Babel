#!/usr/bin/env python3
"""Execute floorplan generation and return JSON status."""
import sys
import subprocess
import json
from pathlib import Path

# Keys the floorplan TCL renderer (render_fp_py.render_floorplan_tcl) requires.
REQUIRED_KEYS = ('top_module', 'die_size', 'core_area')


def validate_fp_config(config_file):
    # type: (str) -> tuple  # (config_dict_or_None, error_str_or_None) — 3.6-compatible (no PEP 604)
    """Validate the floorplan config before emitting Magic TCL.

    Fail loudly (return an error) rather than producing a TCL that silently
    references missing/empty inputs. Checks: config file exists and is
    non-empty valid JSON, all required keys are present, the top module name
    is non-empty, and every io_pad_list entry is well-formed.
    """
    path = Path(config_file)
    if not path.exists():
        return None, f'CONFIG_NOT_FOUND: {config_file}'
    if path.stat().st_size == 0:
        return None, f'CONFIG_EMPTY: {config_file}'

    try:
        config = json.loads(path.read_text())
    except json.JSONDecodeError as e:
        return None, f'CONFIG_INVALID_JSON: {e}'
    if not isinstance(config, dict):
        return None, 'CONFIG_NOT_OBJECT'

    missing = [k for k in REQUIRED_KEYS if k not in config]
    if missing:
        return None, f'CONFIG_MISSING_KEYS: {missing}'

    top = config.get('top_module')
    if not isinstance(top, str) or not top.strip():
        return None, 'CONFIG_TOP_MODULE_EMPTY'

    for dim_key in ('die_size', 'core_area'):
        dim = config[dim_key]
        if not isinstance(dim, dict) or 'width_um' not in dim or 'height_um' not in dim:
            return None, f'CONFIG_BAD_{dim_key.upper()}'

    for i, pad in enumerate(config.get('io_pad_list', [])):
        if not isinstance(pad, dict) or 'cell' not in pad \
                or 'x_um' not in pad or 'y_um' not in pad:
            return None, f'CONFIG_BAD_PAD_ENTRY[{i}]'

    return config, None


def run_floorplan_gen(top_module: str, config_file: str) -> dict:
    """Run Magic floorplan generation."""
    try:
        config, err = validate_fp_config(config_file)
        if err:
            return {'status': 'error', 'top_module': top_module, 'message': err}

        sys.path.insert(0, str(Path(__file__).parent))
        from render_fp_py import render_floorplan_tcl
        tcl_content = render_floorplan_tcl(config)

        tcl_file = f'{top_module}_fp.tcl'
        with open(tcl_file, 'w') as f:
            f.write(tcl_content)

        result = subprocess.run(['magic', '-dnull', '-noconsole', '-rcfile', tcl_file],
                                capture_output=True, text=True, timeout=300)
        log_file = f'floorplan_{top_module}.log'
        with open(log_file, 'w') as f:
            f.write(result.stdout + result.stderr)

        from parse_fp import parse_floorplan_output
        fp_result = parse_floorplan_output(log_file)
        return {'status': fp_result['status'], 'top_module': top_module,
                'die_area': fp_result['die_area'], 'utilization': fp_result['utilization']}
    except subprocess.TimeoutExpired:
        return {'status': 'error', 'message': 'Floorplan generation timeout'}
    except Exception as e:
        return {'status': 'error', 'message': str(e)}

if __name__ == '__main__':
    if len(sys.argv) < 3:
        print("Usage: run_fp_gen.py <top_module> <config.json>", file=sys.stderr)
        sys.exit(1)
    print(json.dumps(run_floorplan_gen(sys.argv[1], sys.argv[2]), indent=2))
