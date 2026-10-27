# WowGPS

| Field | Value |
|-------|--------|
| Status | **Shipped** |
| Version | **1.0.4** |
| Type | In-game GPS / step-by-step travel |
| Folder | `wowgps/` |
| Author tools | `Tools/wowgps/` — destination/entrance builders, HandyNotes reference dumps |
| Clients | Retail (`120105`, `120100`) + MoP/Cata/Wrath/TBC/Era Interface IDs in toc |
| SavedVariables | `WowGPSDB` |
| Optional | **Zygor Guides Viewer** (pathfinding) · TomTom |
| License | GPL-3.0 (HereBeDragons / Ace stack) |

## Description

In-game GPS: search destinations, build a **smart route** (flight, portal, dungeon entrance, local hops), and show step-by-step directions with map pins. Intended to work with **Zygor pathfinding enabled**. TomTom is a fallback arrow.

0.4.x grew the window and Route “Use item” layout; **1.0.0** is the first stable updater offer. **1.0.1** adds Retail Interface `120105` for patch 12.1.5. **1.0.2** adds the Profiles tab for saved waypoints. **1.0.3** adds Labyrinth to the Search and Add type dropdowns. **1.0.4** fixes the import dialog so a missing `end` no longer stops the addon from loading.

## Features

- Search, Route, Saved, Profiles, and Add tabs.
- Travel regions, map coords, route validator.
- Midnight-local and Maw-local route special cases.
- Travel actions + sub-step resolver + route tracker.
- Zygor travel integration, TomTom, map pins, fallback arrow.
- Custom personal locations; import/export.
- Profiles tab: create, rename, load, delete, export, and import. Each profile stores every account-wide and character waypoint. Create starts empty. Export and import use `WGPSPROFILE` text. Existing saved places stay in a profile named Default.
- Search and Add type dropdowns include **Labyrinth**. Tag a saved place with it, then filter Search by Labyrinth.
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
- Keeping saved waypoints inside the active location profile, and moving older account/character stores into Default once, so a new profile does not wipe places that were already saved.
- Keeping HandyNotes/Zygor dumps in Tools so the zip is not a copy of those addons.

## What did not work

- The import dialog was missing the `end` lines that close the saved-list refresh, so the file failed to load and the warning repeated. Those closes are restored: a good paste still refreshes Saved, and a bad paste says whether it looked like a profile.
- GPS without Zygor: fallback arrow is weaker; notes in toc say Zygor pathfinding should be on.
- Generators inside the addon folder — moved to `Tools/wowgps/`.

## Open work

- Destination coverage is seed + playtest, not a full Wowhead dump (and should not become one).
- Playtest a location profile: create one, save places into it, export, import on another character, and confirm Default still has the old places.
- Classic path quality depends on Zygor Classic being installed.
