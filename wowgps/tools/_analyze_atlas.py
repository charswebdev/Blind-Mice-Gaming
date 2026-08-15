import csv
from collections import Counter
from pathlib import Path

p = Path(r"c:\Program Files (x86)\World of Warcraft\_retail_\Interface\AddOns\wowgps\tools\_hn_dl\areapoi.csv")
with p.open(encoding="utf-8-sig", newline="") as f:
    rows = list(csv.DictReader(f))

for atlas in ["6561", "6093", "27116", "16793", "6781"]:
    subset = [r for r in rows if r.get("UiTextureAtlasMemberID") == atlas]
    print(f"\natlas {atlas} count={len(subset)}")
    for r in subset[:8]:
        print(" ", r["ID"], r["Name_lang"], r.get("Description_lang"), "cont", r["ContinentID"])

# Description_lang for 6091/6092
for atlas in ["6091", "6092"]:
    desc = Counter(r.get("Description_lang") for r in rows if r.get("UiTextureAtlasMemberID") == atlas)
    print("atlas", atlas, "desc", desc.most_common(5))
