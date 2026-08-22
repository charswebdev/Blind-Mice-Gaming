# Classic LPL — shared brief for flavor agents

Supervisor: parent agent in the main chat. Flavor agents (Era / TBC / MoP) receive this brief and report only to the supervisor. They do not ask the user directly.

## Product family (locked context)

- **Retail in-game addon:** Light Paws Loadouts (`lpl/`), version ~1.1.1, Interface 12.x Midnight. Composite loadouts, BN share strings, segments: talents, bars, keybinds, gear, PvP, CDM, Edit Mode, conditions, macros, addon sets, addons manager.
- **Retail desktop talent planner:** Light Paws Talent Manager (`talent-manager/`) — shipped, no more work.
- **Retail desktop loadout catalog:** Light Paws Loadout Manager (`loadout-manager/`) — shipped, no more work.
- **This project:** Classic **in-game** LPL addons for Era, TBC Anniversary, MoP — not the Classic desktop talent managers (separate later).

## Classic clients in scope

| Flavor | Clients | AddOns folder | Talent system |
|--------|---------|---------------|---------------|
| Era | Classic Era + Hardcore | `_classic_era_` | 3 trees, 51 points |
| TBC | Anniversary (Burning Crusade) | `_anniversary_` | 3 trees, 61 points |
| MoP | MoP Classic | `_classic_` | Spec + tier rows + glyphs |

Out of v1 unless locked later: Season of Discovery, Wrath/Cata.

## Architecture rules

- Keep LPL vault UX and BN shares; rewrite talent engines per flavor.
- Drop: Cooldown Manager, Retail PvP tab, hero talents / C_Traits, skyriding.
- Gate Edit Mode only if API round-trips on that client.
  - **Classic Era:** Edit Mode / HUD Edit **exists** (`C_EditMode`). Enabled in Era LPL (`hasEditMode = true`).
- Feature-detect; do not assume Midnight UI means Midnight talents.
- Separate packages / SavedVariables so flavors do not clobber each other.
- Ship Era to BMG Updater before starting TBC; MoP after TBC is honest.

## Plan canvas

`classic-lpl-addon-plan.canvas.tsx` — full investigation and phased todos.

## Phase 0 locks (fill as supervisor records answers)

- Package display names (**LOCKED** — Decision 1 = B):
  - **In-game LPL**
    - Era: **Light Paws Loadouts - Classic Era**
    - MoP (name only; client map next): **Light Paws Classic**
    - TBC Anniversary: **Light Paws - Anniversary**
  - **Desktop LPTM**
    - **Light Paws Talent Manager - Classic Era**
    - **Light Paws Talent Manager - Anniversary**
    - **Light Paws Talent Manager - Classic**
- Client ↔ name map (**LOCKED** — Decision 2 = A):
  - **Classic Era** titles → Classic Era client (`_classic_era_`); Hardcore policy still open
  - **Anniversary** titles → TBC Anniversary (`_anniversary_`)
  - **Classic** titles → MoP Classic (`_classic_`)
- Hardcore / SoD policy (**LOCKED** — Decision 3 = B):
  - **Hardcore** uses the **Classic Era** LPL + LPTM products (same packages).
  - **Season of Discovery** is **in this program** as its own later package(s) (runes) — not deferred forever; scheduled after Era is stable. Exact SoD display names still open.
- Ship path (**LOCKED** — Decision 4 = A, reinforced Decision 5):
  - **All Light Paws addons** (Retail LPL + Classic LPL flavors + future SoD) update via **BMG Updater only**.
  - **All desktop apps** (Retail LPTM/LPLM + Classic Era/Anniversary/Classic LPTM) **self-update on launch** from their own `catalog.json` / GitHub release (same model as current LPTM/LPLM).
- Packaging (**LOCKED** — Decision 5 = A): **Separate package per product** — own folder, own SavedVariables or AppData, own updater/catalog zip. No mega multi-client zip for v1.
- Repo / folder names (**LOCKED** — Decision 6 = A):
  - Addons: `lpl-classic-era/` · `lpl-anniversary/` · `lpl-classic/`
  - Desktop: `talent-manager-classic-era/` · `talent-manager-anniversary/` · `talent-manager-classic/`
  - SoD folders later when that phase opens
- Build order hint: Era (addon + desktop) → Anniversary → Classic(MoP) → SoD

## Phase 0 status: COMPLETE

All Phase 0 decisions locked.

## Era addon phase order (**LOCKED** — user reorder 2026-08-21)

Phases 0–4 are done. Remaining Era **in-game** work order:

| Phase | Focus | Status |
|-------|--------|--------|
| 0 | Product locks | Done |
| 1 | Compatibility shell (Era-only tabs) | Done |
| **2** | **Talent Engine A (Era)** — 3 trees / 51 pts, Wago data, capture/apply, BN | **Done** |
| **3** | **Action Bars** — Era slot map, no skyriding, Bars 6–8, Edit Mode | **Done** (identity smoke optional) |
| **4** | **Portable vault polish** — macros, keybinds, gear, conditions (Classic prune + round-trip) | **Done** |
| **5** | Composite loadouts + first Era ship (BMG Updater) | **Done** (Era 1.0.0 shipped) |
| — | Desktop LPTM Classic Era | After addon Era is honest |
| — | Anniversary / MoP / SoD | After Era |

## Active build (supervisor + user)

Work continues **in the main chat only**: supervisor + user, one slice at a time.

- `lpl-classic-era/` — Phases 0–4 done; **Phase 5** composite loadouts + BMG Updater ship
- `talent-manager-classic-era/` — not created yet (after addon)

Anniversary / Classic(MoP) / SoD: idle until Era is honest.

## Agents under this supervisor (six products)

| Agent | Product title | Type | Client | Repo folder |
|-------|---------------|------|--------|-------------|
| Era LPL | Light Paws Loadouts - Classic Era | In-game addon | Classic Era (`_classic_era_`) | `lpl-classic-era/` |
| Anniversary LPL | Light Paws - Anniversary | In-game addon | TBC Anniversary (`_anniversary_`) | `lpl-anniversary/` |
| Classic LPL | Light Paws Classic | In-game addon | MoP Classic (`_classic_`) | `lpl-classic/` |
| Era LPTM | Light Paws Talent Manager - Classic Era | Desktop planner | Classic Era | `talent-manager-classic-era/` |
| Anniversary LPTM | Light Paws Talent Manager - Anniversary | Desktop planner | TBC Anniversary | `talent-manager-anniversary/` |
| Classic LPTM | Light Paws Talent Manager - Classic | Desktop planner | MoP Classic | `talent-manager-classic/` |
| SoD (later) | Names TBD | Addon and/or desktop | Season of Discovery | TBD |

Agents receive this brief, work only when assigned, report only to the supervisor. User questions stay in the main chat, one at a time.

## Agent behavior

1. Read this brief before any Classic LPL or Classic LPTM work.
2. Report findings and file changes to the supervisor only.
3. Do not invent locks; if blocked on a product decision, stop and tell the supervisor.
4. Prefer small slices matching the plan phases.
