# WowGPS - WoW Forever

| Field | Value |
|-------|--------|
| Status | **Shipped** |
| Version | **1.1.2** |
| Type | In-game GPS window |
| Folder | `wowgps-forever/` |
| Clients | `_classic_beta_` (ForeverBeta) |
| SavedVariables | `WowGPSForeverDB` |
| Slash | `/gps` |
| Install | BMG Updater folder `wowgps-forever` |

## Description

Search lists vanilla zones and cities by the names this client returns, plus flight masters and dungeon entrances from the client’s own map data, plus places you saved. `/gps` opens the window. Nothing opens on login. Saved places stay in `WowGPSForeverDB` after `/reload`. The window uses the same dark layout, gold title, and WowGPS icon as retail WowGPS. The icon file is a copy in `wowgps-forever/Media/`. Do not point Forever at Retail `wowgps\Media`. Do not install Retail `wowgps/` into `_classic_beta_`.

The catalog row is `wowgps-forever` **1.1.2**. The toc uses the same Forever interface list as the other Forever addons: `16002`, `16001`, `16000`, `121500`, `121000`. Saved data is `WowGPSForeverDB`, loaded with `LoadSavedVariablesFirst`. The keybind header is `WOWGPS`, the same pattern as Light Paws Loadouts.

## Features

- Title **WowGPS**, the WowGPS icon, and tabs **Search**, **Route**, **Saved**, and **Add**.
- Search shows **where you are**, then zones, the six cities, flight masters, and dungeon and raid entrances, plus places you saved. A row marked **Flight**, **Dungeon**, **Raid**, or **City** is that kind of pin. Typing `dungeon` or `dungeons` lists the dungeon doors. **Start Route** opens the Route tab and points the arrow. **Set Arrow** points the arrow and stays on Search.
- The arrow uses TomTom when that addon is installed. Otherwise WowGPS draws its own arrow, and it also sets the Blizzard map pin when this client allows it.
- Route lists the steps in order. On the same continent the first step is the nearest flight master on your map, then the destination. A boat, zeppelin, or the Deeprun Tram is added when the destination is across the water or between Stormwind and Ironforge. The gold row is the step the arrow is pointing at. **End route** clears the pin and the arrow.
- Saved lists account-wide places and places for this character. Each card has **Start**, **Arrow**, **Export**, and **Delete**. **Delete** removes that place.
- Add saves a name plus either where you are standing or a map ID and coordinates. Scope is account-wide or this character. **Import** pastes WowGPS strings (`WGPS:Name:map:x:y:tag:scope:note`) or `/way` lines, one place per line. On Saved, each place has **Start**, **Arrow**, **Export**, and **Delete** along the bottom of the card, in that order. **Export** copies that one place. **Export all** at the bottom of the tab copies every saved place. `/gps export` does the same as Export all. `/gps import` opens the import box. A zone name in a `/way` line uses this client’s map.
- The window position is kept in `WowGPSForeverDB` after `/reload`. The window stays closed until `/gps`.

## Development plan

Phase 1 is the window. Phase 2, in 1.0.3, is the character’s zone and coordinates. Phase 3, in 1.0.4, is one destination: a pin, an arrow, and personal places. 1.0.5 reads zone names and flight masters from the client. 1.0.6 adds dungeon and raid doors, because this client does not return them from the journal API. 1.0.7 matches a plural search such as `dungeons` to those rows. Phase 4, in 1.0.8, is the travel steps: flight master, boat, zeppelin, and the Deeprun Tram. 1.0.9 adds import of WowGPS strings and `/way` lines. 1.1.0 adds export of those same strings. 1.1.1 puts the single-place **Export** button on the saved card, before **Delete**, and leaves **Export all** at the bottom of the Saved tab. No Midnight routes, no Maw routes, and no Zygor requirement.

## Sources and data

The window layout and colors follow retail `wowgps/UI/`. The icon is `wowgps/Media/WowGPS.png`, copied into this folder. Position comes from `GetZoneText`, `GetSubZoneText`, and `C_Map`. `Data/Zones.lua` lists the vanilla UiMapIDs. `Core/World.lua` asks `C_Map.GetMapInfo` for the zone name and `C_TaxiMap.GetTaxiNodesForMap` for flight masters. A zone or city pin sits at the middle of that map. A flight pin uses the coordinates the client returns. `Data/Entrances.lua` is the dungeon and raid door list, because `C_EncounterJournal.GetDungeonEntrancesForMap` does not return those doors on this client. `Core/Travel.lua` is the boat, zeppelin, and tram list, plus the step order. Flight masters still come from `C_TaxiMap.GetTaxiNodesForMap`. MapUtils in the Forever AddOns folder was the reference for which map IDs and docks this client uses. Its license is All Rights Reserved, so its source is not copied into this addon. Personal places are stored in `WowGPSForeverDB`. Secret values are dropped before they are shown or saved. This version does not load Ace, HereBeDragons, or Zygor.

## What worked

1.0.2 loaded on Forever with no Lua error. Phase 2, the zone and coordinates, worked in game. 1.0.7 search for `dungeons` listed the dungeon doors.

## What did not work

1.0.0 built the window while the addon was still loading. 1.0.1 waits until `/gps` to build the window. On 2026-10-01 at 3:47 PM the client logged `Glue Fatal Error: 1016` after Battle.net connected and then disconnected. That happens on the account login screen, before addons load.

## Open work

No further features are planned. Retail Midnight routes, Maw routes, Zygor pathfinding, and editing a saved place were not part of this addon.

Still to check in game:

- From Kalimdor, start a route to an Eastern Kingdoms place. The Route tab should list a flight and a boat or zeppelin. The gold row should match the arrow.
- Import a `/way` line or a `WGPS:` string, `/reload`, and see it on Saved.
- Export one place and Export all, then import that string again.
