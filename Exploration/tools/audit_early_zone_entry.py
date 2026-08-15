#!/usr/bin/env python3
"""Find travel pins that pull the player into a new map before the prior
explore-map's fog pins are finished.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from pin_io import extract_route_block, parse_route_pins  # noqa: E402

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


def main() -> None:
    text = GENERATED.read_text(encoding="utf-8")
    for route in CURATED:
        try:
            _, _, block = extract_route_block(text, route)
        except KeyError:
            continue
        pins = parse_route_pins(block)
        if not pins:
            continue

        # Track remaining explore counts per map as we walk
        remaining = {}
        for p in pins:
            if not p.get("travel"):
                remaining[p["map"]] = remaining.get(p["map"], 0) + 1

        issues = []
        finished_maps = set()
        current_explore_map = None
        for i, p in enumerate(pins):
            mid = p["map"]
            if p.get("travel"):
                # Travel into a map that isn't the current explore map while
                # current map still has remaining fog pins.
                if (
                    current_explore_map is not None
                    and mid != current_explore_map
                    and remaining.get(current_explore_map, 0) > 0
                ):
                    issues.append(
                        (
                            i,
                            p["name"],
                            mid,
                            current_explore_map,
                            remaining[current_explore_map],
                        )
                    )
                continue

            # explore pin
            if current_explore_map is None:
                current_explore_map = mid
            elif mid != current_explore_map:
                if remaining.get(current_explore_map, 0) > 0:
                    issues.append(
                        (
                            i,
                            p["name"],
                            mid,
                            current_explore_map,
                            remaining[current_explore_map],
                        )
                    )
                finished_maps.add(current_explore_map)
                current_explore_map = mid
            remaining[mid] = remaining.get(mid, 0) - 1
            if remaining[mid] == 0:
                finished_maps.add(mid)

        if issues:
            print(f"\n{route}: {len(issues)} early-zone-entry issues")
            for i, name, mid, cur, left in issues[:25]:
                print(
                    f"  idx={i} {name!r} map={mid} while map {cur} still has {left} fog pins"
                )
        else:
            print(f"OK {route}")


if __name__ == "__main__":
    main()
