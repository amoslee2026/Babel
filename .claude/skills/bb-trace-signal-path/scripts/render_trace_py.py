#!/usr/bin/env python3
"""Generate trace analysis configuration script.

Renders a Python script that performs DFS-based signal path tracing
through the AST JSON, from source signal to sink signal.
"""
import json
import sys
from pathlib import Path


def render_trace_script(
    ast_path: str,
    source_signal: str,
    sink_signal: str,
    design_name: str,
    output_path: str,
    max_depth: int = 50,
    cdc_lib: str = "",
) -> str:
    """Render a standalone Python trace script.

    Args:
        ast_path: Path to AST JSON from bb-parse-ast.
        source_signal: Source signal path (e.g., 'top.u_rx.rx_data').
        sink_signal: Sink signal path (e.g., 'top.u_tx.tx_data').
        design_name: Name of the design.
        output_path: Path to write trace result JSON.
        max_depth: Maximum DFS depth to prevent infinite loops.
        cdc_lib: Path to cdc_classifier.py library directory.

    Returns:
        Python source code as a string.
    """
    cdc_import = ""
    if cdc_lib:
        cdc_import = f'''
import sys as _sys
_sys.path.insert(0, {json.dumps(cdc_lib)})
from cdc_classifier import classify_path, classify_rdc
'''

    return f'''#!/usr/bin/env python3
"""Auto-generated signal trace script for {design_name}."""
import json
from pathlib import Path
{cdc_import}

def trace(ast, source_signal, sink_signal, max_depth={max_depth}):
    """DFS trace from source to sink through AST.

    Args:
        ast: Parsed AST JSON dict.
        source_signal: Source signal identifier.
        sink_signal: Sink signal identifier.
        max_depth: Maximum search depth.

    Returns:
        Tuple of (path_list, crosses_clock_domain).
    """
    # Build adjacency from assignments and connections
    edges = build_edges(ast)

    # Parse signal names (support hierarchical: "mod.sub.sig" or local: "mod.sig")
    src_parts = source_signal.rsplit(".", 1)
    dst_parts = sink_signal.rsplit(".", 1)

    src_module = src_parts[0] if len(src_parts) > 1 else ""
    src_sig = src_parts[-1]
    dst_module = dst_parts[0] if len(dst_parts) > 1 else ""
    dst_sig = dst_parts[-1]

    # DFS
    visited = set()
    path = []

    def _dfs(current_module, current_sig, depth):
        if depth > max_depth:
            return False
        key = (current_module, current_sig)
        if key in visited:
            return False
        visited.add(key)
        path.append({{
            "module": current_module,
            "signal": current_sig,
            "line": None,
            "op": "trace",
        }})

        # Check if we reached the sink
        if current_sig == dst_sig and (not dst_module or current_module == dst_module or dst_module in current_module):
            return True

        # Follow edges
        for next_mod, next_sig, op in edges.get(key, []):
            if _dfs(next_mod, next_sig, depth + 1):
                path[-1]["op"] = op
                return True

        path.pop()
        return False

    found = _dfs(src_module, src_sig, 0)

    # Classify CDC if path found and classifier available
    crosses_cdc = False
    if found and path:
        try:
            cdc_result = classify_path(path)
            crosses_cdc = cdc_result["crosses_clock_domain"]
        except Exception:
            pass

    return path if found else [], crosses_cdc


def build_edges(ast):
    """Build signal adjacency graph from AST.

    Returns:
        Dict mapping (module, signal) -> list of (next_module, next_signal, op).
    """
    edges = {{}}

    for mod in ast.get("modules", []):
        mod_name = mod.get("name", "")

        for item in mod.get("items", []):
            item_type = item.get("type", "")

            # Continuous assignments: assign lhs = rhs
            if item_type == "Assign":
                children = item.get("children", [])
                if len(children) >= 2:
                    lhs = children[0].get("name", "")
                    rhs = children[1].get("name", "")
                    if lhs and rhs:
                        key = (mod_name, rhs)
                        edges.setdefault(key, []).append((mod_name, lhs, "cont_assign"))

            # Non-blocking assignments in always blocks
            if item_type == "Always":
                _extract_assignments(item, mod_name, edges, "non_blocking_assign")

            # Module instances (port connections)
            if item_type == "Instance":
                inst_name = item.get("name", "")
                for child in item.get("children", []):
                    if child.get("type") == "PortConnection":
                        port = child.get("name", "")
                        sig = child.get("value", "")
                        if port and sig:
                            # External -> internal
                            key_ext = (mod_name, sig)
                            edges.setdefault(key_ext, []).append(
                                (f"{{mod_name}}.{{inst_name}}", port, "port_connection")
                            )

    return edges


def _extract_assignments(node, mod_name, edges, op_type):
    """Recursively extract assignments from always blocks."""
    for child in node.get("children", []):
        child_type = child.get("type", "")
        if child_type in ("Subst", "NonBlockingSubst", "BlockingSubst"):
            children = child.get("children", [])
            if len(children) >= 2:
                lhs = children[0].get("name", "")
                rhs = children[1].get("name", "")
                if lhs and rhs:
                    key = (mod_name, rhs)
                    actual_op = "non_blocking_assign" if child_type == "NonBlockingSubst" else "blocking_assign"
                    edges.setdefault(key, []).append((mod_name, lhs, actual_op))
        _extract_assignments(child, mod_name, edges, op_type)


def main():
    ast = json.load(open({json.dumps(ast_path)}))
    path, cdc = trace(ast, {json.dumps(source_signal)}, {json.dumps(sink_signal)})

    result = {{
        "source": {json.dumps(source_signal)},
        "sink": {json.dumps(sink_signal)},
        "path": path,
        "crosses_clock_domain": cdc,
        "valid": len(path) > 0,
        "error": None if path else "path not found",
        "design_name": {json.dumps(design_name)},
    }}

    out_path = Path({json.dumps(output_path)})
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(json.dumps(result, indent=2))

    print(f"Trace: {{len(path)}} nodes, CDC={{cdc}}")
    if not path:
        print("WARNING: path not found - check signal names or try fallback parser")

if __name__ == "__main__":
    main()
'''


def main():
    if len(sys.argv) < 6:
        print(
            f"Usage: {sys.argv[0]} <ast_path> <source> <sink> <design_name> <output_path> [max_depth] [cdc_lib]",
            file=sys.stderr,
        )
        sys.exit(1)

    ast_path = sys.argv[1]
    source = sys.argv[2]
    sink = sys.argv[3]
    design_name = sys.argv[4]
    output_path = sys.argv[5]
    max_depth = int(sys.argv[6]) if len(sys.argv) > 6 else 50
    cdc_lib = sys.argv[7] if len(sys.argv) > 7 else ""

    script = render_trace_script(
        ast_path, source, sink, design_name, output_path, max_depth, cdc_lib
    )
    print(script)


if __name__ == "__main__":
    main()
