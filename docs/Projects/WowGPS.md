# WowGPS

| Field | Value |
|-------|--------|
| Status | **Shipped** |
| Version | **1.0.1** |
| Type | In-game GPS / step-by-step travel |
| Folder | `wowgps/` |
| Author tools | `Tools/wowgps/` — destination/entrance builders, HandyNotes reference dumps |
| Clients | Retail (`120105`, `120100`) + MoP/Cata/Wrath/TBC/Era Interface IDs in toc |
| SavedVariables | `WowGPSDB` |
| Optional | **Zygor Guides Viewer** (pathfinding) · TomTom |
| License | GPL-3.0 (HereBeDragons / Ace stack) |

## Description

In-game GPS: search destinations, build a **smart route** (flight, portal, dungeon entrance, local hops), and show step-by-step directions with map pins. Intended to work with **Zygor pathfinding enabled**. TomTom is a fallback arrow.

0.4.x grew the window and Route “Use item” layout; **1.0.0** is the first stable updater offer. **1.0.1** adds Retail Interface `120105` for patch 12.1.5.

## Features

- Search, Route, Saved, Add-location tabs.
- Travel regions, map coords, route validator.
- Midnight-local and Maw-local route special cases.
- Travel actions + sub-step resolver + route tracker.
- Zygor travel integration, TomTom, map pins, fallback arrow.
- Custom personal locations; import/export.
- Seed destinations + AreaTable + instance entrances JSON.

## Development plan

1. Ace/HereBeDragons shell and player context.
2. Destination database (seed Lua + AreaTable + instance entrances).
3. Step builder and validators (don’t send players through invalid hops).
4. Zygor as the real pathfinder; TomTom/arrow as backup.
5. Flavor-specific local routes (Midnight, Maw).
6. Tools extracted from `wowgps/tools/` in the repo cleanup.

## Sources and data

| Path | Role |
|------|------|
| `Data/AreaTable.lua` | Zone names / hierarchy |
| `Data/InstanceEntrances.json` | Instance door coords |
| `Data/Destinations_seed.lua` | Curated destinations |
| Zygor | Pathfinding at runtime (not copied guide text) |
| HandyNotes dumps | **Tools only** — reference, not shipped as HandyNotes’ database |

## What worked

- Requiring Zygor for serious pathfinding instead of rewriting a traveler graph.
- Keeping HandyNotes/Zygor dumps in Tools so the zip is not a copy of those addons.

## What did not work

- GPS without Zygor: fallback arrow is weaker; notes in toc say Zygor pathfinding should be on.
- Generators inside the addon folder — moved to `Tools/wowgps/`.

## Open work

- Destination coverage is seed + playtest, not a full Wowhead dump (and should not become one).
- Classic path quality depends on Zygor Classic being installed.
