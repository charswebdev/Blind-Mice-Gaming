#!/usr/bin/env python3
"""Find explore pins whose authored map disagrees with DB2 area map
(subzone belonging to zone A sitting in zone B's route block).
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(Path(__file__).resolve().parent))
from pin_io import extract_route_block, parse_route_pins  # noqa: E402
from areatable_audit_nn import load_db2, load_exclusions  # noqa: E402

GENERATED = ROOT / "Data" / "Routes" / "Generated.lua"

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
]


def norm(s: str) -> str:
    return re.sub(r"[^a-z0-9]+", "", s.lower())


def main() -> None:
    text = GENERATED.read_text(encoding="utf-8")
    coords, _ = load_db2()
    by_name = {}
    for aid, e in coords.items():
        if e.get("explorable"):
            by_name.setdefault(norm(e["name"]), []).append((aid, e["map"], e["name"]))

    hard, _ = load_exclusions()
    for route in CURATED:
        try:
            _, _, block = extract_route_block(text, route)
        except KeyError:
            continue
        pins = [p for p in parse_route_pins(block) if not p.get("travel")]
        map_order = []
        for p in pins:
            if p["map"] not in map_order:
                map_order.append(p["map"])
        map_idx = {m: i for i, m in enumerate(map_order)}

        mismatches = []
        for p in pins:
            cands = by_name.get(norm(p["name"])) or []
            # Prefer exact map match
            if any(m == p["map"] for _, m, _ in cands):
                continue
            if not cands:
                continue
            # Unique other map?
            maps = {m for _, m, _ in cands}
            if len(maps) != 1:
                continue
            db2_map = next(iter(maps))
            aid = cands[0][0]
            if aid in hard:
                continue
            if db2_map not in map_idx:
                continue
            # Pin is in wrong zone block relative to where DB2 says it belongs
            if map_idx[p["map"]] != map_idx[db2_map]:
                mismatches.append((p["name"], p["map"], db2_map, aid))

        if mismatches:
            print(f"\n{route}: {len(mismatches)} map mismatches")
            for name, got, want, aid in mismatches[:30]:
                print(f"  {name!r} authored={got} db2={want} area={aid}")


if __name__ == "__main__":
    main()
