# WOW Forever

Client folders (first that exists): `_classic_beta_`, `_forever_`, `_wow_forever_`, `_camelot_`. Artifact pack key: `forever`.

Live Battle.net product on this machine is `wow_classic_beta` in `_classic_beta_` (build `1.60.1.69893`, ForeverBeta, `Interface` `16001`, exe `WowB.exe`). Keep `_forever_` / `_wow_forever_` / `_camelot_` as fallbacks if Blizzard renames the folder.

Mainline UI family next to Midnight (Edit Mode, Housing). Blizzard’s UI Discord: Forever is game type **Camelot** (name may change before launch); Midnight is **Standard**. Shares Midnight addon APIs, including secret values and AuraContainer. TOC also lists `121500` / `121000` for a later 12.x Forever client.

Treat Forever as its own flavor: own addon folder, own SavedVariables, own updater row. Do not install Forever packages into `_retail_`. In-game LPL is `lpl-forever/` (`LPLForeverDB`). AllQuest Forever is `AllQuest-forever/` + `AllQuest_Data_Forever/` (`AllQuestForeverDB`). Desktop LPLM / LPTM Forever are later.

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
- Live folder today is `_classic_beta_`. Still try `_forever_`, then `_wow_forever_`, then `_camelot_` if that product folder is missing.
- Season of Discovery remains a later Classic-family flavor, not Forever.
