#!/usr/bin/env python3
"""Emit Classic→Midnight instance entrances canvas from InstanceEntrances.json."""
from __future__ import annotations

import json
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
JSON = ROOT / "Data" / "InstanceEntrances.json"
OUT = Path(
    r"C:\Users\CharlotteBryant\.cursor\projects"
    r"\c-Program-Files-x86-World-of-Warcraft-retail-Interface-AddOns-wowgps"
    r"\canvases\classic-to-midnight-entrances.canvas.tsx"
)

EXP_ORDER = [
    "Classic",
    "Burning Crusade",
    "Wrath of the Lich King",
    "Cataclysm",
    "Mists of Pandaria",
    "Warlords of Draenor",
    "Legion",
    "Battle for Azeroth",
    "Shadowlands",
    "Dragonflight",
    "The War Within",
    "Midnight",
]


def js_str(s: str) -> str:
    return json.dumps(s, ensure_ascii=False)


def main() -> None:
    data = json.loads(JSON.read_text(encoding="utf-8"))
    by_kind = Counter(e["kind"] for e in data)
    by_exp = Counter(e.get("expansion") or "?" for e in data)
    unique = len({e["name"] for e in data})

    rows = []
    for e in sorted(
        data,
        key=lambda a: (
            EXP_ORDER.index(a["expansion"]) if a.get("expansion") in EXP_ORDER else 99,
            a["kind"],
            a["name"],
            a.get("mapId") or 0,
        ),
    ):
        mid = "null" if e.get("mapId") is None else str(int(e["mapId"]))
        rows.append(
            "  {"
            f" name: {js_str(e['name'])},"
            f" kind: {js_str(e['kind'])},"
            f" expansion: {js_str(e.get('expansion') or 'Unknown')},"
            f" mapId: {mid},"
            f" x: {e['x']:.2f},"
            f" y: {e['y']:.2f},"
            f" source: {js_str(e.get('source') or '')},"
            " },"
        )

    exp_stats = ",\n".join(
        f'  {{ label: {js_str(exp)}, value: {by_exp.get(exp, 0)} }}'
        for exp in EXP_ORDER
        if by_exp.get(exp, 0)
    )

    canvas = f"""import {{
  Callout,
  Divider,
  Grid,
  H1,
  H2,
  Pill,
  Row,
  Select,
  Spacer,
  Stack,
  Stat,
  Table,
  Text,
  TextInput,
  useCanvasState,
}} from "cursor/canvas";

type Kind = "Raid" | "Dungeon" | "Delve" | "All";
type Expansion = "All" | {" | ".join(js_str(e) for e in EXP_ORDER)};

type Entry = {{
  name: string;
  kind: "Raid" | "Dungeon" | "Delve";
  expansion: string;
  mapId: number | null;
  x: number;
  y: number;
  source: string;
}};

const ENTRIES: Entry[] = [
{chr(10).join(rows)}
];

const EXP_OPTIONS: {{ label: string; value: Expansion }}[] = [
  {{ label: "All expansions", value: "All" }},
{chr(10).join(f'  {{ label: {js_str(e)}, value: {js_str(e)} }},' for e in EXP_ORDER)}
];

const KIND_OPTIONS: {{ label: string; value: Kind }}[] = [
  {{ label: "All types", value: "All" }},
  {{ label: "Raids", value: "Raid" }},
  {{ label: "Dungeons", value: "Dungeon" }},
  {{ label: "Delves", value: "Delve" }},
];

const BY_EXP = [
{exp_stats}
];

export default function ClassicToMidnightEntrances() {{
  const [q, setQ] = useCanvasState("q", "");
  const [kind, setKind] = useCanvasState<Kind>("kind", "All");
  const [exp, setExp] = useCanvasState<Expansion>("exp", "All");

  const filtered = ENTRIES.filter((e) => {{
    if (kind !== "All" && e.kind !== kind) return false;
    if (exp !== "All" && e.expansion !== exp) return false;
    const needle = q.trim().toLowerCase();
    if (!needle) return true;
    return (
      e.name.toLowerCase().includes(needle) ||
      e.expansion.toLowerCase().includes(needle) ||
      String(e.mapId ?? "").includes(needle) ||
      e.source.toLowerCase().includes(needle)
    );
  }});

  return (
    <Stack gap={{20}} style={{{{ padding: 20, maxWidth: 1100 }}}}>
      <Stack gap={{6}}>
        <H1>Classic → Midnight instance entrances</H1>
        <Text tone="secondary">
          Full raid, dungeon, and delve portal catalog for WowGPS search/routing.
          Dungeons/raids from HandyNotes + JournalInstance; delves and modern
          content from Method/Icy Veins.
        </Text>
      </Stack>

      <Grid columns={{5}} gap={{12}}>
        <Stat value={{String({len(data)})}} label="Portal pins" />
        <Stat value={{String({unique})}} label="Unique instances" />
        <Stat value={{String({by_kind.get('Raid', 0)})}} label="Raid pins" />
        <Stat value={{String({by_kind.get('Dungeon', 0)})}} label="Dungeon pins" />
        <Stat value={{String({by_kind.get('Delve', 0)})}} label="Delve pins" />
      </Grid>

      <Callout tone="info" title="In-game wiring">
        Data lives in Data/InstanceEntrances.lua and merges into
        DestinationsCatalog after AreaTable. Reload UI, then search e.g.
        \"Voidspire\", \"Deadmines\", or \"Nerub\".
      </Callout>

      <Stack gap={{8}}>
        <H2>Pins by expansion</H2>
        <Table
          headers={{["Expansion", "Pins"]}}
          rows={{BY_EXP.map((r) => [r.label, String(r.value)])}}
        />
      </Stack>

      <Divider />

      <Row gap={{12}} align="end" wrap>
        <Stack gap={{4}} style={{{{ flex: 1, minWidth: 180 }}}}>
          <Text size="small" tone="secondary">
            Search
          </Text>
          <TextInput value={{q}} onChange={{setQ}} placeholder="Name, mapId, source…" />
        </Stack>
        <Stack gap={{4}} style={{{{ width: 180 }}}}>
          <Text size="small" tone="secondary">
            Type
          </Text>
          <Select
            value={{kind}}
            onChange={{(v) => setKind(v as Kind)}}
            options={{KIND_OPTIONS}}
          />
        </Stack>
        <Stack gap={{4}} style={{{{ width: 240 }}}}>
          <Text size="small" tone="secondary">
            Expansion
          </Text>
          <Select
            value={{exp}}
            onChange={{(v) => setExp(v as Expansion)}}
            options={{EXP_OPTIONS}}
          />
        </Stack>
        <Pill tone="neutral">{{filtered.length}} shown</Pill>
      </Row>

      <Table
        headers={{["Name", "Type", "Expansion", "Map", "X", "Y", "Source"]}}
        rows={{filtered.map((e) => [
          e.name,
          e.kind,
          e.expansion,
          e.mapId == null ? "—" : String(e.mapId),
          e.x.toFixed(2),
          e.y.toFixed(2),
          e.source,
        ])}}
      />

      <Spacer />
      <Text size="small" tone="secondary">
        Source: tools/build_instance_entrances.py · regenerates Data/InstanceEntrances.lua
      </Text>
    </Stack>
  );
}}
"""
    OUT.write_text(canvas, encoding="utf-8")
    print(f"Wrote {OUT} ({len(data)} entries)")


if __name__ == "__main__":
    main()
