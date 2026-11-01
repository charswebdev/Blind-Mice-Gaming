# Implementation plan

Charlotte approved this order on 2026-10-29. No page is filled in until that page’s talk is approved. No addon file is created until she says to start a phase.

The work stays in small phases. A phase ends when that slice can be opened in the client and checked, before the next slice starts.

## Flavors

| Order | Flavor | Client folder | Vault tab |
|-------|--------|---------------|-----------|
| 1 | Midnight (retail) | `_retail_` | Yes |
| 2 | Classic Era, including Hardcore | `_classic_era_` | No |
| 3 | Anniversary | `_anniversary_` | No |
| 4 | Classic (MoP) | `_classic_` | No |
| 5 | WoW Forever | `_forever_` | No |

Season of Discovery is not a flavor of this addon. `_classic_beta_` is never used. Forever installs only into `_forever_`.

Each flavor is a separate addon. It has its own folder, its own `.toc`, its own SavedVariables, and, when it ships, its own updater row. One zip must not install onto two clients.

Charlotte locked the folder name **BMGAM** and the SavedVariables name **bmgam_SavedVariables** on 2026-10-29. Midnight’s addon folder is `BMGAM`, and its toc file is `BMGAM.toc`. Each other flavor uses that folder name plus its suffix, so the zips stay separate. Each flavor still has its own database, because each addon is installed in a different client. The SavedVariables global in every toc is `bmgam_SavedVariables`. The slash command that opens the window is `/bmgam`.

| Flavor | Folder | SavedVariables |
|--------|--------|----------------|
| Midnight | `BMGAM` | `bmgam_SavedVariables` |
| Era | `BMGAM-classic-era` | `bmgam_SavedVariables` |
| Anniversary | `BMGAM-anniversary` | `bmgam_SavedVariables` |
| MoP | `BMGAM-classic` | `bmgam_SavedVariables` |
| Forever | `BMGAM-forever` | `bmgam_SavedVariables` |

Interface version and the game-type line are taken from that client when that flavor is built. They are not copied from another flavor. Forever’s current game type is `forever` and `camelot`. That line is not reused on retail or classic.

Author on every `.toc`: Blind Mice Gaming. The addon list groups it under Blind Mice Gaming, the same way the other addons do: `## Category: Blind Mice Gaming` and `## Category-enUS: Blind Mice Gaming`.

Lua is 5.1. The scanner is original. DataStore is not included.

## What a snapshot stores

One record per character, keyed so two realms cannot collide, plus one account block. The full field list is [08-character-record.md](08-character-record.md). The record holds what each tab and the Settings page are allowed to show, and nothing else. The minimap On or Off state, the window position, and the window scale live in the account block. The F6 binding does not. WoW stores that keybind.

On login, for the character who just logged in:

- GUID, name, realm, class file, race file, sex, level, faction (Alliance or Horde), money as total copper, and item level with its quality.
- Guild name, or none.
- Hero name and specialization name. A client with no hero talents does not store a hero.
- The stat lines Overview shows: Strength, Stamina, Armor, Critical Strike, Haste, Mastery, and Versatility.
- Talents the player has taken only. Each stored node has its entry id, name, and tree: class, hero, or specialization. The tooltip text is not stored. Hover asks the client.
- Delver's Journey, Prey, and Traveler's Journey: current progress, the maximum, and the rank. Hearthstone location: the place name.
- Currencies, including a zero on the current Midnight expansion.
- Reputation, including a shared flag when the client reports one.
- Worn gear: item id, link, durability current and maximum when the item has it, enchant name if any, and sockets with the gem if one is socketed.
- Bags and their contents. Names are saved at scan time.

While a window is open:

- Bank, only while the bank frame is open. On Midnight the warband bank is saved once for the account.
- Guild bank, only while the guild bank is open. Stored for that guild on that realm.
- The full inbox is read while the mailbox is open. Login reads the new-mail notice and up to three sender names. A letter sent to another character on this account is saved on that character when it is sent.
- Auctions and bids, on login for the character who is logged in. The Auction House window does not have to be opened.
- Professions, when the profession window opens. Learned recipes are saved then.

On login, also for that character:

- Quests that character is on, under Current, grouped by zone. Quests that character has finished, under Completed, grouped by zone.
- Achievements: Blizzard’s categories in Blizzard’s order, the name, the points, the date it was earned, and who earned it.
- Collections the client has: mounts, pets, transmog, transmog sets, toys, and decor. A header that client lacks is left off. Account-wide rows keep that flag.
- Midnight vault slot status. Other flavors do not store a vault.

Not stored: secret values, the full tooltip string, or another account’s data. “Logged in now” is not stored. It is true when the saved GUID matches the character who is logged in. Sharing snapshots across accounts stays out. Charlotte locked that on 2026-10-30.

An alt with no record yet is absent until that alt has logged in once. A bank or mailbox that has never been opened is marked not scanned, rather than shown as empty.

## Phases

Midnight is built one tab at a time, then Settings, then one flavor at a time. Settings is not a tab. A phase ends when that slice matches its reference and can be checked, before the next slice starts. No addon file is created until Charlotte says to start a phase.

Every expandable header is bold gold and can collapse. Gear has no search box. Every other tab has one, and it matches the names on that page. Settings has no search box.

| Order | What | Phase |
|-------|------|-------|
| 1 | Window, roster, thirteen tabs, forget-a-character, and Overview, with search | 1 |
| 2 | Gear. No search box | 2 |
| 3 | Bags, with search | 3 |
| 4 | Bank, with search. Personal bank, warband bank, guild bank | 4 |
| 5 | Professions, with search | 5 |
| 6 | Currency, with search | 6 |
| 7 | Reputation, with search | 7 |
| 8 | Mail, with search | 8 |
| 9 | Auction, with search | 9 |
| 10 | Quests, with search | 10 |
| 11 | Achievements, with search | 11 |
| 12 | Collections, with search. Item icon beside each name | 12 |
| 13 | Vault, Midnight only, with search | 13 |
| 14 | Settings, opened from the gear. Minimap, F6, `/avread`, Export / Import | 14 |
| 15 | Classic Era, including Hardcore | 15 |
| 16 | Anniversary | 16 |
| 17 | Classic (MoP) | 17 |
| 18 | WoW Forever | 18 |
| 19 | Updater rows, only when Charlotte says to ship | 19 |

### 0. Design

This folder. The plan was approved on 2026-10-29, and the later page pictures were approved through 2026-10-30. All thirteen tabs and the Settings page are approved. Phase 1 code started on 2026-10-30 in `BMGAM`. It is not installed, and it is not in the catalog.

### 1. Midnight shell and Overview

The window, close, and the approved settings button. Escape does not close the window. The minimap button uses the addon icon and opens or closes the window. Titan Panel can open it too: the addon registers a LibDataBroker launcher named BMG Alt Manager, the same kind of button Everything Delves uses, and a left-click opens or closes the window. The slash command that opens the window is `/bmgam`. Left roster for characters already saved. The roster scrolls. Each card is the approved four lines: class icon and gold name, Level, Race, Item Level in the quality color, Server, Faction in blue or red, and money with the client coin icons.

The first open is 1120×658. The minimum is 860×505. Scale starts at 1. Position and scale are remembered.

Selecting a row shows that character’s header: the client race portrait for that race and sex, the name, and “Logged in now” when the GUID matches. The trash can sits on the far right of that name line. Hovering it says **Forget this character**. Forget removes that character from this flavor’s SavedVariables only, after the confirmation. Selecting a character opens Overview. The Midnight tab row is thirteen pictures, Overview first and Vault last, with tooltips and only the open tab lit. A flavor hides a tab it does not have. Selecting another tab lights that tab and shows a blank page. That page has no search box and no message until its own phase. Gear never has a search box. Returning to Overview shows the Overview page again. The settings gear is on the window. Clicking it does nothing until phase 14, when the Settings page exists. Overview has a search box under the tabs. Every Overview section header is bold gold and can collapse.

Pictures this phase follows:

- [overview-page-full.jpg](reference/overview-page-full.jpg) is the window, the roster, the thirteen tabs, the search box, and the Overview page.
- [forget-character.jpg](reference/forget-character.jpg) is the trash can on the name line and the confirmation. The confirmation in that picture is open so the words can be seen. It is not always on the page.
- [addon-icon.jpg](reference/addon-icon.jpg) is the minimap button. Hovering it says **BMG Alt Manager**.
- [close-button.jpg](reference/close-button.jpg) and [settings-button.jpg](reference/settings-button.jpg) are the title-bar buttons. The settings tooltip says Settings.
- The thirteen tab icons in [13-icon-files.md](13-icon-files.md). A tab tooltip is that tab’s name.

Overview is filled in this phase, from [overview-page-full.jpg](reference/overview-page-full.jpg):

- Class, Hero, and Specialization. The label is bold bright yellow. The name beside it is bold bright white.
- Stats, with the same yellow labels and white numbers, right-aligned.
- Guild as its own header in bold gold. The guild name under it is bold bright white. No guild says Not in Guild in that white.
- Delver's Journey beside Prey, then Traveler's Journey beside Hearthstone Location. The first three show progress and rank. The progress label and the word Rank are bold bright yellow. The numbers are bold bright white. Hearthstone Location shows the place in bold bright white.
- Each heading line sits below its title and clear of the line under it.
- Talents, Hero talent, and Specialization talent. A row is the client’s talent icon and a bold bright yellow name. Only talents the player has taken are listed. Hovering the name shows the client’s full talent tooltip. The tooltip text is not stored. A client with no hero talents omits Hero and Hero talent.

Check: log two characters, reopen, and see both cards with the right class icon, race, item level color, side color, and coins. Select one and see Overview, not Gear. The code for this phase is in `BMGAM`, and that folder was copied into `_retail_\Interface\AddOns` on 2026-10-30.

### 2. Midnight Gear

Phase 2 code started on 2026-10-30 in `BMGAM`. The approved two-column gear list in [gear-page-full.jpg](reference/gear-page-full.jpg). Client item icons and quality-colored names. Weapons are the last row. Durability is current/maximum plus a bar: green at 60% and above, gold from 25% up to 60%, red under 25%. Neck, rings, trinkets, shirt, and tabard have no durability. An enchant name shows when one is present. “Not enchanted” is gold when the slot can take one and does not. “Cannot be enchanted” is only for shirt, tabard, and trinkets. Rings can be enchanted. A filled gem uses the gem’s name and color. “Empty socket” is gold. “No gem slot” is dim. A chest can show a filled gem and an empty socket together. A 0 gem field in a Midnight item link is not an empty socket. Socket count uses `C_Item.GetItemNumSockets`. The enchant name is the Enchantment line from `C_TooltipInfo.GetInventoryItem`.

A slot with nothing equipped stays on the page and says **Empty Slot**. There is no durability bar, enchant line, or gem line on that row. An item at 0 durability shows `0 / maximum` and a red bar. It does not say Broken. Midnight has no ranged row. A later flavor shows that row only when its client has the ranged slot.

### 3. Midnight Bags

Phase 3 code started on 2026-10-30 in `BMGAM`. The approved grids in [bags-page-full.jpg](reference/bags-page-full.jpg). One section per carried bag: Backpack, then equipped bags, then the Midnight reagent bag. Older flavors have no reagent bag. An unequipped bag slot is omitted. The header is the bag icon, the name in bold gold, and filled/size. The backpack icon stays cream because it is not an item. Filled slots use the client icon, a quality border, and a stack count when it is over 1. Empty slots are dark boxes. Hovering a filled slot, or the bag item in a header, shows the client tooltip from the stored link. The tooltip text is not saved. Empty slots and the backpack header have no item tooltip. The search box matches stored item names on this page only. A non-match hides, empty slots hide, and a bag with no matches hides. Clearing the box restores the page. Search does not read tooltip text.

### 4. Midnight Bank

Phase 4 code started on 2026-10-30 in `BMGAM`. The approved grids in [bank-page-full.jpg](reference/bank-page-full.jpg). Personal bank first, then the Midnight warband bank, then the guild bank. Each header collapses and expands. Slots match Bags, including empty slots and the hover tooltip. The warband bank is shared, saved once for the account, and scanned only while that bank is open. The guild bank is scanned only while the guild bank is open. Never opened says “Not scanned yet.” Older flavors have a personal bank only when that client has no warband bank. A flavor with no guild bank omits that section. Search matches stored names in every bank section on the page.

### 5. Midnight Professions

Phase 5 code started on 2026-10-30 in `BMGAM`. The page has Primary Professions and Secondary Professions. One header per profession: client icon and name. Under that, expansions from newest to oldest, each with skill/max and its recipes. A recipe row is the result icon, a quality border, and the name. Each expansion is listed once. A learned recipe is cream and has no character name beside it. A recipe this character has not learned is gold and says Missing, and the names of other characters on this account who know it follow that word. Hover shows the full tooltip. Recipes are saved when that profession window opens. An expansion that was never opened says “Not scanned yet.” Cooking and fishing are secondary. Archaeology is included only if that client still has it. Profession tools and cooldowns stay off. Search matches profession names, expansion names, and recipe names.

### 6. Midnight Currency

Phase 6 code started on 2026-10-30 in `BMGAM`. The approved page in [currency-page-full.jpg](reference/currency-page-full.jpg). A search box sits under the tabs and matches the names on this page. Gold, silver, and copper stay on the character card and at the top of this page, in two rows: Character: and Account Wide:, labels on the left, coins on the right, amounts bold. Account Wide is the sum of money already saved on each scanned character for this flavor. It is not a second stored currency. Bold headers are the client’s own, in the client’s order, including Crests, Delves, Zones, Dungeon and Raid, Miscellaneous, Player vs. Player, Legacy, and the expansion headers nested there. Every currency the client lists is shown, including a zero amount. Trader’s Tender says Account. Honor says PvP. A zero amount is dim but bold. An amount above zero is cream and bold. Names stay regular cream. A cap is amount/max only when the client provides one. The scan runs on login and reads the client’s currency categories, so the currency panel does not have to be opened. Legacy is included while that header is collapsed in the default panel. Closing Legacy on this page hides the expansions under it. A gold scrollbar sits on the right when the list is taller than the page. Older flavors list only currencies the character has, and they omit zeros.

### 7. Midnight Reputation

Phase 7 code started on 2026-10-30 in `BMGAM`. Charlotte played it on 2026-10-31 and called this phase complete. The approved page in [reputation-page-full.jpg](reference/reputation-page-full.jpg). A search box sits under the tabs and matches faction names. Alliance and Horde on the character card are the character’s side, and they are also groups under Classic. The reputation list uses the client’s own headers and order, including every expansion and the groups nested under them. A row is the full faction name, Warband when the reputation is warbound, the bar, current/maximum, and the standing word. The standing word and the bar use the client’s standing color. Renown and Level are standing words on the faction. Delver's Journey, Prey: Season 1, and Preyhunter's Journey show Rank and the progress toward the next rank. Delves seasons stay under their expansion. Captain Tokka, Slayer's Duellum, and Valeera Sanguinar stay under Silvermoon Court. A friendship rank stays on that faction. There is no Friendship header, and renown is not given its own header. A reputation that can be earned stays on the list at zero, including Neutral with an empty bar. A warbound reputation says Warband. Paragon and renown rewards stay off. Scanned on login.

### 8. Midnight Mail

Phase 8 code started on 2026-10-31 in `BMGAM`. Charlotte said this worked on 2026-10-31 and started the next phase. The approved inbox in [mail-page-full.jpg](reference/mail-page-full.jpg). A search box sits under the tabs and matches sender, subject, and attached item names. One row per letter: sender, subject, days left, attached coins, and attached items. An unread subject is bold. A read subject is regular. Days left are bold, cream until fewer than 3 days, then gold. The saved days count down after the mailbox closes. Attached coins use the client coin icons and include a zero coin when the letter has money. No coins when the money is 0. Hovering an attached item shows the client tooltip from the stored link. The tooltip text is not saved. A letter with nothing attached still shows. Login shows the new-mail notice and up to three sender names without opening a mailbox. Those rows say New mail. A letter this character sends to another character on this account is saved on the recipient at send time. Auction House mail, Blizzard mail, and mail from other players still need that character to open a mailbox once for the subject, items, and coins. Sent mail and cash-on-delivery stay off. A character who has never been checked says “Not scanned yet.” A login check with no new-mail notice says “No new mail.” Opened and empty says “Inbox is empty.”

### 9. Midnight Auction

Phase 9 code started on 2026-10-31 in `BMGAM`. Charlotte called this phase complete on 2026-10-31. The reference is [auction-page-full.jpg](reference/auction-page-full.jpg), approved on 2026-10-29. The tab icon is [tab-auction.jpg](reference/tab-auction.jpg). **Auctions** and **Bids** are bold gold headers. Column labels are bold white. Search matches item names. Headers collapse and expand. A posted row is the item, its time left, the current bid, and the buyout. A bid row is the item, that character’s bid, and the time left. A whole-gold price shows the gold coin. Silver and copper show when that price has them. No current bid says “No bids.” No buyout says “None.” A commodity stack’s buyout is the unit price times the stack. Time left uses the Auction House bands: 30 min, 2 hours, 12 hours, or 2 days. Sold auctions are left off. The lists are read on login, so the Auction House does not have to be opened. A character who has never been logged in says “Not scanned yet.” A login check with nothing posted says “No auctions”, and nothing bid says “No bids.” The items, times, and prices in the picture are samples.

### 10. Midnight Quests

Phase 10 code started on 2026-10-31 in `BMGAM`. The reference is [quests-page-full.jpg](reference/quests-page-full.jpg), approved on 2026-10-30. On 2026-10-31 Charlotte asked for Character and Warband under Completed. The tab icon is [tab-quests.jpg](reference/tab-quests.jpg). **Current Quest** and **Completed Quest** are bold gold headers, in that order. **Character** sits under Current Quest. **Character**, then **Warband**, sit under Completed Quest. Character lists that character’s own quests. Warband lists account-wide quests. Under each, quests are grouped by world, then content, then zone. Quest names sit under the zone. There is no Quest header. Level stays on the row, and a completed row also shows the date. Level is the quest’s level, with Dungeon, Raid, Scenario, or Delve when the client marks it that way. Date is the day this addon saw the quest turned in. The client does not keep older completion days, so those dates stay blank. Those headers collapse and expand, and they start open. Search matches quest names in both parts. A header with no match hides. Both parts are scanned on login. The list scrolls when it is taller than the page, and only the rows on screen are drawn. The client does not return a zone for most finished quests. The map id comes from the client’s quest-pin table in `Data/QuestMaps.lua`, and a quest with no pin uses a stored map id from that file. When Quest Completist is installed, its zone is used before that pin. When BtWQuests is installed, its quest location fills a quest that still has no zone. A Rumble appearance quest and a Renowned renown quest stay on Warband. A quest titled Tracking Quest, or titled only Level and a number, is left off. The client still names the world, content, and zone from that map. When a current quest still has no zone, it uses the quest log header it sits under. A finished quest that still has no zone is still listed under Character or Warband. Never logged in says “Not scanned yet.” No current quests says “No quests.” An empty Character or Warband list says “No quests.” The quest names and levels in the picture are samples.

### 11. Midnight Achievements

Phase 11 code started on 2026-10-31 in `BMGAM`. Charlotte called this phase done on 2026-10-31. The reference is [achievements-page-full.jpg](reference/achievements-page-full.jpg), approved on 2026-10-30. On 2026-10-31 Charlotte asked for Blizzard’s own categories, the date each achievement was earned, and who earned it. The tab icon is [tab-achievements.jpg](reference/tab-achievements.jpg). Categories are the client’s headers, in the client’s order, nested the way the achievement list nests them. Statistics stay off. Headers are bold gold. They start closed. Column labels are Points, Date, and Who, in bold white. An earned achievement name is bold bright green, with the client’s date and the character who earned it. When that character cannot be determined, Who says Account Wide. An achievement that is not earned has a bold yellow name. Clicking an achievement opens its steps. A finished step shows the date it was completed. A step that is not finished shows what is left, in white. An objective wraps onto extra lines so the whole sentence can be read. Steps of one chain stay on that one achievement. Every achievement in those categories is listed, earned and not earned, whether it is for one character or for the warband, including the other steps in a chain. Search matches achievement names and category names. A meta achievement is included with the others. An achievement that is not earned shows its progress on the row, such as 4/12. Hovering it shows that status and each requirement. Hovering an achievement name shows the client’s full achievement tooltip beside that name. Hovering a quest name shows the client’s full quest tooltip beside that name. Scanned on login for the character who is logged in. The picture’s categories and names are samples.

### 12. Midnight Collections

Phase 12 code started on 2026-10-31 in `BMGAM`. Charlotte called the Achievements phase done the same day. The reference is [collections-page-full.jpg](reference/collections-page-full.jpg), approved on 2026-10-30. The tab icon is [tab-collections.jpg](reference/tab-collections.jpg). On 2026-10-31 she asked for Collected and Not Collected as the first two headers. Both start closed. Under each, the types are Mounts, Manuscripts, Pets, Transmog, Transmog Sets, Toys, and Decor, and each of those starts closed. A type that client does not have is left off. Manuscripts are listed on every character. Druid forms are grouped by Bear Form, Cat Form, Moonkin Form, Travel Form, Flight Form, Aquatic Form, Treant Form, and Mount Form. Hunter tomes are grouped by pet family. A family a hunter's race already knows counts as collected only on a hunter. Every item in those types is listed, whether it is collected or not. A row is the client’s icon beside the name. A collected name is bold in that item’s quality color. A name that is not collected is bold bright yellow. Clicking a name opens how to obtain it, in white, and that line wraps so the whole sentence can be read. Hovering a name shows the client’s tooltip when the client has one. Search matches the names and the obtain text. The list is read on login for the character who is logged in. Swift Palomino, Reins of the Raven Lord, Panda Cub, and Golden Crown are picture samples.

### 13. Midnight Vault

Phase 13 code started on 2026-10-31 in `BMGAM`. Charlotte called this phase complete on 2026-10-31. The approved page in [vault-page-full.jpg](reference/vault-page-full.jpg). Midnight only. A search box sits under the tabs and matches the activity names. This phase does not exist for the other flavors. Each activity is a row. Its three slots go left to right, in the client’s order. A slot does not show 1, 2, or 3. A ready slot says Tier: and the client’s tier number, in bold bright green, with a bright gold-yellow border. Under that is the item level of the reward that slot will give. The requirement sentence stays under that. A locked slot shows progress such as 4/8, in bold cream, with a dull gold border, and the requirement sentence under that. There is no Taken state. A slot that has met its threshold stays ready, including one whose reward was already collected. Item choices inside a ready slot stay off. There is no mythic+ history and no separate progress bar. The snapshot is saved on login.

### 14. Settings

Phase 14 code started on 2026-10-31 in `BMGAM`. Charlotte called this phase complete on 2026-10-31. The approved page in [settings-page-full.jpg](reference/settings-page-full.jpg). Charlotte locked this drawing on 2026-10-29. It opens from the gold gear, not from a tab. No tab is lit.

- Show minimap button. A click turns it On or Off. The row shows the state it is in now. On means the button is visible. The button uses the addon icon.
- Read under the mouse. The default key is F6, not Ctrl+F6. A player who already bound F6 keeps that binding.
- Slash command `/avread`. Reading aloud happens only for that key or that slash. It reads what is under the mouse. Nothing is read on its own.
- WoW’s Key Bindings window gets a section named **BMG Alt Manager**. The commands under it are **Open or close** and **Read under the mouse**. Open or close has no default key. Read under the mouse defaults to F6. F6 reads in the same order Accessibility Helper uses: the tooltip that is showing, the tooltip a key press just hid, a Titan or LibQTip tip, the label under the cursor, an action button, then the unit under the mouse. The binding file is in the Midnight addon as of 2026-10-30, so the section shows before this Settings page is built. `Bindings.xml` is not listed in the `.toc`. On Midnight the speech call is voice, text, rate, then volume.
- The same addon icon is `IconTexture`, so WoW’s addon list shows it. The list groups the addon under Blind Mice Gaming with `## Category: Blind Mice Gaming` and `## Category-enUS: Blind Mice Gaming`. The icon file is made when a coding phase starts: uncompressed 32-bit TGA, 64×64.
- **Export / Import** is a header on this page, with two buttons: **Import** and **Export**. **Import** opens a popup with an empty text field, and the cursor is in that empty field. The player pastes a code there. Loading that pasted code replaces this flavor’s stored data. Closing the popup without loading leaves the stored data as it is. A code that cannot be read does not change the stored data. **Export** opens a popup that shows the code of this flavor’s stored data, and that code is already selected. Copying it does not change the stored data. The code is text. It starts with `BMGAM2` and must load back into the same records. The box shows one page of 4000 letters, already selected. **Next** shows the next page. On Import, **Add** keeps a page and **Load** replaces this flavor’s saved data. **Close** leaves it as it is. The settings picture shows the header, both buttons, and both popups so the two fields can be seen. In the addon, only the popup for the button that was clicked is open. `BMGAM-sample` is a picture sample.

These are not on the locked page, and this phase does not build them: a row for window position, and a search box. `/bmgam` is locked in phase 1. It is not a row on this page. A flavor hides a tab it does not have. That is not a Settings row. The trash can that forgets a character is built in phase 1, from [forget-character.jpg](reference/forget-character.jpg). It is not a Settings row.

### 15. Classic Era

Era, including Hardcore, starts from the Midnight addon and drops what that client does not have. Confirm that client’s calls before coding. Vault is left out. The ranged slot is shown when that client has it.

### 16. Anniversary

Anniversary starts from the Midnight addon and drops what that client does not have. Confirm that client’s calls before coding. Vault is left out. The ranged slot is shown when that client has it.

### 17. Classic (MoP)

MoP starts from the Midnight addon and drops what that client does not have. Confirm that client’s calls before coding. Vault is left out. MoP has no ranged slot.

### 18. WoW Forever

Forever starts from the Midnight addon and drops what that client does not have. Forever’s calls and slot list are confirmed on that client before this phase is coded. Vault is left out. The ranged slot is shown only when that client has it. Forever installs only into `_forever_`.

Dropped on any of these flavors when the client does not have them: Vault, the reagent bag, the warband bank, the guild bank, Renown, Delver Companion, Warband reputation, hero talents, the Delver's Journey, Prey, and Traveler's Journey headers, and any collection header that client lacks. Older currencies omit zeros. Reputation is the standard bar only. A flavor that has the ranged slot shows it, including **Empty Slot** when nothing is equipped. A flavor that does not have it leaves the row off.

### 19. Ship

Only when Charlotte says to ship. Then a catalog row per flavor that is actually built, a patch version bump, and the updater. No catalog row is added during planning.

## Load

Charlotte asked on 2026-10-31 how the addon can keep every list and still load without slowing the game. The model is Altoholic on the Classic client (`_classic_\Interface\AddOns\Altoholic` and `DataStore_*`). Its code stays there. Nothing from it is copied into BMGAM, and DataStore is not vendored.

Altoholic is many addons. Each data addon has its own saved-variables file and scans only its own list. The character addon listens for gold, level, and guild on their own events. Quests scan when the character is in the world, and the quest-log event is used once because it fires too often. Achievements scan once in one pass, then that listener is removed. A later achievement scans that one id. The achievement module’s own note, dated 2026-07-06, says spreading that walk across timers made startup worse, so they went back to one pass. Each tab addon is load-on-demand and is loaded when that tab is clicked. The window shell does not build those tabs at login.

The same scan rules are in place as of 2026-10-31:

- The first time the character is in the world, quests, achievements, collections, currencies, reputation, auctions, professions, the mail notice, and the vault run once.
- Gold, gear, bags, and talents update on their own. Those updates do not walk the lists again.
- Opening the window does not scan again. The window is created when it is opened. A scan does not build it while it is closed.

The two storage pieces are in place the same day. Mounts, pets, toys, transmog, transmog sets, and decor are stored once in `BMGAM_Account` (`bmgam_Account`). Manuscripts stay per character in `BMGAM_Collections` (`bmgam_Collections`), because a druid form and a hunter tome can differ by character. Quests are `BMGAM_Quests` (`bmgam_Quests`). Achievements are `BMGAM_Achievements` (`bmgam_Achievements`). `BMGAM` depends on those four. Forgetting a character removes that character from the quest, achievement, and manuscript files. The shared catalog stays. The window still lives in `BMGAM`. A tab addon that loads only when the tab is clicked is not part of this step.

## Explicitly out

Charlotte locked this out on 2026-10-30:

- Sharing snapshots across accounts. One Battle.net account’s saved characters do not appear on a different Battle.net account.

Until Charlotte asks for them:

- Mythic+ history beyond a vault slot’s status
- Search on Gear. Every other tab has a search box. Settings is not a tab and has no search box
- A settings row for window position. Hiding a tab the flavor does not have is automatic. Forgetting a character is the trash can on the name line. Neither is a Settings row.

Reading aloud is in the first Midnight version. It is only the F6 key and `/avread`, and it only reads what is under the mouse.

## Playtest

Midnight is copied into the retail AddOns folder only after phase 1 exists and she wants it tried. Other clients are not copied early. Forever is never copied into `_classic_beta_` or `_retail_`.

## Coverage

Each approved picture has a phase. A later coding phase uses that picture and the rules in its phase above.

| Approved picture | Phase |
|------------------|-------|
| Window, roster, thirteen tabs, forget-a-character, Overview, with search | 1 |
| Gear. No search box | 2 |
| Bags, including search and item tooltips | 3 |
| Bank, including the Midnight warband bank, the guild bank, and search | 4 |
| Professions, including Missing and search | 5 |
| Currency, including Character, Account Wide, and search | 6 |
| Reputation, including Renown, Delver Companion, Warband, and search | 7 |
| Mail, including unread, days left, item tooltips, and search | 8 |
| Auction, including Auctions, Bids, and search | 9 |
| Quests, Current and Completed, each grouped by zone, with search | 10 |
| Achievements, in Blizzard’s categories, with the date, who earned it, and search | 11 |
| Collections, item icon beside the name, and search | 12 |
| Vault, Midnight only, with search | 13 |
| Settings, F6, `/avread`, the minimap toggle, and Export / Import | 14 |
| Classic Era, including Hardcore | 15 |
| Anniversary | 16 |
| Classic (MoP) | 17 |
| WoW Forever | 18 |
| Updater rows | 19, only when Charlotte says to ship |
