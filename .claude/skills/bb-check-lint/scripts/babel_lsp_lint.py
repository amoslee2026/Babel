#!/usr/bin/env uv run python
"""babel-lsp SV syntax check CLI wrapper.

Uses slang (the same engine Babel-LSP uses internally via sv-analyzer) for
SystemVerilog syntax checking. Parses slang output into the same JSON format
as verible's run_lint.py, so downstream consumers (bb-check-lint, bba-guru-rtl)
are backend-agnostic.

2026-07-21: Created as part of Babel-LSP integration.
            Babel-LSP (https://github.com/amoslee2026/Babel-LSP) provides
            the LSP/MCP layer; this script provides the CLI check path.

Usage:
    uv run python babel_lsp_lint.py <top_module> <rtl_dir> [--tb]
    uv run python babel_lsp_lint.py --files file1.sv file2.sv [--tb]
"""
import sys
import subprocess
import json
import re
import shutil
from pathlib import Path


def find_slang() -> str | None:
    """Locate slang binary. Checks ~/.local/bin first, then PATH."""
    local_bin = Path.home() / ".local" / "bin" / "slang"
    if local_bin.is_file():
        return str(local_bin)
    return shutil.which("slang")


def parse_slang_output(output: str) -> list[dict]:
    """Parse slang diagnostic output into structured list.

    slang format: file.sv:10:5: error: message
                  file.sv:10:5: warning: message
                  file.sv:10:5: note: message
    """
    diagnostics = []
    pattern = re.compile(
        r'^(?P<file>[^:]+):(?P<line>\d+):(?P<col>\d+):\s*'
        r'(?P<severity>error|warning|note):\s*(?P<message>.+)$'
    )
    for line in output.splitlines():
        line = line.strip()
        if not line:
            continue
        m = pattern.match(line)
        if m:
            diagnostics.append({
                "file": m.group("file"),
                "line": int(m.group("line")),
                "col": int(m.group("col")),
                "severity": m.group("severity"),
                "message": m.group("message"),
                "source": "babel-lsp",  # slang is babel-lsp's SV engine
            })
    return diagnostics


def check_file(slang_path: str, file_path: str, include_dirs: list[str] | None = None) -> tuple[int, str, str]:
    """Run slang --check-only on a single file. Returns (rc, stdout, stderr)."""
    cmd = [slang_path, "--check-only", "--error-limit=0"]
    if include_dirs:
        for d in include_dirs:
            cmd += [f"-I{d}"]
    cmd.append(file_path)
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=120)
        return result.returncode, result.stdout, result.stderr
    except subprocess.TimeoutExpired:
        return -1, "", f"timeout checking {file_path}"
    except FileNotFoundError:
        return -1, "", f"slang not found at {slang_path}"


def run_babel_lsp_lint(
    top_module: str,
    rtl_dir: str,
    is_tb: bool = False,
    include_dirs: list[str] | None = None,
) -> dict:
    """Run babel-lsp (slang) syntax check on RTL/TB files.

    Returns JSON-compatible dict matching bb-check-lint output contract.
    """
    slang_path = find_slang()
    if not slang_path:
        return {
            "valid": False,
            "error": "babel-lsp dependency missing: slang not found. "
                     "Run scripts/install-babel-lsp.sh to install.",
        }

    rtl_path = Path(rtl_dir)
    sv_files = sorted(rtl_path.glob("*.sv")) + sorted(rtl_path.glob("*.v"))
    if not sv_files:
        return {"valid": False, "error": "No HDL files found in " + rtl_dir}

    all_diagnostics: list[dict] = []
    errors: list[dict] = []
    warnings: list[dict] = []

    for f in sv_files:
        rc, stdout, stderr = check_file(slang_path, str(f), include_dirs)
        combined = stdout + "\n" + stderr
        diags = parse_slang_output(combined)
        all_diagnostics.extend(diags)

        for d in diags:
            if d["severity"] == "error":
                errors.append(d)
            elif d["severity"] == "warning":
                warnings.append(d)

    src_clean = len(errors) == 0

    return {
        "valid": True,
        "backend": "babel-lsp",
        "top_module": top_module,
        "src_clean": src_clean,
        "errors": errors,
        "warnings": warnings,
        "error_count": len(errors),
        "warning_count": len(warnings),
        "file_count": len(sv_files),
        "diagnostics": all_diagnostics,
        "status": "pass" if src_clean else "fail",
    }


def run_babel_lsp_lint_files(
    files: list[str],
    include_dirs: list[str] | None = None,
) -> dict:
    """Check explicit file list (for file_list.f mode)."""
    slang_path = find_slang()
    if not slang_path:
        return {
            "valid": False,
            "error": "babel-lsp dependency missing: slang not found. "
                     "Run scripts/install-babel-lsp.sh to install.",
        }

    all_diagnostics: list[dict] = []
    errors: list[dict] = []
    warnings: list[dict] = []

    for f in files:
        rc, stdout, stderr = check_file(slang_path, f, include_dirs)
        combined = stdout + "\n" + stderr
        diags = parse_slang_output(combined)
        all_diagnostics.extend(diags)
        for d in diags:
            if d["severity"] == "error":
                errors.append(d)
            elif d["severity"] == "warning":
                warnings.append(d)

    src_clean = len(errors) == 0
    return {
        "valid": True,
        "backend": "babel-lsp",
        "src_clean": src_clean,
        "errors": errors,
        "warnings": warnings,
        "error_count": len(errors),
        "warning_count": len(warnings),
        "file_count": len(files),
        "diagnostics": all_diagnostics,
        "status": "pass" if src_clean else "fail",
    }


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(
            "Usage: babel_lsp_lint.py <top_module> <rtl_dir> [--tb]\n"
            "       babel_lsp_lint.py --files file1.sv file2.sv [--tb]",
            file=sys.stderr,
        )
        sys.exit(1)

    if sys.argv[1] == "--files":
        is_tb = "--tb" in sys.argv[2:]
        files = [a for a in sys.argv[2:] if a != "--tb"]
        result = run_babel_lsp_lint_files(files)
    else:
        is_tb = "--tb" in sys.argv[3:]
        result = run_babel_lsp_lint(sys.argv[1], sys.argv[2], is_tb)

    print(json.dumps(result, indent=2, ensure_ascii=False))
    sys.exit(0 if result.get("status") == "pass" else 1)
