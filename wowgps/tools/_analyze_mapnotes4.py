from pathlib import Path
import re
from collections import Counter

path = Path(
    r"c:\Program Files (x86)\World of Warcraft\_retail_\Interface\AddOns"
    r"\HandyNotes_MapNotes_Instances\Nodes\InstanceLocations.lua"
)
text = re.sub(r"--.*?$", "", path.read_text(encoding="utf-8", errors="replace"), flags=re.M)

# Parse assignments more carefully with brace matching
assign_re = re.compile(r"nodes\[(\d+)\]\[(\d{6,8})\]\s*=")


def matching_brace(s, i):
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


entries = []
for m in assign_re.finditer(text):
    open_i = text.find("{", m.end() - 1)
    close_i = matching_brace(text, open_i)
    if close_i < 0:
        continue
    body = text[open_i + 1 : close_i]
    map_id = int(m.group(1))
    coord = int(m.group(2))
    typ_m = re.search(r'type\s*=\s*"([^"]+)"', body)
    typ = typ_m.group(1) if typ_m else "?"
    show_zone = "showInZone = true" in body or "showInZone=true" in body
    show_cont = "showOnContinent = true" in body
    ids = []
    lm = re.search(r"\bid\s*=\s*\{([^}]+)\}", body)
    if lm:
        ids = [int(x.strip()) for x in lm.group(1).split(",") if x.strip().isdigit()]
    else:
        sm = re.search(r"\bid\s*=\s*(\d+)", body)
        if sm:
            ids = [int(sm.group(1))]
    s = f"{coord:08d}"
    x = int(s[0:2]) + int(s[2:4]) / 100.0
    y = int(s[4:6]) + int(s[6:8]) / 100.0
    entries.append(
        {
            "mapId": map_id,
            "x": round(x, 2),
            "y": round(y, 2),
            "type": typ,
            "ids": ids,
            "showInZone": show_zone,
            "showOnContinent": show_cont,
            "body": body,
        }
    )

print("total entries", len(entries))
print("by type", Counter(e["type"] for e in entries))
zone = [e for e in entries if e["showInZone"]]
print("showInZone", len(zone), Counter(e["type"] for e in zone))

# Cosmic/continent map IDs commonly used
COSMOS = {946, 947}
# Continent-ish maps in retail
continentish = {
    12,
    13,
    101,
    113,
    424,
    572,
    619,
    875,
    876,
    905,
    1550,
    1978,
    2274,
    946,
    947,
}

zone_only = [e for e in zone if e["mapId"] not in continentish and e["mapId"] not in COSMOS]
print("zone maps only showInZone", len(zone_only), Counter(e["type"] for e in zone_only))

# Classify buckets
RAID_T = {"Raid", "MultipleR", "VInstanceR", "PassageRaid"}
DUNG_T = {
    "Dungeon",
    "MultipleD",
    "VInstanceD",
    "MultiVInstance",
    "PassageDungeon",
    "VInstance",
    "MultiVInstanceD",
}
DELVE_T = {"Delves", "DelvesPassage"}


def bucket(t):
    if t in RAID_T or "Raid" in t:
        return "Raid"
    if t in DELVE_T or "Delve" in t:
        return "Delve"
    if t in DUNG_T or "Dungeon" in t:
        return "Dungeon"
    if t == "MultipleM":
        return "Mixed"
    if t == "LFR":
        return "LFR"
    return "Other"


for label, subset in [
    ("all", entries),
    ("showInZone", zone),
    ("zoneMaps", zone_only),
]:
    c = Counter(bucket(e["type"]) for e in subset)
    print(label, dict(c))

# Expand Mixed MultipleM using journal - treat each id based on journal flags later
# Count pins that user might count: Raid+MultipleR+VInstanceR
r = [e for e in entries if bucket(e["type"]) == "Raid"]
d = [e for e in entries if bucket(e["type"]) == "Dungeon"]
print("raid pins", len(r), "dungeon pins", len(d))
print("raid+MultipleR+VInstanceR from type counter already")

# Try zone dungeon file from full MapNotes similarly
zpath = Path(
    r"c:\Program Files (x86)\World of Warcraft\_retail_\Interface\AddOns"
    r"\HandyNotes_MapNotes\Nodes\Retail\RetailZoneDungeonNodesLocation.lua"
)
ztext = re.sub(r"--.*?$", "", zpath.read_text(encoding="utf-8", errors="replace"), flags=re.M)
zentries = []
for m in assign_re.finditer(ztext):
    open_i = ztext.find("{", m.end() - 1)
    close_i = matching_brace(ztext, open_i)
    body = ztext[open_i + 1 : close_i]
    typ_m = re.search(r'type\s*=\s*"([^"]+)"', body)
    typ = typ_m.group(1) if typ_m else "?"
    map_id = int(m.group(1))
    coord = int(m.group(2))
    ids = []
    lm = re.search(r"\bid\s*=\s*\{([^}]+)\}", body)
    if lm:
        ids = [int(x.strip()) for x in lm.group(1).split(",") if x.strip().isdigit()]
    else:
        sm = re.search(r"\bid\s*=\s*(\d+)", body)
        if sm:
            ids = [int(sm.group(1))]
    s = f"{coord:08d}"
    zentries.append(
        {
            "mapId": map_id,
            "x": round(int(s[0:2]) + int(s[2:4]) / 100.0, 2),
            "y": round(int(s[4:6]) + int(s[6:8]) / 100.0, 2),
            "type": typ,
            "ids": ids,
            "showInZone": "showInZone = true" in body,
        }
    )
print("\nZoneDungeon file", len(zentries), Counter(bucket(e["type"]) for e in zentries))
print("ZoneDungeon types", Counter(e["type"] for e in zentries))
print("ZoneDungeon showInZone", Counter(bucket(e["type"]) for e in zentries if e["showInZone"]))

# Combine InstanceLocations showInZone + ZoneDungeon? 
# User target 185/315/42
# InstanceLocations Raid types: 183+3 MultipleR + ? = 
print("\nIL Raid-like", sum(1 for e in entries if bucket(e["type"])=="Raid"))
print("IL Dungeon-like", sum(1 for e in entries if bucket(e["type"])=="Dungeon"))
print("IL Mixed", sum(1 for e in entries if bucket(e["type"])=="Mixed"))
print("IL LFR", sum(1 for e in entries if bucket(e["type"])=="LFR"))

# If MultipleM split half? or use journal
# 183 raid + 2 delves? no
# 183 + MultipleR(3) -1 = 185?
print("Raid+MultipleR", Counter(e["type"] for e in entries)["Raid"] + Counter(e["type"] for e in entries)["MultipleR"])
