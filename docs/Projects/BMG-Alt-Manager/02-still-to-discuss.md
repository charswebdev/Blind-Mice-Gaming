# Still to discuss

The implementation plan was approved on 2026-10-29. The Gear, Bags, Bank, Professions, Currency, Reputation, Mail, Vault, Overview, and Settings page pictures were approved the same day.

Nothing in this file is permission to build.

## Gear — picture approved

The approved reference is [gear-page-full.jpg](reference/gear-page-full.jpg). It is the roster plus a two-column gear list.

Approved row:

1. Real item icon from the WoW client, with the item’s quality border. The slot name sits beside it. The item name uses the quality color.
2. Durability as current/maximum and a bar. Green at 60% and above. Gold from 25% up to 60%. Red under 25%. Items with no durability say **No durability**.
3. Enchant name when one is present. **Not enchanted** in gold when the item can take an enchant and does not have one. **Cannot be enchanted** in dim text when it cannot.
4. Gem name in the gem’s color when a socket is filled. **Empty socket** in gold when a gem can still be added. **No gem slot** in dim text when a gem cannot be added. An item with two sockets shows both, as the chest does in the drawing.

Charlotte locked three Gear rules on 2026-10-29:

- A slot with nothing equipped stays on the page. Where the item name would be, the row says **Empty Slot**. There is no durability bar, enchant line, or gem line.
- An item at 0 durability does not say Broken. The row shows `0 / maximum`, such as `0 / 100`. That pair is the durability percent. The bar and the numbers are red, because 0 is under 25 percent.
- The ranged slot is shown only on a flavor whose client has it. Midnight and MoP do not show it. Era and Anniversary do. Forever shows it only if that client has the slot. On a flavor that has it, an empty ranged slot still says **Empty Slot**.

## Bags — picture approved

The approved reference is [bags-page-full.jpg](reference/bags-page-full.jpg). Charlotte approved it on 2026-10-29. It is the roster plus the Bags page. The Bags tab is the only lit tab.

The page in that drawing:

- One section per bag the character is carrying, in this order: Backpack, then the equipped bags, then the Midnight reagent bag. A bag slot with no bag equipped is left out. Older flavors have no reagent bag.
- Each header shows the bag icon in that bag’s quality color, the name in bold gold, and how full it is, such as 16 / 20. The backpack is not an item, so its icon stays cream.
- Filled slots are the item icon with a quality-colored border. A stack bigger than 1 shows the count in the corner. Empty slots are dark boxes, so free space stays visible. Item names are not printed on the grid.
- Worn gear stays on the Gear page.
- A search box sits under the tabs. It matches item names on this page. The box in the picture is empty and shows the placeholder Search. Typing hides slots that do not match, and hides empty slots. Clearing the box shows every slot again.
- Hovering a filled slot shows the game’s item tooltip: name, item level, binding, slot and type, damage or armor, stats, durability, requirements, and sell price, for whatever the client knows about that item. The bag item in a header does the same. An empty slot has no item tooltip. The backpack header has no bag item, so it does not.

The tooltip in the drawing is open so the hover can be seen. It is not a panel that stays on the page.

The tooltip text is not stored. The page asks the client to show the tooltip for the item link that was saved at scan time.

## Bank — picture approved

The approved reference is [bank-page-full.jpg](reference/bank-page-full.jpg). Charlotte approved it on 2026-10-29.

- Personal bank first, then the Midnight warband bank, then the guild bank. Each is its own grid, with the same slot look as Bags. Empty slots stay visible. Each header collapses and expands.
- On Midnight, the warband bank is shared by the account and saved once. It was locked on 2026-10-29.
- Updated only while that bank is open. The guild bank is updated only while the guild bank is open.
- A bank that has never been opened says **Not scanned yet**. The guild bank in the picture says that.
- The search box matches item names in the personal bank, the warband bank, and the guild bank. Same hide-and-restore rules as Bags.
- The counts in the picture, 18 / 28 and 22 / 40, are a sample. The client supplies the real size.

## Professions — picture approved

The approved reference is [professions-page-full.jpg](reference/professions-page-full.jpg). Charlotte approved it on 2026-10-29.

The page in that drawing:

- One section per profession. The header is the profession icon, the name in bold gold, and the skill, such as 85 / 100. Midnight can also show an extra rank when that client has one.
- Learned recipes are listed by name. A recipe another scanned character knows, and this one does not, is gold and says **Missing**.
- If another character knows a recipe, that character’s name is on the row. More than one name is listed. The selected character’s own name is not repeated on that row.
- A profession window that has never been opened on this character says **Not scanned yet**.
- Cooking and fishing sit in this list when that character has them. Archaeology is included only on a client that still has it.
- A search box sits under the tabs. It matches profession names and recipe names on this page. The same hide-and-restore rules as Bags apply. The picture shows the box empty.
- Profession tools and cooldowns stay off this page.

The names in the picture, Lyra, Sylas, and Vex, are the other characters on the sample roster. Ares is the character the page is showing.

## Currency — picture approved

The approved reference is [currency-page-full.jpg](reference/currency-page-full.jpg). Charlotte approved the page on 2026-10-29, then approved the two money rows the same day. The coin-stack picture is [tab-currency.jpg](reference/tab-currency.jpg).

The Dragonflight header in the picture is a sample older expansion. Trader’s Tender at 450 and Honor at 2,500 are sample amounts. A live scan uses the client’s names and amounts.

Locked on 2026-10-29:

- Each row is the currency icon, the name, and the amount. The amount is **bold**.
- Gold, silver, and copper stay on the character card. The Currency page also shows them at the top, on two rows, with the coins on the right. The first row says Character:. The second says Account Wide:. The account amount is the sum of the money saved for every character on this account. A character who has never been scanned is not in that sum. In the sample, the rows read Character: 50g 12s 34c and Account Wide: 470g 57s 63c.
- Headers are **bold**, so a player can see which expansion a currency belongs to.
- The current expansion is its own header. On Midnight that header lists every current-expansion currency, including a zero. That includes crests, Delve currency, Catalyst currency, profession currency, Nebulace cores, and the rest of the current expansion.
- Each older expansion that this character has currency for is its own bold header. A zero from an older expansion is left off.
- Currencies that are not from an expansion sit under a bold **Other** header. Trader’s Tender is one. PvP currencies such as Honor are another. Honor’s row says Honor, and the row shows that it is PvP.
- A Midnight character also shows any other currency that character actually has.
- Older flavors list only currencies that character has, under the same kind of headers. A zero balance is left off.
- Inside a header, the rows follow the client’s own order.
- A shared currency shows on every character with the same amount, and the row says **Account**.

Still to decide:

- The search box, matching the Bags, Bank, and Professions pages.

## Reputation — picture approved

The approved reference is [reputation-page-full.jpg](reference/reputation-page-full.jpg). Charlotte approved the rules, then approved this drawing, on 2026-10-29. She approved the Delver Companion header and the Warband header on 2026-10-30. There is no Friendship header. The medal picture is [tab-reputation.jpg](reference/tab-reputation.jpg). The Reputation tab is the only lit tab. A search box sits under the tabs and matches the names on this page.

Ironforge, Gnomeregan, Bloodsail Buccaneers, the Dragonflight row, Second Renown, and Sample Companion are picture samples. A live scan uses the client’s names, standings, and amounts. Stormwind at Exalted, 42,000 / 42,000, and Sample Renown at Renown 12 of 20 are the data-pack samples. Sample Companion at Level 8 of 10 is a picture sample.

Locked on 2026-10-29:

- Each faction by its full name. Names are not cut off. Alliance and Horde stay on the character card.
- The row is the name, the standing, a bar, and current / maximum. The standing word and the bar use the client’s standing color. The name stays cream. Friendly through Exalted are green. Neutral is yellow. Hostile and Hated are red. Unfriendly is orange.
- Standard factions sit under the client’s own group headers. Inside a header, the rows follow the client’s order.
- A faction the client does not list is left off. A listed faction at Neutral with an empty bar stays on the page.
- On Midnight, renown sits under a bold Renown header, Delver Companion under a bold Delver Companion header, and warband reputation under a bold Warband header. Renown keeps its own label, such as Renown 12. Delver Companion shows a level, such as Level 8. They are not drawn as Exalted. There is no Friendship header. A flavor that does not have one of those headers leaves it off.
- A faction the client reports as shared says Account on the row. A warband faction says Account.
- Paragon and renown rewards stay off.

## Mail — picture approved

The approved reference is [mail-page-full.jpg](reference/mail-page-full.jpg). Charlotte approved the rules, then approved this drawing, on 2026-10-29. The envelope picture is [tab-mail.jpg](reference/tab-mail.jpg). The Mail tab is the only lit tab. A search box sits under the tabs and matches the names on this page.

The letters in the picture are samples, in a sample of the client’s inbox order. A live scan uses the client’s senders, subjects, days left, coins, and items. Lyra, Vex, and Sylas are roster names used here as senders.

Locked on 2026-10-29:

- Inbox only. Sent mail stays off. Cash-on-delivery stays off.
- One row per letter. Sender and subject stay on the left and are not cut off. Days left sit on the right. An unread subject is bold.
- Days left stay cream until fewer than 3 days remain, then they turn gold.
- Attached coins use the gold, silver, and copper icons. That money is the letter’s, not the character’s purse.
- Attached items use the client’s icon, a quality border, and a stack count when there is more than one. Hovering an item shows the client tooltip from the stored link. The tooltip text is not saved. The picture’s tooltip, Ring of the Vale, is a sample.
- A letter with no items and no coins still shows.
- A character who has never been checked says “Not scanned yet”. A login check with no new-mail notice says “No new mail”. A mailbox that was opened and has nothing in it says “Inbox is empty”.
- Login shows the new-mail notice and up to three sender names. A letter sent to another character on this account is saved on that character when it is sent. The full inbox is read while the mailbox is open, and the days count down afterward. Charlotte added that on 2026-10-31.

## Vault — picture approved

The approved reference is [vault-page-full.jpg](reference/vault-page-full.jpg). Charlotte approved the rows and the gold borders on 2026-10-29. The door picture is [tab-vault.jpg](reference/tab-vault.jpg). The Vault tab is the only lit tab. A search box sits under the tabs and matches the names on this page. Midnight only. The other flavors do not get this tab.

Raids, Dungeons, and World, and every tier, item level, and count in the picture, are samples. A live scan uses the client’s column names, tiers, item levels, and requirement lines.

Locked on 2026-10-29:

- All 9 slots. Each activity is a row. Its three slots go left to right, in the client’s order. Slot 1 is the first reward. Slot 3 is the last.
- Each slot shows Locked or Ready, the tier, the item level, and the client’s requirement line. There is no separate progress bar. There is no Taken state.
- A locked slot stays on the page. Locked text is bold cream, with a dull gold border. Ready text is bold bright green, with a bright gold-yellow border. A slot that has met its threshold stays Ready. The page does not try to show that the reward was already collected.
- The items you choose from inside a ready slot stay off. Mythic+ history stays off.
- The snapshot is saved when that character logs in.

## Settings — picture approved

The gold gear was approved on 2026-10-29 and sits to the left of Close: [settings-button.jpg](reference/settings-button.jpg). Tooltip says Settings.

The approved page is [settings-page-full.jpg](reference/settings-page-full.jpg). Charlotte approved this drawing on 2026-10-29, including the Export / Import header. No tab is lit. Settings opens from the gear.

- Show minimap button. A click turns it On or Off. The row shows the state it is in now. The picture is On. The button uses the addon icon, the gold vault and the mouse. That same picture is also the icon in WoW’s addon list.
- Reading aloud happens only when the player presses the keybinding, or types `/avread`. It reads what is under the mouse. Nothing is read on its own.
- In WoW’s Key Bindings window the section is named **BMG Alt Manager**, the same way the other addons name their section. The command under it is **Read under the mouse**. The default key is F6. F1 through F5 target the party. F8 through F12 open bags. F6 and F7 have no Blizzard default. Ctrl+F6 is already a special action button, so the default is F6 by itself. Scroll Lock and Pause cannot be set in WoW’s keybind window. I, J, and Y are free in classic and taken on retail, so they are not the default. A player who already uses F6 keeps that binding and can pick another key here.
- **Export / Import** is a header on this page, with two buttons: **Import** and **Export**. **Import** opens a popup with an empty text field, and the cursor is in that empty field. The player pastes a code there. Loading that pasted code replaces this flavor’s stored data. Closing the popup without loading leaves the stored data as it is. A code that cannot be read does not change the stored data. **Export** opens a popup that shows the code of this flavor’s stored data, and that code is already selected. Copying it does not change the stored data. The code is text. The exact letters are chosen when this phase is built, and they must load back into the same records. The settings picture shows the header, both buttons, and both popups so the two fields can be seen. In the addon, only the popup for the button that was clicked is open. `BMGAM-sample` is a picture sample.

Not on this locked page:

- A row for window position and scale. The window already remembers these.
- `/bmgam` opens the window. Charlotte locked it on 2026-10-29. `/avread` is only the read command.
- Search is not a Settings row. Every tab except Gear already has a search box. Settings has none.
- Which tabs are visible. A flavor hides a tab it does not have. That is not a row on this page. Midnight shows all thirteen. The other flavors hide Vault.
- Forgetting a character. The trash can is on the character name line. Charlotte approved that icon on 2026-10-29. It is not a row on this page.

## Overview — picture approved

The approved reference is [overview-page-full.jpg](reference/overview-page-full.jpg). Charlotte approved this drawing on 2026-10-29. The icon is [tab-overview.jpg](reference/tab-overview.jpg), a gold helmet and breastplate. The Overview tab is the only lit tab. It sits before Gear. This is the page shown when a character is selected.

Every full-page picture uses the thirteen-tab row. Overview is first. Vault is last. Only the open page’s tab is lit. Gear has no search box. Every other tab has one.

On the sample, for Ares:

- Labels are bold bright yellow, about `(255, 236, 64)`. The name or number beside the label is bold bright white. That split is Class, Hero, Specialization, and each stat. Talent names stay bold bright yellow. Stats, Talents, Hero talent, and Specialization talent headers stay the existing gold.
- Class: Warrior. Hero: Sample Hero. Specialization: Arms. Hero, specialization, the stat numbers, and the talent names are picture samples. A live scan uses the client’s names and numbers.
- Stats are Strength, Stamina, Armor, Critical Strike, Haste, Mastery, and Versatility, with the number on the right.
- Guild has its own header. The header label Guild is bold gold. The guild name under it is bold bright white. This sample has no guild, so the name line says Not in Guild in that same white. A real guild name uses the same style.
- Under Guild, four headers: Delver's Journey, Prey, Traveler's Journey, and Hearthstone Location. Charlotte approved this drawing on 2026-10-29. They sit in two rows. Delver's Journey is beside Prey. Traveler's Journey is beside Hearthstone Location. Each heading line sits below its title and clear of the line under it.
- Delver's Journey, Prey, and Traveler's Journey each show progress and rank. The progress label is bold bright yellow. The current / maximum and the rank number are bold bright white. The word Rank is bold bright yellow. The picture uses Delver's Progress 2800 / 4200 Rank 2. Prey Progress 800 / 1600 Rank 1 and Traveler's Journey Progress 1500 / 3000 Rank 3 are picture samples.
- Hearthstone Location shows the place in bold bright white. This sample says Stormwind City. That place is a picture sample.
- Then three lists: Talents, Hero talent, and Specialization talent. A row is the client’s talent icon and the talent name in bold. Only talents the player has taken are listed.
- Hovering a talent name shows the client’s full talent tooltip, the same kind of tooltip Light Paws Loadouts shows: the name, the description, and the rank. The tooltip text is not stored. The picture leaves one tooltip open so the hover can be seen.

## New tabs

Charlotte approved these pictures on 2026-10-29. Every full-page reference uses the thirteen-tab row. The older gear-list picture, which had no tab row, was removed.

Tab order after Mail: Auction, Quests, Achievements, Collections, then Vault. The icons are smaller so thirteen tabs fit. Gear has no search box. Every other tab has one. Every section header collapses and expands. The title of every expandable header is bold gold on every tab page. Charlotte approved that header color on the Overview, Bags, Professions, and Bank pictures on 2026-10-30. On these four pages the column labels under a section are bold white.

- Auction: [auction-page-full.jpg](reference/auction-page-full.jpg), approved on 2026-10-29. Icon [tab-auction.jpg](reference/tab-auction.jpg), a gold gavel. Auctions and Bids are bold gold. Column labels are bold white. Posted auctions show the item, time left, bid, and buyout. Bids show the item, that character’s bid, and the time left. Read on login. The Auction House does not have to be opened. Charlotte asked for that on 2026-10-31.
- Quests: [quests-page-full.jpg](reference/quests-page-full.jpg), approved on 2026-10-30. Icon [tab-quests.jpg](reference/tab-quests.jpg), a rolled scroll. **Current** is a bold gold header. Quests that character is on are grouped by zone under it. **Completed** is a bold gold header. Finished quests are grouped by zone under it. A row is the quest name and its level. Search matches both parts.
- Achievements: [achievements-page-full.jpg](reference/achievements-page-full.jpg), approved on 2026-10-30. Icon [tab-achievements.jpg](reference/tab-achievements.jpg), a gold trophy. Category headers are bold gold. A row is the name, the points, and Earned or Not earned.
- Collections: [collections-page-full.jpg](reference/collections-page-full.jpg), approved on 2026-10-30. Icon [tab-collections.jpg](reference/tab-collections.jpg), a glass display case. Headers: Mounts, Manuscripts, Pets, Transmog, Transmog Sets, Toys, Decor. Manuscripts are druid form unlocks and hunter pet-family tomes. A row is the item icon beside the name, Collected or Not collected, and Account when that collection is account-wide. A header that client does not have is left off.
- Guild bank is a section on the Bank page, after the warband bank. It is scanned only while the guild bank is open. The picture says Not scanned yet.
- Sharing snapshots across accounts stays out. Charlotte locked that on 2026-10-30. One Battle.net account’s saved characters do not appear on a different Battle.net account.

The names in those pictures are samples.

## Plan questions still open

There is no open design question. Search is on every tab except Gear. Settings is not a tab and has no search box.

Hiding a tab the flavor does not have is locked. Midnight shows Overview, Gear, Bags, Bank, Professions, Currency, Reputation, Mail, Auction, Quests, Achievements, Collections, and Vault. Era, Anniversary, MoP, and Forever leave Vault out. The other tabs stay in one row. This is not a Settings choice, and a player cannot hide a tab that flavor has.

## Forget a character

The drawing is [forget-character.jpg](reference/forget-character.jpg). Charlotte approved the icon on 2026-10-29. The approved Overview picture is unchanged.

- The trash can sits on the far right of the selected character’s name line, the same line as the gold name. It is a dark iron button with a bright gold border. The can is dimensional gold, with the lid tilted open. The button file is [trash-button.jpg](reference/trash-button.jpg).
- When this is built, hovering the trash shows a tooltip that says **Forget this character**.
- Clicking the trash does not remove the character yet. A confirmation box opens. The picture shows that box open so the words can be checked. It is not always on the page.
- The box says **Forget Ares?** then **Remove Ares from this roster?** then **The character in the game is not deleted.** The buttons are **Forget** and **Cancel**. A live character uses that character’s name.
- **Cancel** closes the box and keeps the snapshot. **Forget** removes that character from this flavor’s SavedVariables. It does not delete the WoW character. It does not touch another flavor’s copy.

Reading aloud is in the first Midnight version. It is only F6 and `/avread`. The approved pages use the dark panel and gold trim, so that is the addon’s style.
