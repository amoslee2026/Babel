#!/usr/bin/env python3
"""Build code review prompt from RTL sources and specifications."""
import json, sys
from pathlib import Path

def build(rtl_dir: str, mas_path: str, role: str = "ruthless") -> dict:
    rtl_files = list(Path(rtl_dir).rglob("*.sv")) + list(Path(rtl_dir).rglob("*.v"))
    mas_content = ""
    if mas_path and Path(mas_path).exists():
        mas_content = Path(mas_path).read_text(errors="replace")[:5000]

    role_instructions = {
        "ruthless": "Find every defect, no matter how minor. Zero tolerance for style violations.",
        "balanced": "Focus on correctness and safety. Note style issues but don't block on them.",
        "mentor": "Explain why each issue matters. Suggest fixes and best practices.",
    }

    return {
        "role": role,
        "role_instruction": role_instructions.get(role, role_instructions["balanced"]),
        "files": [str(f) for f in rtl_files],
        "file_count": len(rtl_files),
        "mas_excerpt": mas_content,
        "review_dimensions": ["correctness", "safety", "style", "performance", "traceability"],
    }

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print(f"Usage: {sys.argv[0]} <rtl_dir> <mas_path> [role]", file=sys.stderr)
        sys.exit(1)
    role = sys.argv[3] if len(sys.argv) > 3 else "ruthless"
    print(json.dumps(build(sys.argv[1], sys.argv[2], role), indent=2))
