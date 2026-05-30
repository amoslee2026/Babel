#!/usr/bin/env python3
"""Normalize verible-verilog-syntax AST JSON output to common schema.

verible produces a token-tree based JSON. This script maps verible's
syntax tree nodes to the unified AST schema used by downstream consumers.
"""
import json
import sys
from pathlib import Path
from typing import Any


# verible tag -> common schema type mapping
TAG_MAP = {
    "kModuleDeclaration": "ModuleDef",
    "kPortDeclaration": "Port",
    "kPortList": "PortList",
    "kNetDeclaration": "Wire",
    "kRegisterVariable": "Reg",
    "kContinuousAssignmentStatement": "Assign",
    "kAlwaysStatement": "Always",
    "kGenerateIfClause": "GenerateIf",
    "kGenerateForClause": "GenerateFor",
    "kModuleInstantiation": "Instance",
    "kDataDeclaration": "Decl",
    "kParamDeclaration": "Parameter",
    "kTypeAlias": "Typedef",
    "kFunctionDeclaration": "Function",
    "kTaskDeclaration": "Task",
    "kConditionalStatement": "IfStatement",
    "kCaseStatement": "CaseStatement",
}


def normalize_verible_node(node: dict) -> dict | None:
    """Convert a verible syntax tree node to common schema format.

    Args:
        node: A verible AST JSON node.

    Returns:
        Normalized node dict, or None if the node should be skipped.
    """
    if not isinstance(node, dict):
        return None

    tag = node.get("tag", "")
    common_type = TAG_MAP.get(tag, tag)

    # Skip leaf tokens (they have "text" but no structural meaning)
    if "text" in node and "children" not in node:
        return None

    result: dict[str, Any] = {"type": common_type}

    # Extract name from child tokens
    children = node.get("children", [])
    name = _extract_name(children, tag)
    if name:
        result["name"] = name

    # Extract direction for ports
    direction = _extract_direction(children)
    if direction:
        result["direction"] = direction

    # Extract width from range specifications
    width = _extract_width(children)
    if width:
        result["width"] = width

    # Recurse into children
    normalized_children = []
    for child in children:
        normalized = normalize_verible_node(child)
        if normalized is not None:
            normalized_children.append(normalized)
    if normalized_children:
        result["children"] = normalized_children

    return result


def _extract_name(children: list, parent_tag: str) -> str | None:
    """Extract identifier name from children tokens."""
    for child in children:
        if isinstance(child, dict):
            # Look for SymbolIdentifier tokens
            if child.get("tag") == "SymbolIdentifier":
                return child.get("text", "")
            # Recurse for nested identifiers
            sub = _extract_name(child.get("children", []), parent_tag)
            if sub:
                return sub
        elif isinstance(child, dict) and child.get("tag") == "TK_SYMBOL_IDENTIFIER":
            return child.get("text", "")
    return None


def _extract_direction(children: list) -> str | None:
    """Extract port direction from children tokens."""
    for child in children:
        if isinstance(child, dict):
            tag = child.get("tag", "")
            text = child.get("text", "").lower()
            if text in ("input", "output", "inout"):
                return text
            sub = _extract_direction(child.get("children", []))
            if sub:
                return sub
    return None


def _extract_width(children: list) -> str | None:
    """Extract bit width from range specifications."""
    for child in children:
        if isinstance(child, dict):
            if child.get("tag") == "kPackedDimensions":
                # Simplified width extraction
                text_parts = _collect_text(child)
                return "".join(text_parts)
            sub = _extract_width(child.get("children", []))
            if sub:
                return sub
    return None


def _collect_text(node: dict) -> list[str]:
    """Collect all text leaf values from a node tree."""
    texts = []
    if "text" in node:
        texts.append(node["text"])
    for child in node.get("children", []):
        if isinstance(child, dict):
            texts.extend(_collect_text(child))
    return texts


def normalize_verible(input_path: str, output_path: str) -> dict:
    """Normalize a complete verible AST JSON file.

    Args:
        input_path: Path to raw verible AST JSON (may contain multiple JSON objects).
        output_path: Path to write normalized AST JSON.

    Returns:
        Summary dict with module count and status.
    """
    raw_text = Path(input_path).read_text(errors="replace")

    # verible may output multiple JSON objects (one per file)
    all_roots = []
    decoder = json.JSONDecoder()
    pos = 0
    while pos < len(raw_text):
        raw_text_stripped = raw_text[pos:].lstrip()
        if not raw_text_stripped:
            break
        try:
            obj, end = decoder.raw_decode(raw_text_stripped)
            all_roots.append(obj)
            pos = len(raw_text) - len(raw_text_stripped) + end
        except json.JSONDecodeError:
            pos += 1

    if not all_roots:
        return {"valid": False, "error": "empty verible output", "modules": []}

    # Normalize each root and collect modules
    modules = []
    total_nodes = 0
    for root in all_roots:
        normalized = normalize_verible_node(root)
        if normalized is None:
            continue
        total_nodes += _count_nodes(normalized)
        _collect_modules(normalized, modules)

    result = {
        "modules": modules,
        "top_module": modules[0]["name"] if modules else None,
        "node_count": total_nodes,
        "serialized": True,
        "backend": "verible",
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


def _collect_modules(node: dict, modules: list) -> None:
    """Walk normalized tree and collect module definitions."""
    if node.get("type") == "ModuleDef" and "name" in node:
        ports = []
        items = []
        for child in node.get("children", []):
            if child.get("type") == "Port":
                ports.append({
                    "name": child.get("name", ""),
                    "direction": child.get("direction", ""),
                    "width": child.get("width", ""),
                })
            else:
                items.append(child)
        modules.append({
            "name": node["name"],
            "ports": ports,
            "items": items,
        })
    for child in node.get("children", []):
        _collect_modules(child, modules)


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

    result = normalize_verible(input_path, output_path)
    print(json.dumps(result, indent=2))

    sys.exit(0 if result["valid"] else 1)


if __name__ == "__main__":
    main()
