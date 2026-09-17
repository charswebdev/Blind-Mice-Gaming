# BMG Unit Frames

| Field | Value |
|-------|--------|
| Status | **Shipped** |
| Version | **0.7.1** (toc, load banner, `updater/catalog.json`) |
| Type | In-game unit frames (high-contrast, movable, accessible) |
| Folder | `BMG-Unit-frames/` |
| Clients | Retail Midnight (`120100`), MoP, Cata, Titan, Wrath, Anniversary/TBC, Classic Era (`11509` / `11508`) |
| SavedVariables | `BMGUnitFramesDB` |
| Install | BMG Updater folder `BMG-Unit-frames` |
| Slash | `/bmguf` settings · `/uf` · `/bmguf snap` · `/bmguf read` |
| Key bindings | Key Bindings → **BMG Unit Frames** (open settings, lock/unlock, read target) |
| Optional deps | AccessibilityHelper (TTS if present) |

## Description

High-contrast player, pet, target, focus, target-of-target, party, raid, and arena frames. Players move and resize them, pick classic Blizzard or modern class colors, and export a layout code. Built for blind and visually impaired players: dark backgrounds, bright text, slash and keybinds, speech when Accessibility Helper is present. Focus and arena are capability-gated on Classic Era.

The settings window is a two-pane unit list with General / Auras / Indicators / More tabs. It is **not** a copy of Shadowed Unit Frames or Unhalted UF; those were researched so we could adapt width, height, growth, portraits, auras, and indicators to this UI.

## Features

- Movable, resizable frames; lock from settings or a keybind.
- Snap to existing Blizzard / Edit Mode positions (`/bmguf snap`).
- Party includes the player’s own bar.
- Growth for party / raid / arena: up, down, left, right.
- Health and power text: both, percent, current, or none. Primary power plus class secondary power (combo, holy, shards, and so on).
- Portrait on or off; class icon or 3D portrait.
- Per-unit auras (buffs/debuffs, filters, position, growth, timers).
- Indicators: combat, rest, leader, raid target, PvP, role, rez, ready, elite, happiness, phased, out of range, quest.
- Incoming heals, absorb, heal absorb (no-op where the client has no API), mouseover/aggro highlight, range fade.
- Movable, resizable cast bar (below / above / inside / free).
- Layout export/import codes (`!BMGUF:1!…`).
- AddOns category **Blind Mice Gaming** (`Category` + `Category-enUS`). Addon compartment opens settings.

## Development plan

| Slice | Focus |
|-------|--------|
| 0.1–0.3 | Secure frames, hide Blizzard, snap, party-you, settings chrome |
| 0.4 | Footer, growth, dropdowns |
| 0.5–0.6 | HP/power text modes, auras, indicators, extras |
| 0.7.0 | Phase / out of range / quest; SUF-like tabbed settings |
| **0.7.1** | BMG AddOns category; settings keybind like Accessibility Helper; first updater catalog row |

## Sources and data

- Blizzard unit, aura, power, portrait, and (where present) absorb/phase APIs.
- `RAID_CLASS_COLORS` plus a modern palette (Era shaman stays pink on classic).
- No copied SUF/UUF layouts or databases.

## What worked

- Secure unit buttons + `RegisterUnitWatch`; combat lockdown guards.
- Capability gates for focus, arena, absorbs, and phase so Era does not error.
- Bindings.xml at addon root, **not** listed in the toc (same as Accessibility Helper and AllQuest).
- Keeping the folder at **repo root** so the updater copy path is `source/BMG-Unit-frames/`.

## What did not work

- Party `[group:party]` state driver on Era — use `InPartyGroup` + UnitWatch.
- Cycle buttons for options — players could not see the full list; dropdowns replaced them.
- Putting addons under `AddOns/` in the repo — updater would miss the folder.

## Open work

- Playtest Classic Era party/raid growth and snap after more group content.
- Absorb / heal-absorb bars stay empty on Era until those APIs exist.
