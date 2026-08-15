import csv
from collections import Counter
from pathlib import Path

p = Path(r"c:\Program Files (x86)\World of Warcraft\_retail_\Interface\AddOns\wowgps\tools\_hn_dl\areapoi.csv")
with p.open(encoding="utf-8-sig", newline="") as f:
    rows = list(csv.DictReader(f))
print("cols", rows[0].keys())
print("total", len(rows))
# Common atlas member IDs for dungeon/raid
# From WDL SQL: 6091 = Dungeon
atlas = Counter(r.get("UiTextureAtlasMemberID") for r in rows)
print("top atlas", atlas.most_common(30))
# Name samples containing Dungeon/Raid/Delve
for key in ["Name_lang", "Description_lang"]:
    if key in rows[0]:
        print(key, "sample", rows[0][key])

# Count by name patterns in description or atlas
dungeon_atlas = {"6091"}  # known
# scan names that match journal
names = Counter()
for r in rows:
    n = (r.get("Name_lang") or "").lower()
    if any(x in n for x in ("delve", "mines", "cavern", "sanctum")):
        pass

# Print unique atlas IDs that appear with instance-like names
interesting = []
for r in rows:
    n = r.get("Name_lang") or ""
    aid = r.get("UiTextureAtlasMemberID")
    if aid in ("6091", "6092", "6093", "6094") or "Dungeon" in (r.get("PortLoc_0") or ""):
        interesting.append(r)

print("atlas 6091", sum(1 for r in rows if r.get("UiTextureAtlasMemberID") == "6091"))
# Try other known IDs - print rows where ID matches WDL areaPoiIDs
wdl_pois = set()
import re
t = Path(r"c:\Program Files (x86)\World of Warcraft\_retail_\Interface\AddOns\wowgps\tools\_hn_dl\WDL_PinLocations.lua").read_text(encoding="utf-8")
for m in re.finditer(r"areaPoiID = (-?\d+)", t):
    wdl_pois.add(m.group(1))
print("wdl pois", len(wdl_pois))
matched = [r for r in rows if r.get("ID") in wdl_pois]
print("matched areapoi", len(matched))
if matched:
    print("matched atlas", Counter(r.get("UiTextureAtlasMemberID") for r in matched).most_common(10))
    print("sample", matched[0])

# Count all POIs with those atlas IDs
raid_dungeon_atlas = Counter(r.get("UiTextureAtlasMemberID") for r in matched)
target_atlas = set(raid_dungeon_atlas)
all_inst = [r for r in rows if r.get("UiTextureAtlasMemberID") in target_atlas]
print("all with same atlas as WDL", len(all_inst), Counter(r.get("UiTextureAtlasMemberID") for r in all_inst))
