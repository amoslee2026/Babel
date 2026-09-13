#!/usr/bin/env python3
"""Parse code review output into structured findings."""
import json, re, sys

def parse(review_text: str) -> dict:
    findings = []
    severity_re = re.compile(r'\[(CRITICAL|HIGH|MEDIUM|LOW)\]', re.IGNORECASE)
    for match in severity_re.finditer(review_text):
        start = match.start()
        end = review_text.find('\n\n', start)
        if end == -1:
            end = min(start + 500, len(review_text))
        findings.append({
            "severity": match.group(1).upper(),
            "description": review_text[start:end].strip(),
        })
    counts = {}
    for f in findings:
        sev = f["severity"]
        counts[sev] = counts.get(sev, 0) + 1
    return {"findings": findings, "counts": counts, "total": len(findings)}

if __name__ == "__main__":
    if len(sys.argv) < 2:
        text = sys.stdin.read()
    else:
        text = open(sys.argv[1]).read()
    print(json.dumps(parse(text), indent=2))
