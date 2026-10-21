# Light Paws Loadouts - Classic Era

| Field | Value |
|-------|--------|
| Status | **Shipped** (in-game phases 0–5) |
| Version | **1.0.1** |
| Type | In-game composite loadout vault (Classic Era + Hardcore) |
| Folder | `lpl-classic-era/` |
| Clients | `_classic_era_` Interface `11508`, `11509` |
| SavedVariables | `LPLClassicEraDB` (must not clobber Retail `LPLDB`) |
| Slash | `/lpl` |
| Talent model | **3 trees**, shared **51** points, tier×5 gates, prereqs |
| Brief | `docs/classic-lpl-shared-brief.md` |

## Description

Classic Era sibling of Retail LPL. Same vault *idea* (loadouts, bars, keybinds, gear, macros, conditions, addon sets, addons manager, Edit Mode) with an **Era talent engine** and no Retail-only tabs.

**Hardcore** uses this same package (locked). Season of Discovery does **not** — SoD is a later product.

## Features

- Era talent catalog + tree view + capture/apply + BN share (`EraTalentShare`, `ShareCodec`).
- Action bars: Era slot map, **no skyriding**, Bars 6–8, Edit Mode on (`C_EditMode` exists on Era; `hasEditMode = true`).
- Gear, keybinds, macros, conditions, composite loadouts.
- **Dropped vs Retail:** Cooldown Manager, Retail PvP tab, hero talents / `C_Traits`, skyriding.
- FlavorCompat + EraStubs so missing Retail APIs do not error.
- **1.0.1 Profiles:** same Profiles tab as Retail. It stores talents, bars, keybinds, gear, Edit Mode, loadouts, conditions, macros, addon sets, and addon profiles. PvP and Cooldown Manager data keys are included when they exist, even though those tabs are hidden. There is no housing section. The import code is `!LPLP1!` and only loads into Classic Era. SavedVariables stay `LPLClassicEraDB`. Window position and the login-restore mirror stay out of the profile. Existing saves move into Default once. The rail keeps every icon on screen, including Profiles. If the window is short, the icons shrink instead of hiding the last tab. Icon file: `icons/profiles_64.tga`.

## Development plan (locked sequence)

User reorder 2026-08-21; all in-game phases done:

| Phase | Focus | Status |
|-------|--------|--------|
| 0 | Product locks (names, clients, packaging, BMG Updater ship path) | Done |
| 1 | Compatibility shell (Era-only tabs) | Done |
| 2 | Talent Engine A — 3 trees / 51 pts, Wago data, capture/apply, BN | Done |
| 3 | Action bars — Era slots, no skyriding, Bars 6–8, Edit Mode | Done (identity smoke optional) |
| 4 | Portable vault polish — macros, keybinds, gear, conditions | Done |
| 5 | Composite loadouts + first ship via updater | Done (1.0.0) |

Desktop LPTM Era is a **sibling** (shipped 1.0.0). Desktop LPLM Era is the **next** Classic desktop slice.

## Sources and data

- Wago / TalentTab-style Era catalog → `Modules/Talents/EraTalentCatalog.lua` (generated from `Tools/lpl-classic-era/Data/` CSVs, not authored inside the addon as Python).
- Blizzard Era talent APIs (`LearnTalent`, etc.) via `TalentAPI.lua`.
- Share type is Era-specific, not Retail `dftalents`.

**Locked talent truth:** Druid has **three** trees (Balance, Feral Combat, Restoration). Guardian is not a fourth tree. Feral tab icon stem `ability_racial_bearform`.

## What worked

- Separate SavedVariables and folder so Retail and Era can both be installed.
- Feature-detect Edit Mode instead of assuming it is Midnight-only.
- Phased “engine then bars then vault then composite” so BN shares did not ship on a broken talent apply.

## What did not work

- Porting Retail `C_Traits` / hero trees — there is no such system on Era.
- Inventing a 4th Druid tree (user asked; data says 3).
- Nesting this addon under `AddOns/` in the repo — updater copies `source/<folder>/` from **repo root**.
- Putting talent CSV generators in the addon tree — moved to Tools.

## Open work

- Optional identity smoke tests / bugfixes only if assigned.
- Uncommitted TalentAPI / TalentStore / TalentTreeView / FlavorCompat dirty files may exist — do not mix into AllQuest or AH commits.
- Era LPLM desktop not built yet (see that project file).
