#!/usr/bin/env python3
"""Parse Verilog file_list.f into structured file list."""
import json, sys
from pathlib import Path

def parse(filelist_path: str) -> dict:
    files = []
    includes = []
    defines = []
    for line in Path(filelist_path).read_text().splitlines():
        line = line.strip()
        if not line or line.startswith("//"):
            continue
        if line.startswith("+incdir+"):
            includes.append(line[8:].strip("+"))
        elif line.startswith("+define+"):
            defines.append(line[8:])
        elif line.endswith((".v", ".sv", ".svh")):
            files.append(line)
    return {"files": files, "includes": includes, "defines": defines, "file_count": len(files)}

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(f"Usage: {sys.argv[0]} <file_list.f>", file=sys.stderr)
        sys.exit(1)
    print(json.dumps(parse(sys.argv[1]), indent=2))
