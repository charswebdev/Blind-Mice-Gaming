# Light Paws Loadouts - WoW Forever

| Field | Value |
|-------|--------|
| Status | **Shipped** (1.0.0 package; playtest on ForeverBeta) |
| Version | **1.0.0** |
| Type | In-game composite loadout vault |
| Folder | `lpl-forever/` |
| Clients | `_classic_beta_` (live ForeverBeta) · fallbacks `_forever_` / `_wow_forever_` / `_camelot_` · Interface `16001`, `121500`, `121000` |
| SavedVariables | `LPLForeverDB` (must not clobber Retail `LPLDB`) |
| Slash | `/lpl` |
| Optional | LibTalentTree-1.0 (bundled) |

## Description

WoW Forever sibling of Retail **Light Paws Loadouts**. Forever is Mainline (Camelot) next to Midnight, so this package clones the Retail vault — talents, action bars, keybinds, gear, PvP talents, Cooldown Manager, Edit Mode, conditions, macros, addon sets, addons manager, and Housing Blueprints — with its **own folder and SavedVariables**.

Do not install this into `_retail_`. Do not install Retail `lpl/` into `_classic_beta_`.

## Features

- Same module set as Retail LPL 1.1.6 (the committed tree this package was forked from).
- Midnight-style `C_Traits` / hero trees, share strings, composite loadouts.
- Housing Blueprints tab (Forever has Housing).
- Flavor identity in `Core/Flavor.lua` (`id = "forever"`).
- Updater row `client: "forever"` so install targets the Forever product folders.

## Development plan

1. Product locks (folder, SavedVariables, TOC `16001` + 12.x, updater `client`) — done.
2. Clone Retail vault (not Era 3-tree talents) — done.
3. Playtest on live ForeverBeta (`WowB.exe` / `_classic_beta_`).
4. Desktop LPLM / LPTM Forever stay **later** until assigned.

## Sources and data

- Retail LPL committed tree (`lpl/` at 1.1.6).
- Forever client notes: [`docs/WOW Forever/WOW Forever.md`](../WOW%20Forever/WOW%20Forever.md).
- Bundled LibTalentTree-1.0.
- No Classic talent CSV in this tree.

## What worked

- Separate folder + `LPLForeverDB` so Retail and Forever can both be installed.
- Reusing Retail modules because Forever shares Midnight addon APIs (secrets, Edit Mode, Housing).
- Same TOC interface list as BMG Unit Frames Forever (`16001`, `121500`, `121000`).

## What did not work

- Treating Forever as Classic Era / Anniversary FrameXML — it is Mainline.
- One zip shared with Retail — Interface `121500` would also match a naive “Retail = 100000+” check.

## Open work

- In-game playtest on ForeverBeta: `/lpl`, talent apply, bars, housing paste.
- Watch for a Battle.net folder rename to `_forever_` / `_wow_forever_` / `_camelot_`.
- Desktop LPLM / LPTM Forever not started.
- Uncommitted dirty files in Retail `lpl/` were **not** copied into this tree.
