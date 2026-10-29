#!/usr/bin/env python3
"""Rewrites the status block in README.md from status/A.json and status/B.json."""
import json, pathlib, re
root = pathlib.Path(__file__).resolve().parent.parent
TITLES = {"A1":"Scaffold + autoload stubs","A2":"Android export + CI build","A3":"Content loader + validator","A4":"Clock, save, offline arrivals","A5":"Inspect, match, reputation","A6":"Daily mystery + share text","A7":"40 objects content","A8":"Tests + integration fixes","B1":"Theme + UI kit","B7":"Icons, backdrop, shaders","B2":"Main scene + navigation","B3":"Counter + inspect popup","B4":"Owner visit + matching","B9":"15 owners content","B5":"Shelf, catalog, gallery","B6":"Daily + share card","B8":"Audio, haptics, polish"}
ICON = {"done":"✅","doing":"🔄","todo":"⬜"}
def load(x):
    try: d = json.loads((root/"status"/f"{x}.json").read_text())
    except Exception: return []
    t = d.get("tasks", [])
    if isinstance(t, dict): t = [{"id":k,"title":TITLES.get(k,k),"state":v} for k,v in t.items()]
    return t
def block():
    out = []
    for x, label in (("A","Engine"),("B","Front")):
        t = load(x); done = sum(1 for i in t if i.get("state")=="done")
        out.append(f"**Platform {x} · {label}** — {done}/{len(t)} done\n")
        out += [f"- {ICON.get(i.get('state'),'⬜')} {i.get('title', i.get('id'))}" for i in t]
        out.append("")
    return "\n".join(out).strip()
p = root/"README.md"; s = p.read_text()
new = f"<!-- STATUS:START -->\n{block()}\n<!-- STATUS:END -->"
s2 = re.sub(r"<!-- STATUS:START -->.*?<!-- STATUS:END -->", lambda m: new, s, flags=re.S)
if s2 != s: p.write_text(s2)
