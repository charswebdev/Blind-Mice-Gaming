from pathlib import Path
import re
from collections import Counter

base = Path(r"c:\Program Files (x86)\World of Warcraft\_retail_\Interface\AddOns\HandyNotes_MapNotes_Instances\Nodes")
files = [
    "InstanceLocations.lua",
    "InstanceMiniMapLocation.lua",
    "RetailBlizzDelveAreaPoisNodesInfo.lua",
    "MapNotesNodesInfo.lua",
    "MapNotesMinimapNodesInfo.lua",
]

TYPE_RE = re.compile(r'type\s*=\s*"([^"]+)"')
NODE_RE = re.compile(
    r"nodes\[(\d+)\]\[(\d{6,8})\]\s*=\s*\{([^}]*(?:\{[^}]*\}[^}]*)*)\}",
    re.DOTALL,
)
ID_LIST = re.compile(r"\bid\s*=\s*\{([^}]+)\}")
ID_SINGLE = re.compile(r"\bid\s*=\s*(\d+)")
NAME_RE = re.compile(r'name\s*=\s*((?:L\[[^\]]+\])|(?:"[^"]*")|(?:[^,\n}]+))')
MNID_RE = re.compile(r"\bmnID\s*=\s*(\d+)")


def decode_coord(coord: int):
    s = f"{coord:08d}"
    return int(s[0:2]) + int(s[2:4]) / 100.0, int(s[4:6]) + int(s[6:8]) / 100.0


def parse_file(path: Path):
    text = path.read_text(encoding="utf-8", errors="replace")
    # strip comments
    text = re.sub(r"--.*?$", "", text, flags=re.M)
    entries = []
    types = Counter()
    for m in NODE_RE.finditer(text):
        map_id = int(m.group(1))
        coord = int(m.group(2))
        body = m.group(3)
        typ_m = TYPE_RE.search(body)
        typ = typ_m.group(1) if typ_m else "?"
        types[typ] += 1
        ids = []
        lm = ID_LIST.search(body)
        if lm:
            ids = [int(x.strip()) for x in lm.group(1).split(",") if x.strip().isdigit()]
        else:
            sm = ID_SINGLE.search(body)
            if sm:
                ids = [int(sm.group(1))]
        x, y = decode_coord(coord)
        nm = NAME_RE.search(body)
        name = nm.group(1).strip() if nm else None
        mn = MNID_RE.search(body)
        entries.append(
            {
                "mapId": map_id,
                "x": round(x, 2),
                "y": round(y, 2),
                "type": typ,
                "ids": ids,
                "name": name,
                "mnID": int(mn.group(1)) if mn else None,
                "file": path.name,
            }
        )
    return entries, types, text.count("type =")


for f in files:
    p = base / f
    if not p.exists():
        print("missing", f)
        continue
    entries, types, raw = parse_file(p)
    print(f"\n=== {f} nodes={len(entries)} ===")
    print(dict(types.most_common(30)))

# Aggregate InstanceLocations + delve file for raid/dungeon/delve
all_e = []
for f in ["InstanceLocations.lua", "InstanceMiniMapLocation.lua", "RetailBlizzDelveAreaPoisNodesInfo.lua"]:
    e, _, _ = parse_file(base / f)
    all_e.extend(e)

raid_types = {"Raid", "multipleR", "RaidPassage", "passageRaid", "passageRaidMulti", "multipleM"}
dung_types = {"Dungeon", "multipleD", "DungeonPassage", "passageDungeon", "passageDungeonMulti", "passageDungeonRaid", "passageDungeonRaidMulti", "vanillaInstance", "multivanillaInstance"}
delve_types = {"Delves", "DelvesPassage", "BountyDelves"}

# Print all unique types across InstanceLocations
e, types, _ = parse_file(base / "InstanceLocations.lua")
print("\nALL TYPES InstanceLocations:")
for k, v in types.most_common():
    print(f"  {k}: {v}")
