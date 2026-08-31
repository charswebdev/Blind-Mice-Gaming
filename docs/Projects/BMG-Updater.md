# Blind Mice Gaming Updater

| Field | Value |
|-------|--------|
| Status | **Shipped** |
| Version | **1.2.0** (`updaterVersion` + GitHub tag `v1.2.0`) |
| Type | Desktop installer/updater for **all** BMG addons and first-run desktop apps |
| Folder | `updater/` (source mostly local; **`catalog.json` tracked**) |
| Catalog URL | GitHub `main` · `updater/catalog.json` in repo `charswebdev/Blind-Mice-Gaming` |
| Setup | `https://github.com/charswebdev/Blind-Mice-Gaming/releases/download/v1.2.0/BMG-Updater-Setup-1.2.0.exe` |
| Author tools | `Tools/updater/` logo previews / installer art |

## Description

The **player-facing install path** for every Blind Mice Gaming addon and the first install of desktop apps (LPTM, LPLM, itself). It copies addon folders from the GitHub repo (root folder names must match zip paths: `AccessibilityHelper/`, `lpl/`, … — **not** nested under `AddOns/`). Desktop apps are listed with `setupUrl`; after install they may self-update, but from LPLM 1.0.3 the **Updater owns** those app updates.

## Features

- Catalog-driven list of addons (folder lists, toc interfaces, SavedVariables names) and apps (flavor, status shipped/planned, exe prefix).
- Install/update addons into the correct WoW `_retail_` / `_classic_era_` / … `Interface/AddOns` trees.
- Download GitHub release Setups for desktop apps.
- Self-update of the updater exe.
- 1.1.5: SSL-safe GitHub downloads on frozen installs.
- 1.1.6: catalog bump with AllQuest.
- 1.1.7: self-update no longer trips PyInstaller parent-process validation.
- 1.1.8: download progress immediately; self-update runs **before** app installs.
- Addon updates (auto and manual) install even while World of Warcraft is open. Status tells the player to `/reload` in-game. If a folder is locked, files are overwritten in place.
- **1.1.9:** automatic addon updates no longer wait for Wow.exe to close.
- **1.2.0:** self-update starts as soon as the catalog shows a newer `updaterVersion` (not after the addon TOC scan, and not only when the addon auto-update box is checked). Rechecks every 10 minutes. Silent Setup relaunches the new exe.

## Development plan

Updater is the distribution spine. Product locks (2026-08-23): **all** Light Paws addons and desktops appear here. Planned rows exist for Anniversary/MoP/Era LPLM so the UI can show “coming” without a fake zip.

Version compare for addons is catalog `version` vs installed toc. **Short versions** (AH 3.6.2) are a product preference; numeric compare can treat 3.6.18 as newer than 3.6.2.

## Sources and data

- `updater/catalog.json` — single source of truth for what players can install.
- GitHub repo zip / raw files for addon folders.
- GitHub Releases for `.exe` Setups.
- Does not scrape CurseForge or Wago as the ship path.

## What worked

- One catalog for addons + apps.
- Keeping addon folders at **repo root** so copy paths stay `source/AllQuest/`.
- SSL via certifi on frozen Python (same class of bug as LPLM/LPTM).
- Installing addon files while the client is running, then `/reload`.

## What did not work

- Nesting addons under `AddOns/` in the repo (would break copy paths).
- Self-update racing PyInstaller parent checks (1.1.7).
- Running app installs before updater self-update (1.1.8 orders self-update first).
- Progress UI that stayed empty until the download finished (1.1.8).
- Waiting for Wow.exe to close before automatic addon updates. Addons load from disk on `/reload`; the game does not need to quit.
- 1.1.8 self-update waited until every addon TOC was fetched, and only ran if “Automatically update installed addons and apps” was on. A long-running instance never re-checked. Silent Setup also skipped launching the new exe (`skipifsilent`).

## Open work

- Flip `status: planned` to shipped when Era LPLM / Anniversary / MoP actually have Setups.
- Do not put 1.0.0 setup URLs in a flavor `catalog.json` until the GitHub asset exists (Era LPLM stub risk).
