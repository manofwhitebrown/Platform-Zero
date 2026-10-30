#!/usr/bin/env python3
"""Deterministic generator: content/procedural.json (templates) -> content/generated.json.
Usage: python3 tools/gen_procedural.py [--seed N] [--count N]
Ids: obj_201.. / own_201.. (one owner per generated item). Same seed => identical output."""
import argparse, json, os, random, string

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
C = os.path.join(ROOT, "content")
HATS = ["cap", "none", "top", "scarf"]
ACCS = ["none", "glasses", "beard", "pipe"]
SKINS = ["#f1c9a5", "#d9a47a", "#b9805a", "#8d5a3c", "#6b4430"]
HAIRS = ["#2a1d14", "#3b2a20", "#6b4a2b", "#a86b2e", "#c9c3b5", "#1d1d24"]
COATS = ["#7FA6A3", "#B8893E", "#C8503C", "#5b6f8c", "#6d5a7a", "#4f7a58", "#8a8f99"]
PANTS = ["#2f3a40", "#3a3340", "#40362f", "#2c3b33"]
SHOES = ["#2a1d14", "#1d1d24", "#3b2a20"]


def load(n):
    with open(os.path.join(C, n), encoding="utf-8") as f:
        return json.load(f)


def wpick(r, weights, exclude=()):
    keys = [k for k in weights if k not in exclude]
    return r.choices(keys, [weights[k] for k in keys])[0]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--seed", type=int, default=None)
    ap.add_argument("--count", type=int, default=None)
    a = ap.parse_args()
    P = load("procedural.json")
    seed = a.seed if a.seed is not None else P["seed"]
    count = a.count if a.count is not None else P["count"]
    names = load("names.json")
    full = set(names["full"])
    pool = [f"{f} {l}" for f in names["first"] for l in names["last"] if f"{f} {l}" not in full]
    stops = [s["name"] for s in load("routes.json")["stops"]] + P["extra_stations"]
    stops = sorted(set(stops))
    r = random.Random(seed)
    r.shuffle(pool)
    kinds = sorted(P["kinds"])
    colors = P["colors"]
    ot = P["owner_text"]
    seen_names, seen_combo, seen_sig = set(), set(), set()
    objects, owners = [], []
    i = 0
    guard = 0
    while len(objects) < count and guard < count * 50:
        guard += 1
        kind = kinds[len(objects) % len(kinds)] if guard <= count else r.choice(kinds)
        k = P["kinds"][kind]
        mat = r.choice(k["materials"])
        col = r.choice(sorted(colors))
        if (kind, mat, col) in seen_combo:
            continue
        nm = f"{r.choice(P['adjectives'])} {r.choice(k['names'])}"
        if nm in seen_names:
            continue
        seen_combo.add((kind, mat, col))
        seen_names.add(nm)
        idx = 201 + len(objects)
        rar = r.choices(["common", "odd", "rare"], [70, 22, 8])[0]
        n = 3 if rar != "common" or r.random() < 0.55 else 2
        attrs = []
        while len(attrs) < n:
            at = wpick(r, ot["clue_weights"], attrs)
            attrs.append(at)
        if rar == "rare" and not ({"initials", "station_stamp"} & set(attrs)):
            attrs[-1] = r.choice(["initials", "station_stamp"])
        tools_of = {"initials": "m", "station_stamp": "m", "color": "l", "material": "l", "sound": "e", "smell": "n", "wear": "b"}
        if len({tools_of[a] for a in attrs}) < 2:  # C5: never solvable by one tool alone
            attrs[-1] = wpick(r, ot["clue_weights"], list(attrs) + ["color", "material"])
        vals = {
            "color": col, "material": mat, "smell": r.choice(k["smells"]), "sound": r.choice(k["sounds"]),
            "wear": r.choice(P["wear"]),
            "initials": "%s.%s." % (r.choice(string.ascii_uppercase), r.choice(string.ascii_uppercase)),
            "station_stamp": r.choice(stops),
        }
        sig = frozenset((a, str(vals[a])) for a in attrs)
        if sig in seen_sig:  # C5: no two items with identical clue sets
            seen_combo.discard((kind, mat, col))
            seen_names.discard(nm)
            continue
        seen_sig.add(sig)
        clues = []
        for ci, at in enumerate(attrs, 1):
            clues.append({"id": f"c{ci}", "text": r.choice(P["clue_text"][at]).format(v=vals[at]), "attr": at, "value": vals[at]})
        oname = pool.pop()
        oid = f"own_{idx}"
        did = f"obj_{idx}"
        hint = r.choice(clues)
        look = {"skin": r.choice(SKINS), "hair": r.choice(HAIRS), "coat": r.choice(COATS), "hat": r.choice(HATS),
                "accessory": r.choice(ACCS), "build": r.choice(ot["builds"]), "height": round(r.uniform(0.92, 1.08), 2),
                "hair_style": r.choice(ot["hair_styles"]), "pants": r.choice(PANTS), "shoes": r.choice(SHOES)}
        objects.append({"id": did, "name": nm, "icon": kind, "tint": colors[col], "rarity": rar, "owner_id": oid,
                        "clues": clues, "story": r.choice(ot["story"]).format(n=oname.split()[0])})
        art = k["article_noun"]
        owners.append({"id": oid, "name": oname, "look": look, "lost_item_ids": [did],
                       "claim_lines": [f"I lost {art}. {r.choice(ot['vague'])}", f"Has anyone handed in {art}? {r.choice(ot['vague'])}"],
                       "hints": {did: [{"attr": hint["attr"], "value": hint["value"]}]},
                       "thanks_line": r.choice(ot["thanks"]), "wrong_line": r.choice(ot["wrong"])})
    with open(os.path.join(C, "generated.json"), "w", encoding="utf-8") as f:
        json.dump({"_doc": "GENERATED by tools/gen_procedural.py from procedural.json. Do not hand-edit.", "seed": seed, "objects": objects, "owners": owners}, f, indent=1)
        f.write("\n")
    print(f"generated {len(objects)} objects, {len(owners)} owners (seed {seed})")


if __name__ == "__main__":
    main()
