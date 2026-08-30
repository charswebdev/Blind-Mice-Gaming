# Blind Mice Gaming — project documents

Living product files for agents and humans. Versions and catalog URLs change; re-read `updater/catalog.json` and each product’s `.toc` or `catalog.json` when shipping.

**Locked:** any change to a project must update that project’s file in this folder in the same session (Cursor rule `update-project-docs`).

**Repo:** https://github.com/charswebdev/Blind-Mice-Gaming  
**Owner:** Charlotte Bryant (`charswebdev`)  
**Install path for players:** Blind Mice Gaming Updater (addons + first-run desktop apps). Desktop apps also self-update from their own `catalog.json`.  
**Author tools:** `Tools/<project>/` (gitignored except `Tools/README.md`). Addon trees must stay ship-only.

Related briefs: [`docs/AGENT_HANDOFF.md`](../AGENT_HANDOFF.md) (index + required reads), [`docs/classic-lpl-shared-brief.md`](../classic-lpl-shared-brief.md). Method review: [`docs/reports/BMG-design-data-evaluation.md`](../reports/BMG-design-data-evaluation.md). Trusted sites (**locked**): [`docs/Resources.md`](../Resources.md).

## How to use a project file

Each document uses the same sections: description, version, features, development plan, sources and data, what worked, what did not work, open work. Planned products use the locked 5×3 Light Paws matrix even when the folder is empty.

Commit, push, and GitHub releases happen **only when asked**.

## In-game addons

| Document | Status | Version (catalog / toc) |
|----------|--------|-------------------------|
| [Accessibility Helper](Accessibility-Helper.md) | Shipped | 3.6.4 |
| [AllQuest](AllQuest.md) | Shipped | 1.0.10 |
| [Cooldown Assist](Cooldown-Assist.md) | Shipped | 1.1.0 |
| [Exploration](Exploration.md) | Shipped | 2.0.2 |
| [FPSDiag](FPSDiag.md) | Shipped | 0.3.0 |
| [WowGPS](WowGPS.md) | Shipped | 1.0.0 |
| [Light Paws Loadouts (Retail)](Light-Paws-Loadouts-Retail.md) | Shipped | 1.1.4 |
| [Light Paws Loadouts - Classic Era](Light-Paws-Loadouts-Classic-Era.md) | Shipped | 1.0.0 |
| [Light Paws - Anniversary](Light-Paws-Loadouts-Anniversary.md) | Planned | — |
| [Light Paws Classic (MoP)](Light-Paws-Loadouts-Classic-MoP.md) | Planned | — |
| [Season of Discovery LPL](Light-Paws-Loadouts-SoD.md) | Planned (later) | — |

## Desktop apps

| Document | Status | Version |
|----------|--------|---------|
| [Light Paws Talent Manager - Retail](Light-Paws-Talent-Manager-Retail.md) | Shipped | 1.0.9 |
| [Light Paws Talent Manager - Classic Era](Light-Paws-Talent-Manager-Classic-Era.md) | Shipped | 1.0.0 |
| [Light Paws Talent Manager - Anniversary](Light-Paws-Talent-Manager-Anniversary.md) | Planned | — |
| [Light Paws Talent Manager - Classic (MoP)](Light-Paws-Talent-Manager-Classic-MoP.md) | Planned | — |
| [Light Paws Loadout Manager - Retail](Light-Paws-Loadout-Manager-Retail.md) | Shipped | 1.0.3 |
| [Light Paws Loadout Manager - Classic Era](Light-Paws-Loadout-Manager-Classic-Era.md) | Planned (in program) | catalog stub only |
| [Light Paws Loadout Manager - Anniversary](Light-Paws-Loadout-Manager-Anniversary.md) | Planned | — |
| [Light Paws Loadout Manager - Classic (MoP)](Light-Paws-Loadout-Manager-Classic-MoP.md) | Planned | — |
| [Blind Mice Gaming Updater](BMG-Updater.md) | Shipped | 1.1.8 |

## Host

| Document | Status |
|----------|--------|
| [tbfwow.com community host](Community-Host-tbfwow.md) | Live (Retail + Classic Era LPTM wired; other flavors reserved) |

## Locked Light Paws matrix (2026-08-23)

Every flavor is **three products**: in-game LPL + desktop LPLM + desktop LPTM. Separate folder, SavedVariables or AppData, and updater row. No mega multi-client zip for v1.

| Flavor | WoW client | LPL | LPLM | LPTM |
|--------|------------|-----|------|------|
| Retail | `_retail_` | shipped | shipped | shipped |
| Classic Era (Hardcore uses this) | `_classic_era_` | shipped | next desktop slice | shipped |
| Anniversary (TBC) | `_anniversary_` | planned | planned | planned |
| Classic / MoP | `_classic_` (one client today) | planned | planned | planned |
| Season of Discovery | SoD client | later | later | later |

**Build order:** Era addon + LPTM (done) → Era LPLM → Anniversary trio → Classic/MoP trio → SoD. Do not start Anniversary/MoP/SoD **code** until assigned.
