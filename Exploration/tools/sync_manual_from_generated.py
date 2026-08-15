#!/usr/bin/env python3
"""Upsert Manual.lua coords from curated Generated.lua pins (by name+map).

Usage:
  python tools/sync_manual_from_generated.py           # dry-run
  python tools/sync_manual_from_generated.py --apply  # write Manual.lua

Only updates existing Manual rows when Generated has explicit x,y for the same
name on that map. Does not invent Manual packs or delete Manual-only rows.
"""
from __future__ import annotations

import argparse
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
GENERATED = ROOT / "Data" / "Routes" / "Generated.lua"
MANUAL = ROOT / "Data" / "Coords" / "Manual.lua"

ROUTE_RE = re.compile(
    r'R\["([^"]+)"\]\s*=\s*\{(.*?)\n\}',
    re.S,
)
PIN_RE = re.compile(
    r'\{\s*name\s*=\s*"([^"]+)"\s*,\s*map\s*=\s*(\d+)\s*,\s*x\s*=\s*([0-9.]+)\s*,\s*y\s*=\s*([0-9.]+)',
)
MANUAL_ROW_RE = re.compile(
    r'(\{\s*")([^"]+)("\s*,\s*)([0-9.]+)(\s*,\s*)([0-9.]+)((?:\s*,\s*\d+)?(?:\s*,\s*--[^\n]*)?\s*\})'
)


def curated_pins(text: str) -> dict[tuple[str, int], tuple[float, float]]:
    out: dict[tuple[str, int], tuple[float, float]] = {}
    for m in ROUTE_RE.finditer(text):
        body = m.group(2)
        if "curated = true" not in body:
            continue
        for p in PIN_RE.finditer(body):
            name, map_id, x, y = p.group(1), int(p.group(2)), float(p.group(3)), float(p.group(4))
            out[(name, map_id)] = (x, y)
    return out


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--apply", action="store_true")
    args = ap.parse_args()

    pins = curated_pins(GENERATED.read_text(encoding="utf-8"))
    manual = MANUAL.read_text(encoding="utf-8")
    changes = 0

    def repl(m: re.Match[str]) -> str:
        nonlocal changes
        name = m.group(2)
        old_x, old_y = float(m.group(4)), float(m.group(6))
        # Manual packs are map-scoped blocks; match by name only within file is
        # ambiguous across maps. Prefer exact coord update when a unique Generated
        # name exists, else skip.
        matches = [(k, v) for k, v in pins.items() if k[0] == name]
        if len(matches) != 1:
            return m.group(0)
        new_x, new_y = matches[0][1]
        if abs(new_x - old_x) < 1e-6 and abs(new_y - old_y) < 1e-6:
            return m.group(0)
        changes += 1
        return f"{m.group(1)}{name}{m.group(3)}{new_x:g}{m.group(5)}{new_y:g}{m.group(7)}"

    updated = MANUAL_ROW_RE.sub(repl, manual)
    print(f"pins from curated Generated: {len(pins)}")
    print(f"Manual rows that would change: {changes}")
    if args.apply and changes:
        MANUAL.write_text(updated, encoding="utf-8", newline="\n")
        print(f"wrote {MANUAL}")
    elif not args.apply:
        print("dry-run only; pass --apply to write")


if __name__ == "__main__":
    main()
