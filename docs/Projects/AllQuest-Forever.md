# AllQuest - WoW Forever

| Field | Value |
|-------|--------|
| Status | **Shipped** (1.0.0 tracker-first package; journal pack is a stub) |
| Version | **1.0.0** |
| Type | In-game quest tracker + questline journal |
| Folders | `AllQuest-forever/` (runtime) · `AllQuest_Data_Forever/` (journal stub, expansion **60**) |
| Clients | `_classic_beta_` (live ForeverBeta) · fallbacks `_forever_` / `_wow_forever_` / `_camelot_` · Interface `16001`, `121500`, `121000` |
| SavedVariables | `AllQuestForeverDB` (account) · `AllQuestForeverCharDB` (character) |
| Slash | `/aq` settings · `/aqline` journal · `/aqtrack` tracker |

## Description

WoW Forever sibling of Retail **AllQuest**. Forever is Mainline (Camelot) next to Midnight, so this package clones the Retail tracker — custom tracker, scenarios, world quests, auto-accept, speech, plugins — with its **own folder and SavedVariables**.

The journal pack is a **stub**. Forever quest IDs are not Midnight (expansion 11) and not Classic Era (expansion 0). Do not install this into `_retail_`. Do not install Retail `AllQuest/` or `AllQuest_Data_*` into `_classic_beta_`.

## Features

- Same tracker module set as Retail AllQuest 1.1.3 (the committed tree this package was forked from).
- Flavor identity in `Core/Flavor.lua` (`id = "forever"`). `GetFlavor()` is forced to forever so Interface `16001` cannot fall through to Era.
- `IsRetail()` is true for Forever: Mainline quest APIs (`ShowQuestComplete` by quest ID, etc.).
- Allowed journal expansion is **60** only (BMG id for client 1.60). Midnight / Era packs cannot autoload.
- Updater row `client: "forever"` so install targets the Forever product folders.

## Development plan

1. Product locks (folder, SavedVariables, TOC `16001` + 12.x, updater `client`) — done.
2. Clone Retail tracker (not Era pack graphs) — done.
3. Empty `AllQuest_Data_Forever` stub so the journal has a Forever expansion and no wrong IDs — done.
4. Playtest on live ForeverBeta (`WowB.exe` / `_classic_beta_`).
5. Forever journal extract later (own DB2 / QuestLine dump). Do not copy Midnight `Generated.lua`.

## Sources and data

- Retail AllQuest committed tree (`AllQuest/` at 1.1.3).
- Forever client notes: [`docs/WOW Forever/WOW Forever.md`](../WOW%20Forever/WOW%20Forever.md).
- Live Blizzard quest / scenario APIs for the tracker.
- No Midnight or Classic Era chain Lua in this tree.

## What worked

- Separate folder + `AllQuestForeverDB` so Retail and Forever can both be installed.
- Reusing Retail tracker modules because Forever shares Midnight addon APIs (secrets, scenarios, world quests).
- Same TOC interface list as BMG Unit Frames Forever (`16001`, `121500`, `121000`).
- Forcing flavor `forever` instead of trusting `WOW_PROJECT_MAINLINE` (would look like Retail and try expansions 1–11).

## What did not work

- Adding `16001` to the shared `AllQuest.toc`. Interface `16001` is below 20000, so `GetFlavor()` would return **era** and load expansion 0 — wrong IDs.
- Treating Forever as Classic Era / Anniversary FrameXML — it is Mainline.
- Shipping Midnight or Era packs into `_classic_beta_`. Those quest IDs do not match Forever.
- One zip shared with Retail — Interface `121500` would also match a naive “Retail = 100000+” check.

## Open work

- In-game playtest on ForeverBeta: `/aq`, tracker, auto-accept, scenarios, `/aqline` (empty journal is expected).
- Forever QuestLine / campaign extract into `AllQuest_Data_Forever` when a Forever build’s DB2 is available.
- Watch for a Battle.net folder rename to `_forever_` / `_wow_forever_` / `_camelot_`.
- Uncommitted dirty files in Retail `AllQuest/` were **not** copied into this tree.
