# BMG Unit Frames

| Field | Value |
|-------|--------|
| Status | **Shipped** (five flavor packages) |
| Version | **1.1.3** Forever; **1.1.1** Retail / Era / Anniversary / Classic |
| Type | In-game unit frames (high-contrast, movable, accessible) |
| Optional deps | AccessibilityHelper (TTS if present) |

Separate package per WoW flavor — own folder, own SavedVariables, own updater row. Same rule as Light Paws. Season of Discovery is not a flavor folder yet.

| Flavor | Client | Folder | SavedVariables | Interface |
|--------|--------|--------|----------------|-----------|
| Retail (Midnight) | `_retail_` | `BMG-Unit-frames/` | `BMGUnitFramesDB` | `120100`, `120007`, `120005`, `120001` |
| Classic Era + Hardcore | `_classic_era_` | `BMG-Unit-frames-classic-era/` | `BMGUnitFramesClassicEraDB` | `11509`, `11508` |
| Anniversary (TBC) | `_anniversary_` | `BMG-Unit-frames-anniversary/` | `BMGUnitFramesAnniversaryDB` | `20506`, `20505` |
| Classic (MoP) | `_classic_` | `BMG-Unit-frames-classic/` | `BMGUnitFramesClassicDB` | `50504`, `50503` |
| WoW Forever | `_classic_beta_` (live ForeverBeta) | `BMG-Unit-frames-forever/` | `BMGUnitFramesForeverDB` | `16001`, `121500`, `121000` |

Interface numbers match the current live patch plus the previous one so a weekly bump does not unload the addon.

Slash `/bmguf` · `/uf` · Key Bindings → **BMG Unit Frames** (open settings, lock/unlock, read target).

## Description

High-contrast player, pet, target, focus, target-of-target, party, raid, and arena frames. Players move and resize them, pick classic Blizzard or modern class colors, and export a layout code. Built for blind and visually impaired players.

Focus and arena are capability-gated: off on Classic Era, on for Anniversary, MoP, Retail, and Forever. First load snaps to Blizzard / Edit Mode positions. Midnight and Forever hide raw health numbers; those packages then show percent only.

## Features

- Movable, resizable frames; lock from settings or a keybind.
- Snap to existing Blizzard / Edit Mode positions (`/bmguf snap`).
- Party includes the player’s own bar.
- Growth for party / raid / arena: up, down, left, right.
- Settings General tab groups options under the selected unit (Player Frame, Party Frame, and so on), then Name Bar, Health Bar, Power Bar, and Second Power Bar. Each unit keeps its own size, bars, portrait, and portrait side. Name bar background: Dark (default), Transparent, Black, Class color, Gold, or Health green. Bar style: Blizzard Classic (default), Blizzard Modern, or Blocky (flat solid fill with a hard edge).
- Portrait: 3D / 2D / class icon / hidden, plus **Left or Right** per unit (target / tot / focus / arena default to the right).
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
| **1.1.0** | WoW Forever package (own folder and SavedVariables) |
| **1.1.1** | Forever TOC `16001` for the live `_classic_beta_` ForeverBeta client. Retail / Era / Anniversary / Classic: durable `activeProfile`, per-unit portrait, left/right portrait. |
| **1.1.2** | Forever gets the same save + per-unit + portrait-side fixes. |
| **1.1.3** | Forever unit frames set width and height on separate axes so Width/Height steppers match the drawn frame. |

## Sources and data

- Blizzard unit, aura, power, portrait, and (where present) absorb/phase/Edit Mode APIs.
- `RAID_CLASS_COLORS` plus a modern palette (Era shaman stays pink on classic).
- No copied SUF/UUF layouts or databases.

## What worked

- `root.activeProfile` so the current named profile survives a CharacterKey that changes between ADDON_LOADED and login (secret names / "player - Realm").
- Seeding each unit with its own `portrait` and `portraitSide` so Player changes no longer fall back to one profile-wide portrait.
- Committing stepper edit boxes before switching units, so Target does not inherit the number still typed for Player.
- One folder per client so the updater copies `source/<folder>/` into the matching AddOns tree.
- Flavor.lua for title, folder, product id, and SavedVariables name.
- Capability gates so Era does not error on focus/arena.
- UUF-style fill: frame height is the window; health takes leftover after power. Stacking a name row above thin bars left empty black and looked squished.

## What did not work

- Relying only on `profileKeys[CharacterKey()]`. On Forever / Midnight the player name can be unusable at load, so a Save named profile looked gone after `/reload`.
- Sharing `profile.portrait` across units. Changing Player looked like every frame changed, or Target forgot its setting.
- Switching the unit list while a width/height box still had focus — the commit wrote Player's number onto Target.
- One multi-interface zip for every client — user asked for separate folders, same as Light Paws.
- Nesting addons under `AddOns/` in the repo.

## Open work

- Playtest fill layout after `/reload` (Retail + Era first). Existing saved frames keep their height; health now fills that window.
- Live Forever folder is `_classic_beta_` (`wow_classic_beta` / ForeverBeta). Watch for a rename to `_forever_`, `_wow_forever_`, or `_camelot_`.
- Season of Discovery package later (names still open).
