from pathlib import Path
import re
from collections import Counter

inst = Path(r"c:\Program Files (x86)\World of Warcraft\_retail_\Interface\AddOns\HandyNotes_MapNotes_Instances\Nodes")
full = Path(r"c:\Program Files (x86)\World of Warcraft\_retail_\Interface\AddOns\HandyNotes_MapNotes\Nodes\Retail")

for label, p in [
    ("minimap", inst / "InstanceMiniMapLocation.lua"),
    ("delve", inst / "RetailBlizzDelveAreaPoisNodesInfo.lua"),
]:
    t = p.read_text(encoding="utf-8", errors="replace")
    print(f"\n===== {label} {p.name} len={len(t)} =====")
    print(t[:1800])
    print("nodes[", t.count("nodes["), "type=", Counter(re.findall(r'type\s*=\s*"([^"]+)"', t)))

print("\n===== FULL MAPNOTES RETAIL =====")
for p in sorted(full.glob("*.lua")):
    t = p.read_text(encoding="utf-8", errors="replace")
    types = Counter(re.findall(r'type\s*=\s*"([^"]+)"', t))
    interesting = {k: v for k, v in types.items() if any(s in k for s in ("Dungeon", "Raid", "Delve", "Instance", "VInstance", "Multi"))}
    if interesting or "Dungeon" in p.name or "Delve" in p.name or "Zone" in p.name:
        print(p.name, "total_types", sum(types.values()), "interesting", interesting or dict(types.most_common(8)))
