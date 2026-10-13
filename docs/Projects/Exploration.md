# Exploration

| Field | Value |
|-------|--------|
| Status | **Shipped** |
| Version | **2.0.3** |
| Type | In-game outdoor exploration / lorewalking-style route guide |
| Folder | `Exploration/` |
| Author tools | `Tools/Exploration/` — route audits, AreaTable caches, reorder scripts |
| Clients | **Retail** (`120105`, `120100`) only in the current toc |
| SavedVariables | `ExplorationDB` |
| Optional | TomTom |

## Description

An outdoor **zone exploration guide**: ordered routes, map/minimap overlays, waypoints, discovery TTS, housing and taxi hooks. Aimed at completing exploration (and related lorewalking-style steps), not at replacing AllQuest’s quest journal.

Generated route Lua **ships** in `Data/Routes/Generated.lua`. Python that builds or audits it lives under Tools, not in the addon zip.

## Features

- Segmented routes with progress, learned-route state, and conditions.
- World map and minimap overlays; TomTom waypoints.
- Discovery announcements, taxi, housing helpers.
- Import/mark UX; compass-style branding.
- 2.0.2: Lorewalking Warband Bank and Li Li talk steps (per git bump message).
- 2.0.3: Retail Interface `120105` for patch 12.1.5. `120100` stays so 12.1.0 still loads.

## Development plan

- Author routes + ATT exploration-by-map data, then generate `Data/Routes/Generated.lua`.
- Manual coord overrides in `Data/Coords/Manual.lua` plus DB2 coords.
- Tools folder holds regression notes and AreaTable caches so the addon tree stays Lua-only.

## Sources and data

| Path | Role |
|------|------|
| `Data/ATT/ExplorationATTByMap.lua` | All The Things exploration IDs by map (ID census / coverage, not a copied ATT UI) |
| `Data/DB2/Coords.lua` | Blizzard-derived coordinates |
| `Data/Coords/Manual.lua` | Hand fixes |
| `Data/Routes/Generated.lua` | Shipped route graph |
| `Data/SubzoneFilter.lua` | Subzone include/exclude |

Do not paste ATT’s full database or Wowhead scrape dumps into the addon.

## What worked

- Splitting generated Lua (ships) from Python audits (Tools).
- Overlay + TTS so VI players can walk a zone without a visual checklist addon.

## What did not work

- Keeping generators inside `Exploration/tools/` — moved out in the 2026-08-23 repo cleanup so the updater zip stays clean.
- Retail-only toc: Classic exploration is **out of scope** until someone assigns a Classic pack.

## Open work

- Route correctness is playtest + Tools audits (`REGRESSION.md` lived in Tools after the move).
- Other flavors not started.
