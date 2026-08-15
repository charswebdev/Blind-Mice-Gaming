#!/usr/bin/env python3
"""Audit Generated.lua exploration routes for zone-complete ordering.

A zone (map ID) must appear as one contiguous run of explore pins.
Leaving a map and returning later is a violation.
Travel pins are ignored for the run check (they can sit on borders).
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from pin_io import extract_route_block, parse_route_pins  # noqa: E402

GENERATED = Path(__file__).resolve().parents[1] / "Data" / "Routes" / "Generated.lua"


def main() -> int:
    text = GENERATED.read_text(encoding="utf-8")
    keys = re.findall(r'R\["([^"]+)"\] = \{', text)
    viol_routes = []
    ok_multi = []
    skipped = []

    for route in keys:
        try:
            _, _, block = extract_route_block(text, route)
        except Exception as e:
            skipped.append((route, str(e)))
            continue

        pins = parse_route_pins(block)
        explore = [p for p in pins if not p.get("travel")]
        if len(explore) < 2:
            continue

        runs: list[list] = []
        for p in explore:
            mid = p["map"]
            if not runs or runs[-1][0] != mid:
                runs.append([mid, 1, p["name"]])
            else:
                runs[-1][1] += 1

        seen: dict[int, int] = {}
        violations = []
        for i, (mid, n, first) in enumerate(runs):
            if mid in seen:
                violations.append((mid, seen[mid], i, first, n))
            else:
                seen[mid] = i

        maps = sorted({p["map"] for p in explore})
        runseq = [r[0] for r in runs]
        if violations:
            viol_routes.append((route, len(explore), maps, runseq, violations))
        elif len(runs) > 1:
            ok_multi.append((route, len(explore), runseq))

    print("=== ZONE ORDER VIOLATIONS (map re-entered) ===")
    for route, n, maps, runseq, violations in viol_routes:
        print(f"\n{route}: explore={n} unique_maps={len(maps)}")
        print(f"  runseq={runseq}")
        for mid, first_i, later_i, first_name, n in violations:
            print(
                f"  REENTER map {mid}: first_run_idx={first_i} later_run_idx={later_i} "
                f"later_start={first_name!r} pins={n}"
            )

    print(f"\n=== OK multi-map routes ({len(ok_multi)}) ===")
    for route, n, runseq in ok_multi:
        print(f"  {route}: {runseq}")

    print(f"\nSummary: {len(viol_routes)} violations, {len(ok_multi)} ok multi-map")
    return 1 if viol_routes else 0


if __name__ == "__main__":
    raise SystemExit(main())
