# WOW Forever

Client folders (first that exists): `_forever_`, `_wow_forever_`, `_camelot_`. Artifact pack key: `forever`.

Mainline UI family next to Midnight. Blizzard’s UI Discord: Forever is game type **Camelot** (name may change before launch); Midnight is **Standard**. Shares Midnight addon APIs, including secret values and AuraContainer. Based on **12.1.5** (`Interface` `121500`).

Treat Forever as its own flavor: own addon folder, own SavedVariables, own updater row. Do not install Forever packages into `_retail_`.

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
- Game-type TOC suffix is not locked yet. Until Battle.net creates the live folder, try `_forever_`, then `_wow_forever_`, then `_camelot_`.
- Season of Discovery remains a later Classic-family flavor, not Forever.
