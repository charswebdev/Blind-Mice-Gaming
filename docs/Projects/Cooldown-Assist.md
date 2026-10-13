# Cooldown Assist

| Field | Value |
|-------|--------|
| Status | **Shipped** |
| Version | **1.1.1** |
| Type | In-game cooldown / buff-fade TTS (VI) |
| Folder | `CooldownAssist/` |
| Clients | Retail (`120105`, `120100`) + Classic flavors (toc Interface list matches AH) |
| SavedVariables | `CooldownAssistDB` |
| Slash | `/ca` settings · `/ca c` speak ready · `/ca scan` · `/ca rebuild` · `/cas` TTS test |

## Description

Announces when tracked cooldowns become **ready** (`Barkskin ready.`) and when matching buffs **fade**. Built for blind players. Uses **its own TTS queue** — it does not go through Accessibility Helper, so tooltip speech and cooldown speech do not collide.

Retail-only discovery (toys, some teleports, modern skill lines) **degrades** on Classic instead of erroring.

## Features

- Tracks class/combat abilities, racials, pet abilities, teleports, hearth, toys, skyriding/general utilities, equipped on-use gear, bag consumables (potions, flasks, food, bandages, healthstones).
- Ignores cooldowns under **5 seconds**.
- Exclusive Cooldowns-tab filters (All / Combat / Items / Pet / Racial / Teleport / Toys / General).
- Combat CDs announce in combat by default; General / Teleport / Toys anytime.
- Account-wide enable/disable profiles.
- Midnight secret-safe cooldown and aura handling.
- Publishes `GameTooltip.AccessibilityHelperSpeakText` so AH’s tooltip keybind still works on CA UI.
- Minimap button and key bindings.

## Development plan

Pre-1.0 slices (from `CHANGELOG.md`):

| Slice | Focus |
|-------|--------|
| 0.2.x | Spell tracking + ready/charge TTS |
| 0.3.x | Filters, racials, teleports, toys, profiles |
| 0.4.x | Equipped trinkets / on-use |
| 0.5.x | Bag consumables |
| 0.6.x | Buff fades; secret-ID fixes; out-of-combat general/skyriding |
| **1.0.0** | First public Blind Mice Gaming release |
| **1.1.0** | Cross-flavor Classic: SafeCall arity, Classic spellbook, gated events, UnitAura fallback |
| **1.1.1** | Retail Interface `120105` for patch 12.1.5. Older Interface numbers stay. |

## Sources and data

- Blizzard spellbook, action bars, bag, aura, and toy APIs.
- No imported WeakAura or cooldown-manager databases.
- Category tables in `Core/Categories.lua`, `Racials.lua`, `Teleports.lua`.

## What worked

- Independent speech queue.
- Exclusive filters (only **All** shows every group) — easier to reason about for TTS than additive checkboxes.
- Graceful Classic: `pcall` missing events, Classic spell tabs, `UnitAura` fallback.

## What did not work

- `SafeCall` that returned only the first value — **pet action bar spell IDs truncated**. Fixed 1.1.0.
- Bare `>` on Midnight secret charge numbers.
- Assuming Retail `C_UnitAuras` / toy APIs exist on Era.
- Sharing AH’s speech queue (rejected).

## Open work

- Catalog `updated` date is 2026-10-13; toc is 1.1.1. Further Classic discovery holes are playtest-driven.
