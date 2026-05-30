#!/usr/bin/env python3
"""Parse generated verification plan."""
import json, re, sys
from pathlib import Path

REQUIRED_SECTIONS = [
    "Functional Coverage Groups",
    "Code Coverage Targets",
    "Functional Test Points",
    "Corner Cases",
    "Random Constraints",
    "Test Case List",
]

def parse(plan_path: str) -> dict:
    """Parse verification plan and validate required sections."""
    text = Path(plan_path).read_text(errors="replace")

    # Find sections
    found_sections = []
    for section in REQUIRED_SECTIONS:
        pattern = re.compile(rf"^##\s+{re.escape(section)}", re.MULTILINE)
        if pattern.search(text):
            found_sections.append(section)

    # Count FTPs
    ftp_matches = re.findall(r"FTP-\d+", text)
    ftp_count = len(set(ftp_matches))

    # Count coverage bins
    bin_matches = re.findall(r"bins\s+\w+", text)
    covergroup_matches = re.findall(r"covergroup\s+\w+", text)
    coverage_bins = len(bin_matches) + len(covergroup_matches)

    missing = [s for s in REQUIRED_SECTIONS if s not in found_sections]

    return {
        "sections": found_sections,
        "missing_sections": missing,
        "section_count": len(found_sections),
        "required_count": len(REQUIRED_SECTIONS),
        "functional_points": ftp_count,
        "coverage_bins": coverage_bins,
        "valid": len(missing) == 0,
    }

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(f"Usage: {sys.argv[0]} <verification_plan.md>", file=sys.stderr)
        sys.exit(1)
    print(json.dumps(parse(sys.argv[1]), indent=2))
