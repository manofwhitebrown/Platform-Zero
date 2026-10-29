#!/usr/bin/env python3
"""Content validator (minimal; full checks arrive in A3)."""
import json, os, sys

root = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "content")
ok = True
for name in ("objects.json", "owners.json"):
    p = os.path.join(root, name)
    if not os.path.exists(p):
        print(f"skip: {name} not present yet")
        continue
    try:
        json.load(open(p, encoding="utf-8"))
    except Exception as e:
        print(f"ERROR {name}: {e}")
        ok = False
sys.exit(0 if ok else 1)
