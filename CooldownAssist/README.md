# Cooldown Assist

Cooldown readiness announcer for **blind and visually impaired** World of Warcraft players (Midnight retail).

Built by **Blind Mice Gaming**. Speaks short lines like `"Barkskin ready."` and `"Barkskin faded."` using its own TTS queue (independent of Accessibility Helper speech).

## Requirements

- World of Warcraft **Retail** (Midnight) or **Classic flavors** (Era, Cataclysm, MoP Classic, etc.)
- Blizzard Text to Speech enabled in game options (where available)

Retail-only features (toys, modern spellbook skill lines, some teleports) degrade gracefully on Classic.

## Install

1. Copy the `CooldownAssist` folder into:
   `World of Warcraft\_retail_\Interface\AddOns\`
2. Restart the client or `/reload`
3. Confirm the addon is enabled on the character select AddOns list

### Packaging zip layout

```
CooldownAssist/
  CooldownAssist.toc
  README.md
  CHANGELOG.md
  Core/
  Trackers/
  UI/
  Media/
  Bindings.xml
```

Zip the **folder**, not loose files. Do not include `.cursor`, agent transcripts, or SavedVariables.

## Quick start

| Command | Action |
|---------|--------|
| `/ca` | Open settings |
| `/ca c` | Speak currently ready tracked cooldowns (works out of combat) |
| `/ca scan` | Rescan bars / spellbook / items |
| `/ca rebuild` | Clear and rebuild discovery |
| `/cas` | TTS test |
| `/ca help` | Full command list |

## What it tracks

- Class / combat abilities, racials, pet abilities
- Teleports, hearthstone, toys, skyriding / general utilities
- Equipped trinkets and other on-use gear
- Bag consumables (potions, flasks/phials, elixirs, food, bandages, healthstones)
- Buff fades for enabled tracked spells/items

Cooldowns under **5 seconds** are ignored. Filters on the Cooldowns tab are exclusive (only **All** shows every group).

## Announce rules (defaults)

- **Combat** cooldowns announce while you are in combat
- **General / Teleport / Toys** (including skyriding) announce anytime
- Toggle **Announce combat cooldowns only in combat** off to announce everything anytime
- Profiles save per-tracker enable/disable sets account-wide

## Accessibility Helper

Cooldown Assist does **not** route speech through Accessibility Helper. Use Accessibility Helper for tooltips, chat, and other VI features; use Cooldown Assist for cooldown readiness.
