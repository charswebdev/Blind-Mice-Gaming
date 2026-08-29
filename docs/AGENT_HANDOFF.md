# Blind Mice Gaming — Agent Handoff

**Job of this file:** index + locks. It is not a second copy of every product.

**Read the material.** Understanding goals and projects means reading the docs this file points at — not this file alone. Versions live in `updater/catalog.json` and each product’s `.toc` / `catalog.json`. What worked / did not / open work lives in `docs/Projects/`.

| Field | Value |
|-------|--------|
| Repo | https://github.com/charswebdev/Blind-Mice-Gaming |
| Owner | Charlotte Bryant (`charswebdev`) |
| Workspace | `Blind Mice Gaming` (not the old `Light Paws Talent Loadout` planner folder) |
| Last reviewed | 28 August 2026 |
| GitHub | `charswebdev` |

---

## 1. Required read (do this before coding)

Read **all** of the following in order. Skimming only this handoff is not enough.

### 1.1 Index and locks (this file)

Sections **2–6** here: product locks, 5×3 matrix, next slice, do/don’t, Commit rule.

### 1.2 Every product

1. [`docs/Projects/README.md`](Projects/README.md) — status table (re-check versions in catalog/toc when shipping).
2. **Every** file in `docs/Projects/` — description, features, plan, sources, what worked, what did not, open work. That is how you learn the portfolio, not §6 of an old session dump.

### 1.3 Flavors and data method

3. [`docs/WOW Flavors.md`](WOW%20Flavors.md) then all four flavor files:
   - [`docs/WOW Retail/WOW Retail.md`](WOW%20Retail/WOW%20Retail.md)
   - [`docs/WOW Classic Era/WOW Classic Era.md`](WOW%20Classic%20Era/WOW%20Classic%20Era.md)
   - [`docs/WOW Anniversary/WOW Anniversary.md`](WOW%20Anniversary/WOW%20Anniversary.md)
   - [`docs/WOW Classic/WOW Classic.md`](WOW%20Classic/WOW%20Classic.md)
4. [`docs/Cursor/Cursor.md`](Cursor/Cursor.md) — extract / census / no Wowhead scrape.
5. [`docs/Resources.md`](Resources.md) — **locked** trusted sites (Petopia, housing codes, wago, FrameXML, …).
6. [`docs/reports/BMG-design-data-evaluation.md`](reports/BMG-design-data-evaluation.md) — method lock: addon-first, no warehouse blocker.
7. [`docs/classic-lpl-shared-brief.md`](classic-lpl-shared-brief.md) — Classic flavor-agent brief (keep locks aligned with §3 here).

### 1.3 When you start a slice

8. The product folder you will touch, plus `Tools/<that project>/` if the work is extract/generate.
9. `updater/catalog.json` and that product’s `.toc` or `catalog.json` for the version you will bump.

Optional after the above: **Appendix A** (Era LPTM ship notes) if you are in `talent-manager-classic-era/`.

Raw Artifacts zip stays in [`docs/Artifacts/`](Artifacts/README.md). Distilled notes are the flavor files, not the zip.

---

## 2. Locked product decisions

| Decision | Locked value |
|----------|----------------|
| Retail talent planner patch | WoW Retail **12.1** (not War Within fake fixtures) |
| Retail LPTM points at 90 | Class **34**, Spec **34**, Hero **13** |
| Classic Era talents | **3 trees**, shared **51** points, tier×5, prereqs; Druid = Balance / Feral Combat / Restoration (not 4) |
| Era points | `min(51, max(0, level - 9))` at max 60 |
| Era Feral tab icon | `ability_racial_bearform` |
| Era share type | `eratents` (not Retail `dftalents`) |
| Era LPTM AppData | `%APPDATA%\LightPawsTalentManagerClassicEra` |
| Era LPLM | **Next Classic desktop slice** — `loadout-manager-classic-era/` (catalog stub only; updater `planned`) |
| Hardcore | Uses Era LPL + LPLM + LPTM |
| Classic vs MoP | One `_classic_` client today; one trio; display name **Light Paws Classic (MoP)** |
| SoD | Later; own packages; do not land runes in Anniversary |
| Anniversary talents (plan) | 3 trees, **61** points |
| MoP talents (plan) | Spec + tiers + glyphs |
| Repo layout | One folder per product at repo root; author tools in `Tools/<project>/` |
| Addon trees | Ship-only (no scrapers/CSV generators inside the zip) |
| Updater copy path | Addon folders stay at **repo root** (`source/<folder>/`) |
| Desktop git | Usually track `catalog.json` only |
| AllQuest | Quest IDs + `next` links only; titles/coords at runtime; census IDs, not copied graphs; Retail does **not** load expansion 0 |
| World Quest journal buckets | Visible by default |
| Trusted sites | [`docs/Resources.md`](Resources.md) — **locked** |
| Accessibility Helper versions | Short patches (`3.6.2` → `3.6.3`), not `3.6.17`-style |
| Housing Blueprints (Retail LPL) | String vault in `lpl/` (Phases 0–3). Detect `Ag…` codes; Copy for House; no house apply. Not Classic. |
| User communication | Concise; bold sparingly; no unsolicited commits |

### Node chrome (LPTM / shared)

Granted = gold frame, color icon, no rank badge, cannot spend. Selected regular = gold ring + rank. Available = **green** ring. Locked = grey + greyscale. No green checkmark on nodes. Sidebar selection = gold border only.

---

## 3. Light Paws 5×3 and build order

Every flavor is **LPL + LPLM + LPTM**. Separate folder, SavedVariables or AppData, updater row. No mega multi-client zip.

| Flavor | Client | LPL | LPLM | LPTM |
|--------|--------|-----|------|------|
| Retail | `_retail_` | shipped | shipped | shipped |
| Classic Era | `_classic_era_` | shipped | **next desktop** | shipped |
| Anniversary (TBC) | `_anniversary_` | planned | planned | planned |
| Classic / MoP | `_classic_` | planned | planned | planned |
| Season of Discovery | SoD client | later | later | later |

**Build order:** Era addon + LPTM (done) → **Era LPLM** → Anniversary trio → Classic/MoP trio → SoD.

Do **not** start Anniversary / MoP / SoD **code** until assigned.

Classic flavors: keep vault UX; rewrite talent engines; drop CDM / Retail PvP / hero / skyriding. Feature-detect Edit Mode.

---

## 4. Portfolio map (folders only)

Versions: `docs/Projects/README.md` + catalog/toc. Do not copy versions into this file.

**Addons:** `AccessibilityHelper/` · `AllQuest/` + `AllQuest_Data_*` · `CooldownAssist/` · `Exploration/` · `FPSDiag/` · `wowgps/` · `lpl/` · `lpl-classic-era/` · planned `lpl-anniversary/` · `lpl-classic/` · SoD TBD

**Desktop:** `talent-manager/` · `talent-manager-classic-era/` · `loadout-manager/` · `updater/` · planned `loadout-manager-classic-era/` (stub) · planned Anniversary/MoP LPTM/LPLM folders

**Host:** `tbfwow-lptm/` — `/lptm/retail/`, `/lptm/classic-era/` live; `/lptm/classic/`, `/lptm/anniversary/`, loadouts routes reserved. Do not point Era at `/lptm/retail/`.

**Author:** `Tools/<project>/` (gitignored except `Tools/README.md`).

---

## 5. What to work on next

Wait for assignment. Locked suggestions:

1. **Classic Era Loadout Manager** (`loadout-manager-classic-era/`) — highest-priority planned Classic desktop. Keep updater `status: planned` until a real Setup exists.
2. Product maintenance only if asked (AllQuest overlays, AH, catalog bumps).
3. Retail LPL **Housing Blueprints** — shipped in 1.1.4. `.tga` only if the PNG looks soft.
4. Anniversary then Classic/MoP trios only when assigned.

---

## 6. Do / don’t

### Do

- Open workspace **`Blind Mice Gaming`**.
- Finish §1 reads before coding a new slice.
- Update `docs/Projects/<that product>.md` in the same session as any product change (Cursor rule `update-project-docs`). Update the Projects README table if version or status changed.
- Put author scripts in `Tools/<project>/`.
- Census IDs only for third-party quest/exploration addons.
- Ask before starting a new Light Paws flavor **code** slice.

### Don’t

- Don’t invent a 4th Era Druid tree or port `C_ClassTalents` / hero / CDM to Era.
- Don’t mix Era quest IDs into Retail Chromie (AllQuest expansion 0 stays off Retail).
- Don’t scrape Wowhead guides or copy Questie/Zygor/BtW graphs into packs.
- Don’t add trusted sites beyond [`docs/Resources.md`](Resources.md) unless the user unlocks that list.
- Don’t nest addons under `AddOns/` without updater path changes.
- Don’t delete `FPSDiag/Tools.lua` thinking it is `Tools/`.
- Don’t mix unrelated dirty trees (`lpl/`, `tbfwow-lptm/`, AllQuest WIP) into one commit.
- Don’t mark Era LPLM 1.0.0 as shipped while only a catalog stub exists.

### When the user says **Commit**

Cursor rule `commit-bump-ship`: for each **product whose shippable files changed** — small **patch +1** only (`3.6.2` → `3.6.3`, never `3.6.21`), update that project’s `docs/Projects/` file, commit **only** those files + matching toc/catalog/docs, push `origin` (`main` unless named), ship via `updater/catalog.json`. Desktop Setup apps also need `gh release create`. Docs-only or Cursor-rule-only commits do not bump a product.

---

## 7. Related docs

| Path | Role |
|------|------|
| This file | Index + locks |
| `docs/Projects/` | Living product files |
| `docs/WOW */` | Per-client capability and sources |
| `docs/Cursor/Cursor.md` | Collection / manifest rules |
| `docs/Resources.md` | Locked trusted sites |
| `docs/reports/BMG-design-data-evaluation.md` | Design/data method review |
| `docs/classic-lpl-shared-brief.md` | Classic flavor-agent brief |
| `docs/Artifacts/` | Raw starter-pack extract |
| `Tools/README.md` | Author-tools index |

---

## Appendix A — Era LPTM ship notes (optional)

Only needed when working in `talent-manager-classic-era/`. Full living file: [`docs/Projects/Light-Paws-Talent-Manager-Classic-Era.md`](Projects/Light-Paws-Talent-Manager-Classic-Era.md).

- Run: `python app.py` from that folder. Frozen `LPTM-Classic-Era-1.0.0.exe`. Community `https://tbfwow.com/lptm/classic-era/` → table `lptm_classic_era`.
- Data: `classic_era_talents.json`, `era_spell_icons.json` (432), `era_spell_tooltips.json` (1357). Do not depend on leftover Retail JSON at runtime.
- Bump checklist: `APP_VERSION`, `catalog.json`, `LPTM.iss`, `LPTM.spec`, `update.USER_AGENT`, `build.bat`.
- Community: preserve `community_owner_token` on CreatePage save; Era stubs `spec_id="trees"`, `hero_id="era"`.
- Icons: Wowhead classic `?dataEnv=4`; Feral tab `ability_racial_bearform`. Generators in `Tools/talent-manager-classic-era/`.

Session that shipped 1.0.0 (2026-08-23): Retail-parity tree UI and AsNeeded scrollbars; icon/tooltip fill; community URL wired; Setup + GitHub release; Tools extraction from addon/desktop trees.

---

*End of index. Prefer `docs/Projects/` + catalog/toc for versions. Prefer this file for locks and read order.*
