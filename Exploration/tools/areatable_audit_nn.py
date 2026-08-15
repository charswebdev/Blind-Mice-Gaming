#!/usr/bin/env python3
"""AreaTable discovery-XP audit + curated-route NN recuration.

Discovery-XP signal (in-repo): ExplorationDB2Coords.explorable == true
  <=> AreaBit > 0 and (Flags_1 & 0x80) == 0 and selected by DB2 export.

Also flags any AreaTable rows with AreaBit>0 & !NotExplorable that are
missing from DB2 as candidates to refresh Coords.lua.
"""
from __future__ import annotations

import csv
import math
import re
import sys
from collections import defaultdict
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(Path(__file__).resolve().parent))
from pin_io import parse_route_pins, replace_route_pins  # noqa: E402

CACHE = ROOT / "tools" / "db2_cache"
GENERATED = ROOT / "Data" / "Routes" / "Generated.lua"
MANUAL = ROOT / "Data" / "Coords" / "Manual.lua"
DB2 = ROOT / "Data" / "DB2" / "Coords.lua"
FILTER = ROOT / "Data" / "SubzoneFilter.lua"
DYSTINCT = ROOT / ".." / "Dystinct_EarthenSkyriding" / "Util" / "Default.lua"
REPORT = ROOT / "tools" / "audit_report.txt"

NOT_EXPLORABLE = 0x80  # Flags_1

# Name patterns that are never route-worthy (junk tier).
JUNK_NAME = re.compile(
    r"UNUSED|Hackathon|zzOld|NOT TEMP|copy\)|\(copy\)|Test Area|Designer|"
    r"NYI|DO NOT USE|Placeholder",
    re.I,
)


def load_areatable():
    rows = list(csv.DictReader((CACHE / "AreaTable.csv").open(encoding="utf-8-sig", newline="")))
    return {int(r["ID"]): r for r in rows}


def load_uimap_centroids():
    """AreaID -> {uiMapID: (x%, y%)} from UiMapAssignment region centers."""
    rows = list(csv.DictReader((CACHE / "UiMapAssignment.csv").open(encoding="utf-8-sig", newline="")))
    out = defaultdict(dict)
    for r in rows:
        aid = int(float(r["AreaID"] or 0))
        if aid <= 0:
            continue
        umap = int(float(r["UiMapID"] or 0))
        # Prefer world map style assignments with Ui 0..1
        try:
            umin0, umin1 = float(r["UiMin_0"]), float(r["UiMin_1"])
            umax0, umax1 = float(r["UiMax_0"]), float(r["UiMax_1"])
        except ValueError:
            continue
        # Convert Ui coords (0..1) to percentage map coords. WoW map Y is often inverted.
        cx = (umin0 + umax0) / 2.0 * 100.0
        cy = (umin1 + umax1) / 2.0 * 100.0
        if not (0 <= cx <= 100 and 0 <= cy <= 100):
            continue
        # Keep smallest region (more specific subzone) — approximate by area of ui rect
        area = abs(umax0 - umin0) * abs(umax1 - umin1)
        prev = out[aid].get(umap)
        if prev is None or area < prev[2]:
            out[aid][umap] = (round(cx, 2), round(cy, 2), area)
    # strip area size
    clean = {}
    for aid, maps in out.items():
        clean[aid] = {m: (xy[0], xy[1]) for m, xy in maps.items()}
    return clean


def load_db2():
    text = DB2.read_text(encoding="utf-8")
    coords = {}
    by_map = defaultdict(list)
    for m in re.finditer(r"ExplorationDB2Coords\[(\d+)\] = \{([^}]+)\}", text):
        aid = int(m.group(1))
        body = m.group(2)
        name_m = re.search(r'name = "([^"]*)"', body)
        map_m = re.search(r"map = (\d+)", body)
        if not name_m or not map_m:
            continue
        entry = {
            "name": name_m.group(1),
            "map": int(map_m.group(1)),
            "explorable": "explorable = true" in body,
            "areaID": aid,
        }
        coords[aid] = entry
        by_map[entry["map"]].append(aid)
    return coords, by_map


def load_exclusions():
    text = FILTER.read_text(encoding="utf-8")
    excluded_ids = set(int(x) for x in re.findall(r"^\s*\[(\d+)\]\s*=\s*true", text, re.M))
    # EXCLUDED_ON_MAP blocks: [map] = { [id]=true }
    on_map = defaultdict(set)
    for m in re.finditer(r"\[(\d+)\]\s*=\s*\{([^{}]*)\}", text):
        mid = int(m.group(1))
        body = m.group(2)
        # heuristic: only small-ish map id tables inside EXCLUDED_ON_MAP
        ids = [int(x) for x in re.findall(r"\[(\d+)\]\s*=\s*true", body)]
        if ids and mid < 10000:
            for i in ids:
                on_map[mid].add(i)
    return excluded_ids, on_map


def parse_manual():
    """map -> list of {name,x,y,areaID?} and areaID -> (map,x,y,name)"""
    text = MANUAL.read_text(encoding="utf-8")
    by_map = defaultdict(list)
    by_id = {}
    by_name_map = {}
    for mm in re.finditer(r"\[(\d+)\]\s*=\s*\{", text):
        mid = int(mm.group(1))
        start = mm.end()
        # find matching close at same nesting — crude: until next [digits] = { at column-ish or pack end
        depth = 1
        i = start
        while i < len(text) and depth:
            if text[i] == "{":
                depth += 1
            elif text[i] == "}":
                depth -= 1
            i += 1
        block = text[start : i - 1]
        for e in re.finditer(
            r'\{\s*"([^"]+)"\s*,\s*([\d.]+)\s*,\s*([\d.]+)(?:\s*,\s*(\d+))?\s*\}',
            block,
        ):
            name, x, y, aid = e.group(1), float(e.group(2)), float(e.group(3)), e.group(4)
            rec = {"name": name, "x": x, "y": y, "areaID": int(aid) if aid else None, "map": mid}
            by_map[mid].append(rec)
            by_name_map[(mid, name.lower())] = rec
            if aid:
                by_id[int(aid)] = rec
    return by_map, by_id, by_name_map


def parse_generated_routes():
    text = GENERATED.read_text(encoding="utf-8")
    routes = {}
    for m in re.finditer(r'R\["([^"]+)"\]\s*=\s*\{', text):
        key = m.group(1)
        start = m.start()
        # find end of this table — next R[" or EOF
        nxt = re.search(r'\nR\["', text[m.end() :])
        end = m.end() + nxt.start() if nxt else len(text)
        block = text[start:end]
        curated = bool(re.search(r"curated\s*=\s*true", block))
        dv_m = re.search(r"dataVersion\s*=\s*(\d+)", block)
        pins = []
        for p in re.finditer(
            r'\{\s*name\s*=\s*"([^"]+)"\s*,\s*map\s*=\s*(\d+)\s*,\s*x\s*=\s*([\d.]+)\s*,\s*y\s*=\s*([\d.]+)[^}]*\}',
            block,
        ):
            pins.append(
                {
                    "name": p.group(1),
                    "map": int(p.group(2)),
                    "x": float(p.group(3)),
                    "y": float(p.group(4)),
                }
            )
        routes[key] = {
            "curated": curated,
            "dataVersion": int(dv_m.group(1)) if dv_m else None,
            "pins": pins,
            "start": start,
            "end": end,
            "block": block,
        }
    return text, routes


def parse_dystinct():
    """map,name -> (x,y) from Default.lua exploration-ish pins."""
    if not DYSTINCT.exists():
        return {}
    text = DYSTINCT.read_text(encoding="utf-8", errors="replace")
    out = {}
    for m in re.finditer(
        r'\{\s*name\s*=\s*"([^"]+)"\s*,\s*map\s*=\s*(\d+)\s*,\s*x\s*=\s*([\d.]+)\s*,\s*y\s*=\s*([\d.]+)',
        text,
    ):
        name, mid, x, y = m.group(1), int(m.group(2)), float(m.group(3)), float(m.group(4))
        key = (mid, name.lower())
        if key not in out:
            out[key] = (x, y)
    return out


def parse_exploration_sv_coords():
    """Learned waypoint keys: Name|map|x|y from Exploration.lua SavedVariables if present."""
    sv = Path(r"c:\Program Files (x86)\World of Warcraft\_retail_\WTF\Account")
    out = {}
    accounts = []
    if sv.exists():
        accounts = list(sv.glob("*/SavedVariables/Exploration.lua"))
    preferred = [p for p in accounts if "FREYAHEART" in str(p)]
    paths = preferred or accounts
    for path in paths[:1]:
        text = path.read_text(encoding="utf-8", errors="replace")
        for m in re.finditer(
            r'\["([^"|]+)\|(\d+)\|([\d.]+)\|([\d.]+)"\]\s*=\s*\{',
            text,
        ):
            name, mid, x, y = m.group(1), int(m.group(2)), float(m.group(3)), float(m.group(4))
            key = (mid, norm(name))
            if key not in out:
                out[key] = (x, y)
    return out


def norm(s: str) -> str:
    return re.sub(r"\s+", " ", s.strip().lower())


NO_XP_COMMENT = re.compile(
    r"no discovery|Entering only|NotExplorable|Flags_1\s*=\s*0|AreaBit\s*==?\s*0|"
    r"never clears|glyph|interior|micro-dungeon|researched|disc\s*=\s*false|"
    r"no fog|shared fog|secondary on|NoDiscover|Entering-only|treasure cave|"
    r"seam-misplaced|open air|stuck post-discover|pin sat",
    re.I,
)

KEEP_DESPITE_EXCLUDE = re.compile(
    r"Discover XP exists|grants? discovery|discovery XP",
    re.I,
)


def load_exclusion_comments():
    text = FILTER.read_text(encoding="utf-8")
    comments = {}
    for m in re.finditer(r"\[(\d+)\]\s*=\s*true,\s*--\s*([^\n]+)", text):
        comments[int(m.group(1))] = m.group(2)
    return comments


def is_excluded(aid, mid, excluded_ids, on_map, comments):
    """Skip SubzoneFilter exclusions unless comment says Discover XP exists."""
    excluded = aid in excluded_ids or (mid in on_map and aid in on_map[mid])
    if not excluded:
        return False
    comment = comments.get(aid, "")
    if KEEP_DESPITE_EXCLUDE.search(comment):
        return False
    # Hard no-XP / shared-fog / never-clears stay excluded
    if NO_XP_COMMENT.search(comment) or comment:
        return True
    return True


def nn_order(pins):
    """Nearest-neighbor within contiguous same-map segments; preserve map-visit order."""
    if not pins:
        return pins
    # Split into map runs
    runs = []
    cur = [pins[0]]
    for p in pins[1:]:
        if p["map"] == cur[0]["map"]:
            cur.append(p)
        else:
            runs.append(cur)
            cur = [p]
    runs.append(cur)

    def nn(run):
        if len(run) <= 2:
            return run
        remaining = run[1:]
        ordered = [run[0]]
        while remaining:
            lx, ly = ordered[-1]["x"], ordered[-1]["y"]
            best_i = 0
            best_d = float("inf")
            for i, p in enumerate(remaining):
                d = (p["x"] - lx) ** 2 + (p["y"] - ly) ** 2
                if d < best_d:
                    best_d = d
                    best_i = i
            ordered.append(remaining.pop(best_i))
        return two_opt(ordered)

    def two_opt(run, passes=40):
        n = len(run)
        if n < 4:
            return run
        best = run[:]

        def length(path):
            s = 0.0
            for i in range(len(path) - 1):
                s += math.hypot(path[i + 1]["x"] - path[i]["x"], path[i + 1]["y"] - path[i]["y"])
            return s

        best_len = length(best)
        for _ in range(passes):
            improved = False
            for i in range(1, n - 2):
                for k in range(i + 1, n - 1):
                    cand = best[:i] + best[i : k + 1][::-1] + best[k + 1 :]
                    cl = length(cand)
                    if cl + 1e-9 < best_len:
                        best, best_len = cand, cl
                        improved = True
            if not improved:
                break
        return best

    out = []
    for run in runs:
        out.extend(nn(run))
    return out


def format_pin(p):
    """New pins only (audit adds). Existing pins must use pin_io preservation."""
    xs = f"{float(p['x']):.2f}"
    ys = f"{float(p['y']):.2f}"
    return (
        f'        {{ name = "{p["name"]}", map = {p["map"]}, '
        f'x = {xs}, y = {ys}, trigger = {{ type = "proximity" }} }},'
    )


def classify_candidate(name: str, src: str | None, has_xy: bool) -> str:
    """Return must-add | review | junk."""
    if JUNK_NAME.search(name or ""):
        return "junk"
    if has_xy and src in ("manual-id", "manual-name", "dystinct", "exploration-sv"):
        return "must-add"
    if has_xy and src == "uimap-centroid":
        return "review"
    return "review"


def main(apply: bool = False, force_lossy: bool = False):
    at = load_areatable()
    db2, db2_by_map = load_db2()
    excluded_ids, on_map = load_exclusions()
    excl_comments = load_exclusion_comments()
    manual_by_map, manual_by_id, manual_by_name = parse_manual()
    gen_text, routes = parse_generated_routes()
    dyst = parse_dystinct()
    learned = parse_exploration_sv_coords()
    centroids = load_uimap_centroids()

    missing_db2 = []
    for aid, r in at.items():
        bit = int(r["AreaBit"])
        f1 = int(r["Flags_1"])
        if bit <= 0 or (f1 & NOT_EXPLORABLE):
            continue
        if aid not in db2:
            missing_db2.append((aid, r["AreaName_lang"], r["ParentAreaID"], r["Flags_1"]))

    curated = {k: v for k, v in routes.items() if v["curated"]}

    stamp = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S UTC")
    report = []
    report.append(f"Exploration AreaTable audit — {stamp}")
    report.append("Tiers: must-add (trusted coords) | review (needs human) | junk (UNUSED/hackathon/etc.)")
    report.append("Gate 0: --apply blocked unless --force-lossy-apply. Prefer tools/nn_reorder_route.py.")
    report.append("")
    report.append(f"AreaTable rows: {len(at)}")
    explorable_n = sum(1 for v in db2.values() if v["explorable"])
    report.append(f"DB2 coords: {len(db2)} explorable={explorable_n}")
    report.append(f"AreaBit>0 !NotExplorable missing from DB2: {len(missing_db2)}")
    report.append(f"Curated routes: {len(curated)}")
    report.append("")

    route_new_pins = {}
    tier_totals = {"must-add": 0, "review": 0, "junk": 0}

    for rkey, rdata in sorted(curated.items()):
        pin_count_by_map = defaultdict(int)
        for p in rdata["pins"]:
            pin_count_by_map[p["map"]] += 1
        maps = sorted(mid for mid, n in pin_count_by_map.items() if n >= 3)
        route_names = {(p["map"], norm(p["name"])) for p in rdata["pins"]}

        missing = []
        for mid in maps:
            for aid in db2_by_map.get(mid, []):
                e = db2[aid]
                if not e["explorable"]:
                    continue
                if is_excluded(aid, mid, excluded_ids, on_map, excl_comments):
                    continue
                key = (mid, norm(e["name"]))
                if key in route_names:
                    continue
                if aid in manual_by_id:
                    mrec = manual_by_id[aid]
                    if (mrec["map"], norm(mrec["name"])) in route_names:
                        continue
                missing.append((aid, e["name"], mid))

        resolved = []
        by_tier = {"must-add": [], "review": [], "junk": []}
        for aid, name, mid in missing:
            src = None
            xy = None
            if aid in manual_by_id and manual_by_id[aid]["map"] == mid:
                xy = (manual_by_id[aid]["x"], manual_by_id[aid]["y"])
                src = "manual-id"
            elif (mid, norm(name)) in manual_by_name:
                rec = manual_by_name[(mid, norm(name))]
                xy = (rec["x"], rec["y"])
                src = "manual-name"
            elif (mid, norm(name)) in dyst:
                xy = dyst[(mid, norm(name))]
                src = "dystinct"
            elif (mid, norm(name)) in learned:
                xy = learned[(mid, norm(name))]
                src = "exploration-sv"
            elif aid in centroids and mid in centroids[aid]:
                xy = centroids[aid][mid]
                src = "uimap-centroid"
            elif aid in centroids and len(centroids[aid]) == 1:
                only_map, xy = next(iter(centroids[aid].items()))
                if only_map == mid:
                    src = "uimap-centroid"
                else:
                    xy = None
            lname = name.lower()
            looks_interior = bool(
                re.search(
                    r"\b(cavern|cave|crypt|catacomb|vault|hall of|grotto|depths|passage|underground|mines?|dig)\b",
                    lname,
                )
            )
            has_xy = bool(xy)
            if looks_interior and src not in ("manual-id", "manual-name"):
                has_xy = False
                xy = None
                src = None
            elif xy and looks_interior and src == "uimap-centroid":
                has_xy = False
                xy = None
                src = None

            tier = classify_candidate(name, src, has_xy)
            tier_totals[tier] += 1
            entry = {
                "name": name,
                "map": mid,
                "x": float(xy[0]) if xy else None,
                "y": float(xy[1]) if xy else None,
                "areaID": aid,
                "source": src,
                "tier": tier,
            }
            by_tier[tier].append(entry)
            if tier == "must-add" and xy:
                resolved.append(entry)

        report.append(
            f"=== {rkey} (dv={rdata['dataVersion']}, pins={len(rdata['pins'])}, maps={maps})"
        )
        report.append(
            "  candidates: {0}  must-add={1}  review={2}  junk={3}".format(
                len(missing),
                len(by_tier["must-add"]),
                len(by_tier["review"]),
                len(by_tier["junk"]),
            )
        )
        for p in by_tier["must-add"][:30]:
            report.append(
                f"  [must-add] {p['name']} ({p['areaID']}) map={p['map']} "
                f"{p['x']:.2f},{p['y']:.2f} [{p['source']}]"
            )
        if len(by_tier["must-add"]) > 30:
            report.append(f"  ... +{len(by_tier['must-add'])-30} more must-add")
        for p in by_tier["review"][:15]:
            if p["x"] is not None:
                report.append(
                    f"  [review] {p['name']} ({p['areaID']}) map={p['map']} "
                    f"{p['x']:.2f},{p['y']:.2f} [{p['source']}]"
                )
            else:
                report.append(f"  [review] {p['name']} ({p['areaID']}) map={p['map']} NO COORDS")
        if len(by_tier["review"]) > 15:
            report.append(f"  ... +{len(by_tier['review'])-15} more review")
        for p in by_tier["junk"][:8]:
            report.append(f"  [junk] {p['name']} ({p['areaID']}) map={p['map']}")
        if len(by_tier["junk"]) > 8:
            report.append(f"  ... +{len(by_tier['junk'])-8} more junk")
        report.append("")
        route_new_pins[rkey] = resolved

    wrong_excl = []
    ftext = FILTER.read_text(encoding="utf-8")
    for m in re.finditer(r"\[(\d+)\]\s*=\s*true,\s*--\s*([^\n]+)", ftext):
        aid = int(m.group(1))
        comment = m.group(2)
        if aid in db2 and db2[aid]["explorable"]:
            if re.search(r"not Explore", comment, re.I) and not re.search(
                r"no discovery|Entering only|NotExplorable|shared fog|Flags_1=0|interior|AreaBit",
                comment,
                re.I,
            ):
                wrong_excl.append((aid, db2[aid]["name"], db2[aid]["map"], comment.strip()))

    report.append("=== Possibly wrong exclusions (explorable + 'not Explore' only) ===")
    for row in wrong_excl[:80]:
        report.append(f"  [{row[0]}] {row[1]} map={row[2]} — {row[3]}")
    report.append(f"Total wrong-exclusion candidates: {len(wrong_excl)}")
    report.append("")
    report.append(
        f"TOTALS must-add={tier_totals['must-add']} "
        f"review={tier_totals['review']} junk={tier_totals['junk']}"
    )
    report.append(
        f"Trusted pins eligible to add (must-add only): "
        f"{sum(len(v) for v in route_new_pins.values())}"
    )

    if apply and not force_lossy:
        report.append("")
        report.append("REFUSED --apply: use tools/nn_reorder_route.py for safe reorder.")
        report.append("Override only with --force-lossy-apply (not recommended).")
        REPORT.write_text("\n".join(report), encoding="utf-8")
        print("\n".join(report[-60:]))
        print(f"\nFull report: {REPORT}")
        print("\n--apply blocked (Gate 0).")
        return

    REPORT.write_text("\n".join(report), encoding="utf-8")
    print("\n".join(report[-60:]))
    print(f"\nFull report: {REPORT}")

    if not apply:
        print("Dry-run only. Tiered report written.")
        return

    print("WARNING: --force-lossy-apply requested but Manual/Generated merge remains disabled in Gate 0.")
    print("Use must-add list from the report + pin_io-preserving edits instead.")
    _ = (parse_route_pins, replace_route_pins, format_pin, gen_text, manual_by_map)


if __name__ == "__main__":
    apply = "--apply" in sys.argv
    force = "--force-lossy-apply" in sys.argv
    if force:
        apply = True
    main(apply=apply, force_lossy=force)
