#!/usr/bin/env python3
"""Enforce zone-complete ordering on all curated exploration routes.

Rules:
  1. Explore pins for each map appear as one contiguous block.
  2. Map visit order = first-appearance order (chapter intent preserved).
  3. Within each map: NN + 2-opt from that map's original first pin.
  4. Leading travel prefix unchanged. Other travel pins move to the boundary
     after the map they followed (never splitting a map's fog pins).

Usage:
  python tools/enforce_zone_complete.py
  python tools/enforce_zone_complete.py --dry-run
  python tools/enforce_zone_complete.py --route "Burning Crusade - Exploration"
"""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from pin_io import extract_route_block, parse_route_pins, replace_route_pins  # noqa: E402
from nn_reorder_route import nn_from, path_len  # noqa: E402

GENERATED = Path(__file__).resolve().parents[1] / "Data" / "Routes" / "Generated.lua"

CURATED = [
    "BFA Alliance - Exploration",
    "BFA Horde - Exploration",
    "Classic EK - Exploration",
    "Classic Kalimdor - Exploration",
    "WoD - Exploration - Alliance",
    "WoD - Exploration - Horde",
    "MoP - Exploration",
    "Cataclysm - Mainland",
    "Cataclysm - Vashj'ir",
    "Cataclysm - Deepholm",
    "Cataclysm - Finale - Alliance",
    "Cataclysm - Finale - Horde",
    "Burning Crusade - Exploration",
    "Legion - Exploration",
    "Northrend - Exploration",
    "Dragonflight - Exploration",
    "The War Within - Isle of Dorn",
    "The War Within - The Ringing Deeps",
    "The War Within - Hallowfall",
    "The War Within - Azj-Kahet",
    "The War Within - City of Threads",
    "Midnight - Harandar",
    "Midnight - Voidstorm",
    "Midnight - Silvermoon & Quel'Danas",
    "Midnight - Eversong Woods",
    "Midnight - Zul'Aman",
]


def leading_travel_count(pins: list) -> int:
    n = 0
    for p in pins:
        if p.get("travel"):
            n += 1
        else:
            break
    return n


def has_map_reentry(explore: list) -> bool:
    seen = set()
    run = None
    for p in explore:
        if p["map"] != run:
            if p["map"] in seen:
                return True
            seen.add(p["map"])
            run = p["map"]
    return False


def reorder_pins(pins: list) -> tuple[list, list[int], float, float]:
    prefix_n = leading_travel_count(pins)
    prefix = list(pins[:prefix_n])
    body = pins[prefix_n:]

    explore = [p for p in body if not p.get("travel")]
    if len(explore) < 2:
        return pins, [], 0.0, 0.0

    map_order: list[int] = []
    for p in explore:
        if p["map"] not in map_order:
            map_order.append(p["map"])

    by_map: dict[int, list] = {m: [] for m in map_order}
    for p in explore:
        by_map[p["map"]].append(p)

    # Travels after each map: when we leave map A (next explore is B!=A),
    # or at end of body, attach pending travels to A.
    after_map: dict[int, list] = {m: [] for m in map_order}
    pending: list = []
    last_map = None
    for p in body:
        if p.get("travel"):
            pending.append(p)
            continue
        if pending and last_map is not None:
            after_map[last_map].extend(pending)
            pending = []
        last_map = p["map"]
    if pending and last_map is not None:
        after_map[last_map].extend(pending)
    elif pending:
        prefix.extend(pending)

    old_len = path_len(explore)
    grouped: list = []
    for mid in map_order:
        group = by_map[mid]
        grouped.extend(nn_from(group[0], group))
        grouped.extend(after_map[mid])

    new_pins = prefix + grouped
    if len(new_pins) != len(pins):
        raise RuntimeError(f"pin count {len(pins)} -> {len(new_pins)}")
    if has_map_reentry([p for p in new_pins if not p.get("travel")]):
        raise RuntimeError("reorder left a map re-entry")

    new_len = path_len([p for p in new_pins if not p.get("travel")])
    return new_pins, map_order, old_len, new_len


def process_route(text: str, route: str, dry_run: bool) -> tuple[str, bool]:
    start, end, block = extract_route_block(text, route)
    pins = parse_route_pins(block)
    explore = [p for p in pins if not p.get("travel")]
    if len(explore) < 2:
        print(f"SKIP tiny: {route}")
        return text, False

    viol = has_map_reentry(explore)
    new_pins, map_order, old_len, new_len = reorder_pins(pins)
    changed = [p["name"] for p in pins] != [p["name"] for p in new_pins]
    print(
        f"{route}: maps={map_order} path {old_len:.1f}->{new_len:.1f} "
        f"{'REORDER' if changed else 'ok'} reentry_before={viol}"
    )

    if dry_run or not changed:
        return text, changed

    dv_m = re.search(r"dataVersion\s*=\s*(\d+)", block)
    new_dv = int(dv_m.group(1)) + 1 if dv_m else 1
    block2 = re.sub(r"dataVersion\s*=\s*\d+", f"dataVersion = {new_dv}", block, count=1)
    new_block = replace_route_pins(block2, new_pins)
    print(f"  dataVersion={new_dv}")
    return text[:start] + new_block + text[end:], True


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--route", default="")
    args = ap.parse_args()

    text = GENERATED.read_text(encoding="utf-8")
    routes = [args.route] if args.route else CURATED
    any_changed = False
    for route in routes:
        try:
            text, changed = process_route(text, route, args.dry_run)
            any_changed = any_changed or changed
        except KeyError:
            print(f"SKIP missing: {route}")
        except Exception as e:
            print(f"ERROR {route}: {e}")
            return 1

    if any_changed and not args.dry_run:
        GENERATED.write_text(text, encoding="utf-8", newline="\n")
        print("Wrote Generated.lua")
    elif args.dry_run:
        print("Dry-run only; no write")
    else:
        print("No route order changes (already zone-complete blocks)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
