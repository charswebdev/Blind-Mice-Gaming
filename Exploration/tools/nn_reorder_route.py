#!/usr/bin/env python3
"""NN-reorder a curated Generated.lua route without stripping pin metadata.

Preserves triggers (zone/buff/cast/proximity+radius), notes, travel flags,
actions, and preceding -- comments by rewriting pin *order* only.

Usage:
  python tools/nn_reorder_route.py --route "Burning Crusade - Exploration" --start "The Stair of Destiny" --maps 100,102,108,107,105,109,104
  python tools/nn_reorder_route.py --route "WoD - Exploration - Alliance" --start "Starfall Outpost" --keep-prefix 1
"""
from __future__ import annotations

import argparse
import math
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from pin_io import extract_route_block, parse_route_pins, replace_route_pins  # noqa: E402

GENERATED = Path(__file__).resolve().parents[1] / "Data" / "Routes" / "Generated.lua"


def two_opt(run, passes=40):
    n = len(run)
    if n < 4:
        return run
    best = run[:]

    def length(path):
        s = 0.0
        for i in range(len(path) - 1):
            s += math.hypot(path[i + 1]["x"] - path[i]["x"], path[i + 1]["y"] - path[i]["y"])
        return s

    best_len = length(best)
    for _ in range(passes):
        improved = False
        for i in range(1, n - 2):
            for k in range(i + 1, n - 1):
                cand = best[:i] + best[i : k + 1][::-1] + best[k + 1 :]
                cl = length(cand)
                if cl + 1e-9 < best_len:
                    best, best_len = cand, cl
                    improved = True
        if not improved:
            break
    return best


def nn_from(start_pin, group):
    remaining = [
        p
        for p in group
        if not (
            p["name"] == start_pin["name"]
            and p["map"] == start_pin["map"]
            and abs(p["x"] - start_pin["x"]) < 1e-9
            and abs(p["y"] - start_pin["y"]) < 1e-9
        )
    ]
    ordered = [start_pin]
    while remaining:
        lx, ly = ordered[-1]["x"], ordered[-1]["y"]
        best_i = min(
            range(len(remaining)),
            key=lambda i: (remaining[i]["x"] - lx) ** 2 + (remaining[i]["y"] - ly) ** 2,
        )
        ordered.append(remaining.pop(best_i))
    return two_opt(ordered)


def path_len(ps):
    s = 0.0
    for i in range(len(ps) - 1):
        if ps[i]["map"] == ps[i + 1]["map"]:
            s += math.hypot(ps[i + 1]["x"] - ps[i]["x"], ps[i + 1]["y"] - ps[i]["y"])
    return s


def main():
    ap = argparse.ArgumentParser(
        description="NN-reorder a route while preserving full pin source text."
    )
    ap.add_argument("--route", required=True)
    ap.add_argument("--start", required=True, help="First explore pin name (after optional prefix)")
    ap.add_argument("--maps", default="", help="Comma map IDs for zone visit order")
    ap.add_argument("--keep-prefix", type=int, default=0, help="Keep first N pins unchanged (travel)")
    ap.add_argument("--zone-starts", default="", help="mapId:Name,mapId:Name preferred zone starts")
    ap.add_argument(
        "--dry-run",
        action="store_true",
        help="Print plan only; do not write Generated.lua",
    )
    args = ap.parse_args()

    text = GENERATED.read_text(encoding="utf-8")
    start, end, block = extract_route_block(text, args.route)

    pins = parse_route_pins(block)
    if not pins:
        raise SystemExit("no pins parsed")

    # Sanity: every pin must have preservable raw text
    missing_raw = [p["name"] for p in pins if not p.get("raw")]
    if missing_raw:
        raise SystemExit(f"pins missing raw source (parser bug): {missing_raw[:5]}")

    prefix = pins[: args.keep_prefix]
    body = pins[args.keep_prefix :]

    start_pin = next((p for p in body if p["name"] == args.start), None)
    if start_pin is None:
        raise SystemExit(f"start pin not in route: {args.start}")

    by_map: dict[int, list] = {}
    for p in body:
        by_map.setdefault(p["map"], []).append(p)

    if args.maps:
        map_order = [int(x) for x in args.maps.split(",") if x.strip()]
        map_order = [mid for mid in map_order if mid in by_map]
    else:
        map_order = [start_pin["map"]]
        for p in body:
            if p["map"] not in map_order:
                map_order.append(p["map"])

    zone_starts = {start_pin["map"]: args.start}
    if args.zone_starts:
        for part in args.zone_starts.split(","):
            if not part.strip():
                continue
            mid_s, name = part.split(":", 1)
            zone_starts[int(mid_s)] = name

    grouped = []
    for mid in map_order:
        group = by_map[mid]
        pref = zone_starts.get(mid)
        sp = next((p for p in group if p["name"] == pref), None) if pref else None
        if sp is None:
            sp = group[0]
        ordered = nn_from(sp, group)
        print(f"map {mid}: start={ordered[0]['name']} pins={len(ordered)}")
        grouped.extend(ordered)

    # Append any maps not listed in --maps (should not drop pins)
    for mid, group in by_map.items():
        if mid not in map_order:
            print(f"WARN: map {mid} not in --maps; appending NN order ({len(group)} pins)")
            grouped.extend(nn_from(group[0], group))

    new_pins = prefix + grouped
    if len(new_pins) != len(pins):
        raise SystemExit(
            f"pin count changed {len(pins)} -> {len(new_pins)}; refusing to write"
        )

    print(f"{args.route}: {len(pins)} pins, within-map {path_len(body):.1f} -> {path_len(grouped):.1f}")
    print(f"first explore: {grouped[0]['name']} map={grouped[0]['map']}")
    print("metadata: preserved (raw pin source + comments)")

    if args.dry_run:
        # Spot-check a non-proximity pin still has its trigger in raw
        special = [
            p
            for p in new_pins
            if "type = \"zone\"" in (p.get("pin_src") or "")
            or "type = \"buff\"" in (p.get("pin_src") or "")
            or "type = \"cast\"" in (p.get("pin_src") or "")
        ]
        print(f"non-proximity pins preserved: {len(special)}")
        if special:
            print("  example:", special[0]["name"], "->", special[0]["pin_src"][:80], "...")
        return

    dv_m = re.search(r"dataVersion\s*=\s*(\d+)", block)
    new_dv = int(dv_m.group(1)) + 1 if dv_m else 1
    block2 = re.sub(r"dataVersion\s*=\s*\d+", f"dataVersion = {new_dv}", block, count=1)
    new_block = replace_route_pins(block2, new_pins)
    GENERATED.write_text(text[:start] + new_block + text[end:], encoding="utf-8", newline="\n")
    print(f"Wrote dataVersion={new_dv}")


if __name__ == "__main__":
    main()
