#!/usr/bin/env python3
"""
AllQuest chain extractor (outside the addon zip).

Reads public quest relationship dumps (JSON) or wago.tools DB2 CSVs and writes
linear AllQuest AddChain calls into an expansion pack's Generated.lua.

Do not copy BTWQuests or Questie databases. Input should be:
  * client DB2 / wago.tools CSV (QuestLine + QuestLineXQuest + Campaign*), or
  * /aqdebug questlines JSON you save from Retail, or
  * the sample file tools/quests_sample.json

JSON schema (list or {"quests": [...]}):
  {
    "expansion": 0,
    "expansionName": "Classic",
    "output": "AllQuest_Data_Classic/Generated.lua",
    "quests": [
      {
        "id": 783,
        "name": "A Threat Within",
        "zone": "Elwynn Forest",
        "categoryId": 1001,
        "minLevel": 1,
        "faction": "Alliance",
        "next": [5261],
        "prev": []
      }
    ]
  }

Usage:
  python extract_chains.py tools/quests_sample.json
  python extract_chains.py dump.json --output ../AllQuest_Data_Classic/Generated.lua
  python extract_chains.py --db2-dir %TEMP%\\allquest_db2 --write-packs
  python extract_chains.py --download --write-packs
"""

from __future__ import annotations

import argparse
import csv
import json
import os
import re
import sys
import urllib.request
from collections import defaultdict


PACKS = {
    0: "AllQuest_Data_Classic",
    1: "AllQuest_Data_TBC",
    2: "AllQuest_Data_Wrath",
    3: "AllQuest_Data_Cata",
    4: "AllQuest_Data_MoP",
    5: "AllQuest_Data_WoD",
    6: "AllQuest_Data_Legion",
    7: "AllQuest_Data_BFA",
    8: "AllQuest_Data_Shadowlands",
    9: "AllQuest_Data_Dragonflight",
    10: "AllQuest_Data_TWW",
    11: "AllQuest_Data_Midnight",
}

DB2_TABLES = ("QuestLine", "QuestLineXQuest", "Campaign", "CampaignXQuestLine")
WAGO_CSV = "https://wago.tools/db2/%s/csv"

# First matching substring wins. More specific titles before generic ones.
CAMPAIGN_RULES = [
    ("midnight", 11),
    ("eversong", 11),
    ("naigtal", 11),
    ("sunstrider", 11),
    ("arator", 11),
    ("12.1", 11),
    ("12.0", 11),
    ("coiled isle", 11),
    ("ula'tek", 11),
    ("atal'utek", 11),
    ("atal’utek", 11),
    ("call of the void", 11),
    ("empowered folio", 11),
    ("war of light", 11),
    ("welcome to val", 11),
    ("the war within", 10),
    ("catch up: the war within", 10),
    ("isle of dorn", 10),
    ("ringing deeps", 10),
    ("hallowfall", 10),
    ("azj-kahet", 10),
    ("undermine", 10),
    ("siren isle", 10),
    ("dark heart", 10),
    ("harbinger", 10),
    ("kirin tor", 10),
    ("red dawn", 10),
    ("lingering shadows", 10),
    ("arathi highlands siege", 10),
    ("ecological succession", 10),
    ("lorewalking", 10),
    ("shadowed sun", 10),
    ("knife's edge", 10),
    ("dragonflight", 9),
    ("dragonscale", 9),
    ("ohn'ahran", 9),
    ("waking shores", 9),
    ("azure span", 9),
    ("thaldraszus", 9),
    ("valdrakken", 9),
    ("iskaara", 9),
    ("neltharion", 9),
    ("guardians of the dream", 9),
    ("dracthyr", 9),
    ("flightstones", 9),
    ("shadowflame", 9),
    ("zskera", 9),
    ("obsidian citadel", 9),
    ("oathstone", 9),
    ("blue dragonflight", 9),
    ("green dragonflight", 9),
    ("the dreamer", 9),
    ("shadowlands", 8),
    ("revendreth", 8),
    ("venthyr", 8),
    ("bastion", 8),
    ("night fae", 8),
    ("kyrian", 8),
    ("ardenweald", 8),
    ("maldraxxus", 8),
    ("torghast", 8),
    ("first ones", 8),
    ("threads of fate", 8),
    ("covenant", 8),
    ("chains of domination", 8),
    ("blade of the primus", 8),
    ("exile's reach", 8),
    ("silver purpose", 8),
    ("peering into darkness", 8),
    ("box of many things", 8),
    ("looming dark", 8),
    ("art of war", 8),
    ("battle for azeroth", 7),
    ("nazjatar", 7),
    ("mechagon", 7),
    ("n'zoth", 7),
    ("n’zoth", 7),
    ("war campaign", 7),
    ("visions of azeroth", 7),
    ("legion: remix", 6),
    ("legionfall", 6),
    ("shadows of argus", 6),
    ("nightfallen", 6),
    ("insurrection", 6),
    ("order hall", 6),
    ("azsuna", 6),
    ("val'sharah", 6),
    ("highmountain", 6),
    ("stormheim", 6),
    ("legion", 6),
    ("mists of pandaria", 4),
    ("thunder king", 4),
    ("escalation", 4),
    ("siege of orgrimmar", 4),
    ("landfall", 4),
]

# QuestLine names that are zones / hubs (used when no campaign maps the line).
ZONE_RULES = [
    ("eversong woods", 1),
    ("eversong", 11),
    ("silvermoon", 11),
    ("zul'aman", 11),
    ("ghostlands", 11),
    ("isle of dorn", 10),
    ("ringing deeps", 10),
    ("hallowfall", 10),
    ("azj-kahet", 10),
    ("undermine", 10),
    ("karesh", 10),
    ("siren isle", 10),
    ("waking shores", 9),
    ("ohn'ahran", 9),
    ("azure span", 9),
    ("thaldraszus", 9),
    ("valdrakken", 9),
    ("zaralek", 9),
    ("emerald dream", 9),
    ("forbidden reach", 9),
    ("bastion", 8),
    ("maldraxxus", 8),
    ("ardenweald", 8),
    ("revendreth", 8),
    ("the maw", 8),
    ("korthia", 8),
    ("zereth", 8),
    ("oribos", 8),
    ("exile's reach", 8),
    ("zuldazar", 7),
    ("nazmir", 7),
    ("voldun", 7),
    ("vol'dun", 7),
    ("tiragarde", 7),
    ("drustvar", 7),
    ("stormsong", 7),
    ("nazjatar", 7),
    ("mechagon", 7),
    ("boralus", 7),
    ("dazar'alor", 7),
    ("azsuna", 6),
    ("val'sharah", 6),
    ("highmountain", 6),
    ("stormheim", 6),
    ("suramar", 6),
    ("broken shore", 6),
    ("argus", 6),
    ("krokuun", 6),
    ("mac'aree", 6),
    ("antoran", 6),
    ("dalaran", 6),
    ("shadowmoon valley", 5),
    ("frostfire", 5),
    ("gorgrond", 5),
    ("talador", 5),
    ("spires of arak", 5),
    ("nagrand", 5),
    ("tanaan", 5),
    ("ashran", 5),
    ("lunarfall", 5),
    ("frostwall", 5),
    ("jade forest", 4),
    ("valley of the four winds", 4),
    ("krasarang", 4),
    ("kun-lai", 4),
    ("townlong", 4),
    ("dread wastes", 4),
    ("vale of eternal", 4),
    ("isle of thunder", 4),
    ("timeless isle", 4),
    ("pandaria", 4),
    ("mount hyjal", 3),
    ("vashj'ir", 3),
    ("deepholm", 3),
    ("uldum", 3),
    ("twilight highlands", 3),
    ("tol barad", 3),
    ("thousand needles", 3),
    ("southern barrens", 3),
    ("northern barrens", 3),
    ("azshara", 3),
    ("dustwallow", 3),
    ("burning steppes", 3),
    ("searing gorge", 3),
    ("felwood", 3),
    ("feralas", 3),
    ("plaguelands", 3),
    ("desolace", 3),
    ("stranglethorn", 3),
    ("hinterlands", 3),
    ("silverpine", 3),
    ("blasted lands", 3),
    ("darkshore", 3),
    ("winterspring", 3),
    ("badlands", 3),
    ("tanaris", 3),
    ("stonetalon", 3),
    ("duskwood", 3),
    ("ashenvale", 3),
    ("wetlands", 3),
    ("hillsbrad", 3),
    ("swamp of sorrows", 3),
    ("loch modan", 3),
    ("redridge", 3),
    ("westfall", 3),
    ("elwynn", 3),
    ("northshire", 3),
    ("goldshire", 3),
    ("dun morogh", 3),
    ("ironforge", 3),
    ("stormwind", 3),
    ("orgrimmar", 3),
    ("thunder bluff", 3),
    ("undercity", 3),
    ("durotar", 3),
    ("tirisfal", 3),
    ("mulgore", 3),
    ("teldrassil", 3),
    ("echo isles", 3),
    ("gilneas", 3),
    ("ungoro", 3),
    ("silithus", 3),
    ("moonglade", 3),
    ("deadwind", 3),
    ("arathi highlands", 3),
    ("gnomeregan", 3),
    ("wandering isle", 4),
    ("path of ascension", 8),
    ("maruuk", 9),
    ("khaz algar", 10),
    ("severed threads", 10),
    ("moth hunt", 11),
    ("infinite research", 11),
    ("saltheril", 11),
    ("coiled isle", 11),
    ("atal'utek", 11),
    ("atal’utek", 11),
    ("harandar", 11),
    ("haranir", 11),
    ("tokka", 11),
    ("med'jai", 11),
    ("med’jai", 11),
    ("isle of fangs", 11),
    ("venomous", 11),
    ("voidstorm", 11),
    ("astalor", 11),
    ("nalorakk", 11),
    ("ren'dorei", 11),
    ("ren’dorei", 11),
    ("domanaar", 11),
    ("void assault", 11),
    ("prey", 11),
    ("naigtal", 11),
    ("k'aresh", 10),
    ("k’aresh", 10),
    ("artifact research", 6),
    ("balance of power", 6),
    ("in the land of giants", 5),
    ("scarlet enclave", 2),
    ("borean tundra", 2),
    ("howling fjord", 2),
    ("dragonblight", 2),
    ("grizzly hills", 2),
    ("zul'drak", 2),
    ("sholazar", 2),
    ("storm peaks", 2),
    ("icecrown", 2),
    ("crystalsong", 2),
    ("wintergrasp", 2),
    ("hellfire", 1),
    ("zangarmarsh", 1),
    ("terokkar", 1),
    ("nagrand", 1),
    ("blade's edge", 1),
    ("netherstorm", 1),
    ("shadowmoon", 1),
    ("azuremyst", 1),
    ("bloodmyst", 1),
    ("isle of quel'danas", 1),
]

SKIP_CAMPAIGN = (
    "test campaign",
    "ui testing",
    "laura test",
    "(dnt)",
    "catching up",
    "intro start",
    "jump to chapter",
    "intro skip",
    "onboarding skip",
    "professions onboarding",
)


def is_internal_name(name: str) -> bool:
    """Match Core/PluginAPI.lua Data.IsInternalContent. Keep 'Testing Loyalties'."""
    n = _norm(name)
    if not n:
        return False
    if "delete me" in n:
        return True
    if "(stm)" in n or "(poc)" in n or "(dnt)" in n or "[dnt]" in n or "[ph]" in n:
        return True
    if "peter's test" in n or n.startswith("test -") or "zone 3 neck" in n:
        return True
    if "prototype" in n:
        return True
    if "testing -" in n:
        return True
    if "the testing of " in n or " testing of " in n:
        return True
    if "- rpe -" in n or " rpe -" in n:
        return True
    if n.endswith(" test"):
        return True
    if re.match(r"^\d+\.\d+", n):
        if re.search(r" z\d+", n) or "prelaunch" in n or "endeavor" in n or "housing" in n or "cleanup" in n:
            return True
    if "moth hunt - group" in n:
        return True
    return False


def lua_str(s: str) -> str:
    return '"' + str(s).replace("\\", "\\\\").replace('"', '\\"') + '"'


def load_data(path: str) -> dict:
    with open(path, "r", encoding="utf-8") as f:
        data = json.load(f)
    if isinstance(data, list):
        return {"quests": data}
    if not isinstance(data, dict):
        raise SystemExit("JSON must be an object or array")
    return data


def as_ids(value) -> list:
    if value is None:
        return []
    if isinstance(value, int):
        return [value]
    if isinstance(value, list):
        return [int(x) for x in value if x is not None]
    return []


def build_chains(quests: list) -> list:
    by_id = {}
    for q in quests:
        qid = int(q["id"])
        q = dict(q)
        q["id"] = qid
        q["next"] = as_ids(q.get("next") or q.get("nextQuestInChain"))
        q["prev"] = as_ids(q.get("prev") or q.get("prevQuest") or q.get("PrevQuest"))
        by_id[qid] = q

    # Reverse next pointers into prev if missing.
    for q in by_id.values():
        for nxt in q["next"]:
            if nxt in by_id and q["id"] not in by_id[nxt]["prev"]:
                by_id[nxt]["prev"].append(q["id"])

    used = set()
    chains = []

    def walk(start: int) -> list:
        seq = []
        cur = start
        seen = set()
        while cur and cur in by_id and cur not in seen:
            seen.add(cur)
            seq.append(cur)
            nxts = [n for n in by_id[cur]["next"] if n in by_id]
            if len(nxts) == 1:
                cur = nxts[0]
            else:
                break
        return seq

    roots = []
    for qid, q in sorted(by_id.items()):
        if not q["prev"]:
            roots.append(qid)
    if not roots:
        roots = sorted(by_id)

    for root in roots:
        if root in used:
            continue
        seq = walk(root)
        if not seq:
            continue
        for qid in seq:
            used.add(qid)
        first = by_id[seq[0]]
        chains.append(
            {
                "name": first.get("name") or "Quest %s" % seq[0],
                "zone": first.get("zone") or "Unknown",
                "categoryId": first.get("categoryId"),
                "faction": first.get("faction"),
                "minLevel": first.get("minLevel") or first.get("level") or 1,
                "questIDs": seq,
            }
        )

    orphans = [qid for qid in sorted(by_id) if qid not in used]
    for qid in orphans:
        q = by_id[qid]
        chains.append(
            {
                "name": q.get("name") or "Quest %s" % qid,
                "zone": q.get("zone") or "Unknown",
                "categoryId": q.get("categoryId"),
                "faction": q.get("faction"),
                "minLevel": q.get("minLevel") or 1,
                "questIDs": [qid],
            }
        )
    return chains


def emit_lua(expansion: int, chains: list) -> str:
    lines = [
        "-- Generated by AllQuest/tools/extract_chains.py",
        "-- QuestLine / next-in-chain coverage. Rename / branch in Overlay.lua.",
        "local AQ = AllQuest",
        "if not AQ or not AQ.Data then return end",
        "",
    ]
    by_zone = defaultdict(list)
    for ch in chains:
        by_zone[ch["zone"]].append(ch)

    chain_base = expansion * 100000 + 90000
    cat_fallback = expansion * 1000 + 900
    zone_ids = {}
    n = 0
    for zone, zchains in sorted(by_zone.items()):
        cat_id = zchains[0].get("categoryId") or (cat_fallback + n)
        zone_ids[zone] = cat_id
        lines.append("AQ.Data:AddCategory({")
        lines.append("    id = %s," % cat_id)
        lines.append("    expansion = %s," % expansion)
        lines.append("    name = %s," % lua_str(zone))
        lines.append("})")
        lines.append("")
        n += 1

    for i, ch in enumerate(chains, start=1):
        cid = ch.get("chainId") or (chain_base + i)
        cat_id = ch.get("categoryId") or zone_ids.get(ch["zone"])
        lines.append("AQ.Data:AddChain({")
        lines.append("    id = %s," % cid)
        lines.append("    category = %s," % cat_id)
        lines.append("    expansion = %s," % expansion)
        lines.append("    name = %s," % lua_str(ch["name"]))
        if ch.get("faction"):
            lines.append("    restrictions = { faction = %s }," % lua_str(ch["faction"]))
        lines.append("    prerequisites = { { type = \"level\", min = %s } }," % int(ch.get("minLevel") or 1))
        lines.append("    nodes = {")
        ids = ch["questIDs"]
        for idx, qid in enumerate(ids, start=1):
            nxt = "{ %s }" % (idx + 1) if idx < len(ids) else "{}"
            lines.append("        { id = %s, type = \"quest\", questID = %s, next = %s }," % (idx, qid, nxt))
        lines.append("    },")
        lines.append("})")
        lines.append("")
    return "\n".join(lines)


def _norm(s: str) -> str:
    return (s or "").strip().lower()


def expansion_from_title(title: str) -> int | None:
    n = _norm(title)
    if not n:
        return None
    for needle, exp in CAMPAIGN_RULES:
        if needle in n:
            return exp
    return None


def expansion_from_zone(name: str) -> int | None:
    n = _norm(name)
    if not n:
        return None
    for needle, exp in ZONE_RULES:
        if needle in n:
            return exp
    return None


def skip_campaign(title: str) -> bool:
    n = _norm(title)
    return any(s in n for s in SKIP_CAMPAIGN)


def load_csv(path: str) -> list[dict]:
    with open(path, "r", encoding="utf-8-sig", newline="") as f:
        return list(csv.DictReader(f))


def download_db2(dest_dir: str) -> None:
    os.makedirs(dest_dir, exist_ok=True)
    for table in DB2_TABLES:
        url = WAGO_CSV % table
        out = os.path.join(dest_dir, table + ".csv")
        print("Downloading %s ..." % url)
        req = urllib.request.Request(url, headers={"User-Agent": "AllQuest-extract/1.0"})
        with urllib.request.urlopen(req, timeout=180) as resp:
            data = resp.read()
        with open(out, "wb") as f:
            f.write(data)
        print("  %s bytes -> %s" % (len(data), out))


def load_pack_categories(addons_dir: str) -> dict[tuple[int, str], int]:
    """Reuse category ids from Expansion.lua and Generated.lua so zone art stays wired."""
    known: dict[tuple[int, str], int] = {}
    cat_re = re.compile(
        r"AddCategory\(\s*\{(.*?)\}\s*\)",
        re.S,
    )
    for exp_id, pack in PACKS.items():
        for fname in ("Expansion.lua", "Generated.lua"):
            path = os.path.join(addons_dir, pack, fname)
            if not os.path.isfile(path):
                continue
            text = open(path, encoding="utf-8").read()
            for block in cat_re.findall(text):
                id_m = re.search(r"\bid\s*=\s*(\d+)", block)
                name_m = re.search(r"\bname\s*=\s*\"([^\"]+)\"", block)
                exp_m = re.search(r"\bexpansion\s*=\s*(\d+)", block)
                if id_m and name_m:
                    eid = int(exp_m.group(1)) if exp_m else exp_id
                    key = (eid, name_m.group(1).lower())
                    if key not in known:
                        known[key] = int(id_m.group(1))
    return known


def chains_from_db2(db2_dir: str) -> dict[int, list]:
    qlines = {int(r["ID"]): r for r in load_csv(os.path.join(db2_dir, "QuestLine.csv")) if r.get("ID")}
    qlx = load_csv(os.path.join(db2_dir, "QuestLineXQuest.csv"))
    camps = {int(r["ID"]): r for r in load_csv(os.path.join(db2_dir, "Campaign.csv")) if r.get("ID")}
    cx = load_csv(os.path.join(db2_dir, "CampaignXQuestLine.csv"))

    camp_exp: dict[int, int] = {}
    for cid, row in camps.items():
        title = row.get("Title_lang") or ""
        if skip_campaign(title) or is_internal_name(title):
            continue
        exp = expansion_from_title(title)
        if exp is not None:
            camp_exp[cid] = exp

    line_campaign: dict[int, tuple[int, str]] = {}
    for r in cx:
        try:
            camp_id = int(r["CampaignID"])
            line_id = int(r["QuestLineID"])
        except (TypeError, ValueError):
            continue
        if camp_id not in camp_exp:
            continue
        title = (camps.get(camp_id) or {}).get("Title_lang") or "Campaign"
        prev = line_campaign.get(line_id)
        # Prefer the higher expansion if a line is reused.
        if not prev or camp_exp[camp_id] >= prev[0]:
            line_campaign[line_id] = (camp_exp[camp_id], title)

    by_line: dict[int, list[int]] = defaultdict(list)
    order_pairs: dict[int, list[tuple[int, int]]] = defaultdict(list)
    for r in qlx:
        try:
            lid = int(r["QuestLineID"])
            qid = int(r["QuestID"])
            order = int(r.get("OrderIndex") or 0)
        except (TypeError, ValueError):
            continue
        order_pairs[lid].append((order, qid))
    for lid, pairs in order_pairs.items():
        pairs.sort()
        # Keep first occurrence of a quest id in this line.
        seen = set()
        seq = []
        for _, qid in pairs:
            if qid not in seen:
                seen.add(qid)
                seq.append(qid)
        by_line[lid] = seq

    per_exp: dict[int, list] = defaultdict(list)
    unmapped_rows: list[tuple[int, str, int]] = []
    skipped_internal = 0
    for lid, seq in by_line.items():
        if not seq:
            continue
        row = qlines.get(lid, {})
        lname = (row.get("Name_lang") or ("Questline %s" % lid)).strip()
        if is_internal_name(lname):
            skipped_internal += 1
            continue
        mapped = line_campaign.get(lid)
        if mapped:
            exp, zone = mapped
            if is_internal_name(zone):
                skipped_internal += 1
                continue
        else:
            exp = expansion_from_zone(lname) or expansion_from_title(lname)
            zone = lname
        if exp is None or exp == 0:
            unmapped_rows.append((lid, lname, len(seq)))
            continue
        per_exp[exp].append(
            {
                "name": lname,
                "zone": zone,
                "questLineID": lid,
                "minLevel": 1,
                "questIDs": seq,
            }
        )
    print("DB2: %s questlines with quests, %s unmapped, %s internal skipped, %s assigned" % (
        len(by_line),
        len(unmapped_rows),
        skipped_internal,
        sum(len(v) for v in per_exp.values()),
    ))
    return per_exp, unmapped_rows


def assign_category_ids(expansion: int, chains: list, known: dict[tuple[int, str], int]) -> None:
    cat_fallback = expansion * 1000 + 900
    used = set()
    max_known = cat_fallback - 1
    for (eid, _), cid in known.items():
        if eid == expansion:
            used.add(cid)
            if cid > max_known:
                max_known = cid
    zone_ids: dict[str, int] = {}
    next_id = max_known + 1
    for ch in chains:
        zone = ch["zone"]
        if zone in zone_ids:
            ch["categoryId"] = zone_ids[zone]
            continue
        key = (expansion, zone.lower())
        cat_id = known.get(key)
        if not cat_id:
            while next_id in used:
                next_id += 1
            cat_id = next_id
            next_id += 1
        used.add(cat_id)
        zone_ids[zone] = cat_id
        ch["categoryId"] = cat_id


def write_lua(path: str, text: str) -> None:
    os.makedirs(os.path.dirname(os.path.abspath(path)) or ".", exist_ok=True)
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write(text)
        if not text.endswith("\n"):
            f.write("\n")


def write_json_pack(data: dict, output: str | None, addons: str) -> int:
    quests = data.get("quests") or data.get("Quest") or []
    if not quests:
        print("No quests in input", file=sys.stderr)
        return 1
    expansion = int(data.get("expansion") or 0)
    chains = build_chains(quests)
    lua = emit_lua(expansion, chains)
    out = output or data.get("output")
    if not out:
        pack = PACKS.get(expansion, "AllQuest_Data_Classic")
        out = os.path.join(addons, pack, "Generated.lua")
    write_lua(out, lua)
    print("Wrote %s chains (%s quests) -> %s" % (len(chains), len(quests), out))
    return 0


def write_audit_report(db2_dir: str, per_exp: dict[int, list], unmapped_rows: list[tuple[int, str, int]]) -> str:
    path = os.path.join(db2_dir, "audit_report.txt")
    lines = ["AllQuest QuestLine audit", ""]
    for exp in sorted(per_exp):
        chains = per_exp[exp]
        nq = sum(len(c["questIDs"]) for c in chains)
        zones = sorted({c["zone"] for c in chains})
        pack = PACKS.get(exp, "?")
        lines.append("%s (exp %s): %s questlines, %s quests, %s folders" % (
            pack, exp, len(chains), nq, len(zones),
        ))
    lines.append("")
    lines.append("Unmapped QuestLines (not assigned to an expansion pack): %s" % len(unmapped_rows))
    for lid, name, nq in sorted(unmapped_rows, key=lambda r: r[1].lower()):
        lines.append("  [%s] %s (%s quests)" % (lid, name, nq))
    write_lua(path, "\n".join(lines))
    print("Wrote audit report -> %s" % path)
    return path


def write_db2_packs(db2_dir: str, addons: str) -> int:
    known = load_pack_categories(addons)
    per_exp, unmapped_rows = chains_from_db2(db2_dir)
    write_audit_report(db2_dir, per_exp, unmapped_rows)
    total = 0
    for exp in sorted(per_exp):
        if exp == 0:
            print("Skipping Classic pack (hand-authored chains only)")
            continue
        pack = PACKS.get(exp)
        if not pack:
            continue
        chains = sorted(per_exp[exp], key=lambda c: (c["zone"], c["name"]))
        assign_category_ids(exp, chains, known)
        lua = emit_lua(exp, chains)
        out = os.path.join(addons, pack, "Generated.lua")
        write_lua(out, lua)
        nq = sum(len(c["questIDs"]) for c in chains)
        print("Wrote %s chains (%s quests) expansion %s -> %s" % (len(chains), nq, exp, out))
        total += len(chains)
    print("Total chains written: %s" % total)
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description="Build AllQuest Generated.lua from quest JSON or DB2 CSV")
    parser.add_argument("input", nargs="?", help="quests JSON file")
    parser.add_argument("--output", help="Lua file to write")
    parser.add_argument("--db2-dir", help="Directory containing QuestLine/Campaign CSVs")
    parser.add_argument("--write-packs", action="store_true", help="Write each expansion pack Generated.lua (skips Classic)")
    parser.add_argument("--download", action="store_true", help="Download wago.tools DB2 CSVs into --db2-dir")
    args = parser.parse_args()

    here = os.path.dirname(os.path.abspath(__file__))
    addons = os.path.abspath(os.path.join(here, "..", ".."))
    db2_dir = args.db2_dir or os.path.join(here, "db2_cache")

    if args.download:
        download_db2(db2_dir)

    if args.write_packs or (args.db2_dir and not args.input):
        if not os.path.isfile(os.path.join(db2_dir, "QuestLineXQuest.csv")):
            print("Missing QuestLineXQuest.csv in %s (use --download)" % db2_dir, file=sys.stderr)
            return 1
        return write_db2_packs(db2_dir, addons)

    if not args.input:
        parser.print_help()
        return 2
    data = load_data(args.input)
    return write_json_pack(data, args.output, addons)


if __name__ == "__main__":
    sys.exit(main())
