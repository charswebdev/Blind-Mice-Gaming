# AllQuest

| Field | Value |
|-------|--------|
| Status | **Shipped** (journal data plan phases 0–5 complete) |
| Version | **1.0.9** (addon toc + updater catalog; data packs are `1.0.0` with `X-AllQuest-AutoLoad`) |
| Type | In-game quest tracker + questline journal + expansion data plugins |
| Folders | `AllQuest/` (runtime) · `AllQuest_Data_*` (one pack per expansion) |
| Author tools | `Tools/AllQuest/` — extractors, wago DB2 cache, ID census (gitignored) |
| Clients | Retail loads expansions **1–11**. Classic Era loads expansion **0** only. MoP/Cata/Wrath/TBC catalogs allow Classic packs plus older Retail-style IDs per `Compat.AllowedExpansionIDs()`. |
| SavedVariables | `AllQuestDB` (account) · `AllQuestCharDB` (character, includes `/aqdebug` log) |
| Optional plugins | Accessibility Helper (speech), TomTom, Masque, RareScanner, SilverDragon, PetTracker, Battle Pet Completionist, All The Things, Zygor, QuestCompletist, BtWQuests |

## Description

AllQuest is a **high-contrast quest tracker** and a **questline journal** (expansion → category → chain graph). Packs store **quest IDs and next-links only**. Titles, completion, and pickup coordinates come from Blizzard at runtime (`Integrations/QuestSources.lua`), then optional plugins.

It is original Blind Mice Gaming data. Third-party quest addons are an **integer ID census**, not a source of graphs, pins, NPC lists, exclusive groups, or guide text.

World-quest / repeatable journal buckets stay **visible** by default (setting can hide them).

## Features

### Tracker

- Custom tracker (can hide Blizzard’s).
- Sections: popups, quests, world quests, scenarios, campaigns, achievements, recipes, activities, events, collectibles, pets, rares.
- Delve instance block: under Nemesis Influence, **Nemesis Strong Box** (`0/4 Nemesis Packs defeated`) and **Bonus loot**. Pack count uses Everything Delves’ seasonal vignette IDs (7531 / 7869); bonus loot uses Sanctified Banner interact/buff spell IDs. Retail AddOns copy must be synced — WoW does not load this repo folder.
- Auto-accept / auto-turn-in (Shift at NPC skips).
- Super-track, items, sounds, colors, filters, profiles.
- Speech of focused rows (AH queue if loaded).

### Journal

- List + graph views of chains; quest detail pane.
- Load-on-demand data packs (`## LoadOnDemand: 1`, `X-AllQuest-Expansion`).
- Newest allowed expansion autoloads (`X-AllQuest-AutoLoad`).
- Campaign folders and chapter order (Retail). CliTask **forks** where completed-quest parents exist.
- Profession category, Unlisted census buckets.
- Classic Era: zone folders from AreaTable, Questie census chains, QuestV2 leftovers in Unlisted, hand Elwynn/Durotar starters.

### Debug

- `/aqdebug record` — zone + quest log.
- `/aqdebug gap` — log + map pins vs packs.
- `/aqdebug maps` / `crawl` — descendant maps, IDs not in packs.
- `/aqdebug questlines` — Retail `C_QuestLine` dump.

## Development plan

Approved 27 Aug 2026 (canvas: `allquest-journal-data-plan.canvas.tsx`). Retail Midnight first; Classic Era as its own pack; WQ buckets visible; census IDs only.

| Phase | Plan | Status |
|-------|------|--------|
| 0 | Restore `Tools/AllQuest`: `extract_chains.py`, coverage, census | Done |
| 1 | Fresh Midnight 12.1 extract from QuestLineXQuest; keep WQ buckets | Done |
| 1b | Census IDs into Unlisted; profession QuestLines | Done |
| 2 | Enrich nodes from Quest DB2 (level, faction, type); Overlay.lua is the only hand branch file | Done |
| 3 | Campaign folders + CliTask forks for every Retail pack; Midnight Light’s Summons stays a hand overlay | Done |
| 4 | Classic Era pack from 1.15.9 AreaTable + Questie ID census; keep Northshire / Goldshire / Valley of Trials | Done |
| 5 | Gap hunt: `/aqdebug` crawl; Era QuestV2 leftovers in Unlisted; do not dump unplaceable Retail census IDs | Done |

**Locked:** Retail does **not** load Classic (`expansion 0`) because Era IDs ≠ Chromie / old-world Retail IDs.

## Sources and data

| Source | Take | Do not take |
|--------|------|-------------|
| wago.tools DB2 **12.1.0.69497** | QuestV2, QuestLine, QuestLineXQuest, QuestV2CliTask, ContentTuning, QuestInfo, Campaign* | — |
| wago Era **1.15.9.69109** | AreaTable, QuestSort, thin QuestV2 (ID + UniqueBitFlag) | Quest / QuestLine / CliTask — **404**, do not invent them |
| Questie `classicQuestDB.lua` | Keys + integer fields: zoneOrSort, nextQuestInChain, race/class/level, flags | Coords, `startedBy`, `exclusiveTo`, preQuest tables as graphs |
| BtW / QuestCompletist / Zygor | Integer quest IDs | Chain Lua, pin DBs, Zygor guide steps |
| Wowhead | Not scraped (ToS) | HTML, comments, walkthroughs |
| Hand overlays | Midnight Light’s Summons; Classic Elwynn/Durotar starters | Copying another addon’s story graph |

Retail extractor: campaign merge, skip lorewalking / catch-up / `[DNT]` / wrappers, zone campaigns over wrap campaigns.

Classic extractor: Questie zone grouping, `next`/`pre` glue, Alliance/Horde from Era race masks, Repeatables from special flags, leftover Era QuestV2 → Unlisted.

Approximate Retail pack shape after phase 3: Legion ~307 chains / 22 campaigns; BFA 330 / 6; SL 223 / 21; DF 130 / 13; TWW 165 / 15; Midnight 146 / 5 + overlay. TBC/Wrath/WoD stay thin/linear.

Classic after phase 5: **822** chains, **5,519** unique IDs, Era QuestV2 **4,807/4,807** in pack; **275** QC/Zygor IDs not in Era QuestV2 left out.

## What worked

- Treating other addons as a census, then rebuilding graphs from DB2 — legally and structurally cleaner than pasting BtW/Zygor Lua.
- `AddChain` replacing a chain **removes** it from the old category (needed for overlays).
- Campaign folders + CliTask forks on TWW/Midnight where Blizzard lists completed-quest parents.
- True Era pack instead of “reuse Retail Cata old-world.”
- `/aqdebug gap` for holes the census cannot see (player-available map quests).

## What did not work

- **Era Quest.db2 / QuestLine / CliTask** on wago: 404. Cannot build Era the Retail way.
- Linear QuestLine extract as a “story guide”: parallel side quests and “do these three then converge” need Overlay.lua. Most older packs stay one line.
- Dumping ~11k Retail census IDs with **no expansion** (or on skipped internal lines: lorewalking, catch-up wrappers, `[DNT]`). That would pollute Midnight Unlisted.
- Copying Questie pins/NPCs — copyrighted compilation; also wrong product (journal ≠ arrow addon).
- Classic auto-names like `"Westfall 12–65"` and `"Northshire Abbey — more"`: expected dump quality, not a finished leveling guide.
- TBC / Wrath / WoD: often one chain per zone.
- Delve extras only on a classified nemesis spell: Shadowguard Point showed **Nemesis Influence** with no Strong Box / Bonus loot. Midnight can list that line as a currency or a spell without a numeric id.
- Guessing Strongbox progress from in-delve spell widgets or vignette *names*. Everything Delves: those widgets exist only on the entrance picker; pack names can be Midnight secret strings. Live source is vignette **IDs**.
- Editing `Documents\\…\\AllQuest` and `/reload` while `_retail_\\Interface\\AddOns\\AllQuest` is a separate Aug-27 copy — none of the extras code was loaded.

## Open work

- Delve Nemesis extras: live screenshot at Shadowguard Point showed Influence but no Strong Box / Bonus loot — extras only fired on a classified nemesis *spell*. Midnight can list Influence as a currency or a spell without a numeric id; attach now keys off any “nemesis” chrome row.
- Confirm live tooltip/vignette names if a season renames Ula'tek packs or bonus spoils.
- Hand starter overlays past Elwynn/Durotar (Westfall, Barrens, Loch Modan, …) — overlay work, not another extract phase.
- Playtest on Era (`/reload`); Retail will not show the Classic pack.
- TBC/Wrath/WoD remaining linear dumps.
- Overlay.lua empty except Midnight (and Classic hand chain files).
