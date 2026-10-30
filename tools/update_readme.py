#!/usr/bin/env python3
"""Rewrites the status block in README.md from status/*.json (+ status/titles.json)."""
import json, pathlib, re
root = pathlib.Path(__file__).resolve().parent.parent
try: META = json.loads((root/"status"/"titles.json").read_text())
except Exception: META = {}
TITLES = META.get("titles", {}); PLAN = META.get("plan", {})
ICON = {"done":"\u2705","doing":"\U0001F504","todo":"\u2B1C","skip":"\u2796"}
def load(x):
    try: d = json.loads((root/"status"/f"{x}.json").read_text())
    except Exception: return [], {}
    t = d.get("tasks", [])
    if isinstance(t, dict): t = [{"id":k,"title":TITLES.get(k,k),"state":v} for k,v in t.items()]
    have = {i.get("id") for i in t}
    for pid in PLAN.get(x, []):
        if pid not in have: t.append({"id":pid,"title":TITLES.get(pid,pid),"state":"todo"})
    for i in t:
        if str(i.get("state","")).startswith("cancel"): i["state"] = "skip"
    return t, d
def block():
    out = []
    for x, label in (("A","Engine"),("B","Screens"),("C","Sound + Story"),("D","World")):
        t, d = load(x)
        done = [i for i in t if i.get("state")=="done"]; total = sum(1 for i in t if i.get("state")!="skip")
        out.append(f"**Platform {x} \u00b7 {label}** \u2014 {len(done)}/{total} done\n")
        for i in t:
            if i.get("state") not in ("done","skip"): out.append(f"- {ICON.get(i.get('state'),'\u2B1C')} {i.get('title', i.get('id'))}")
        if d.get("note"): out.append(f"\n> {str(d['note'])[:220]}")
        out.append("\n<details><summary>Finished (%d)</summary>\n" % len(done))
        out += [f"- \u2705 {i.get('title', i.get('id'))}" for i in done]
        out.append("\n</details>\n")
    return "\n".join(out).strip()
p = root/"README.md"; s = p.read_text()
new = f"<!-- STATUS:START -->\n{block()}\n<!-- STATUS:END -->"
s2 = re.sub(r"<!-- STATUS:START -->.*?<!-- STATUS:END -->", lambda m: new, s, flags=re.S)
if s2 != s: p.write_text(s2)
