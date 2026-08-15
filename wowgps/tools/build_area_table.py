#!/usr/bin/env python3
"""Build WowGPS Data/AreaTable.lua from Exploration curated Manual coords.

One-shot / maintenance: not required at runtime.
"""

from __future__ import annotations

import re
from collections import OrderedDict
from pathlib import Path

ADDON_ROOT = Path(__file__).resolve().parents[1]
EXP_ROOT = ADDON_ROOT.parent / "Exploration"
MANUAL = EXP_ROOT / "Data" / "Coords" / "Manual.lua"
DB2 = EXP_ROOT / "Data" / "DB2" / "Coords.lua"
OUTPUT = ADDON_ROOT / "Data" / "AreaTable.lua"

PACK_RE = re.compile(r'ExplorationManualCoords\["([^"]+)"\]\s*=\s*\{')
ALIAS_RE = re.compile(
    r'ExplorationManualCoords\["([^"]+)"\]\s*=\s*ExplorationManualCoords\['
)
MAP_RE = re.compile(r"\[(\d+)\]\s*=\s*\{")
ENTRY_RE = re.compile(
    r'\{\s*"([^"]+)"\s*,\s*([-+]?\d*\.?\d+)\s*,\s*([-+]?\d*\.?\d+)(?:\s*,\s*(\d+))?\s*\}'
)
DB2_RE = re.compile(
    r'ExplorationDB2Coords\[(\d+)\]\s*=\s*\{\s*name\s*=\s*"([^"]+)",\s*map\s*=\s*(\d+)'
)


def matching_brace(text: str, open_idx: int) -> int:
    depth = 0
    i = open_idx
    while i < len(text):
        c = text[i]
        if c == "{":
            depth += 1
        elif c == "}":
            depth -= 1
            if depth == 0:
                return i
        i += 1
    raise ValueError(f"unbalanced brace at {open_idx}")


def load_db2_area_ids(text: str) -> dict[tuple[str, int], int]:
    out: dict[tuple[str, int], int] = {}
    for m in DB2_RE.finditer(text):
        aid, name, mid = int(m.group(1)), m.group(2), int(m.group(3))
        out[(name.lower(), mid)] = aid
    return out


def parse_manual(text: str, db2_ids: dict[tuple[str, int], int]) -> OrderedDict:
    aliases = {m.group(1) for m in ALIAS_RE.finditer(text)}
    organized: OrderedDict[str, OrderedDict[int, list]] = OrderedDict()
    seen: set[tuple[int, str]] = set()

    for m in PACK_RE.finditer(text):
        pack_name = m.group(1)
        if pack_name in aliases:
            continue
        open_idx = m.end() - 1
        close_idx = matching_brace(text, open_idx)
        block = text[open_idx : close_idx + 1]
        maps: OrderedDict[int, list] = OrderedDict()

        for mm in MAP_RE.finditer(block):
            mid = int(mm.group(1))
            m_open = mm.end() - 1
            m_close = matching_brace(block, m_open)
            sub = block[m_open : m_close + 1]
            pts = []
            for em in ENTRY_RE.finditer(sub):
                name = em.group(1)
                x = float(em.group(2))
                y = float(em.group(3))
                aid = int(em.group(4)) if em.group(4) else db2_ids.get((name.lower(), mid))
                key = (mid, name.lower())
                if key in seen:
                    continue
                seen.add(key)
                pts.append((name, x, y, aid))
            if pts:
                maps[mid] = pts

        if maps:
            organized[pack_name] = maps

    return organized


def lua_escape(s: str) -> str:
    return s.replace("\\", "\\\\").replace('"', '\\"')


def emit(organized: OrderedDict[str, OrderedDict[int, list]]) -> str:
    lines: list[str] = [
        "local _, ns = ...",
        "",
        "-- WowGPS exploration AreaTable (standalone catalog).",
        "-- Organized by expansion pack -> uiMapID -> points.",
        "-- Primary static destination data (player SavedVariables are separate).",
        "-- x/y are map percent (0-100). Destination layer normalizes to 0-1.",
        "-- Not linked to the Exploration addon at runtime.",
        "",
        "ns.AreaTable = {",
    ]

    total = 0
    for pack_name, maps in organized.items():
        lines.append(f'    ["{lua_escape(pack_name)}"] = {{')
        for mid, pts in maps.items():
            lines.append(f"        [{mid}] = {{")
            for name, x, y, aid in pts:
                n = lua_escape(name)
                if aid:
                    lines.append(
                        f'            {{ name = "{n}", x = {x:g}, y = {y:g}, areaID = {aid} }},'
                    )
                else:
                    lines.append(f'            {{ name = "{n}", x = {x:g}, y = {y:g} }},')
                total += 1
            lines.append("        },")
        lines.append("    },")

    lines.extend(
        [
            "}",
            "",
            "-- Flat destination list for search/routing (built from AreaTable).",
            "ns.DestinationsCatalog = {}",
            "do",
            "    local catalog = ns.DestinationsCatalog",
            "    for packName, maps in pairs(ns.AreaTable) do",
            "        for mapId, points in pairs(maps) do",
            "            for _, p in ipairs(points) do",
            '                local id = string.format("explore:%d:%s", mapId, (p.name or ""):lower():gsub("[^%w]+", "-"):gsub("^%-+", ""):gsub("%-+$", ""))',
            "                catalog[#catalog + 1] = {",
            "                    id = id,",
            "                    name = p.name,",
            '                    type = "zone",',
            "                    mapId = mapId,",
            "                    x = (p.x or 0) / 100,",
            "                    y = (p.y or 0) / 100,",
            "                    z = 0,",
            "                    areaID = p.areaID,",
            "                    pack = packName,",
            '                    flavor = "retail",',
            "                }",
            "            end",
            "        end",
            "    end",
            "    table.sort(catalog, function(a, b)",
            "        if a.pack ~= b.pack then return tostring(a.pack) < tostring(b.pack) end",
            "        if a.mapId ~= b.mapId then return (a.mapId or 0) < (b.mapId or 0) end",
            "        return tostring(a.name) < tostring(b.name)",
            "    end)",
            "end",
            "",
            f"-- Points: {total}",
            "",
        ]
    )
    return "\n".join(lines)


def main() -> None:
    if not MANUAL.is_file():
        raise SystemExit(f"Missing Exploration Manual coords: {MANUAL}")
    manual = MANUAL.read_text(encoding="utf-8")
    db2_ids = load_db2_area_ids(DB2.read_text(encoding="utf-8")) if DB2.is_file() else {}
    organized = parse_manual(manual, db2_ids)
    total = sum(len(pts) for maps in organized.values() for pts in maps.values())
    OUTPUT.write_text(emit(organized), encoding="utf-8")
    print(f"Wrote {OUTPUT} ({total} points, {len(organized)} packs)")


if __name__ == "__main__":
    main()
