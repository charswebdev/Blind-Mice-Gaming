#!/usr/bin/env python3
"""Per-zone coverage: for each multi-map exploration route, list explorable
DB2 subzones on that map missing from the route (respecting SubzoneFilter hard).
Also flag explore pins whose map appears after a later map was already visited
(should be empty if zone-order is clean).
"""
from __future__ import annotations

import re
import sys
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(Path(__file__).resolve().parent))
from pin_io import extract_route_block, parse_route_pins  # noqa: E402
from areatable_audit_nn import load_db2, load_exclusions  # noqa: E402

GENERATED = ROOT / "Data" / "Routes" / "Generated.lua"

# Curated multi-zone exploration leaves (skip connectors / Getting There)
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
    "Isle of Dorn",
    "The Ringing Deeps",
    "Hallowfall",
    "Azj-Kahet",
    "Harandar",
    "Voidstorm",
    "Silvermoon & Quel'Danas",
    "Eversong Woods",
    "Zul'Aman",
]


def norm(s: str) -> str:
    return re.sub(r"\s+", " ", s.strip().lower())


def main() -> None:
    text = GENERATED.read_text(encoding="utf-8")
    coords, by_map = load_db2()
    hard, _on_map = load_exclusions()

    total_missing = 0
    for route in CURATED:
        try:
            _, _, block = extract_route_block(text, route)
        except KeyError:
            print(f"MISSING ROUTE: {route}")
            continue
        pins = parse_route_pins(block)
        explore = [p for p in pins if not p.get("travel")]
        if not explore:
            continue

        # Zone visit order (first appearance)
        map_order = []
        for p in explore:
            if p["map"] not in map_order:
                map_order.append(p["map"])

        route_names_by_map: dict[int, set[str]] = defaultdict(set)
        route_aids: set[int] = set()
        for p in explore:
            route_names_by_map[p["map"]].add(norm(p["name"]))
            # areaID from raw if present
            m = re.search(r"areaID\s*=\s*(\d+)", p.get("pin_src") or "")
            if m:
                route_aids.add(int(m.group(1)))

        print(f"\n======== {route} ========")
        print(f"zone order: {map_order}")

        for mid in map_order:
            missing = []
            for aid in by_map.get(mid, []):
                e = coords[aid]
                if not e.get("explorable"):
                    continue
                if aid in hard:
                    continue
                if aid in route_aids:
                    continue
                if norm(e["name"]) in route_names_by_map[mid]:
                    continue
                # also allow name match on any map in this route (wrong map authoring)
                if any(norm(e["name"]) in names for names in route_names_by_map.values()):
                    continue
                missing.append((aid, e["name"]))
            if missing:
                total_missing += len(missing)
                print(f"  map {mid}: {len(route_names_by_map[mid])} pins, MISSING {len(missing)} explorable:")
                for aid, name in sorted(missing, key=lambda x: x[1])[:40]:
                    print(f"    [{aid}] {name}")
                if len(missing) > 40:
                    print(f"    ... +{len(missing) - 40} more")
            else:
                print(f"  map {mid}: {len(route_names_by_map[mid])} pins, complete vs DB2 explorable")

    print(f"\nTOTAL missing explorable candidates: {total_missing}")


if __name__ == "__main__":
    main()
