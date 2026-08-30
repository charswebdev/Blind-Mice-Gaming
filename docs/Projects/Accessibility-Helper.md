# Accessibility Helper

| Field | Value |
|-------|--------|
| Status | **Shipped** |
| Version | **3.6.4** (toc, Init banner, settings footer fallback, `updater/catalog.json`) |
| Type | In-game addon (VI / TTS) |
| Folder | `AccessibilityHelper/` |
| Author tools | `Tools/AccessibilityHelper/` (release checklists; not in the addon zip) |
| Clients | Retail Midnight (`120100`), MoP Classic, Cata, Wrath, TBC, Classic Era (`11509` / `11508`) |
| SavedVariables | `AccessibilityHelperDB` (account) |
| Install | BMG Updater folder `AccessibilityHelper` |
| Slash | `/ah` settings · `/ahcmds` · `/ahclear` · `/ahstop` · `/ahs` TTS test · `/ahtip` tooltip · `/ahread` under mouse |
| Optional deps | TomTom, Zygor, MountSpy, QuestCompletist, RareScanner, SilverDragon, HandyNotes, Zugzug, Titan, LibSharedMedia |

## Description

Accessibility Helper is Blind Mice Gaming’s general **text-to-speech accessibility layer** for blind and visually impaired players. It reads tooltips, chat, movement and combat state, loot, quests, casts, and UI errors. It is **not** a quest tracker (AllQuest) and **not** a cooldown announcer (Cooldown Assist). Cooldown Assist uses its own TTS queue on purpose so the two do not steal each other’s speech.

The settings UI is a two-pane AllQuest-style layout: a topic tree on the left, one spacious option row on the right, hover tooltips that also speak. Alerts can be **TTS, a sound, or both** per item.

Version numbers stay short on purpose (3.6.2, then 3.6.3) — not 3.6.18-style patches. The updater compares catalog versions; jumping *down* from 3.6.17/3.6.18 to 3.6.2 can hide the update from players already on the longer number.

## Features

### Speech and sounds

- Own speech queue (`Core/Speech.lua`) with volume, rate, voice, and a critical-priority interrupt path.
- Midnight **secret-value** safety: never concatenate, compare, or table-key secret strings/numbers (`Compat.CanUseValue` / `CanUseNumber` / `UsableString`). Creature chat (`CHAT_MSG_MONSTER_*`) is often a secret string — skip it instead of `message == ""`.
- Per-alert delivery: TTS, sound kit, or both (`Core/Alerts.lua`). Default sound fallback.

### Reading the world

- Tooltip reader (`/ahtip`) and under-mouse reader (`/ahread`), including published `GameTooltip.AccessibilityHelperSpeakText` from other BMG addons (e.g. Cooldown Assist).
- Cursor kind: mount / loot / open / collect (secret-safe on Midnight).
- TomTom and Zygor waypoint distance and arrow reads.
- Target distance and **clock facing** (plus target-of-target on the target keybind).
- Subzone / discovery announcements.
- Chat channels (town, nearby, groups, whispers, creatures, crafting, pets, PvP, system) and a filter for **other addons’** printed chat.

### Player and combat state

- Follow, mount, swim, taxi; combat, death, health, breath, fatigue.
- Resting, instances, bags, durability, money.
- AFK, PvP, stealth, form, pet, group.
- Level-up, quest accept/complete, target acquired/cleared.
- **Target-of-target aggro** (hostile target looking at someone else / back on you) — tanks. Midnight: `UnitIsUnit` / `UnitExists` on `targettarget` are secret booleans; event filter uses unit tokens, checks go through `Compat.SafeBool`.
- Battle.net friends online/offline.
- Quest windows and objectives.
- Loot items and currencies.
- Profession skill, XP, reputation standing.
- Cast and channel bars for **player** and **hostile target / focus / boss / arena** only.
- Interrupt-ready cue (skips if silenced/stunned).
- Loss of control (stun, root, silence, lockout), harmful debuff types, combat buff apply/fade/stacks.

### UI

- Minimap button, key bindings header **Accessibility Helper**, high-contrast settings.

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
- `guid ~= ""` before `issecretvalue` in `Compat.UnitSeen`. Targeting from a macro (`TargetUnit` / action button) returns a secret `UnitGUID("target")`; `type()` is `"string"` so the empty-string compare ran and threw. `UsableString` first.

## Open work

- Players stuck on 3.6.17/3.6.18 may need a forced updater/reinstall to see 3.6.4.
- Chat secret-string skip is in tree (unshipped until the next AH patch). Creature Say in delves will stay silent when Blizzard marks the line secret.
- More starter-zone or encounter-specific cues belong in other addons unless they are generic unit/combat facts.
