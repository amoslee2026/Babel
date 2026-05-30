#!/usr/bin/env python3
"""Normalize slang AST JSON output to the common AST schema.

slang produces a different JSON structure than pyverilog.
This script maps slang-specific node types and structure to
the unified schema used by downstream consumers.
"""
import json
import sys
from pathlib import Path
from typing import Any


# slang node type -> common schema type mapping
TYPE_MAP = {
    "Design": "Design",
    "CompilationUnit": "CompilationUnit",
    "InstanceDefinitionBodySymbol": "ModuleDef",
    "DefinitionSymbol": "ModuleDef",
    "PortSymbol": "Port",
    "NetSymbol": "Wire",
    "VariableSymbol": "Reg",
    "ContinuousAssignSymbol": "Assign",
    "ProceduralBlockSymbol": "Always",
    "InstanceSymbol": "Instance",
    "TypeAliasSymbol": "Typedef",
    "ParameterSymbol": "Parameter",
    "FieldSymbol": "Field",
}

# slang direction strings
DIRECTION_MAP = {
    "In": "input",
    "Out": "output",
    "InOut": "inout",
    "Ref": "ref",
}


def normalize_node(node: dict) -> dict | None:
    """Convert a slang AST node to common schema format.

    Args:
        node: A slang AST JSON node.

    Returns:
        Normalized node dict, or None if the node should be skipped.
    """
    if not isinstance(node, dict):
        return None

    slang_kind = node.get("kind", "")
    common_type = TYPE_MAP.get(slang_kind, slang_kind)

    result: dict[str, Any] = {"type": common_type}

    # Map common attributes
    if "name" in node:
        result["name"] = node["name"]
    if "direction" in node:
        result["direction"] = DIRECTION_MAP.get(node["direction"], node["direction"])

    # Handle type/width info
    decl_type = node.get("type", {})
    if isinstance(decl_type, dict):
        if "bitWidth" in decl_type:
            result["width"] = str(decl_type["bitWidth"])
        if "name" in decl_type:
            result["data_type"] = decl_type["name"]

    # Recurse into children
    members = node.get("members", [])
    body = node.get("body", [])
    children_source = members if members else body
    if isinstance(children_source, list):
        children = []
        for child in children_source:
            normalized = normalize_node(child)
            if normalized is not None:
                children.append(normalized)
        if children:
            result["children"] = children

    return result


def normalize_slang(input_path: str, output_path: str) -> dict:
    """Normalize a complete slang AST JSON file.

    Args:
        input_path: Path to raw slang AST JSON.
        output_path: Path to write normalized AST JSON.

    Returns:
        Summary dict with module count and status.
    """
    raw = json.loads(Path(input_path).read_text(errors="replace"))
    normalized_root = normalize_node(raw)

    if normalized_root is None:
        return {"valid": False, "error": "empty slang AST", "modules": []}

    # Extract modules from normalized tree
    modules = []
    def _collect_modules(node: dict) -> None:
        if node.get("type") == "ModuleDef" and "name" in node:
            ports = []
            for child in node.get("children", []):
                if child.get("type") == "Port":
                    ports.append({
                        "name": child.get("name", ""),
                        "direction": child.get("direction", ""),
                        "width": child.get("width", ""),
                    })
            modules.append({
                "name": node["name"],
                "ports": ports,
                "items": [c for c in node.get("children", []) if c.get("type") != "Port"],
            })
        for child in node.get("children", []):
            _collect_modules(child)

    _collect_modules(normalized_root)

    result = {
        "modules": modules,
        "top_module": modules[0]["name"] if modules else None,
        "node_count": _count_nodes(normalized_root),
        "serialized": True,
        "backend": "slang",
    }

    Path(output_path).parent.mkdir(parents=True, exist_ok=True)
    Path(output_path).write_text(json.dumps(result, indent=2))

    return {
        "valid": len(modules) > 0,
        "error": None,
        "modules": [m["name"] for m in modules],
        "module_count": len(modules),
        "output_path": output_path,
    }


def _count_nodes(node: dict) -> int:
    """Count total nodes in normalized AST tree."""
    count = 1
    for child in node.get("children", []):
        count += _count_nodes(child)
    return count


def main():
    if len(sys.argv) < 3:
        print(f"Usage: {sys.argv[0]} <input_path> <output_path>", file=sys.stderr)
        sys.exit(1)

    input_path = sys.argv[1]
    output_path = sys.argv[2]

    if not Path(input_path).exists():
        print(f"ERROR: Input file not found: {input_path}", file=sys.stderr)
        sys.exit(1)

    result = normalize_slang(input_path, output_path)
    print(json.dumps(result, indent=2))

    sys.exit(0 if result["valid"] else 1)


if __name__ == "__main__":
    main()
