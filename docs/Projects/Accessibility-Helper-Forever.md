# Accessibility Helper - WoW Forever

| Field | Value |
|-------|--------|
| Status | **Shipped** |
| Version | **1.4.4** |
| Type | In-game addon (VI / TTS) |
| Folder | `AccessibilityHelper-forever/` |
| Clients | `_forever_` (wowf 1.60.1.70634, Interface 16001) |
| SavedVariables | `AccessibilityHelperForeverDB` |
| Slash | `/ah` window · `/ahtip` tooltip |
| Install | BMG Updater folder `AccessibilityHelper-forever` |

## Description

WoW Forever copy of Accessibility Helper. It is its own addon folder and saved-variables table, so it does not share settings with Retail or Classic. This version loads the new window, the tooltip reader, the status announcer, arrow reads, rewards, chat, and the combat page. The older combat, cursor, and quest readers are not loaded.

## Features

- Tooltip reader (`/ahtip`) speaks only when the read key is pressed. A later press stops that read. Holding the key does not start it again.
- `/ah` opens Tooltip, Speech, Status, Arrows, Rewards, Combat, and Chat. Click Rewards, Chat, or Combat to show or hide the section names under it. The arrow points down while they are showing and up while they are hidden. Combat starts quiet until Read combat is on. Status speaks profession skill, level-up, a learned recipe, a crafted item, follow, indoor and outdoors, swimming, flying, mount, AFK, a new location, red error text, and the condition lines when those switches are on. Commands lists the slash commands and key bindings. Arrows reads the TomTom arrow with `/ahtt`, `/aharrow`, `/ahtomtom`, or the TomTom keybind, and the Zygor arrow with `/ahz`, `/ahzygor`, or the Zygor keybind. Rewards speaks experience, reputation, currency, gold, loot, a completed quest, and an earned achievement. Chat Progress speaks achievement progress, quest progress, an accepted quest, and the open quest's description, objectives, and rewards. Chat NPC speaks the window, a merchant sale, and a repair. Chat Collections speaks item pickup and new collection items. Those lines are not printed.
- The older cursor, quest, and combat readers are not loaded. Combat uses the new Combat page. Quest text uses the Chat switches.

## Development plan

1.0.3 loads on WoW Forever in `_forever_` only. The toc allows game type `forever` (and `camelot`) and Interface `16001` for patch 1.60.1. The catalog row uses `client: "forever"`. Never install into `_classic_beta_`.

1.0.4 speaks skill, reputation, loot, currency, recipes, crafts, and level-up as short lines from the game state. Those lines are not printed. The first load turns those switches on so they can be heard. The other readers stay off.

1.0.5 replaces the settings window. `/ah` opens Tooltip, Speech, and Status. Tooltip sets the read key, addon-section reading, the compare window, and a switch for each loaded addon.

1.0.6 keeps the tooltip quiet until the read key is pressed. Holding that key no longer starts and stops the same tooltip over and over. The window does not speak when the mouse moves across a button.

1.0.7 stops loading the older readers. Follow, chat, combat, cursor, quests, and the old settings window no longer run. Level and experience stay in the status announcer.

1.0.8 adds follow, indoor and outdoors, swimming, flying, mount, and AFK to the status announcer. Each has its own switch. Login stays quiet until one of those states changes.

1.0.9 shows a written description when the mouse rests on a window option. Hovering an option does not start speech.

1.1.0 reads only the lines showing on the tooltip. It no longer adds the specialization, abilities, traits, or point count from the talent window around that tooltip.

1.1.1 reads those tooltip lines again. The talent-window labels stay out.

1.1.2 restores the tooltip read after 1.1.1 stayed silent. Talent-window labels are still left out.

1.1.3 puts the working tooltip gather back. Pressing the read key speaks the tooltip that was open. A bad line count no longer stops the read.

1.1.4 stores each window switch description when the mouse is on that switch. The read key speaks that description. Hovering still does not start speech. Opening the window still says the page name, such as “Tooltip.”

1.1.5 checks which switch is under the mouse when the read key is pressed and speaks that switch’s description. Clicking a page still says only the page name.

1.1.6 lets the first press finish. A key repeat was stopping the line before it could be heard. A later press, after that line has started, still stops it.

1.1.7 watches the saved read key itself. A press speaks the switch description, or says that no tooltip is showing.

1.1.8 adds the Chat page. The section names sit under Chat in the left panel. Each section fills the page with its switches. A description tooltip is on every switch. Read chat starts off so existing channel switches do not speak until it is turned on.

1.1.9 lets the left page list collapse and expand. The read key speaks only a switch that is on the open page. A switch on a hidden page is skipped.

1.2.0 adds Collapse under Chat. That hides Line, Town and trade, and the other Chat section names. Expand shows them again. The page list Collapse at the top of the panel is unchanged.

1.2.1 closes the tooltip reader function that was left open, so the addon loads again.

1.2.2 puts the mouse-frame loop back inside its loop, and finishes the read-key function that had been cut off. The saved read key is watched again.

1.2.3 closes the saved-settings check that was left open, so the addon can finish loading.

1.2.4 removes the Collapse and Expand buttons. Clicking the Chat header shows or hides the section names. The arrow points down while they are showing and up while they are hidden.

1.2.5 turns the Chat arrow around. It points down while the section names are showing and up while they are hidden.

1.2.6 replaces the single Channel switch on Line with General, Trade, Local defense, World defense, Services, and Other channels. Each one can be turned on or off.

1.2.7 takes those channels off Line. They stay under Town and trade, with Looking for group added. Other channels covers any channel that is not named there.

1.2.8 adds the Combat page. Read combat starts off. Fight speaks combat started and ended, an enemy targeting you, and your target's name. Health and power speaks health under 35 percent, main power under 35 percent, and a secondary power when it is low or full. Attacks speaks a cast aimed at you, an interrupt, and a dispel. Control speaks stunned, rooted, silenced, poisoned, possessed, polymorphed, crowd control, and other loss of control. Auras speaks a buff or debuff when it lands on you. Each switch has a description tooltip.

1.2.9 closes the window when Escape is pressed. The description tooltip is drawn above the window.

1.3.0 makes the read-key binding call the tooltip reader. Releasing the key does not read again.

1.3.1 adds the Rewards page. Experience says you gained an amount, then your experience is now the new total over the amount to the next level. Reputation says the amount gained with that faction, then the new amount over the amount to the next standing. A new standing says you have reached that standing with that faction. Currency and gold say the amount gained, then the amount you now have. Loot says you looted the item and the count. Quest complete and achievement earned start off. Chat gains Progress and Collections. Those switches start off, and Read chat does not have to be on.

1.3.2 adds quest accepted and quest details under Chat Progress. Quest accepted says the quest name. Quest details reads the offer or the quest selected in the log: the name, the description, the objectives, and the rewards. Chat NPC reads the window that opened, a merchant sale, and a gear repair. Those switches start off.

1.3.3 leaves the game menu key to the game. Escape still closes the helper window. The addon no longer calls the protected stop-casting function.

1.3.4 reads the TomTom arrow and the Zygor arrow from a keybind or a slash command. Those switches start on. Status gains New location. That switch starts off and speaks the place name when you enter it. Login stays quiet for about two seconds.

1.3.5 speaks a new location every time the place changes. A smaller place name is used when there is one. An area with no smaller name speaks the area name. A short wait no longer drops the next place.

1.3.6 adds Error messages on the Status page. It starts off. On, the red message in the middle of the screen is spoken. Out of range. Not enough mana. Spell is not ready yet stays quiet. The same message does not repeat for one second.

1.3.7 adds the rest of the status lines. Death, ghost, resurrect, taxi, resting, instance, bags, durability, money, breath, fatigue, stuck, falling, PvP, stealth, form, pet, and group. Each starts off. Commands is the last page. It lists the slash commands and the key bindings. `/ah commands` opens that page.

1.3.8 changes those spoken lines. Your Dead. Ghost. Your Resurrected. On Taxi. Taxi ended. Entered rested area. Left rested area. Instance is gone. Your bags are full, and bag space stays quiet. Durability is low under 25 percent, and Durability is Restored when gear is fully repaired. You gained 6 silver. You spent 2 gold. Your breathing is low under 35 percent, and Above water when the breath bar goes away. You are getting Fatigued when the bar appears, Your fatigue is low under 35 percent, and Fatigue is cleared when it goes away. Your falling after more than a second. PVP on. PVP off. Your in stealth. You are no longer stealthed. You have shifted into Bear Form. You shifted back. Wolf summoned. Wolf is dismissed. Wolf was healed. Wolf Revived.

1.3.9 adds three pet lines on that same switch. Wolf dead. Wolf health is under 35%. Feed Wolf when that pet is content or unhappy. Each speaks once until the pet recovers. Login stays quiet.

1.4.0 ships that same addon. The patch was already 9, so this bump moves the minor. Retail is this window under the name Accessibility Helper - Retail.

1.4.1 skips pet health when the game hides that number. The old check divided a secret health value and filled the error log.

1.4.2 no longer registers the combat log. That call was blocked. A mend still says the pet was healed when the mend cast succeeds.

1.4.3 speaks taming on the Pet switch. Hogger is getting tamed. Hogger is tamed. Hogger can't be tamed. Hogger is not allowed to be tamed. Spectral Gryphon cant be tamed needs Taming Rod to tame. A tame that starts and is then interrupted stays quiet.

1.4.4 says “Another pet is active.” when a tame fails because a pet is already out.

## Sources and data

Copied from `AccessibilityHelper/` at 3.6.5. Game state still comes from Blizzard APIs. Saved defaults live in `Core/DB.lua` and are stored in `AccessibilityHelperForeverDB`.

## What worked

On 2026-09-27 the tooltip reader spoke on Forever. The Retail and Classic addon already guards secret values and missing APIs with `pcall`, so the same feature files load on this client.

On 2026-11-10, v1.1.7, Numpad * speaks the tooltip again. The saved read key is watched directly. Clicking a page still says only the page name. Hovering stays quiet.

## What did not work

The read key spoke a switch from a page that was not open, because hidden switches still sat under the mouse. 1.1.9 speaks only a switch on the open page. The window switch descriptions were drawn on screen, and the read key did not speak them. 1.1.4 keeps that description with the switch and speaks it on the read key. A second tooltip key press could start the read again while the first one was still speaking. 1.0.2 stops speech when that same tooltip is still under the mouse. Holding the read key then started and stopped that line in a loop, and moving the mouse over a window button spoke that button again and again. 1.0.6 reads once per press. The older player-state reader was still loaded, so a saved Following switch kept saying “Following” and “Stopped following.” 1.0.7 does not load that reader.

## Open work

- Other status lines can be added on the Status page. The older cursor and quest readers are not loaded.
