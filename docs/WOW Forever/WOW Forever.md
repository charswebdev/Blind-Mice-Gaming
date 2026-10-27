# WOW Forever

Client folders (first that exists): `_forever_`, `_wow_forever_`, `_camelot_`. Artifact pack key: `forever`. Never `_classic_beta_`.

Live Battle.net product is `wowf` in `_forever_` (build **1.60.1.70634**, Interface `16001`, exe `Wow.exe`). Addon TOCs keep `16002`, `16001`, `16000`, `121500`, and `121000`, and `AllowLoadGameType: forever, camelot`.

Mainline UI family next to Midnight (Edit Mode, Housing). Blizzard’s UI Discord: Forever is game type **Camelot** (name may change before launch); Midnight is **Standard**. Shares Midnight addon APIs, including secret values and AuraContainer. TOC also lists `121500` / `121000` for a later 12.x Forever client.

Treat Forever as its own flavor: own addon folder, own SavedVariables, own updater row. Do not install Forever packages into `_retail_`. BMG Unit Frames Forever is `BMG-Unit-frames-forever/` (`BMGUnitFramesForeverDB`, keybind category BMGUF). In-game LPL is `lpl-forever/` (`LPLForeverDB`). AllQuest Forever is `AllQuest-forever/` + `AllQuest_Data_Forever/` (`AllQuestForeverDB`). Desktop LPLM / LPTM Forever are later.

## Resources that helped

| Resource | Role |
|----------|------|
| **In-game Lua API** (Midnight / 12.1.5 Mainline) | Runtime truth. Secrets, unit frames, auras. |
| **WoW UI Discord / Wowhead (2026-09-16)** | Confirmed Forever uses Midnight disarmament and 12.1.5-class APIs. |
| **Townlong-Yak / FrameXML** | Mainline TOC and `AllowLoadGameType` (`standard` vs future Camelot name). |

## Resources that have not helped

| Resource / assumption | Why not |
|------------------------|---------|
| **Classic Era / Anniversary pipelines** | Forever is Mainline, not Vanilla/TBC FrameXML. |
| **One zip shared with Retail** | Same rule as other flavors: separate folder. Interface `121500` would also match a naive “Retail = 100000+” updater check. |

## Developer notes

- Secrets: same rules as Midnight. Do not arithmetic-compare `UnitHealth` / `UnitPower`; use percent APIs and `SetValue`.
- Focus, arena, Edit Mode, 3D portraits: assume present (Mainline).
- Live folder is `_forever_` only. `_wow_forever_` and `_camelot_` are name fallbacks. Never install into `_classic_beta_`.
- Season of Discovery remains a later Classic-family flavor, not Forever.
