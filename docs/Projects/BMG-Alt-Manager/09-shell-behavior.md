# Shell behavior

Batch 1 of the data pack. Approved on 2026-10-29. Phase 1 in `BMGAM` follows this file.

The proposals in this file were accepted with batch 1: Escape does not close the window, the roster scrolls, and the first-open size is 1120 by 658 with a minimum of 860 by 505. `/bmgam` and `bmgam_SavedVariables` are locked.

## Opening

The window stays hidden until the player opens it.

- The minimap button opens and closes it.
- A left-click on the Titan Panel launcher named BMG Alt Manager does the same. That button is a LibDataBroker launcher, the same kind Everything Delves registers so Titan Panel can show it. The launcher id has no spaces, because Titan builds the bar button’s name from that id. A space in the name showed the button and dropped the click.
- The slash command `/bmgam` does the same. Charlotte locked it on 2026-10-29.

On open, the selected character is the one logged in. Overview is the active tab. Both of those are locked.

## Closing

Escape does not close the window. BMG Event Tracker uses that same rule, so a player hitting Escape to clear a target or a menu does not also dismiss the alt manager. Close is the red X.

## Roster

The left roster scrolls when the cards are taller than the window. Above the roster, Sort By offers Class, Faction, Item Level, Gold, Level, Race, and Realm. Order offers Ascending and Descending. Charlotte added that on 2026-10-30. The choice is saved on this flavor’s account block. Cards keep the four-line layout already approved. They are not squashed to fit.

The selected card keeps the brighter gold border.

## Size and position

First-open size: 1120 by 658.

The approved window drawing is 1600 by 940. That drawing is art, not a game window. 1120 by 658 is 70 percent of the drawing, so the roster and the right page keep the same proportions and the window can sit on a 1080p screen.

Minimum size: 860 by 505. Below that, the four-line cards and the tab row stop being readable.

The player can scale the window. Scale starts at 1. The anchor, the position, and the scale are remembered on this flavor’s SavedVariables. The next open uses the saved placement instead of the first-open size.

## Locked names

| Item | Name |
|------|------|
| Database | `bmgam_SavedVariables` in every flavor. Each client keeps its own copy |
| Slash command that opens the window | `/bmgam` |

## Not in this file

The settings page is approved in the layout file. Charlotte called phase 14 complete on 2026-10-31. The gold gear opens it, and no tab is lit. Reading aloud is only F6 or `/avread`, and it reads what is under the mouse. Search is on every tab except Gear, and those rules live in the layout file. The settings gear in the title bar is approved. This file says the window can be opened, closed, scrolled, and remembered. Escape does not close it. Hovering the minimap button says **BMG Alt Manager**.
