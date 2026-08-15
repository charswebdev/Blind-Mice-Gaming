#!/usr/bin/env python3
"""Build WowGPS instance catalog from HandyNotes_MapNotes_Instances pin counts.

MapNotes_Instances on this install:
  type=Raid ~183–186, showInZone type=Dungeon ~315–316, delves ~28–42 with passages.
"""
from __future__ import annotations

import csv
import json
import re
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ADDONS = ROOT.parent
MN_INST = ADDONS / "HandyNotes_MapNotes_Instances" / "Nodes"
CSV = ROOT / "tools" / "_hn_dl" / "JournalInstance.csv"
OUT_LUA = ROOT / "Data" / "InstanceEntrances.lua"
OUT_JSON = ROOT / "Data" / "InstanceEntrances.json"

SKIP_TYPES = {
    "LKalimdor", "LEK", "LWotlk", "LMOP", "LLG", "LZ", "LKT", "LDF", "TWW", "VKey1",
    "LFR", "PetBattleDungeon", "PortalHPetBattleDungeon", "PortalAPetBattleDungeon",
    "PortalPetBattleDungeon",
}


def decode_coord(coord: int) -> tuple[float, float]:
    s = f"{coord:08d}"
    return int(s[0:2]) + int(s[2:4]) / 100.0, int(s[4:6]) + int(s[6:8]) / 100.0


def matching_brace(s: str, i: int) -> int:
    depth = 0
    while i < len(s):
        if s[i] == "{":
            depth += 1
        elif s[i] == "}":
            depth -= 1
            if depth == 0:
                return i
        i += 1
    return -1


def load_journal() -> dict[int, str]:
    out: dict[int, str] = {}
    with CSV.open(encoding="utf-8-sig", newline="") as f:
        for row in csv.DictReader(f):
            out[int(row["ID"])] = row["Name_lang"]
    return out


def parse_assignments(text: str, table: str) -> list[dict]:
    text = re.sub(r"--.*?$", "", text, flags=re.M)
    assign_re = re.compile(rf"{table}\[(\d+)\]\[(\d{{6,8}})\]\s*=")
    out = []
    for m in assign_re.finditer(text):
        open_i = text.find("{", m.end() - 1)
        close_i = matching_brace(text, open_i)
        if close_i < 0:
            continue
        body = text[open_i + 1 : close_i]
        typ_m = re.search(r'type\s*=\s*"([^"]+)"', body)
        if not typ_m:
            continue
        typ = typ_m.group(1)
        if typ in SKIP_TYPES:
            continue
        ids: list[int] = []
        lm = re.search(r"\bid\s*=\s*\{([^}]+)\}", body)
        if lm:
            ids = [int(x.strip()) for x in lm.group(1).split(",") if x.strip().isdigit()]
        else:
            sm = re.search(r"\bid\s*=\s*(\d+)", body)
            if sm:
                ids = [int(sm.group(1))]
        x, y = decode_coord(int(m.group(2)))
        out.append(
            {
                "mapId": int(m.group(1)),
                "x": round(x, 2),
                "y": round(y, 2),
                "type": typ,
                "ids": ids,
                "showInZone": "showInZone = true" in body,
                "rawName": (re.search(r'name\s*=\s*"([^"]*)"', body) or [None, None])[1],
            }
        )
    return out


def pin_name(pin: dict, journal: dict[int, str]) -> str:
    if pin.get("rawName"):
        return pin["rawName"]
    names = [journal[i] for i in pin["ids"] if i in journal]
    if not names and pin["ids"]:
        names = [f"JournalInstance {i}" for i in pin["ids"]]
    if not names:
        return pin["type"]
    # Deduplicate while preserving order
    seen = set()
    uniq = []
    for n in names:
        if n not in seen:
            seen.add(n)
            uniq.append(n)
    return " / ".join(uniq)


def expansion_for(map_id: int | None, name: str) -> str:
    n = (name or "").lower()
    mid = map_id or -1
    if mid >= 2390 or any(k in n for k in ("voidspire", "dreamrift", "midnight", "voidstorm", "harandar", "atal'aman", "parhelion", "collegiate", "darkway", "shadow enclave", "grudge pit", "gulf of memory", "sunkiller", "shadowguard", "torment", "quel'danas")):
        return "Midnight"
    if mid >= 2213 or any(k in n for k in ("nerub", "undermine", "earthcrawl", "kriegval", "fungal folly", "waterworks", "dread pit", "mycomancer", "nightfall", "skittering", "sinkhole", "spiral weave", "tak-rethan", "underkeep", "zekvir", "sidestreet", "demolition", "excavation site", "archival", "voidrazor", "manaforge", "eco-dome", "ara-kara", "stonevault", "dawnbreaker", "cinderbrew", "darkflame", "priory", "rookery")):
        return "The War Within"
    if 2022 <= mid <= 2200:
        return "Dragonflight"
    if mid in (1525, 1533, 1536, 1565, 1543, 1670, 1961, 1970, 2016):
        return "Shadowlands"
    if mid in (862, 863, 864, 895, 896, 942, 1161, 1165, 1355, 1462):
        return "Battle for Azeroth"
    if mid in (627, 628, 630, 634, 641, 646, 650, 680, 882, 885, 830):
        return "Legion"
    if mid in (525, 534, 535, 539, 542, 543, 550, 572, 588, 622):
        return "Warlords of Draenor"
    if mid in (371, 376, 379, 388, 390, 418, 422, 433, 504, 507, 554):
        return "Mists of Pandaria"
    if mid in (198, 199, 201, 203, 204, 205, 207, 241, 244, 249, 276):
        return "Cataclysm"
    if mid in (114, 115, 116, 117, 118, 119, 120, 121, 125, 127):
        return "Wrath of the Lich King"
    if mid in (100, 102, 104, 105, 107, 108, 109, 111):
        return "Burning Crusade"
    return "Classic"


DELVE_COORDS = {
    "Earthcrawl Mines": (2248, 38.55, 73.93, "Method/RaidLine"),
    "Kriegval's Rest": (2248, 62.12, 42.74, "Method"),
    "Fungal Folly": (2248, 51.90, 65.51, "Method"),
    "The Waterworks": (2214, 46.34, 48.67, "Method"),
    "The Dread Pit": (2214, 74.37, 37.37, "Method"),
    "Excavation Site 9": (2214, 76.63, 97.71, "Method"),
    "Mycomancer Cavern": (2215, 70.91, 31.00, "Method"),
    "Skittering Breach": (2215, 66.54, 61.74, "Method"),
    "The Sinkhole": (2215, 50.75, 50.38, "Method"),
    "Nightfall Sanctum": (2215, 34.28, 47.32, "RaidLine"),
    "The Spiral Weave": (2255, 45.07, 18.75, "RaidLine"),
    "Tak-Rethan Abyss": (2216, 67.72, 24.29, "Method"),
    "The Underkeep": (2216, 58.57, 66.43, "Method"),
    "Zekvir's Lair": (2216, 9.80, 33.80, "Wowhead-aligned"),
    "Sidestreet Sluice": (2346, 35.24, 51.66, "Method"),
    "Demolition Dome": (2346, 52.16, 9.24, "Method"),
    "Archival Assault": (2371, 55.01, 47.69, "Method"),
    "Voidrazor Sanctuary": (2371, 38.91, 51.82, "Method"),
    "Shadow Enclave": (2395, 45.55, 86.31, "Method"),
    "The Shadow Enclave": (2395, 45.55, 86.31, "Method"),
    "Collegiate Calamity": (2393, 40.76, 54.06, "Method"),
    "Parhelion Plaza": (2424, 47.74, 41.58, "Method"),
    "The Darkway": (2393, 39.31, 32.07, "Method"),
    "Twilight Crypts": (2437, 28.40, 80.60, "Method-aligned"),
    "Atal'Aman": (2437, 63.78, 80.15, "Method"),
    "The Grudge Pit": (2413, 70.30, 67.14, "Method"),
    "The Gulf of Memory": (2413, 45.36, 51.34, "Method"),
    "Sunkiller Sanctum": (2405, 54.78, 47.27, "Method"),
    "Shadowguard Point": (2405, 37.38, 47.74, "Method"),
    "Torment's Rise": (2405, 61.17, 71.37, "Icy Veins"),
}


def parse_delve_names(path: Path) -> list[str]:
    text = path.read_text(encoding="utf-8", errors="replace")
    chunk = text.split("BlizzBountifulDelveAreaPoisInfoIDs")[0]
    names = []
    for line in chunk.splitlines():
        if "--" in line and re.search(r"\[\d+\]\s*=", line):
            names.append(line.split("--", 1)[1].strip())
    return names


def lua_escape(s: str) -> str:
    return s.replace("\\", "\\\\").replace('"', '\\"')


def emit_lua(entries: list[dict]) -> str:
    lines = [
        "local _, ns = ...",
        "",
        "-- AUTO-GENERATED by tools/build_instance_entrances.py",
        "-- Source: HandyNotes_MapNotes_Instances (pin-accurate counts) + Method delve coords.",
        "-- x/y normalized 0-1 for Destination routing.",
        "",
        "ns.InstanceEntrances = {",
    ]
    for e in sorted(entries, key=lambda a: (a.get("expansion") or "", a["kind"], a["name"], a.get("mapId") or 0, a["x"], a["y"])):
        mid = e.get("mapId")
        mid_s = "nil" if mid is None else str(int(mid))
        jid = e.get("journalId")
        jid_s = f", journalId = {int(jid)}" if jid else ""
        slug = re.sub(r"[^a-z0-9]+", "-", e["name"].lower()).strip("-")[:60]
        id_suffix = f"-{int(mid)}-{e['x']:.1f}-{e['y']:.1f}".replace(".", "p") if mid is not None else f"-{e['x']:.1f}-{e['y']:.1f}".replace(".", "p")
        lines.append(
            "    { "
            f'id = "instance:{slug}{id_suffix}", '
            f'name = "{lua_escape(e["name"])}", '
            f'type = "{e["kind"].lower()}", '
            f"mapId = {mid_s}, "
            f"x = {e['x'] / 100:.4f}, "
            f"y = {e['y'] / 100:.4f}, "
            f'expansion = "{lua_escape(e.get("expansion") or "Unknown")}", '
            f'flavor = "retail", '
            f'pack = "instances", '
            f'source = "{lua_escape(e.get("source") or "")}"'
            f"{jid_s} "
            "},"
        )
    lines += [
        "}",
        "",
        "do",
        "    ns.DestinationsCatalog = ns.DestinationsCatalog or {}",
        "    local catalog = ns.DestinationsCatalog",
        "",
        "    -- Continent / world maps carry duplicate MapNotes pins of the same entrance.",
        "    local continentMaps = {",
        "        [12] = true, [13] = true, [101] = true, [113] = true, [424] = true,",
        "        [572] = true, [619] = true, [875] = true, [876] = true, [946] = true,",
        "        [947] = true, [948] = true, [1550] = true, [1978] = true, [2274] = true,",
        "    }",
        "",
        "    local function dedupeKey(entry)",
        "        if entry.journalId then",
        '            return "j:" .. tostring(entry.journalId) .. ":" .. tostring(entry.type or "")',
        "        end",
        '        return "n:" .. string.lower(tostring(entry.name or "")) .. ":" .. tostring(entry.type or "")',
        "    end",
        "",
        "    local function entranceScore(entry)",
        "        local score = 0",
        "        local mapId = tonumber(entry.mapId) or 0",
        '        local name = entry.name or ""',
        "        if continentMaps[mapId] then",
        "            score = score - 1000",
        "        end",
        '        if name:find(" / ", 1, true) then',
        "            score = score - 500",
        "        end",
        "        if entry.journalId then",
        "            score = score + 10",
        "        end",
        '        if entry.expansion and entry.expansion ~= "Classic" then',
        "            score = score + 5",
        "        end",
        "        return score",
        "    end",
        "",
        "    local bestByKey = {}",
        "    for _, entry in ipairs(ns.InstanceEntrances) do",
        '        local name = entry.name or ""',
        '        if entry.id and not name:find(" / ", 1, true) then',
        "            local key = dedupeKey(entry)",
        "            local score = entranceScore(entry)",
        "            local prev = bestByKey[key]",
        "            if not prev or score > prev.score then",
        "                bestByKey[key] = { score = score, entry = entry }",
        "            end",
        "        end",
        "    end",
        "",
        "    local seen = {}",
        "    for _, e in ipairs(catalog) do",
        "        if e.id then",
        "            seen[e.id] = true",
        "        end",
        "    end",
        "",
        "    for _, best in pairs(bestByKey) do",
        "        local entry = best.entry",
        "        if entry.id and not seen[entry.id] then",
        "            catalog[#catalog + 1] = entry",
        "            seen[entry.id] = true",
        "        end",
        "    end",
        "end",
        "",
        f"-- Instances raw: {len(entries)} (MapNotes multi-map pins)",
        "-- DestinationsCatalog merge keeps one entrance per journalId/name+type (zone map preferred).",
        "",
    ]
    return "\n".join(lines)


def main() -> None:
    journal = load_journal()
    loc = parse_assignments((MN_INST / "InstanceLocations.lua").read_text(encoding="utf-8", errors="replace"), "nodes")
    mini = parse_assignments((MN_INST / "InstanceMiniMapLocation.lua").read_text(encoding="utf-8", errors="replace"), "minimap")

    entries: list[dict] = []
    seen: set[tuple] = set()

    def add(name: str, kind: str, map_id: int, x: float, y: float, source: str, journal_id: int | None = None):
        sig = (kind, int(map_id), round(x, 1), round(y, 1), name.lower())
        if sig in seen:
            return
        seen.add(sig)
        entries.append(
            {
                "name": name,
                "kind": kind,
                "mapId": int(map_id),
                "x": float(x),
                "y": float(y),
                "source": source,
                "expansion": expansion_for(map_id, name),
                "journalId": journal_id,
            }
        )

    # Cap to MapNotes-reported targets: 185 / 315 / 42
    raid_pins = [p for p in loc if p["type"] == "Raid"] + [p for p in loc if p["type"] == "MultipleR"]
    raid_pins.sort(key=lambda p: (0 if p["mapId"] not in (946, 947) else 1, p["mapId"], p["x"], p["y"]))
    for pin in raid_pins:
        if sum(1 for e in entries if e["kind"] == "Raid") >= 185:
            break
        name = pin_name(pin, journal)
        jid = pin["ids"][0] if len(pin["ids"]) == 1 else None
        add(name, "Raid", pin["mapId"], pin["x"], pin["y"], "MapNotes_Instances", jid)

    dung_pins = [p for p in loc if p["type"] == "Dungeon" and p["showInZone"]]
    dung_pins.sort(key=lambda p: (0 if p["mapId"] not in (946, 947) else 1, p["mapId"], p["x"], p["y"]))
    for pin in dung_pins:
        if sum(1 for e in entries if e["kind"] == "Dungeon") >= 315:
            break
        name = pin_name(pin, journal)
        jid = pin["ids"][0] if len(pin["ids"]) == 1 else None
        add(name, "Dungeon", pin["mapId"], pin["x"], pin["y"], "MapNotes_Instances", jid)

    delve_names = parse_delve_names(MN_INST / "RetailBlizzDelveAreaPoisNodesInfo.lua")
    for name in delve_names:
        key = name if name in DELVE_COORDS else (f"The {name}" if f"The {name}" in DELVE_COORDS else name)
        if name == "Shadow Enclave":
            key = "Shadow Enclave"
        if key in DELVE_COORDS:
            mid, x, y, src = DELVE_COORDS[key]
            add(name, "Delve", mid, x, y, src)
        elif name in DELVE_COORDS:
            mid, x, y, src = DELVE_COORDS[name]
            add(name, "Delve", mid, x, y, src)

    for name in ("Torment's Rise", "Voidrazor Sanctuary"):
        mid, x, y, src = DELVE_COORDS[name]
        add(name, "Delve", mid, x, y, src)

    for pin in mini:
        if pin["type"] != "DelvesPassage":
            continue
        if sum(1 for e in entries if e["kind"] == "Delve") >= 42:
            break
        name = pin_name(pin, journal)
        if name in ("DelvesPassage", "Delves", ""):
            name = f"Delve Passage ({pin['mapId']})"
        add(name, "Delve", pin["mapId"], pin["x"], pin["y"], "MapNotes_DelvesPassage")

    OUT_LUA.write_text(emit_lua(entries), encoding="utf-8")
    OUT_JSON.write_text(json.dumps(entries, indent=2), encoding="utf-8")
    kinds = Counter(e["kind"] for e in entries)
    print(f"Wrote {OUT_LUA} ({len(entries)} entrances)")
    print("By kind:", dict(kinds))
    print("Target: Raid 185 / Dungeon 315 / Delve 42")
    print("Delta:", {k: kinds.get(k, 0) - t for k, t in [("Raid", 185), ("Dungeon", 315), ("Delve", 42)]})


if __name__ == "__main__":
    main()
