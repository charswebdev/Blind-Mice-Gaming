from pathlib import Path
import re
from collections import Counter

# Exact match hunt for 185/315/42
path = Path(
    r"c:\Program Files (x86)\World of Warcraft\_retail_\Interface\AddOns"
    r"\HandyNotes_MapNotes_Instances\Nodes\InstanceLocations.lua"
)
text = re.sub(r"--.*?$", "", path.read_text(encoding="utf-8", errors="replace"), flags=re.M)
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
    body = text[open_i + 1 : close_i]
    typ_m = re.search(r'type\s*=\s*"([^"]+)"', body)
    typ = typ_m.group(1) if typ_m else "?"
    entries.append({"type": typ, "showInZone": "showInZone = true" in body, "mapId": int(m.group(1)), "body": body, "coord": int(m.group(2))})

# Candidates for Raid=185
c = Counter(e["type"] for e in entries)
print("Raid", c["Raid"], "+MultipleR", c["Raid"]+c["MultipleR"], "+VInstanceR", c["Raid"]+c["VInstanceR"], "+both", c["Raid"]+c["MultipleR"]+c["VInstanceR"])
# Dungeon=315
z = [e for e in entries if e["showInZone"]]
cz = Counter(e["type"] for e in z)
print("showInZone Dungeon", cz["Dungeon"], "-1?", cz["Dungeon"]-1)
print("Dungeon showInZone without logos maps", sum(1 for e in z if e["type"]=="Dungeon" and e["mapId"] not in {946}))

# MiniMap + Locations showInZone dungeon?
mini = Path(
    r"c:\Program Files (x86)\World of Warcraft\_retail_\Interface\AddOns"
    r"\HandyNotes_MapNotes_Instances\Nodes\InstanceMiniMapLocation.lua"
)
mt = re.sub(r"--.*?$", "", mini.read_text(encoding="utf-8", errors="replace"), flags=re.M)
# minimap uses minimap[id][coord]
assign_m = re.compile(r"minimap\[(\d+)\]\[(\d{6,8})\]\s*=")
mentries = []
for m in assign_m.finditer(mt):
    open_i = mt.find("{", m.end() - 1)
    close_i = matching_brace(mt, open_i)
    body = mt[open_i + 1 : close_i]
    typ_m = re.search(r'type\s*=\s*"([^"]+)"', body)
    mentries.append({"type": typ_m.group(1) if typ_m else "?", "mapId": int(m.group(1)), "coord": int(m.group(2)), "body": body})
print("minimap types", Counter(e["type"] for e in mentries))

# Delve POIs
delve_path = Path(
    r"c:\Program Files (x86)\World of Warcraft\_retail_\Interface\AddOns"
    r"\HandyNotes_MapNotes_Instances\Nodes\RetailBlizzDelveAreaPoisNodesInfo.lua"
)
dt = delve_path.read_text(encoding="utf-8")
# all [poi]=map pairs
pairs = re.findall(r"\[(\d+)\]\s*=\s*(\d+)", dt)
print("all delve poi pairs", len(pairs), "unique poi", len({a for a,_ in pairs}), "unique maps", len({b for _,b in pairs}))

# Full MapNotes RetailBlizzDelve
for p in Path(r"c:\Program Files (x86)\World of Warcraft\_retail_\Interface\AddOns\HandyNotes_MapNotes").rglob("*Delve*"):
    if p.suffix == ".lua":
        t = p.read_text(encoding="utf-8", errors="replace")
        pairs2 = re.findall(r"\[(\d+)\]\s*=\s*(\d+)", t)
        types = Counter(re.findall(r'type\s*=\s*"([^"]+)"', t))
        print(p.name, "pairs", len(pairs2), "types", dict(types))

# AreaPOI delves - atlas? Check POIs for delve names from MapNotes list
import csv
names = []
for line in dt.splitlines():
    if "--" in line and "[" in line:
        names.append(line.split("--")[-1].strip())
print("delve names", names)
print("count names", len([n for n in names if n and "BOUNTIFUL" not in n.upper()]))
