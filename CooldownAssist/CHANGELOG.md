# Cooldown Assist changelog

## 1.1.0 — 2026-08-07

Cross-flavor compatibility and bugfix.

### Fixes
- `SafeCall` now preserves all API return values (pet action bar spell IDs were truncated)
- Spell cooldown / charge reads work on Classic multi-return APIs and Retail tables
- Secret charge comparisons no longer use bare `>` on opaque numbers
- Events that do not exist on a client are registered safely (no load errors)
- TTS SpeakText tries destination and overlap signatures across clients
- Classic spellbook scan via `GetNumSpellTabs` / `GetSpellBookItemInfo`
- Buff fade seeding falls back to `UnitAura` when `C_UnitAuras` is missing
- Toy / specialization / TTS events gated so Classic can load
- Non-combat utilities (skyriding, etc.) group under General
- Removed unused `quietUntilOffCooldown` default; DB.Get fills missing defaults

### Compatibility
- TOC Interface list covers Retail Midnight/PTR, MoP Classic, Cata, Wrath, TBC, Vanilla Era

## 1.0.0 — 2026-08-07

First public release (Blind Mice Gaming).

### Features
- Speaks when tracked cooldowns become ready (`Name ready.`) and when charges are gained
- Speaks when matched buffs fade (`Name faded.`)
- Own TTS queue with volume, rate, and voice controls
- Discovery: spellbook, action bars, pet, racials, teleports, hearth, toys
- Equipped trinkets / on-use gear and bag consumables
- Exclusive Cooldowns tab filters (Combat, Items, Pet, Racial, Teleport, Toys, General)
- Account-wide tracking profiles
- Combat-gated announces for combat CDs; General / Teleport / Toys announce out of combat
- Midnight secret-safe cooldown and aura handling
- Minimap button, key bindings, `/ca` slash commands

### Earlier development (pre-1.0)
- 0.6.x — Buff fades; secret-ID cooldown fixes; out-of-combat skyriding/general announces
- 0.5.x — Bag consumables (potions, flasks, food, bandages, healthstones)
- 0.4.x — Equipped trinkets and on-use gear (Items tab)
- 0.3.x — Exclusive filters, racials, teleports, toys, profiles
- 0.2.x — Core spell tracking and TTS ready/charge announces
