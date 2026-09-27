# Accessibility Helper - WoW Forever

| Field | Value |
|-------|--------|
| Status | **Shipped** |
| Version | **1.0.2** |
| Type | In-game addon (VI / TTS) |
| Folder | `AccessibilityHelper-forever/` |
| Clients | `_classic_beta_` (ForeverBeta) |
| SavedVariables | `AccessibilityHelperForeverDB` |
| Slash | `/ah` settings · `/ahtip` tooltip · `/ahcmds` |
| Install | BMG Updater folder `AccessibilityHelper-forever` |

## Description

WoW Forever copy of Accessibility Helper. It is its own addon folder and saved-variables table, so it does not share settings with Retail or Classic. The same readers are included. On a new install only the tooltip reader is on. The other readers are in `/ah` and stay quiet until the player turns them on.

## Features

- Tooltip reader (`/ahtip`) is on by default. Item compare and Titan Panel tooltip reading start off. Pressing the tooltip keybind again on the same tooltip stops that read. A different tooltip starts a new read.
- Key bindings are under **Accessibility Helper - WoW Forever**: tooltip, under mouse, TomTom, Zygor, settings, target distance, read target, stop, repeat, quest objectives, and quest window.
- The same speech queue, secret-value checks, and alert delivery (TTS, sound, or both) as Accessibility Helper 3.6.5.
- Chat, under-mouse text, cursor, distance, facing, subzone, UI errors, loot, quests, player state, combat, casts, and progress are included and start off.
- TomTom and Zygor reads work only when those addons are installed.
- Minimap button opens settings. Keybind category is **Accessibility Helper - WoW Forever**.

## Development plan

1.0.2 is the first Forever package in the updater: the 3.6.5 readers, Forever interface numbers, and tooltip-only defaults. The catalog row uses `client: "forever"` so it installs into `_classic_beta_`.

## Sources and data

Copied from `AccessibilityHelper/` at 3.6.5. Game state still comes from Blizzard APIs. Saved defaults live in `Core/DB.lua` and are stored in `AccessibilityHelperForeverDB`.

## What worked

On 2026-09-27 the tooltip reader spoke on Forever. The Retail and Classic addon already guards secret values and missing APIs with `pcall`, so the same feature files load on this client.

## What did not work

A second tooltip key press could start the read again while the first one was still speaking. 1.0.2 stops speech when that same tooltip is still under the mouse.

## Open work

- Other readers stay off until the player turns them on in `/ah`.
