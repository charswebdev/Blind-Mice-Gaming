# Client notes by page

Batch 3 of the data pack. Approved on 2026-10-29. Gear and Bags are read by `BMGAM` as of 2026-10-30. The other pages in this file are still notes.

Each page says what the snapshot stores, which Midnight functions supply it, and what is still unconfirmed. The Forever check from 2026-11-08 is in the section **WoW Forever** at the end of this file.

Names are saved at scan time. Full tooltips are not stored. Gold, silver, and copper stay on the character record from batch 1. The Currency page reads that money. It does not store a second copy.

## Bags

Stored for the logged-in character, on login.

| Field | Contents |
|-------|----------|
| Bag | Backpack, one of the four equipped bags, or the Midnight reagent bag |
| Bag item | Id, name, quality, and slot count when the bag itself is an item. Quality colors the bag name. The backpack has no bag item |
| Slot | Empty, or item id, link, name, quality, icon, and stack count |

Midnight reads bags through `C_Container` while the character is logged in. The backpack is bag 0. The four equipped bags are bags 1 through 4. The reagent bag is `Enum.BagIndex.ReagentBag` when that client has it, and bag 5 otherwise. A bag whose slot count is 0 is left off. `BMGAM` scans these on login and when a bag changes, as of 2026-10-30.

Era, Anniversary, and MoP use the backpack and the equipped bags that client has. Whether they call `C_Container` or the older container functions is **unconfirmed**. They do not get a reagent bag. Confirm the bag indexes on each client before that flavor is coded.

Not stored: worn gear, the bank, the guild bank, and the words of the item tooltip.

On the Bags page, hovering a filled slot asks the client to show the item tooltip for the stored link. Hovering the bag item in a header does the same. The backpack has no bag item. An empty slot does not. If the client does not know that item yet, the tooltip can be thin until the client can describe it. The tooltip text is not written into the snapshot.

The search box on this page matches the item name saved on the slot. It does not search tooltip text. While the box has text, slots that do not match are hidden, and empty slots are hidden. A bag with no matches is hidden. Clearing the box shows the full page.

## Gear

Stored for the logged-in character, on login and when worn gear changes. Midnight does not store the ranged slot.

| Field | Contents |
|-------|----------|
| Slot | The client inventory slot number |
| Empty | True when nothing is equipped. The slot is still stored |
| Item | Id, link, name, quality, and icon. The name is saved at scan time |
| Durability | Current and maximum when the item has durability. Neck, rings, trinkets, shirt, and tabard do not |
| Enchant | Enchant id, and the enchant name, or `not-enchanted`, or `cannot` |
| Upgrade | The track and rank saved at scan time, such as `Hero 1/6`, when `C_Item.GetItemUpgradeInfo` returns one |
| Sockets | One entry per socket. A filled socket stores the gem id, name, and quality. An empty socket is empty. No list means no gem slot |

Socket count is `C_Item.GetItemNumSockets` on the item link. If that call is missing, the count is the `EMPTY_SOCKET` keys from `C_Item.GetItemStats`. A `0` in a gem field of the link is not an empty socket. The enchant name is the permanent enchant line on the worn item (`ItemEnchantmentPermanent`), read after the tooltip values are surfaced. A number in the item link’s enchant field is not used as the name, and it does not mark the item as enchanted. When that line is missing, or the line says Not enchanted, the item is not enchanted. A gem name comes from `C_Item.GetItemGem` or the gem socket line on that same tooltip.

On the Gear page, hovering an equipped item asks the client to show the tooltip for the stored link. An empty slot does not. There is no search box.

## Bank

Stored only while that bank is open. A bank that has never been opened stays “Not scanned yet.”

| Field | Contents |
|-------|----------|
| Scanned | True only after that bank has been open |
| Scanned at | When that open-bank scan was saved |
| Slots | Same item fields as a bag slot. Empty slots are kept |

The personal bank is stored on the character. Midnight reads it from `Enum.BagIndex.CharacterBankTab_1` through `CharacterBankTab_9` with `C_Container`, only while the bank is open. A tab whose slot count is 0 is left off. The event is `BANKFRAME_OPENED`.

The warband bank is Midnight only. It is its own grid. It is saved once on the account, because every character on the account shares it. Midnight reads it from `Enum.BagIndex.AccountBankTab_1` through `AccountBankTab_9`, only while the bank is open. If it has never been opened, that grid says “Not scanned yet” and the personal bank is unchanged.

The guild bank is its own grid. It is saved once for that guild on that realm, and only while the guild bank is open (`GUILDBANKFRAME_OPENED`). A tab the character cannot view is left off. Each viewable tab keeps its empty slots.

Era, Anniversary, and MoP have a personal bank only. The function is **unconfirmed** on each of them. They do not get a warband bank. A flavor with no guild bank omits that section.

Not stored: bag contents, worn gear, and the words of the item tooltip.

The Bank page uses the same hover tooltip as Bags. The search box matches stored item names in the personal bank, the warband bank, and the guild bank. It follows the same hide-and-restore rules as the Bags search.

## Professions

Stored when the profession window opens, which is the locked scan rule.

| Field | Contents |
|-------|----------|
| Name | Profession name at scan time |
| Skill | Current skill |
| Maximum | The cap the client reports |
| Icon | File id, when the client provides one |
| Recipes | Each recipe that character has learned: recipe id and name |

Charlotte locked this on 2026-10-29. The page has to show learned recipes so a player can see that one character already knows a recipe and another is missing it. The comparison uses the learned lists. A recipe no scanned character has learned does not appear.

Midnight reads the profession list on login with `GetProfessions` and `GetProfessionInfo`. That is how a profession can say “Not scanned yet” before its window has been opened. Learned and unlearned recipes are read only while that profession window is open. The calls are `C_TradeSkillUI.GetBaseProfessionInfo`, `C_TradeSkillUI.GetChildProfessionInfos`, `C_TradeSkillUI.GetAllRecipeIDs`, and `C_TradeSkillUI.GetRecipeInfo`. Each recipe is stored with its learned flag. `IsRecipeInSkillLine` places a recipe on its expansion. The result icon, quality, and tooltip link come from `GetRecipeOutputItemData` or `GetRecipeItemLink`. A profession name that is only a number is discarded, and the name is read from the skill line instead.

Era, Anniversary, and MoP store the learned recipes that client can report. Their skill-line and recipe calls are **unconfirmed**.

Not stored: profession tools, cooldowns. Unlearned recipes are not stored one by one. Missing means “another scanned character knows it, and this one does not.”

The page builds that comparison from the learned lists already saved. It does not store a separate copy of who knows a recipe. When another character’s list contains the recipe, that character’s name is shown on the row. The selected character’s name is not repeated there.

The search box matches the profession name and the recipe name saved at scan time. While it has text, rows that do not match are hidden. Clearing it shows the full page.

## Currency

Stored on login for the logged-in character. The currency panel does not have to be open. Midnight reads currencies from `C_CurrencyInfo.GetPlayerCurrencyCategoryInfo` and `GetCurrencyInfo`, so a collapsed header in that panel still contributes the currencies under it. That is how Legacy and the expansions under it are stored. Profession currency, such as Artisan Moxie, is also read from that character’s profession skill lines and kept under Professions. If that category read returns nothing, the flat list from `GetCurrencyListSize` and `GetCurrencyListInfo` is used for whatever it already contains. The two reads are combined, and a shorter read does not replace a longer one. Every currency the client lists is stored, including a zero amount. The header saved on each currency is the client header it sits under, in the client’s order. Those names stay as the client wrote them, including Crests, Delves, Features, Professions, Season 2, Zones, Dungeon and Raid, Miscellaneous, Player vs. Player, Legacy, War Within, Dragonflight, and Unused. Trader’s Tender is tagged `account`. Honor is tagged `pvp`. A maximum is stored only when the client reports a cap.

Charlotte locked this on 2026-10-29.

| Flavor | What the page shows |
|--------|---------------------|
| Midnight | Every currency the client lists, including a zero balance. That includes the current expansion, its categories, older expansions, and currencies under Miscellaneous, Player vs. Player, Dungeon and Raid, and Unused |
| Era, Anniversary, MoP, Forever | Only currencies that character actually has. A zero balance is not listed |

| Field | Contents |
|-------|----------|
| Currency id | The client id. Ids are taken from the client at scan time, not typed in from memory |
| Name | Saved at scan time |
| Icon | File id |
| Expansion | Current expansion, or an older one |
| Amount | The count the client reports |
| Maximum | Only when the client provides a cap |
| Tag | `account` for Trader’s Tender. `pvp` for Honor. Absent on a normal currency |

The older flavors’ currency function is **unconfirmed**.

Gold, silver, and copper stay stored on the character record. The Currency page shows them at the top, before the expansion headers, on two rows. The first row says Character: and puts that character’s coins on the right. The second row says Account Wide: and puts the account total on the right. The account total is the sum of every scanned character’s money on this account. A character with no snapshot is left out of the sum. The sample characters add up to 470 gold, 57 silver, and 63 copper. Ares’s own line is 50 gold, 12 silver, and 34 copper. Both amounts are bold.

### Currency sample

Sample only, for a Midnight character. The ids are placeholders. A live scan replaces this with the client’s current list.

```text
- name: Crests
  expansion: Midnight
  amount: 0
- name: Delve currency
  expansion: Midnight
  amount: 40
- name: Catalyst currency
  expansion: Midnight
  amount: 0
- name: Profession currency
  expansion: Midnight
  amount: 15
- name: Nebulace cores
  expansion: Midnight
  amount: 3
- name: Older expansion token
  expansion: older
  amount: 8
```

A Midnight character shows every currency the client lists. A zero amount stays on the row.

The page groups those rows under bold headers. The current expansion has its own header. Each older expansion this character has currency for has its own header. Currencies that are not from an expansion sit under **Other**. Trader’s Tender is one of those. Honor is one of those, and its row shows that it is PvP. Amounts are bold. A zero amount stays dim. An amount above zero is cream, and still bold.

## Reputation

Stored on login for the logged-in character. The row is the faction’s full name, the standing, and the progress. Alliance and Horde are not rows. They stay on the character card.

| Field | Contents |
|-------|----------|
| Faction id | The client id |
| Name | The full name, saved at scan time |
| Group | The client’s header for a standard faction, saved at scan time |
| Kind | `standard`, or on Midnight also `renown` or `companion` |
| Standing | The label, such as Exalted |
| Current | Progress toward the next mark |
| Maximum | The top of that bar |
| Shared | True when `isAccountWide` or `C_Reputation.IsAccountWideReputation` says this faction is warbound. The row then says Warband |

Midnight’s standard list is `C_Reputation.GetFactionDataByIndex`. The read turns on legacy reputations so Alliance, Horde, Neutral, and every older expansion are in that list, then puts the client’s switch back. Collapsed headers are opened for the read, then put back. Renown is `C_MajorFactions`, stored as kind `renown`, and it stays under the expansion header the client uses. The numbers are the renown level and its maximum, not the Hated-through-Exalted bar. A companion is stored as kind `companion` under Delver's Companion, including when the level is 0. The row says Level. Delves seasons stay under the expansion they belong to. Delver's Journey, Prey: Season 1, and Preyhunter's Journey stay under that expansion too. Their standing is Rank, and the numbers are the progress toward the next rank. A faction whose name contains Traveler's Journey is read the same way when the client has one. Delves: Season 3 and Preyhunter's Journey keep the rank on a warband currency. That currency is the rank, and the row says Warband. Factions the character has not earned stay on the list at zero. The Faction DB2 supplies the name and the parent, because the reputation API does not include the parent and it omits a faction the character has not listed. Paragon, deprecated, and hidden DB2 rows are not shown. A friendship rank comes from `C_GossipInfo.GetFriendshipReputation` and stays on that faction. Captain Tokka, Slayer's Duellum, and Valeera Sanguinar stay under Silvermoon Court, which is nested under Midnight. The Faction DB2 parents those three on Midnight, and the reputation panel does not. Paragon progress is not read.

The page groups factions under the client’s own headers, in the client’s order. Renown stays on that faction as its standing, read from `C_MajorFactions`. A companion in that list uses its level as the standing. A friendship rank, read from `C_GossipInfo.GetFriendshipReputation`, stays on that faction. There is no Friendship header, and renown is not moved into its own header. A group that also has a standing keeps that standing on the header, with its factions nested under it. The standing’s floor is stored so the bar starts empty at the bottom of that standing. The numbers on the row are the current standing and the next mark.

The faction name stays cream. The standing word and the bar use the client’s standing color. A faction the client does not list is left off. A listed faction with an empty bar stays. Paragon and renown rewards are not stored. A search box matches the names on this page.

Era, Anniversary, and MoP use the standard bar only. `GetNumFactions` and `GetFactionInfo` are the historical calls. Confirm them before that flavor is coded. They do not get renown, Delver Companion, or a Warband header unless that client has it.

### Reputation sample

Sample only.

```text
- id: 0
  name: Stormwind
  kind: standard
  standing: Exalted
  current: 42000
  maximum: 42000
- id: 0
  name: Sample Renown
  kind: renown
  standing: Renown 12
  current: 12
  maximum: 20
  shared: true
```

The second row is Midnight only. `shared: true` is why that row says Warband. The picture’s other rows are samples of standing colors and of the Delver Companion level. Their live names come from the client.

## Talents on the Overview page

Charlotte locked this on 2026-10-29, including the drawing [overview-page-full.jpg](reference/overview-page-full.jpg). Overview is the page shown when a character is selected.

Stored for the logged-in character. Only talents the player has taken are stored. A node is taken when the talent frame shows it selected, which is `ranksPurchased` greater than 0. An empty node is left off. Gray nodes and hero nodes marked unavailable are left off.

| Field | Contents |
|-------|----------|
| Entry id | The client id, so a hover can ask for the icon and the tooltip |
| Name | Saved at scan time |
| Tree | Class talents, hero talent, or specialization talent |

The row uses the same icon as the client’s talent button: the definition’s override icon when that talent has one, otherwise the spell’s original icon. The name is bold bright yellow. Hovering the name shows the client’s full talent tooltip, the same kind Light Paws Loadouts shows: name, description, and rank. The tooltip text is not stored. A client with no hero talents does not get the Hero talent list. The hero name on the Class line is the active hero specialization. The three lists are the nodes that character has taken: class, hero, and specialization.

Hearthstone Location is the next header after Guild, aligned to the left like the other headers. The place sits under that header. Delver's Journey sits beside Prey, then Traveler's Journey. Charlotte corrected the Hearthstone alignment on 2026-10-30. Delver's Journey, Prey, and Traveler's Journey show progress and rank. Hearthstone Location shows the place the hearthstone is set. The live numbers and the place come from the client at scan time. Phase 1 reads Delver's Journey, Prey, and Traveler's Journey from `C_MajorFactions` when the faction name is exactly that title. A track whose client uses a different name is left off. Hearthstone Location uses `GetBindLocation`.

## Mail

The full inbox is stored when the mailbox is open. Login stores the new-mail check for the character who is logged in. No new-mail notice is saved as checked, and the page says “No new mail”. A letter sent to another character on this account is stored on that character at send time. A character who has never been checked stays “Not scanned yet”.

| Field | Contents |
|-------|----------|
| Scanned | True after the mailbox has been open and the inbox was read |
| Scanned at | When that full inbox was saved |
| Notice | Up to three sender names from the new-mail notice. No subject, items, or coins |
| Sent | Letters this account sent to this character, until the next full inbox read |
| Sender | Who sent the letter |
| Subject | The subject line. A notice row says New mail |
| Money | Copper attached to the letter. This is mailbox money, not the character’s purse |
| Days left | As the client reports it, then counted down from the time it was saved. Cream on the page until fewer than 3 days remain, then gold |
| Read | True when the client says the letter was opened. An unread subject is bold |
| Items | Id, name, quality, count, icon, and the item link for each attachment |

`HasNewMail` and `GetLatestThreeSenders` supply the notice without a mailbox. `GetInboxNumItems`, `GetInboxHeaderInfo`, and `GetInboxItem` supply the full inbox while the mailbox is open. After that read, the client keeps the same inbox for the rest of the session, and the saved copy keeps the days counting down. A letter sent with `SendMail` is written onto the recipient when that recipient is a character already saved on this account. The item link is what a hover uses to show the client tooltip. The tooltip text is not stored. The same family is the expected one on the older flavors. Confirm it before each of those flavors is coded.

The page is one row per letter. Notice rows come first, then letters sent to this character, then the saved inbox. Sent mail is not stored as an outbox. Cash-on-delivery is not stored. A search box matches the names on this page.

A character who has never been checked says “Not scanned yet”. A login check with no new-mail notice says “No new mail”. A mailbox that was opened and has no letters says “Inbox is empty”.

## Auction

Auctions and bids are read on login for the character who is logged in. The Auction House window does not have to be opened. A character who has never been logged in stays “Not scanned yet.”

| Field | Contents |
|-------|----------|
| Scanned | True after both the posted list and the bid list have been read |
| Scanned at | When that pair of lists was saved |
| Owned | Auctions this character has posted. A sold auction is left off |
| Bids | Auctions this character has bid on |
| Item | Id, name, quality, count, icon, and the item link |
| Time left | The Auction House band. The page says 30 min, 2 hours, 12 hours, or 2 days, which is the same clock the Auction House uses. It moves to the next band as time passes |
| Bid | The current bid, in copper. Empty when nobody has bid |
| Buyout | The buyout, in copper. For a commodity this is the unit price times the stack. Empty when the auction has none |
| My bid | On a bid row, the copper this character has bid |

`C_AuctionHouse.QueryOwnedAuctions` and `QueryBids` ask for the lists on login, while the Auction House is closed. Asking again while that window is open is skipped, because that call can break the sell tab. `GetOwnedAuctionInfo` and `GetBidInfo` supply the rows after `OWNED_AUCTIONS_UPDATED` and `BIDS_UPDATED`. A count of zero before those events is not saved as an empty list. Closing the Auction House asks again, so a sale or a bid from that visit is saved after the window closes. The item link is what a hover uses to show the client tooltip. The tooltip text is not stored.

The page has an Auctions header and a Bids header. Column labels are bold white. Search matches item names. Never logged in says “Not scanned yet.” A login check with no rows says “No auctions” or “No bids.”

## Quests

Current quests and finished quests are read on login for the character who is logged in. A character who has never been logged in stays “Not scanned yet.”

| Field | Contents |
|-------|----------|
| Scanned | True after the quest log has been read |
| Completed ready | True after the finished-quest list has been walked |
| Scanned at | When that read was saved |
| Current | Quests in the log: name, level, zone, activity, and quest id |
| Completed | Quests the client says are turned in: name, level, activity, world, content, zone, account-wide or not, completion day when this addon saw the turn-in, and quest id |

`C_QuestLog.GetNumQuestLogEntries` and `GetInfo` read the log. A hidden row is left off. The place names come from that quest’s map, climbed to a world, a continent, and a zone. Azeroth is a world. Northrend is content. Borean Tundra is a zone. The client does not return a zone for most finished quests, so the map id comes from the client’s quest-pin table in `Data/QuestMaps.lua`. A quest with no pin uses a stored map id from the same file. When Quest Completist is installed, its zone for that quest is used before the pin table. When BtWQuests is installed, its quest location is used when the quest still has no zone. Neither addon’s files are copied. The client still names the zone from that map. Account-wide quests, including an Account tag or a Warband tag, go under Warband. A Rumble appearance quest and a Renowned renown quest also go under Warband. A quest titled Tracking Quest, or titled only Level and a number, is left off. The others stay on Character. A quest this character finished stays on Character. When a current quest still has no zone, it keeps the quest log header it sits under. A finished quest that still has no zone is still listed. `GetAllCompletedQuestIDs` reads finished quests. `GetTitleForQuestID` reads the name. A name that is not loaded yet is asked for with `RequestLoadQuestByID`, a few at a time, and filled in on `QUEST_DATA_LOAD_RESULT`. `GetQuestDifficultyLevel` supplies the level when the log row has none. `GetQuestTagInfo` supplies Dungeon, Raid, Scenario, and Delve. The client does not keep the day a quest was finished. The day is stored when `QUEST_TURNED_IN` fires while this addon is loaded, and that day is kept on later reads. The quest id keeps the same quest from being stored twice. Tooltip text is not stored. Hovering a quest name asks the client for the full quest tooltip beside that name.

The page has a Current Quest header, then a Completed Quest header. Character sits under Current Quest. Character, then Warband, sit under Completed Quest. World, content, and zone sit under those. Quest names sit under the zone. There is no Quest header. Level stays on the row, and a completed row also shows the date. Search matches quest names. A header with no match hides. Never logged in says “Not scanned yet.” No current quests says “No quests.” An empty Character or Warband list says “No quests.”

## Achievements

Achievements are read on login for the character who is logged in. A character who has never been logged in stays “Not scanned yet.”

| Field | Contents |
|-------|----------|
| Scanned | True after the achievement list has been walked |
| Scanned at | When that read was saved |
| Categories | The client’s categories, except Statistics: id, name, parent, and Blizzard’s order |
| Rows | Each achievement in that category’s client order: id, name, points, category, earned, the date, and who earned it |

`GetCategoryList` and `GetCategoryInfo` supply the categories. The parent is the client’s parent. The order is Blizzard’s display order for that category. `GetStatisticsCategoryList` marks the Statistics tree, and those categories are left off. `GetCategoryNumAchievements` is asked for every achievement in the category, including one the journal hides until it is earned. `GetAchievementInfo` supplies each row. A chain is walked so earlier and later steps are stored too. A character achievement and a warband achievement are both stored. A statistic is left off. The date is the month, day, and year the client returns for an earned achievement. The year is years since 2000 when the client sends it that way. Who is the character the client names. For an account-wide achievement, that is the character who earned it, including a character other than the one logged in. Who is not filled in with the character who is logged in. A completed step can name the character who finished it. When that character cannot be told apart from the one logged in, Who is Account Wide. An achievement this character has not earned stores no date and no name. The achievement id keeps the same achievement from being stored twice. The description is not stored. Steps of one chain are stored on that achievement. An earned achievement name is bold bright green. An achievement that is not earned has a bold yellow name. Clicking it opens the steps. A finished step shows the date it was completed. A step that is not finished shows what is left, in white. An achievement that is not earned also stores its progress, such as 4/12, and each requirement. A meta achievement’s requirements are the achievements it asks for. Hovering an achievement name asks the client for the full achievement tooltip beside that name, then shows that status and those requirements.

The page lists those categories in that order, with each child under its parent. Headers start closed. Under an open category, the labels are Points, Date, and Who. Search matches achievement names and category names. A header with no match hides. Never logged in says “Not scanned yet.” A login check with nothing in these categories says “No achievements.”

## Collections

`C_MountJournal` lists every mount, including one that is not collected. Manuscripts are listed on every character. A druid row is a barbershop form, grouped under Bear Form, Cat Form, Moonkin Form, Travel Form, Flight Form, Aquatic Form, Treant Form, or Mount Form. A hunter row is one tome, grouped under that pet family. Collected means the quest is complete, the spell is known, or the appearance is collected. A race that already knows a family counts only when this character is a hunter. Clicking a manuscript name opens where it comes from. The extra mount call supplies how a mount is obtained. `C_PetJournal` lists collected and not collected pets, one row per species, and the species call supplies how it is obtained. The pet journal filters are put back when the read finishes. `C_TransmogCollection` lists each transmog appearance. A name the client has not loaded yet is filled in after the read. `C_TransmogSets` lists transmog sets. `C_ToyBox` lists collected and not collected toys, and the toy box filters are put back when the read finishes. `C_HousingCatalog` lists decor when that client has it. A header that client does not have is left off. The obtain sentence is stored. The tooltip text is not stored.

## Vault

Midnight only. This section is not copied to Era, Anniversary, MoP, or Forever.

Charlotte locked this on 2026-10-29, including the drawing [vault-page-full.jpg](reference/vault-page-full.jpg). The page shows all 9 slots. Each activity is its own row, and that row’s three slots go left to right. A locked slot is still shown. The player can see which slot they have, what that slot still needs, the tier that slot is on, and its item level.

A slot does not show 1, 2, or 3. A ready slot says Tier: and the client’s tier number, in bold bright green, with a bright gold-yellow border. Under that is the item level of the reward that slot will give. A locked slot shows progress/threshold, such as 4/8, in bold cream, with a dull gold border. There is no Taken state. A slot that has met its threshold stays ready, including one whose reward was already collected. The requirement line is the client’s own text, in that same text color. There is no separate progress bar. The items inside a ready slot are not stored. A search box matches the names on this page. The picture’s activity names and counts are samples.

Stored on login for the logged-in character, and again on `WEEKLY_REWARDS_UPDATE`. Midnight’s family is `C_WeeklyRewards`. `GetActivities` supplies each row. The requirement line is the Great Vault’s own threshold sentence for that slot, filled with that slot’s threshold. Raids use the client’s raid sentence. Dungeons, World, and PvP use that activity’s own sentence. The tier number is the client’s level for that slot. The item level is the same number the Great Vault tooltip shows for the reward that slot will give. The numbers and the requirement text are saved at scan time so the page matches the vault the player would see in game.

| Field | Contents |
|-------|----------|
| Group | The Blizzard column this slot belongs to |
| Slot | 1, 2, or 3 inside that group. All nine are stored |
| Tier | The tier the client has locked to that slot |
| Item level | The item level the client shows for that slot |
| Status | `locked` or `ready` |
| Progress | How far this slot has moved |
| Needed for the next | What the client says is still required to unlock the next slot |

Status is decided at scan time. Progress under the threshold is `locked`. Progress at or over the threshold is `ready`. A collected reward stays `ready`. The page does not store a claimed state.

The item choices inside a ready slot are not stored. A ready slot shows Tier: and the item level. A locked slot shows progress/threshold.

## Still unconfirmed, on purpose

| Item | Where |
|------|--------|
| Container function on Era, Anniversary, and MoP | Bags and personal bank |
| Personal bank bag indexes, and the warband-bank calls | Midnight bank |
| Learned-recipe call | Professions |
| Skill-line calls | Older professions |
| Currency function | Older flavors |
| Completed-quest history call | Quests |
| Every Forever function | Written below, from the 2026-11-08 check |

## WoW Forever

Checked 2026-11-08 on this PC. Client `1.60.1.70862`, Interface `16001`, product `wowf`, game type `camelot`, folder `_forever_`. The client does not keep loose FrameXML on disk, so this list comes from a scan that already ran here (Syndicator saved data for characters on account FREYAHEART, including Elenna Briarfield and Freya Emberhammer) and from addons that loaded on this same client without those calls showing up as errors. No Forever Alt Manager files were created.

Secret values still apply. A value that cannot be read is dropped, the same rule as Midnight.

### Gear

The saved equipment list uses classic slot numbers and includes slot 0. Slots present: Ammo `0`, Head `1`, Neck `2`, Shoulder `3`, Shirt `4`, Chest `5`, Waist `6`, Legs `7`, Feet `8`, Wrist `9`, Hands `10`, Finger `11`, Finger `12`, Trinket `13`, Trinket `14`, Back `15`, Main Hand `16`, Off Hand `17`, Ranged `18`, Tabard `19`. Ammo and Ranged were empty on the cloth character and are still stored. Shirt and tabard stay locked on the page.

Calls that already ran: `GetInventoryItemID`, `GetInventoryItemLink`, `C_Item.DoesItemExist`, `C_Item.IsBound`.

### Bags

`C_Container.GetContainerItemInfo` already ran. The backpack and four bag slots are in use. One character had a Light Quiver in a bag slot.

Charlotte noted on 2026-11-09 that reagent bags are on WoW Forever. The reagent bag is its own section after the four bags, the same place Midnight puts it, when that bag has slots. An empty reagent-bag slot is left off. The slot after the reagent bag is the keyring. The bag bar on this client is the backpack, bags 1 through 4, `CharacterReagentBag0Slot`, then `KeyRingButton`. Its bag id is `Enum.BagIndex.Keyring`. On Forever its size comes from `GetKeyRingSize()`, not from `C_Container.GetContainerNumSlots`. The page uses the bag’s own name, and a reagent bag with no name yet says Reagent Bag.

### Bank

Personal bank on this client uses `C_Bank` bank tabs (`FetchPurchasedBankTabData`, `BANK_TABS_CHANGED`). Step 18.4 reads those tabs only while the bank is open. The saved tab list stays empty until then, and the page says Not scanned yet.

Warband bank is off. The bag addon turns that bank off on Forever, and the saved warband bank is empty.

Guild bank uses the classic calls: `GetNumGuildBankTabs`, `GetGuildBankTabInfo`, `GetGuildBankItemLink`, `GetGuildBankMoney`. No guild bank has been opened on this account, so no contents are saved. The Bank page keeps the section and says **Not scanned yet** until it is opened. If that first open has no tabs, the section stays with that message.

### Currency, mail, auctions

`C_CurrencyInfo.GetCurrencyListInfo` already ran. One character’s list was a single header, Unknown, and no currencies. Gold is stored on its own (955 copper on that character). Step 18.6 reads that list on login and when a currency changes. A collapsed header is opened once so a currency under it is not missed. The token list on this client stays at the header Unknown until a currency is discovered, so that list alone does not show the rows. The page still lists the Forever currencies, and reads each amount with `C_CurrencyInfo.GetCurrencyInfo`. Honor Points `1792` and Rank Points `3468` sit under Player vs. Player. Tarnished Undermine Real `3469` sits under Dungeon and Raid. Merchant's Favor `3402` sits under Professions & Tradeskills. Darkmoon Prize Ticket `515` sits under Miscellaneous. An amount the character does not have, including a currency this character has not discovered, is stored as 0. A header name from the client’s own category replaces the fallback name when that category lists the currency. Midnight headers such as Crests and Delves are not added.

### Reputation

Step 18.7 reads the reputation panel with `C_Reputation.GetNumFactions` and `GetFactionDataByIndex`, or `GetNumFactions` and `GetFactionInfo` when those are the calls this client has. Every reputation header is opened for the read, including with `ExpandAllFactionHeaders` and `ExpandFactionHeader(0)`, and then a header that was closed is closed again. The page then lists every Forever faction under Alliance, Alliance Forces, Horde, Horde Forces, Steamwheedle Cartel, and Other. A standing the client returns is kept. A faction this character has not discovered is still listed, at Neutral 0 / 3,000 when the client has no standing for it. The groups follow that client order. Each faction stores the normal standing, from Hated through Exalted, the standing floor, and the next mark. The bar is that standing’s bar. A friendship rank, when the client has one, stays on that faction. There is no Friendship header. Renown, Delver Companion, and Warband reputation stay off. Alliance and Horde stay headers when the client uses them as headers. They are not extra rows.

Step 18.8 reads the inbox while the mailbox is open, with `GetInboxNumItems`, `GetInboxHeaderInfo`, and `GetInboxItem`. Login reads `HasNewMail` and `GetLatestThreeSenders` without a mailbox. A letter sent with `SendMail` is stored on the recipient when that recipient is already on this account. Cash-on-delivery is left off. Sent mail is not an outbox. Days left keep counting down from the time the inbox was saved.

Step 18.9 reads owned auctions and bids on login with `C_AuctionHouse.QueryOwnedAuctions` and `QueryBids` when this client is not the old auction house. Asking again while that window is open is skipped. `GetOwnedAuctionInfo` and `GetBidInfo` supply the rows after `OWNED_AUCTIONS_UPDATED` and `BIDS_UPDATED`. A sold auction is left off. When `IsUsingLegacyAuctionClient` says this is the old auction house, the lists are read with `GetNumAuctionItems` and `GetAuctionItemInfo` while the Auction House is open. Time left uses the same bands as the Auction House: 30 min, 2 hours, 12 hours, or 2 days.

Step 18.10 reads the quest log on login. A collapsed header is opened for the read and then closed again. Current quests use `C_QuestLog.GetInfo` or `GetQuestLogTitle`. Finished quests use `C_QuestLog.GetAllCompletedQuestIDs`, then `GetQuestsCompleted` when that first call is missing. The title comes from `C_QuestLog.GetTitleForQuestID`. The zone comes from the quest’s map when the client has one, and a current quest with no map keeps the quest log header. A quest with no zone is still stored. Account-wide is stored only when `C_QuestLog.IsQuestFlaggedCompletedOnAccount` says so, and Warband is shown only then. Tracking Quest, a [DNT] title, and a title that is only Level and a number are left off.

Step 18.11 reads achievements on login with `GetCategoryList`, `GetCategoryInfo`, and `GetAchievementInfo`. Statistics are left off. An earned row stores the client’s date and who earned it. Who is Account Wide when the client marks that achievement account-wide. A chain uses `GetPreviousAchievement` and `GetNextAchievement` when those calls exist. An achievement that is not earned stores its progress.

Step 18.13 is Settings. The minimap button follows `account.minimap`. Read under the mouse uses the `BMGAM_READUNDERMOUSE` binding, F6 unless it was changed, and the row says Not bound when no key is stored. `/avread` reads the same way. Export writes this Forever saved data, marked `client = "forever"`. Import refuses a code that is not that Forever export, including a retail BMGAM2 code.

### Professions and quests

`Blizzard_Professions` has loaded on this client. WhatsTraining, also installed here, reads skill lines with `GetNumSkillLines`. Step 18.5 stores the profession list on login from `GetProfessions` and `GetProfessionInfo`, and adds a profession skill line `GetNumSkillLines` returns when that line is a profession this client knows. The line under the profession uses that skill line’s own name, skill, and maximum. Midnight expansion names are not invented. Recipes are read only while the profession window is open, from `C_TradeSkillUI` when that client returns them, and from `GetNumTradeSkills` when it does not. Each recipe keeps its learned flag. A filtered profession window does not replace a longer saved list.

Questie Forever (Interface `16001`) is loaded and reads completed quests with `C_QuestLog.GetAllCompletedQuestIDs`, then `GetQuestsCompleted` if that first call is missing.

### Collections

Addons on this install call `C_MountJournal`, `C_PetJournal`, `C_ToyBox`, `C_Heirloom`, and `C_TransmogCollection`. Step 18.12 reads those journals on login, and `C_TransmogSets` when this client has it. A type with no rows is left off the page. Manuscripts and Decor are not read. Heirlooms are stored when `C_Heirloom` returns them. The icon stays beside the name. Collected and Not Collected both start closed.

### Left off

Vault stays off. There is no weekly-rewards scan. Warband reputation, Delver’s Journey, Prey, and Traveler’s Journey stay off. Achievements are read with `GetCategoryList` and `GetAchievementInfo`. Statistics stay off.
