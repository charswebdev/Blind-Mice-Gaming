# BMG Unit Frames

| Field | Value |
|-------|--------|
| Status | **Shipped** (four flavor packages) |
| Version | **1.0.0** (each toc + `updater/catalog.json`) |
| Type | In-game unit frames (high-contrast, movable, accessible) |
| Optional deps | AccessibilityHelper (TTS if present) |

Separate package per WoW flavor — own folder, own SavedVariables, own updater row. Same rule as Light Paws. Season of Discovery is not a flavor folder yet.

| Flavor | Client | Folder | SavedVariables | Interface |
|--------|--------|--------|----------------|-----------|
| Retail (Midnight) | `_retail_` | `BMG-Unit-frames/` | `BMGUnitFramesDB` | `120100`, `120007`, `120005`, `120001` |
| Classic Era + Hardcore | `_classic_era_` | `BMG-Unit-frames-classic-era/` | `BMGUnitFramesClassicEraDB` | `11509`, `11508` |
| Anniversary (TBC) | `_anniversary_` | `BMG-Unit-frames-anniversary/` | `BMGUnitFramesAnniversaryDB` | `20506`, `20505` |
| Classic (MoP) | `_classic_` | `BMG-Unit-frames-classic/` | `BMGUnitFramesClassicDB` | `50504`, `50503` |

Interface numbers match the current live patch plus the previous one so a weekly bump does not unload the addon.

Slash `/bmguf` · `/uf` · Key Bindings → **BMG Unit Frames** (open settings, lock/unlock, read target).

## Description

High-contrast player, pet, target, focus, target-of-target, party, raid, and arena frames. Players move and resize them, pick classic Blizzard or modern class colors, and export a layout code. Built for blind and visually impaired players.

Focus and arena are capability-gated: off on Classic Era, on for Anniversary, MoP, and Retail. First load snaps to Blizzard / Edit Mode positions. Midnight hides raw health numbers; the Retail package then shows percent only.

## Features

- Movable, resizable frames; lock from settings or a keybind.
- Snap to existing Blizzard / Edit Mode positions (`/bmguf snap`).
- Party includes the player’s own bar.
- Growth for party / raid / arena: up, down, left, right.
- Settings General tab groups options under the selected unit (Player Frame, Party Frame, and so on), then Name Bar, Health Bar, Power Bar, and Second Power Bar. Name bar background: Dark (default), Transparent, Black, Class color, Gold, or Health green. Bar style: Blizzard Classic (default), Blizzard Modern, or Blocky (flat solid fill with a hard edge).
- Name bar includes unit level. Each bar (name, health, power, second power) has its own width and alignment. Name, level, health number, health percent, power number, and power percent each have a position.
- Per-unit auras and indicators (including tank/healer/DPS, main tank or assist, rare, rare elite, elite, phased, out of range, quest). Each indicator has on/off, position, size, and a preview of the icon used on the frame.
- Movable, resizable cast bar. Layout export/import codes.
- AddOns category **Blind Mice Gaming**.

## Development plan

| Slice | Focus |
|-------|--------|
| 0.1–0.7.1 | Classic Era build, settings, keybind, first catalog row |
| 0.7.2 | Retail APIs in the shared tree |
| **0.7.3** | Split into four flavor folders; current-patch Interface lists |
| **0.7.7** | UUF-style fill layout: window is the health box; power is a bottom strip; no reserved name row |
| **0.7.8** | Click a stepper number and type the value (width, height, scale, bars, auras, cast) |
| **0.7.9** | Name bar: placement, height, background color, text color |
| **0.8.0** | Level on the name bar; per-bar widths; independent text positions |
| **0.8.1** | Rare indicator; per-indicator position and size |
| **0.8.2** | Rare elite as its own indicator; synced on all four flavor packages |
| **0.8.3** | Indicator settings show the same icon used on the unit frame |
| **0.8.4** | Name text positions across the name bar; name bar width is a typed number |
| **0.8.5** | Name bar width sits directly under name bar height |
| **0.8.6** | General settings grouped by bar: unit frame first, then Name / Health / Power / Second power |
| **0.8.7** | Name bar background can be Transparent; Dark stays the default |
| **0.8.8** | Bar style: Blizzard Classic, Blizzard Modern, or Blocky (Plater-style flat fill) |
| **0.8.9** | Group role indicator: Tank, Healer, or DPS |
| **0.9.0** | Role icons use one Blizzard sheet: shield = tank, cross = healer, swords = DPS |
| **1.0.0** | First public release: four flavor packages, bar styles, grouped settings, group roles |

## Sources and data

- Blizzard unit, aura, power, portrait, and (where present) absorb/phase/Edit Mode APIs.
- `RAID_CLASS_COLORS` plus a modern palette (Era shaman stays pink on classic).
- No copied SUF/UUF layouts or databases.

## What worked

- One folder per client so the updater copies `source/<folder>/` into the matching AddOns tree.
- Flavor.lua for title, folder, product id, and SavedVariables name.
- Capability gates so Era does not error on focus/arena.
- UUF-style fill: frame height is the window; health takes leftover after power. Stacking a name row above thin bars left empty black and looked squished.

## What did not work

- One multi-interface zip for every client — user asked for separate folders, same as Light Paws.
- Nesting addons under `AddOns/` in the repo.

## Open work

- Playtest fill layout after `/reload` (Retail + Era first). Existing saved frames keep their height; health now fills that window.
- Season of Discovery package later (names still open).
