# Light Paws Loadouts (Retail)

| Field | Value |
|-------|--------|
| Status | **Shipped** |
| Version | **1.1.4** |
| Type | In-game composite loadout vault |
| Folder | `lpl/` |
| Clients | Retail Midnight (`120100`, `120007`, `120001`) |
| SavedVariables | `LPLDB` |
| Slash | `/lpl` |
| Optional | LibTalentTree-1.0 (bundled) |

## Description

Retail **Light Paws Loadouts** is the in-game vault: plan, save, share (Battle.net-style strings), and apply **composite loadouts** — talents, action bars, keybinds, gear, PvP talents, Cooldown Manager, Edit Mode, conditions, macros, addon sets, and an addons-manager (import strings for WeakAuras, ElvUI, Plater, etc.).

This is the pattern every Classic flavor is supposed to **clone for UX** while replacing the talent engine.

## Features (modules)

- **Talents** — Midnight class / spec / hero trees, sandbox, share, activate (`C_Traits` / loadout strings).
- **Action bars** — slot codec, cursor, editor, bars including modern extra bars / skyriding where Retail has them.
- **Keybinds** — capture/apply/share.
- **Equipment** — sets, cursor, restrictions.
- **PvP talents** — Retail PvP tab.
- **Cooldown Manager** — Retail CDM layouts.
- **Edit Mode** — HUD layouts.
- **Loadouts** — composite bundles of the above.
- **Conditions** — when a loadout should prompt/apply.
- **Macros** — sets + icon picker.
- **Addon sets** — enable/disable lists.
- **Addons manager** — detect/import third-party profile strings (WeakAuras `!WA:`, ElvUI, Plater, Cell, TMW, Grid2, MDT `!` blobs, etc.).
- Vault import chooser, list grouping/filtering, tooltip accessibility, activate feedback.
- 1.1.3: cursor / action-bar macro fixes (shipped with AH 3.6.16 bump).
- **1.1.4 Housing Blueprints** — vault tab like Macro Manager / Addons Manager: name, notes, Blizzard code. Retail only. Icon `housing_64.png`. Generic Import auto-detects live `Ag…` codes; chooser stays Macro vs Addon Profile. **Copy for House** copies the code and speaks/prints plot import steps. Window min height fits every sidebar tab. LPL does not place the house. Plan: [`docs/reports/lpl-housing-blueprints-plan.md`](../reports/lpl-housing-blueprints-plan.md).

## Development plan

Retail LPL matured as the **reference vault**. Later Classic work (phases 0–5 on Era) was “keep vault UX, rewrite talent engines, drop CDM / Retail PvP / hero / skyriding.”

Desktop siblings: **LPTM** (talent planner) and **LPLM** (loadout catalog + community).

**Housing Blueprints:** Phases 0–3 shipped in **1.1.4**. Phase 1 (`.tga`/`.blp`) only if the PNG looks soft in-game. Not a loadout activate segment.

## Sources and data

- Blizzard talent/loadout/edit-mode/CDM APIs.
- Bundled LibTalentTree-1.0.
- No Classic talent CSV in this tree (Era CSVs live under `Tools/lpl-classic-era/`).
- **Housing codes:** detect locked from public samples on [WoWDB Housing](https://housing.wowdb.com/) (Has Blueprint Code) and official forums (24-char `Ag…` tokens). Also Wago type `HOUSING-BLUEPRINTS`, WoWkea Discord Blueprints Depot. In-game Copy to Clipboard is the format source of truth. See [`docs/Resources.md`](../Resources.md).

## What worked

- Segment architecture (`ModuleRegistry`) so flavors can stub or drop tabs.
- Share strings per segment plus composite loadouts.
- Addons manager as “paste detector,” not a pirate copy of those addons’ UIs.
- Housing should follow the same paste-detector pattern: we store the Blizzard code, we do not rebuild the house.

## What did not work

- Assuming Midnight APIs exist on Classic — Era uses `FlavorCompat` / `EraStubs` instead.
- Mixing Era talent rules into this folder — **separate package** is locked.
- `RequiredFrameHeight` above `local function CollectTabs` — Lua treated `CollectTabs` as a missing global (`Sidebar.lua:18`). Helper now sits after `CollectTabs`.

## Open work

- Uncommitted Module dirty files may exist locally (`ActionBars`, `Loadouts`, `Keybinds`, …). Do not mix into unrelated commits.
- Further Midnight patch talent layout changes track Blizzard, not a BMG DB2 extract.
- Convert Housing icon to `.tga`/`.blp` only if PNG looks soft. No bundled public-code catalog unless assigned. Not a composite loadout segment.
