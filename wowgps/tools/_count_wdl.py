from pathlib import Path
from collections import Counter
import re
import json

out = Path(r"c:\Program Files (x86)\World of Warcraft\_retail_\Interface\AddOns\wowgps\tools\_hn_dl")
t = (out / "WDL_PinLocations.lua").read_text(encoding="utf-8", errors="replace")
print("Dungeon", t.count('atlasName = "Dungeon"'))
print("Raid", t.count('atlasName = "Raid"'))
print("lines in data", t.count("journalInstanceID"))

# Parse all entries
pat = re.compile(
    r"\{ journalInstanceID = (\d+), areaPoiID = (-?\d+), atlasName = \"([^\"]+)\", pos0 = ([-\d.]+), pos1 = ([-\d.]+), continentID = (\d+)"
)
rows = pat.findall(t)
print("parsed", len(rows), Counter(r[2] for r in rows))

for f in ["gh_dath.json", "gh_mn2.json"]:
    p = out / f
    if p.exists():
        d = json.loads(p.read_text(encoding="utf-8"))
        print(f, d.get("total_count"))
        for i in d.get("items", [])[:10]:
            print(" ", i["full_name"])
