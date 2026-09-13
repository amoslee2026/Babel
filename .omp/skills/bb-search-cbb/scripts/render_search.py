#!/usr/bin/env python3
"""Render CBB search query from requirements."""
import json, sys

def render(requirements: dict) -> dict:
    keywords = requirements.get("keywords", [])
    category = requirements.get("category", "")
    return {
        "query": " ".join(keywords),
        "category": category,
        "search_paths": ["wiki/cbb/", "rtl/cbb/"],
        "max_results": requirements.get("max_results", 10),
    }

if __name__ == "__main__":
    with open(sys.argv[1]) as f:
        reqs = json.load(f)
    print(json.dumps(render(reqs), indent=2))
