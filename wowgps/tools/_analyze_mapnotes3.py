from pathlib import Path
import re
from collections import Counter

# Sum type="Raid"/"Dungeon"/"Delves*" across Instances addon zone+minimap+locations
# and MapNotes Retail zone dungeon files

TYPE_RE = re.compile(r'type\s*=\s*"([^"]+)"')

def count_types(path: Path) -> Counter:
    t = path.read_text(encoding="utf-8", errors="replace")
    t = re.sub(r"--.*?$", "", t, flags=re.M)
    return Counter(TYPE_RE.findall(t))

inst = Path(r"c:\Program Files (x86)\World of Warcraft\_retail_\Interface\AddOns\HandyNotes_MapNotes_Instances\Nodes")
full = Path(r"c:\Program Files (x86)\World of Warcraft\_retail_\Interface\AddOns\HandyNotes_MapNotes\Nodes\Retail")

# Hypothesis: user counted from MapNotes_Instances InstanceLocations + InstanceMiniMap
c1 = count_types(inst / "InstanceLocations.lua")
c2 = count_types(inst / "InstanceMiniMapLocation.lua")
print("Locations", dict(c1))
print("MiniMap", dict(c2))
print("sum Raid", c1["Raid"] + c2["Raid"])
print("sum Dungeon", c1["Dungeon"] + c2["Dungeon"])
print("sum Delves*", c1["Delves"] + c2["Delves"] + c2["DelvesPassage"] + c1.get("DelvesPassage", 0))

# Zone dungeon only (travel targets)
cz = count_types(full / "RetailZoneDungeonNodesLocation.lua")
cm = count_types(full / "RetailZoneMiniMapDungeonNodesLocation.lua")
print("\nZoneDungeon", {k: v for k, v in cz.items() if "Dungeon" in k or "Raid" in k or "Delve" in k or "Instance" in k or "Multiple" in k or "Passage" in k or "VInst" in k})
print("ZoneMini", {k: v for k, v in cm.items() if "Dungeon" in k or "Raid" in k or "Delve" in k or "Instance" in k or "Multiple" in k or "Passage" in k or "VInst" in k})

# Expand journal IDs: each id in id={a,b,c} counts as separate?
NODE = re.compile(r"nodes\[(\d+)\]\[(\d+)\]\s*=\s*\{([^;]*?)(?=\n\s*(?:nodes\[|minimap\[|end|if |function |local |--#|\Z))", re.S)
# simpler: for each type=Raid/Dungeon entry, expand id lists

ASSIGN = re.compile(
    r"(?:nodes|minimap)\[(\d+)\]\[(\d{6,8})\]\s*=\s*\{(.*?)\n\s*\}",
    re.S,
)
ID_LIST = re.compile(r"\bid\s*=\s*\{([^}]+)\}")
ID_ONE = re.compile(r"\bid\s*=\s*(\d+)")
TYPE = re.compile(r'type\s*=\s*"([^"]+)"')

def expand_counts(path: Path, table_name: str):
    text = re.sub(r"--.*?$", "", path.read_text(encoding="utf-8", errors="replace"), flags=re.M)
    kind_pins = Counter()
    kind_ids = Counter()
    for m in ASSIGN.finditer(text):
        body = m.group(3)
        typ_m = TYPE.search(body)
        if not typ_m:
            continue
        typ = typ_m.group(1)
        ids = []
        lm = ID_LIST.search(body)
        if lm:
            ids = [int(x.strip()) for x in lm.group(1).split(",") if x.strip().isdigit()]
        else:
            sm = ID_ONE.search(body)
            if sm:
                ids = [int(sm.group(1))]
        # classify
        low = typ.lower()
        if "delve" in low:
            bucket = "Delve"
        elif "raid" in low or typ in ("MultipleR", "VInstanceR"):
            bucket = "Raid"
        elif "dungeon" in low or typ in ("MultipleD", "VInstanceD", "VInstance", "MultiVInstance", "MultiVInstanceD", "MultipleM"):
            # MultipleM is mixed - count ids separately later
            bucket = "Dungeon"
        elif typ == "MultipleM":
            bucket = "Mixed"
        else:
            continue
        kind_pins[bucket] += 1
        if typ == "MultipleM" and ids:
            # need journal to split - count as Mixed pin
            kind_ids["MixedPin"] += 1
            kind_ids["MixedIds"] += len(ids)
        elif ids:
            kind_ids[bucket] += len(ids)
        else:
            kind_ids[bucket + "NoId"] += 1
    return kind_pins, kind_ids

print("\n=== EXPAND InstanceLocations ===")
print(expand_counts(inst / "InstanceLocations.lua", "nodes"))
print("=== EXPAND InstanceMiniMap ===")
print(expand_counts(inst / "InstanceMiniMapLocation.lua", "minimap"))
print("=== EXPAND ZoneDungeon ===")
print(expand_counts(full / "RetailZoneDungeonNodesLocation.lua", "nodes"))

# Delve POI list
delve = (inst / "RetailBlizzDelveAreaPoisNodesInfo.lua").read_text(encoding="utf-8")
print("delve map entries", len(re.findall(r"\[\d+\]\s*=\s*\d+", delve.split("Bountiful")[0])))
print("bountiful", len(re.findall(r"\[\d+\]\s*=\s*\d+", delve.split("Bountiful")[1] if "Bountiful" in delve else "")))
