#!/usr/bin/env python3
"""Solvability audit for Platform Zero content (AI-C). Exit 1 on any failure.
Checks (objects.json + generated.json + owners):
 1. every item has >=2 clues, from >=2 DIFFERENT bench tools
 2. no two items share an identical set of (attr,value) clues
 3. every clue attr maps to a bench tool and has >=2 possible values (an imposter wrong detail is catchable)
 4. clue text matches its value; generated colour/material/smell/sound values fit the item kind and tint
 5. owner hints point at real clues of the owner's item; claimant names are unique
Usage: python3 tools/audit_solvable.py [--quiet]"""
import collections, json, os, sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
C = os.path.join(ROOT, "content")
TOOL = {"initials": "magnifier", "station_stamp": "magnifier", "color": "lamp", "material": "lamp",
        "sound": "ear", "smell": "nose", "wear": "brush"}


def load(n):
    with open(os.path.join(C, n), encoding="utf-8") as f:
        return json.load(f)


def main():
    quiet = "--quiet" in sys.argv
    objs = load("objects.json")
    gen = load("generated.json")
    owners = load("owners.json") + gen["owners"]
    P = load("procedural.json")
    objs_all = [(o, False) for o in objs] + [(o, True) for o in gen["objects"]]
    by_id = {o["id"]: o for o, _ in objs_all}
    fails, warns = [], []
    values = collections.defaultdict(set)
    for o, _ in objs_all:
        for c in o["clues"]:
            values[c["attr"]].add(str(c["value"]))
    seen = {}
    tool_use = collections.Counter()
    for o, g in objs_all:
        cl = o["clues"]
        tools = {TOOL.get(c["attr"]) for c in cl}
        for c in cl:
            tool_use[TOOL.get(c["attr"], "?")] += 1
        if len(cl) < 2 or len(tools) < 2 or None in tools:
            fails.append("%s: needs >=2 clues from different tools (has %s)" % (o["id"], sorted(map(str, tools))))
        sig = frozenset((c["attr"], str(c["value"])) for c in cl)
        if sig in seen:
            fails.append("%s duplicates clue set of %s" % (o["id"], seen[sig]))
        seen[sig] = o["id"]
        for c in cl:
            if len(values[c["attr"]]) < 2:
                fails.append("%s: attr %s has no alternative value" % (o["id"], c["attr"]))
            v = str(c["value"]).lower().replace("-", " ").replace("_", " ")
            if v not in c["text"].lower().replace("-", " "):
                (fails if g else warns).append("%s: clue text lacks value '%s': %s" % (o["id"], c["value"], c["text"]))
        if g:
            k = P["kinds"].get(o["icon"], {})
            for c in cl:
                a, v = c["attr"], c["value"]
                if a == "color" and P["colors"].get(v, "").lower() != o["tint"].lower():
                    fails.append("%s: colour %s does not match tint %s" % (o["id"], v, o["tint"]))
                for key, lst in (("material", "materials"), ("smell", "smells"), ("sound", "sounds")):
                    if a == key and v not in k.get(lst, []):
                        fails.append("%s: %s '%s' unlikely for %s" % (o["id"], key, v, o["icon"]))
    names = collections.Counter(w["name"] for w in owners)
    fails += ["duplicate claimant name: %s" % n for n, c in names.items() if c > 1]
    for w in owners:
        for iid in w.get("lost_item_ids", []):
            o = by_id.get(iid)
            if o is None:
                fails.append("%s: unknown item %s" % (w["id"], iid))
                continue
            real = {(c["attr"], str(c["value"])) for c in o["clues"]}
            for h in w.get("hints", {}).get(iid, []):
                if (h["attr"], str(h["value"])) not in real:
                    fails.append("%s: hint %s=%s is not a clue of %s" % (w["id"], h["attr"], h["value"], iid))
    for w in fails[:40]:
        print("FAIL", w)
    if not quiet:
        for w in warns[:15]:
            print("warn", w)
    print("audit_solvable: %d items, %d owners, %d fail, %d warn; clues per tool %s" % (
        len(objs_all), len(owners), len(fails), len(warns), dict(tool_use)))
    sys.exit(1 if fails else 0)


if __name__ == "__main__":
    main()
