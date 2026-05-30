#!/usr/bin/env python3
"""Parse markdown tables to extract interface signal definitions."""
import json, re, sys
from pathlib import Path

def parse_tables(md_path: str) -> dict:
    text = Path(md_path).read_text(errors="replace")
    tables = []
    in_table = False
    current = []
    for line in text.split("\n"):
        if "|" in line and "---" not in line:
            in_table = True
            cells = [c.strip() for c in line.split("|") if c.strip()]
            if cells:
                current.append(cells)
        elif in_table and "---" in line:
            continue  # separator
        elif in_table:
            if current:
                tables.append(current)
            current = []
            in_table = False
    if current:
        tables.append(current)
    return {"tables": tables, "table_count": len(tables), "source": md_path}

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(f"Usage: {sys.argv[0]} <file.md>", file=sys.stderr)
        sys.exit(1)
    print(json.dumps(parse_tables(sys.argv[1]), indent=2))
