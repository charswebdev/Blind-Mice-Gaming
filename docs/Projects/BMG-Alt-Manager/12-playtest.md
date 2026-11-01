# Playtest list

Batch 4 of the data pack. Approved on 2026-10-29. Phase 1 of `BMGAM` was copied into the retail AddOns folder on 2026-10-30. This file is still the check list, not the addon.

Use this list when a coding phase exists and Charlotte wants it tried. Check the rows for the phase that was just built. Later rows wait until that page exists.

## Roster and window

- Log an Alliance character and a Horde character. Each card shows the class icon, gold name, level, race, item level in quality color, server, side color, and the three coin amounts.
- Log a woman. The right header uses her race portrait, not the male portrait of that race.
- Open the addon on one character, then on the other. “Logged in now” shows only for the character who is logged in.
- Two characters on different realms both appear, even if they share a name.
- Add enough characters that the cards are taller than the window. The roster scrolls.
- Sort By changes the card order for Class, Faction, Item Level, Gold, Level, Race, and Realm. Order switches that list between Ascending and Descending. Reload and confirm the same choice is still selected.
- Escape leaves the window open. The red X closes it.
- Move and scale the window, reload, and confirm it comes back in that place at 1120 by 658 only on the first open.

## Gear

- One empty socket shows “Gem Slot: Empty socket”.
- A shirt, tabard, or trinket shows “Cannot be enchanted” and “Gem Slot: No gem slot”.
- An enchanted item shows “Enchant:” and the enchant name. A socketed gem shows “Gem Slot:” and the gem name.
- A ring with no enchant shows “Not enchanted”, not “Cannot be enchanted”.
- A neck, ring, trinket, shirt, or tabard shows “No durability”.
- One item under 25 percent durability shows a red bar. One from 25 percent up to 60 percent shows gold. One at 60 percent or above shows green.
- The slot name is a gold header above that item. Under it, the item name is the quality color, then the upgrade track and rank when the item has one, such as Hero 1/6.
- The durability line starts with the word Durability, then the bar, then the percent. At 0 it shows `0%` and `0 / maximum` in red. It does not say Broken.
- Every worn slot is on the page, in two columns. Shirt and tabard stay when they are empty. Midnight does not show a ranged slot.
- The icon is the client’s item icon.

## Bags, bank, and mail

- Bags match what that character is carrying after login.
- Hover a filled bag slot. The game’s item tooltip shows for that item. An empty slot does not. The snapshot does not contain the tooltip text.
- Type part of an item name in the Bags search box. Slots that do not match hide, and empty slots hide. Clear the box and the full bags come back.
- An alt who has never opened the bank shows “Not scanned yet”, not an empty bank.
- The Bank search matches names in the personal bank, the warband bank, and the guild bank. Clearing it shows the grids again.
- Open the personal bank, reload, and confirm those slots stayed.
- On Midnight, the warband bank is its own grid. Before it has been opened it says “Not scanned yet”. After it has been opened, every character on the account shows the same warband contents.
- The guild bank is its own grid. Before it has been opened it says “Not scanned yet”. After it has been opened, characters in that guild on that realm show the same guild bank.
- After login, a character with no new-mail notice shows “No new mail”. A character who has never been checked shows “Not scanned yet”.
- Login can show New mail and up to three sender names before the mailbox is opened. That row has no coins and no items.
- A letter sent to another character on this account shows on that character without that character opening the mailbox.
- An alt whose mailbox was opened and has no letters shows “Inbox is empty”.
- Days left count down after the mailbox closes. Fewer than 3 days is gold.
- An unread subject is bold. A letter with fewer than 3 days left shows those days in gold.
- Hover an attached item. The game’s item tooltip shows. The snapshot does not contain the tooltip text.
- Sent mail is not listed. Coins on a letter are the money attached to that letter, not the character’s purse.
- After login, the Auction page shows this character’s posted auctions and bids without opening the Auction House. Nothing posted says “No auctions”. Nothing bid says “No bids”. A character who has never been logged in says “Not scanned yet”.
- Posted rows show the item, time left, bid, and buyout. Bid rows show the item, that character’s bid, and the time left.
- A posted auction with no bid says “No bids”. One with no buyout says “None”. A sold auction is not listed.
- Reload. The saved rows stay. Time left matches the Auction House clock: 30 min, 2 hours, 12 hours, or 2 days.
- Type part of an item name in the Auction search box. Rows that do not match hide. Clear the box and the lists come back.
- Hover an auction icon. The game’s item tooltip shows. The snapshot does not contain the tooltip text. A stack of linen cloth shows the buyout for the whole stack, not the price of one cloth. Charlotte called this phase complete on 2026-10-31.

## Professions, currency, reputation, vault

These rows apply when that page exists.

- Two characters with the same profession. A recipe one has learned and the other has not shows as already known on one and missing on the other. The missing row names the character who knows it.
- Type a recipe name in the Professions search box. Rows that do not match hide. Clear the box and the full list comes back.
- On Midnight, every currency the client lists is shown, including a zero balance. That includes crests, Delve currency, older expansions, and the Unused section.
- Gold, silver, and copper on the Currency page are two rows. Character: shows that character’s coins on the right. Account Wide: shows the sum of every scanned character on the right. A character who has never logged in is not in that sum.
- On an older flavor, a currency with a zero balance is not listed.
- A reputation row shows the full faction name, Warband when the reputation is warbound, the bar, current/maximum, and the standing. Alliance and Horde stay on the character card, and they are also groups under Classic.
- A reputation that can be earned stays on the page at zero. Neutral with an empty bar stays.
- On Midnight, factions stay under the client’s headers. Renown and Level are the standing on the row. Delver's Companion is its own header. Delves seasons stay under their expansion. Captain Tokka, Slayer's Duellum, and Valeera Sanguinar stay under Silvermoon Court. A warbound reputation says Warband. There is no Friendship header. Paragon and renown rewards are not shown. Charlotte called this phase complete on 2026-10-31.
- On an older flavor, a Renown, Delver Companion, or Warband header that client does not have is absent.
- On Quests, the order is Current Quest, then Completed Quest. Current Quest has Character. Completed Quest has Character, then Warband. Character lists quests that character finished. Warband lists account-wide quests, not every other character’s quest log. A finished quest takes its zone from Quest Completist when that addon is installed, then from the client’s quest-pin table, then from BtWQuests when that addon is installed. A Rumble appearance quest and a Renowned renown quest stay on Warband. A quest titled Tracking Quest, or titled only Level and a number, is left off. A quest that still has no zone stays on the list. Under each, the groups are world, then content, then zone, such as Azeroth, Northrend, and Borean Tundra. Quest names sit under the zone. There is no Quest header. Headers are bold gold and start open. An open header points down, and a closed header points up. Level stays on the quest row. A completed row also shows the date. Level shows the quest level, and Dungeon, Raid, Scenario, or Delve when the client marks it that way. Date is filled when a quest is turned in while this addon is loaded. Older finished quests leave the date blank. Search matches quest names in both parts, and a header with no match hides. A character who has never been logged in says Not scanned yet. No current quests says No quests. An empty Character or Warband list says No quests. The list scrolls when it is taller than the page.
- On Achievements, the categories match the achievement list: the same names, the same parents, and the same order. Statistics are not on this page. A category starts closed. An open header points down, and a closed header points up. An earned achievement shows the date and the character who earned it. When that character cannot be determined, Who says Account Wide. Earned and unearned achievements are both listed, including a character achievement and a warband achievement. A meta achievement is in the list with the others. An achievement that is not earned shows its progress on the row, such as 4/12. Hover it. The tooltip shows that status and each requirement, and a finished requirement is dim. Hover an achievement name. The client’s full achievement tooltip opens beside the name. Hover a quest name. The client’s full quest tooltip opens beside the name. An earned achievement name is bold bright green. An achievement that is not earned has a bold yellow name. Click an achievement. Its steps open. A finished step shows the date. A step that is not finished shows what is left, in white. An objective wraps onto extra lines so the whole sentence can be read. Got My Mind On My Money is one achievement, and its gold steps are inside it. Search matches achievement names and category names. A character who has never been logged in says Not scanned yet.
- On Collections, Collected is the first header and Not Collected is the second. Both start closed. Under each, Mounts, Manuscripts, Pets, Transmog, Transmog Sets, Toys, and Decor start closed. A type that client does not have is left off. Manuscripts is listed on every character. Druid forms are under Bear Form, Cat Form, Moonkin Form, Travel Form, Flight Form, Aquatic Form, Treant Form, and Mount Form. Hunter tomes are under each pet family. A family a hunter's race already knows counts as collected only on a hunter. Every item in those types is listed, collected or not. A row shows the client’s icon and the name. A collected name is bold in its quality color. A name that is not collected is bold bright yellow. Click a name. How to obtain it opens in white, and the line wraps so the sentence can be read. Hover a name. The client’s tooltip opens when the client has one. Search matches names and that obtain text. A character who has never been logged in says Not scanned yet. Nothing in these lists says No collections.
- On Midnight, the vault shows each activity as a row, and its slots go left to right. A locked slot is visible. A slot does not show 1, 2, or 3. A ready slot says Tier: and the tier number, then Item Level: and the reward item level, in bold bright green with a bright gold-yellow border. A locked slot shows progress such as 4/8, in bold cream with a dull gold border. There is no Taken state. The items inside a ready slot are not shown.
- On Era, Anniversary, MoP, and Forever, the Vault tab is not shown. The other tabs stay in one row.
- Hover the trash can on the selected character’s name line. The tooltip says “Forget this character”.
- Click the trash can. The character stays until Forget is chosen. Cancel closes the box and keeps the character. Forget removes that character from this flavor only.
- On Settings, the gold gear opens the page and no tab is lit. **Import** opens a popup with an empty text field and the cursor in that field. **Load** replaces this flavor’s stored data. **Close** leaves the data as it is. A code that cannot be read leaves the data as it is.
- On Settings, **Export** opens a popup with the code of this flavor’s stored data, and that page is already selected. If the backup is longer than the box, Next shows the next page. Copying it does not change the data. On Import, Add each copied page, then Load.
- In WoW’s Key Bindings window, BMG Alt Manager is the section name. Open or close is a command with no default key. Read under the mouse is the other command, and its default key is F6. Hover Class and press F6. It speaks Class and that character’s class, not the window title or the sort row. Hover a tooltip, a Titan Panel button, or a unit and press F6. The client speaks that text. Assign a key to Open or close and confirm it shows and hides the window.
- In Titan Panel, add the launcher named BMG Alt Manager. If an older BMG Alt Manager button is already on the bar and a click does nothing, remove that one and add BMG Alt Manager again. Left-click opens and closes the window. The tooltip says BMG Alt Manager.
- Clicking Show minimap button switches it between On and Off, and the row shows the state it is in now.
- Selecting a character opens Overview. Class, Hero, Specialization, and the stat labels are bold bright yellow. The names and numbers beside them are bold bright white. The Guild header is bold gold, and the guild name is bold bright white. A character with no guild says Not in Guild in that white.
- Hearthstone Location is the next header after Guild, aligned to the left like the other headers, and shows where that character’s hearthstone is set. Under that, Delver's Journey sits beside Prey, then Traveler's Journey. The first three show that character’s progress and rank. Each heading line sits below its title.
- On Overview, a talent row is the client’s icon and a bold bright yellow name. Only talents the player has taken are listed. Hovering the name shows the client’s full talent tooltip. The snapshot does not contain the tooltip text.

## Forever

No Forever check until that flavor is being built. Do not install a Forever addon into `_classic_beta_` or `_retail_`.
