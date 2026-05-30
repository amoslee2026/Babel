#!/usr/bin/env python3
"""Generate parser configuration script from input parameters.

Renders a Python script that uses pyverilog to parse RTL files
and serialize the AST to JSON via ast_serializer.
"""
import json
import sys
from pathlib import Path


def render_parser_script(
    file_list: str,
    design_name: str,
    output_path: str,
    serializer_lib: str,
) -> str:
    """Render a standalone Python parser script.

    Args:
        file_list: Path to file_list.f containing RTL file paths.
        design_name: Name of the design being parsed.
        output_path: Path where the AST JSON will be written.
        serializer_lib: Path to the bb-parse-ast lib directory containing ast_serializer.

    Returns:
        Python source code as a string.
    """
    return f'''#!/usr/bin/env python3
"""Auto-generated parser script for {design_name}."""
import json
import sys
from pathlib import Path

# Add serializer library to path
sys.path.insert(0, {json.dumps(serializer_lib)})
from ast_serializer import serialize_ast

from pyverilog.vparser.parser import parse

def main():
    file_list_path = {json.dumps(file_list)}
    output_path = {json.dumps(output_path)}

    # Read file list
    files = [l.strip() for l in open(file_list_path) if l.strip() and not l.startswith("//")]
    if not files:
        print("ERROR: No files in file list", file=sys.stderr)
        sys.exit(1)

    # Parse with pyverilog
    ast, _ = parse(files)

    # Serialize to JSON
    result = serialize_ast(ast)
    result["design_name"] = {json.dumps(design_name)}
    result["source_files"] = files

    # Write output
    Path(output_path).parent.mkdir(parents=True, exist_ok=True)
    with open(output_path, "w") as f:
        json.dump(result, f, indent=2)

    module_names = [m["name"] for m in result["modules"]]
    print(f"Parsed {{len(files)}} files, found {{len(module_names)}} modules: {{module_names}}")

if __name__ == "__main__":
    main()
'''


def main():
    if len(sys.argv) < 5:
        print(
            f"Usage: {sys.argv[0]} <file_list> <design_name> <output_path> <serializer_lib>",
            file=sys.stderr,
        )
        sys.exit(1)

    file_list = sys.argv[1]
    design_name = sys.argv[2]
    output_path = sys.argv[3]
    serializer_lib = sys.argv[4]

    script = render_parser_script(file_list, design_name, output_path, serializer_lib)
    print(script)


if __name__ == "__main__":
    main()
