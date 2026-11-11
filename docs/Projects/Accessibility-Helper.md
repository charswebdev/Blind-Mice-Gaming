# Accessibility Helper - Retail

| Field | Value |
|-------|--------|
| Status | **Shipped** |
| Version | **3.7.6** |
| Type | In-game addon (VI / TTS) |
| Folder | `AccessibilityHelper/` |
| Author tools | `Tools/AccessibilityHelper/` (release checklists; not in the addon zip) |
| Clients | Retail (`120105`, `120100`), MoP Classic, Cata, Wrath, TBC, Classic Era (`11509` / `11508`) |
| SavedVariables | `AccessibilityHelperDB` (account) |
| Install | BMG Updater folder `AccessibilityHelper` |
| Slash | `/ah` window · `/ah commands` · `/ahstop` · `/ahrepeat` · `/ahclear` · `/ahs` TTS test · `/ahtt` TomTom · `/ahz` Zygor |
| Optional deps | TomTom, Zygor, MountSpy, QuestCompletist, RareScanner, SilverDragon, HandyNotes, Zugzug, Titan, LibSharedMedia |

## Description

Accessibility Helper - Retail is the Forever addon window and readers, with Retail’s folder, saved variables, and interface numbers. `/ah` opens Tooltip, Speech, Status, Arrows, Rewards, Combat, Chat, and Commands. The older Retail settings window and the older Retail readers are not loaded. It is **not** a quest tracker (AllQuest) and **not** a cooldown announcer (Cooldown Assist). WoW Forever stays its own addon. Do not install this folder into `_forever_`.

Version numbers stay short on purpose (3.6.2, then 3.6.3) — not 3.6.18-style patches. The updater compares catalog versions; jumping *down* from 3.6.17/3.6.18 to 3.6.2 can hide the update from players already on the longer number.

## Features

3.7.6 loads the same files and window as Accessibility Helper - WoW Forever 1.4.7.

- `/ah` opens Tooltip, Speech, Status, Arrows, Rewards, Combat, Chat, and Commands.
- Tooltip reads on the key. TomTom is `/ahtt`. Zygor is `/ahz`.
- Status speaks skill, level, follow, place, a new location, red error text, and the condition lines, including pet death, low health, and food.
- Rewards speaks experience, reputation, currency, gold, loot, a completed quest, and an earned achievement.
- Chat speaks the channels that are on, plus progress, collections, an accepted quest, quest details, the NPC window, a sale, and a repair.
- Combat speaks the fight lines that are on. Read combat starts off.
- Commands lists the slash commands and key bindings.
- The older Retail readers stay in the folder and are not loaded.

## Development plan (how it was built)

Work was phased in the Lua headers and later combat/cast slices:

| Phase | Focus | Outcome |
|-------|--------|---------|
| 1.1 | `Compat.lua` | Flavor detection, secret-safe wrappers, map/quest helpers |
| 1.2–1.4 | Speech queue | Single-flight TTS, critical interrupt, SAPI overlap quirks on Midnight |
| 3 | Bindings | Secure click proxies for TomTom/Zygor reads |
| 4 | Tooltips | Speak GameTooltip lines; other addons can publish plain text |
| 5 | Distance + waypoints | Target range, TomTom/Zygor |
| 6.2 | UI errors | Red error frame TTS |
| 7 | Player state | Movement, vitals, world, identity, social |
| 8 | Progress | Skill / XP / rep |
| 9 | Init | Load banner, `/ah` wiring |
| Later | Combat + casts | LoC, debuffs, buffs, duration bars, interrupt sound |
| 3.6.2 | Cast filter + ToT | Hostile-only enemy casts; target-of-target aggro |
| 3.6.3 | ToT secrets | GUID/`UnitSeen` instead of boolean-testing `UnitIsUnit` on `targettarget` |
| 3.6.4 | UnitSeen GUID | `UsableString` before any `guid ~= ""` (macro `TargetUnit` secret GUID) |
| 3.6.5 | UnitSeen AddOns | SameUnit / follow GUID also go through `UsableString`; live AddOns copy no longer compares secret `guid ~= ""` |
| 3.6.6 | Retail 12.1.5 | Interface `120105` added. Older Interface numbers stay so 12.1.0 still loads. |
| 3.6.7 | Merchant name | `OpenMerchantAction` uses `UsableString` before comparing `UnitName("npc")`. A secret merchant name is skipped. |
| 3.6.9 | Forever window | Retail loads the Forever window and readers. Title is Accessibility Helper - Retail. Saved variables stay `AccessibilityHelperDB`. |
| 3.7.0 | Pet health | A secret pet health number is skipped. The same check is in Forever 1.4.1. |
| 3.7.1 | Pet mend | The combat log is not registered. A mend still speaks when the cast succeeds. Same as Forever 1.4.2. |
| 3.7.2 | Taming | The Pet switch speaks the tame, the finished pet, and why a target cannot be tamed. Same as Forever 1.4.3. |
| 3.7.3 | Active pet | A tame that fails because a pet is already out says “Another pet is active.” Same as Forever 1.4.4. |
| 3.7.4 | Tooltip number | A stray number after the visible tooltip lines is not spoken. Same as Forever 1.4.5. |
| 3.7.5 | Active pet | A tame that fails because a pet is already out says “Another pet is active.” Same as Forever 1.4.6. |
| 3.7.6 | Read key | The tooltip read key can be Alt, Control, Shift, a mouse button, or the mouse wheel. Same as Forever 1.4.7. |

Settings were rewritten to the two-pane pattern so VI users get one topic at a time instead of a dense options dump.

## Sources and data

- **Blizzard APIs only** for game state (unit, combat log-adjacent LoC, quest log, chat events).
- **No third-party quest graphs.** Optional addons are *integrations* (TomTom arrows, Zygor waypoint text), not copied databases.
- Sound kits via Blizzard + optional LibSharedMedia.
- Saved defaults in `Core/DB.lua`.

## What worked

- Secret-safe tooltip and cursor reading on Midnight (3.6.17 cursor work, then 3.6.2 follow-through).
- Splitting “turn the alert on” (You / Combat) from “how it plays” (Sounds).
- Using Accessibility Helper as a speech **backend** for AllQuest when loaded, without making AH a quest addon.
- Filtering `UNIT_SPELLCAST_*` to player / target / focus / boss / arena. Nameplates, party, and raid fire the same events; labeling those “Enemy” was false feedback for blind players.
- ToT must not `if UnitIsUnit(...)` or `if` a secret even after `canaccessvalue`. Identify ToT with usable GUIDs (`Compat.SameUnit` / `UnitSeen`).
- `UnitSeen` must run `UsableString` (issecretvalue first). `type(guid) == "string" and guid ~= ""` still throws on a secret GUID.

## What did not work

- **Default `UnitLabel` = `"Enemy"`** for any non-target unit. Nearby players on nameplates were announced as enemies. Fixed in 3.6.2: watched units only, `UnitCanAttack` / `UnitIsFriend` / party-raid checks, never call a friendly player “Enemy”.
- Treating `UnitIsFriend` as “not hostile” *before* `UnitCanAttack` would have muted **duel** opponents (same faction, still attackable). Attackable wins.
- Long patch versions (3.6.16 → 3.6.17 → 3.6.18). Product rule is now short numbers (3.6.2).
- Routing Cooldown Assist through AH speech: rejected; overlapping “ready” lines fought the tooltip queue.
- `if UnitIsUnit(...)` and `if v then` after `canaccessvalue` on `targettarget` vs `player`. Midnight still forbids boolean-testing that secret. Fixed in 3.6.3: GUID/`UnitSeen` only.
- `message == ""` on `CHAT_MSG_MONSTER_SAY` (secret string, tainted). Skip via `Compat.UsableString` before any compare.
- `guid ~= ""` before `issecretvalue` in `Compat.UnitSeen`. Targeting from a macro (`TargetUnit` / action button) returns a secret `UnitGUID("target")`; `type()` is `"string"` so the empty-string compare ran and threw. `UsableString` first. Retail AddOns still had the old `type(guid) == "string" and guid ~= ""` at Compat.lua:123 (`PLAYER_TARGET_CHANGED` → `OnTarget` → `UnitSeen`); Documents already used `UsableString`.
- `OpenMerchantAction` compared `UnitName("npc")` with `type(n) == "string" and n ~= ""`. A merchant name is often a secret string, so the cursor poll threw hundreds of times. `UsableString` first; if the name stays secret, the vendor line is skipped.

## Open work

3.6.9 is the Forever window under the name Accessibility Helper - Retail. The old Retail window is not loaded. Do not add gathering-node detection. Do not install this folder into `_forever_`.
