#!/usr/bin/env python3
"""Validate content/objects.json and content/owners.json against the shared contract.

Usage: validate_content.py [--strict] [--content DIR]
  --strict   a missing objects.json is an error (otherwise a warning)
"""
import argparse
import json
import os
import re
import sys

ICON_KEYS = {
    "mitten", "watch", "card", "jar", "umbrella", "key", "glove", "book", "hat", "ring",
    "bag", "scarf", "spectacles", "ticket", "lantern", "doll", "flute", "compass",
    "thermos", "letter", "shoe", "coin", "photo", "music_box",
}
ATTRS = {"color", "smell", "initials", "station_stamp", "wear", "sound", "material"}
# Attrs the front-end's owners.json currently uses but the contract does not list.
# Tolerated (warning) until AI-B moves their hints onto the contract set.
TOLERATED_ATTRS = {
    "metal", "engraving", "contents", "mark", "shape", "gem", "seal",
    "behavior", "image", "feature", "origin",
}
RARITIES = {"common", "odd", "rare"}
HATS = {"cap", "none", "top", "scarf"}
ACCESSORIES = {"none", "glasses", "beard", "pipe"}
HEX = re.compile(r"^#[0-9A-Fa-f]{6}$")
OBJ_ID = re.compile(r"^obj_\d{3}$")
OWN_ID = re.compile(r"^own_\d{3}$")
EXPECTED_OBJECTS = 40

errors: list[str] = []
warnings: list[str] = []


def err(msg: str) -> None:
    errors.append(msg)


def warn(msg: str) -> None:
    warnings.append(msg)


def load(path: str):
    try:
        with open(path, encoding="utf-8") as f:
            return json.load(f)
    except Exception as e:  # noqa: BLE001
        err(f"{os.path.basename(path)}: cannot parse ({e})")
        return None


def is_str(v) -> bool:
    return isinstance(v, str) and v.strip() != ""


def check_owners(owners) -> dict:
    index: dict = {}
    if not isinstance(owners, list):
        err("owners.json: top level must be an array")
        return index
    for w in owners:
        if not isinstance(w, dict):
            err("owners.json: entry is not an object")
            continue
        wid = w.get("id", "?")
        if not (isinstance(wid, str) and OWN_ID.match(wid)):
            err(f"owner {wid}: id must look like own_001")
        if wid in index:
            err(f"owner {wid}: duplicate id")
        index[wid] = w
        for key in ("name", "thanks_line", "wrong_line"):
            if not is_str(w.get(key)):
                err(f"owner {wid}: missing {key}")
        look = w.get("look")
        if not isinstance(look, dict):
            err(f"owner {wid}: missing look")
        else:
            for key in ("skin", "hair", "coat"):
                if not (isinstance(look.get(key), str) and HEX.match(look[key])):
                    err(f"owner {wid}: look.{key} must be #RRGGBB")
            if look.get("hat") not in HATS:
                err(f"owner {wid}: look.hat must be one of {sorted(HATS)}")
            if look.get("accessory") not in ACCESSORIES:
                err(f"owner {wid}: look.accessory must be one of {sorted(ACCESSORIES)}")
        if not isinstance(w.get("lost_item_ids"), list) or not w.get("lost_item_ids"):
            err(f"owner {wid}: lost_item_ids must be a non-empty array")
        if not isinstance(w.get("claim_lines"), list) or not w.get("claim_lines"):
            err(f"owner {wid}: claim_lines must be a non-empty array")
        if not isinstance(w.get("hints"), dict):
            err(f"owner {wid}: hints must be an object")
        for a in w.get("arc", []) or []:
            if not (isinstance(a, dict) and isinstance(a.get("after_matches"), int) and is_str(a.get("line"))):
                err(f"owner {wid}: bad arc entry {a}")
    return index


def check_objects(objects, owner_index: dict) -> dict:
    index: dict = {}
    if not isinstance(objects, list):
        err("objects.json: top level must be an array")
        return index
    if len(objects) != EXPECTED_OBJECTS:
        err(f"objects.json: expected {EXPECTED_OBJECTS} objects, found {len(objects)}")
    for o in objects:
        if not isinstance(o, dict):
            err("objects.json: entry is not an object")
            continue
        oid = o.get("id", "?")
        if not (isinstance(oid, str) and OBJ_ID.match(oid)):
            err(f"object {oid}: id must look like obj_001")
        if oid in index:
            err(f"object {oid}: duplicate id")
        index[oid] = o
        if not is_str(o.get("name")):
            err(f"object {oid}: missing name")
        if o.get("icon") not in ICON_KEYS:
            err(f"object {oid}: invalid icon key {o.get('icon')!r}")
        if not (isinstance(o.get("tint"), str) and HEX.match(o["tint"])):
            err(f"object {oid}: tint must be #RRGGBB")
        if o.get("rarity") not in RARITIES:
            err(f"object {oid}: rarity must be one of {sorted(RARITIES)}")
        if o.get("owner_id") not in owner_index:
            err(f"object {oid}: owner_id {o.get('owner_id')!r} is not a known owner")
        if not is_str(o.get("story")):
            err(f"object {oid}: missing story")
        clues = o.get("clues")
        if not isinstance(clues, list) or not (2 <= len(clues) <= 4):
            err(f"object {oid}: needs 2-4 clues")
            continue
        seen = set()
        for c in clues:
            if not isinstance(c, dict):
                err(f"object {oid}: clue is not an object")
                continue
            cid = c.get("id")
            if not is_str(cid) or cid in seen:
                err(f"object {oid}: clue id missing or duplicate ({cid!r})")
            seen.add(cid)
            if not is_str(c.get("text")):
                err(f"object {oid}/{cid}: missing text")
            if c.get("attr") in TOLERATED_ATTRS:
                warn(f"object {oid}/{cid}: attr {c.get('attr')!r} is not in the contract set (tolerated)")
            elif c.get("attr") not in ATTRS:
                err(f"object {oid}/{cid}: attr {c.get('attr')!r} not in {sorted(ATTRS)}")
            if not is_str(c.get("value")):
                err(f"object {oid}/{cid}: missing value")
    return index


def cross_check(objects: dict, owners: dict) -> None:
    # every owner's lost items exist and point back at that owner
    for wid, w in owners.items():
        for iid in w.get("lost_item_ids", []):
            if iid not in objects:
                err(f"owner {wid}: lost item {iid} does not exist")
            elif objects[iid].get("owner_id") != wid:
                err(f"owner {wid}: lists {iid} but that object's owner_id is {objects[iid].get('owner_id')!r}")
        for iid, hints in (w.get("hints") or {}).items():
            for h in hints if isinstance(hints, list) else []:
                if isinstance(h, dict) and h.get("attr") not in ATTRS:
                    warn(f"owner {wid}/{iid}: hint attr {h.get('attr')!r} is not in the contract set")
            if iid not in w.get("lost_item_ids", []):
                err(f"owner {wid}: hints for {iid} which is not in lost_item_ids")
                continue
            obj = objects.get(iid)
            if not obj or not isinstance(hints, list):
                continue
            pairs = {(c.get("attr"), c.get("value")) for c in obj.get("clues", []) if isinstance(c, dict)}
            matched = [h for h in hints if isinstance(h, dict) and (h.get("attr"), h.get("value")) in pairs]
            if not matched:
                err(f"owner {wid}/{iid}: no hint overlaps any clue of that object (unsolvable by deduction)")
        for iid in w.get("lost_item_ids", []):
            if iid not in (w.get("hints") or {}):
                warn(f"owner {wid}: no hints for {iid}")
    # every object has an owner that claims it
    for oid, o in objects.items():
        w = owners.get(o.get("owner_id"))
        if w is not None and oid not in w.get("lost_item_ids", []):
            err(f"object {oid}: owner {w['id']} does not list it in lost_item_ids")


def check_icon_files(root: str) -> None:
    icons = os.path.join(root, "assets", "icons")
    if not os.path.isdir(icons):
        warn("assets/icons not found; skipping icon file check")
        return
    for key in sorted(ICON_KEYS):
        if not os.path.exists(os.path.join(icons, f"{key}.svg")):
            warn(f"assets/icons/{key}.svg missing")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--strict", action="store_true")
    ap.add_argument("--content", default=None)
    args = ap.parse_args()
    root = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
    content = args.content or os.path.join(root, "content")

    owners_path = os.path.join(content, "owners.json")
    objects_path = os.path.join(content, "objects.json")
    owners_data = load(owners_path) if os.path.exists(owners_path) else None
    if owners_data is None and not os.path.exists(owners_path):
        warn("owners.json not present yet")
    owner_index = check_owners(owners_data) if owners_data is not None else {}

    if os.path.exists(objects_path):
        objects_data = load(objects_path)
        object_index = check_objects(objects_data, owner_index) if objects_data is not None else {}
        if owner_index and object_index:
            cross_check(object_index, owner_index)
    else:
        (err if args.strict else warn)("objects.json not present yet")

    if args.content is None:
        check_icon_files(root)

    for w in warnings:
        print(f"WARN  {w}")
    for e in errors:
        print(f"ERROR {e}")
    print(f"validate_content: {len(errors)} error(s), {len(warnings)} warning(s)")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
