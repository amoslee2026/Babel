#!/usr/bin/env python3
"""Parse specification review output into structured findings."""
import json, re, sys

def parse(review_text: str) -> dict:
    findings = []
    categories = ["contradiction", "ambiguity", "missing_requirement", "inconsistency", "untestable"]
    for cat in categories:
        pattern = re.compile(rf'(?i){cat}[:\s]+(.+?)(?:\n\n|\Z)', re.DOTALL)
        for m in pattern.finditer(review_text):
            findings.append({"category": cat, "description": m.group(1).strip()[:200]})
    return {"findings": findings, "total": len(findings), "categories_found": list(set(f["category"] for f in findings))}

if __name__ == "__main__":
    text = open(sys.argv[1]).read() if len(sys.argv) > 1 else sys.stdin.read()
    print(json.dumps(parse(text), indent=2))
