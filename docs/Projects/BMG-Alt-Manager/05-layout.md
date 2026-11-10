# Layout

The approved Midnight window, with the roster and the Gear page together, is [gear-page-full.jpg](reference/gear-page-full.jpg). Charlotte approved it on 2026-10-29. The approved Bags page, with the same roster, is [bags-page-full.jpg](reference/bags-page-full.jpg), approved the same day. The approved Bank page is [bank-page-full.jpg](reference/bank-page-full.jpg), also approved that day. Both of those pages have a search box under the tabs. The approved Professions page is [professions-page-full.jpg](reference/professions-page-full.jpg), approved the same day, and it has a search box too. The approved Currency page is [currency-page-full.jpg](reference/currency-page-full.jpg), approved the same day. The approved Reputation page is [reputation-page-full.jpg](reference/reputation-page-full.jpg), approved the same day. The approved Mail page is [mail-page-full.jpg](reference/mail-page-full.jpg), approved the same day. The approved Vault page is [vault-page-full.jpg](reference/vault-page-full.jpg), approved the same day. Midnight only. The approved Overview page is [overview-page-full.jpg](reference/overview-page-full.jpg), approved the same day. It is the page shown when a character is selected.

## Window

- Title at the top left: **BMG Alt Manager**, in gold.
- Title-bar buttons at the top right: Settings, if approved, then Close.
- Left side: a sort row, then the roster. The row reads Sort By and Order. Sort By is Class, Faction, Item Level, Gold, Level, Race, or Realm. Order is Ascending or Descending. The choice is remembered. Cards stack vertically under that row. Each card is its own bordered plate. The selected card has the brighter border.
- Right side: the selected character. Header, then the tab row, then the page for the active tab.
- The window opens on Overview, with the logged-in character selected.

WoW Forever uses this same layout and these same icons. The title, roster cards, tab row, page columns, gold headers, and Settings gear stay where they are on Midnight. A tab or a block that client does not have is left out. The pages that remain are not redrawn.

The sample roster in the picture is Ares (selected), Lyra, Sylas, and Vex. Their lines match [01-decisions.md](01-decisions.md).

## Character card

```
[class icon]  Character Name
Level: 70     Race: Human     Item Level: 624
Server: Stormrage             Faction: Alliance
Money:  [gold] 50   [silver] 12   [copper] 34
```

- The class icon is the client texture, to the left of the name.
- The name is gold.
- Item level uses the quality color. In the sample, 624 is epic purple, 610 is rare blue, 580 is uncommon green, and 640 is legendary orange.
- Faction colors the word Alliance or Horde. The label “Faction:” stays cream.
- Coins sit immediately before their amounts.

## Right header

```
[race portrait]  Character Name                                          [trash]
Logged in now
```

The portrait is the race, not the class. “Logged in now” shows only for the character the player is currently playing. Other alts show the portrait and the name, and no extra line under the name.

The trash can is on the far right of the name line. Charlotte approved the icon on 2026-10-29. The button is [trash-button.jpg](reference/trash-button.jpg): a dark iron plate, a bright gold border, and a dimensional gold can with the lid tilted open. [forget-character.jpg](reference/forget-character.jpg) shows it on the name line. Hovering it says **Forget this character**. Clicking it opens a confirmation box. **Cancel** keeps the character. **Forget** removes that character’s snapshot from this flavor only. The box in the picture is open so the words can be seen. It is not part of the resting page.

## Tab row

Midnight, under the header, thirteen tabs. The icons are smaller so the row fits.

Overview, Gear, Bags, Bank, Professions, Currency, Reputation, Mail, Auction, Quests, Achievements, Collections, Vault.

The window opens on Overview. Only the open page’s tab is lit. A flavor hides a tab it does not have. Vault is Midnight only, and it stays last. Era, Anniversary, MoP, and Forever leave Vault out. A collection header is shown only when that client has that collection.

Every tab has a search box under the tabs except Gear. Settings is not a tab and has no search box. Search matches the names on that page. Gear has no search box.

Every section header can be collapsed and expanded. An open header has a downward chevron. A closed header has an upward chevron and hides its rows. The title of every expandable header is bold gold on every tab page. Charlotte approved that header color on the Overview, Bags, Professions, and Bank pictures on 2026-10-30. On 2026-10-30 she corrected the chevron: open points down, closed points up. On Auction, Quests, Achievements, and Collections, the column labels under a section are bold white.

## Gear page

This is the approved Gear page. It is a list, two columns, with the weapons on the last row. The reference is [gear-page-full.jpg](reference/gear-page-full.jpg).

Each equipped item is one block. The slot name is a gold header above the item. Under that header is the item name, then the upgrade track and rank when the item has one, such as Hero 1/6. The icon sits at the left of those lines.

```
Head
[item icon]  Pledgebearer's Mask
             Hero 1/6
             Durability [bar] 100%
             Enchant: Mark of the Claw
             Gem Slot: Quick Sapphire
```

The icon is the real item icon, inside a border of the item’s quality color. The color is the one in the item link: green for uncommon, blue for rare, purple for epic. The slot header is bold gold. The item name is the quality color. The upgrade line is cream. An item with no upgrade track leaves that line blank.

Durability is its own line. The word Durability is in front of the bar, and the percent follows the bar. At 0 the line shows `0%` and `0 / maximum`, such as `0%  0 / 100`. It does not say Broken.

| Condition | What the row says |
|-----------|-------------------|
| Durability at 60% or more | Green bar and a green percent |
| Durability from 25% up to 60% | Gold bar and a gold percent |
| Durability under 25%, including 0 | Red bar and a red percent. At 0 the text is `0%  0 / maximum`. The row does not say Broken |
| No durability (neck, rings, trinkets, shirt, tabard, and any item the client gives no durability) | The word Durability, then “No durability” in dim text, no bar |
| Nothing equipped | The slot header stays. The item name says “Empty Slot”. No bar, no enchant line, and no gem line |
| Has an enchant | “Enchant:” and the enchant name in cream. A long name wraps inside the column. It is not cut off |
| Can be enchanted, and is not | “Enchant: Not enchanted” in gold |
| Cannot be enchanted | “Enchant: Cannot be enchanted” in dim text |
| Socket filled | “Gem Slot:” and the gem name, in the gem’s quality color. A long name wraps inside the column. It is not cut off |
| Socket empty | “Gem Slot: Empty socket” in gold |
| No socket | “Gem Slot: No gem slot” in dim text |
| More than one socket | Each socket on the gem line, filled and empty together |

Sample rows that show every state, once the drawing’s two mistakes are corrected:

| Slot | Durability | Enchant | Gem |
|------|------------|---------|-----|
| Head | 100/100 green | Has an enchant | Gem name |
| Neck | No durability | Has an enchant | No gem slot |
| Shoulder | 64/100 green | Not enchanted | Empty socket |
| Chest | 73/100 green | Has an enchant | One gem and one empty socket |
| Hands | 41/100 gold | Has an enchant | Gem name |
| Waist | 8/100 red | Has an enchant | Empty socket |
| Finger | No durability | Has an enchant | Gem name |
| Trinket, shirt, tabard | No durability | Cannot be enchanted | No gem slot |
| Main hand | 90/100 green | Has an enchant | Empty socket |
| Off hand | 44/100 gold | Not enchanted | No gem slot |

A flavor shows the ranged slot only when that client has it. Midnight and MoP do not. Era and Anniversary do. Forever shows it only if that client has the slot. The row uses the same three lines, or **Empty Slot** when nothing is equipped.

## Bags page

Approved on 2026-10-29. The reference is [bags-page-full.jpg](reference/bags-page-full.jpg). The Bags tab is the only lit tab in that picture. The Gear tab uses the same resting border as the other tabs. The roster is the same roster as the Gear page.

Each bag the character is carrying is its own section, top to bottom: Backpack, the equipped bags, then the reagent bag. WoW Forever has the reagent bag. It sits in that same place when the bag has slots.

```
[bag icon]  Backpack                         16 / 20
[icon] [icon] [icon] [icon] ...
[icon] [empty] [empty]
```

- The header name is bold gold. The bag icon uses that bag’s quality color. Backpack is not an item, so its icon stays cream. The header collapses and expands. Open points down. Closed points up.
- A filled slot is the client item icon inside a border of the item’s quality color. The color is the one in the item link: green for uncommon, blue for rare, purple for epic. Stacks greater than 1 show the count in the corner.
- An empty slot is a dark box.
- Hovering a filled slot, or the bag item in the header, shows the client’s item tooltip for the stored link. The drawing leaves one tooltip open so that hover can be seen. Empty slots do not show an item tooltip.
- A search box sits under the tabs. The placeholder says Search. It matches item names in these bags. While it has text, slots that do not match are hidden, and empty slots are hidden. Clearing it shows the full page.

## Bank page

Approved on 2026-10-29. The reference is [bank-page-full.jpg](reference/bank-page-full.jpg). The Bank tab is the only lit tab. The roster matches the other approved pages.

```
Search
Personal bank                              18 / 28
[icon] [icon] [icon] ...
Warband bank                               22 / 40
[icon] [icon] [icon] ...
```

- Personal bank is first. The Midnight warband bank is the next grid. Guild bank is the next section. Older flavors do not show the warband section. A flavor whose client has no guild bank does not show that section.
- The warband bank header uses the Warband Bank Distance Inhibitor icon.
- Slots match Bags: item icon, quality border, stack count, dark empty box.
- A bank that has never been opened says **Not scanned yet** in that section. The guild bank in the picture says that.
- The search box matches names in the personal bank, the warband bank, and the guild bank. The picture shows the box empty.
- One slot is hovered so the item tooltip can be seen.
- The counts in the picture are a sample.

## Professions page

Approved on 2026-10-29. The reference is [professions-page-full.jpg](reference/professions-page-full.jpg). The Professions tab is the only lit tab.

```
Search
Primary Professions
[icon]  Alchemy
        Midnight                                          85 / 100
        [icon]  Bolt of Imbued Cloth
        [icon]  Azureweave            Missing             Lyra, Sylas
        Khaz Algar
                Not scanned yet
Secondary Professions
[icon]  Cooking
        Classic                                           1 / 300
                Not scanned yet
```

- **Primary Professions** and **Secondary Professions** are bold gold headers. Cooking, Fishing, and Archaeology are secondary. The two profession slots are primary.
- Each profession header is the client icon and the profession name in bold gold. The name is the profession, such as Alchemy, not a number.
- Under each profession, expansions run from newest to oldest. Each expansion shows its skill and maximum.
- A recipe row is the result icon, a quality border, and the recipe name. Hovering it shows the full recipe tooltip.
- Each expansion name appears once. A learned recipe is cream and has no character name beside it. A recipe this character has not learned is gold and says **Missing**, and the other characters on this account who know it are named right after that word. The selected character’s name is not shown.
- An expansion whose profession window has not been opened says **Not scanned yet**.
- The search box matches profession names, expansion names, and recipe names.
- The search box matches profession names and recipe names. The picture shows it empty.
- Cooking is in the list because this sample character has it.
- On WoW Forever the line under a profession is the skill line that client returns, with its skill and maximum. Midnight expansion names are not added. A line whose profession window has not been opened says Not scanned yet. Search matches profession names, skill line names, and recipe names.

## Currency page

Approved on 2026-10-29. The reference is [currency-page-full.jpg](reference/currency-page-full.jpg). The Currency tab is the only lit tab.

```
Money
Character:                    [gold] 50  [silver] 12  [copper] 34
Account Wide:                [gold] 470  [silver] 57  [copper] 63

Midnight
Crests                                                          0
Delve currency                                                 40

Dragonflight
Older expansion token                                           8

Other
Trader's Tender          Account                              450
Honor                    PvP                                2,500
```

- Headers and amounts are bold.
- A zero amount is dim. An amount above zero is cream.
- The account money is the sum of every scanned character. The picture’s Dragonflight row, Trader’s Tender, and Honor amounts are samples.
- The live headers are the client’s own, in the client’s order. That includes Crests, Delves, Features, Professions, Season 2, Zones, Dungeon and Raid, Miscellaneous, Player vs. Player, Legacy, War Within, Dragonflight, and Unused. Closing Legacy hides the expansions under it. A gold scrollbar sits on the right when the list is taller than the page.
- On WoW Forever the Money rows stay. Under them the list is Player vs. Player (Honor Points, Rank Points), Dungeon and Raid (Tarnished Undermine Real), Professions & Tradeskills (Merchant's Favor), and Miscellaneous (Darkmoon Prize Ticket). If this character does not have a currency, or has not discovered it, the amount is 0, and that zero is dim. Search matches currency names, header names, and Account or PvP.

## Reputation page

Approved on 2026-10-29. Charlotte approved the Delver Companion header and the Warband header on 2026-10-30. There is no Friendship header. The reference is [reputation-page-full.jpg](reference/reputation-page-full.jpg). The Reputation tab is the only lit tab. A search box sits under the tabs and matches the names on this page.

```
Classic
Stormwind                         Exalted     [full green bar]     42,000 / 42,000
Ironforge                         Revered     [partial green bar]  12,000 / 21,000
Gnomeregan                        Neutral     [empty yellow bar]        0 / 3,000
Bloodsail Buccaneers              Hostile     [partial red bar]     1,200 / 3,000

Dragonflight
Older expansion faction           Honored     [partial green bar]   6,000 / 12,000

Renown
Sample Renown            Account  Renown 12   [teal bar]                 12 / 20
Second Renown                     Renown 4    [teal bar]                  4 / 20

Delver Companion
Sample Companion                  Level 8     [gold bar]                    8 / 10

Warband
Sample Warband           Account  Honored     [partial green bar]   6,000 / 12,000
```

- The faction name stays cream. The standing word and the bar use the client’s standing color. Renown uses a teal bar. A header can close, and a closed header hides the groups nested under it. A gold scrollbar sits on the right when the list is taller than the page.
- The live list uses the client’s headers. Midnight, The War Within, Dragonflight, Shadowlands, Battle for Azeroth, Legion, and Classic are those headers. Alliance sits under Classic. Renown is the standing on the faction, not its own header. There is no Friendship header. A rank such as Guest, Interloper, or Mastermind stays on that faction. Delver's Companion is its own header, and the row shows the companion’s level, including level 0. A reputation that can be earned stays on the list when the amount is zero, under the parent from the Faction DB2. The name, Account, bar, amount, and standing are fixed columns. A plain expansion header does not draw a bar.
- A group that also has a standing, such as Silvermoon Court, The Cartels of Undermine, The Severed Threads, or Valdrakken Accord, shows that standing on the header. The factions under it stay nested. Captain Tokka, Slayer's Duellum, and Valeera Sanguinar stay under Silvermoon Court. A shared faction says Warband.
- Ironforge, Gnomeregan, Bloodsail Buccaneers, the Dragonflight row, Second Renown, Sample Companion, and Sample Warband are picture samples.
- On WoW Forever the groups are Alliance, Alliance Forces, Horde, Horde Forces, Steamwheedle Cartel, and Other. The row is the normal standing bar, from Hated through Exalted. Renown, Delver Companion, and Warband are left off. A faction this character has not discovered stays on the page at Neutral 0 / 3,000. Search matches faction names and standings.
- A warbound reputation says Warband. Paragon and renown rewards are not on this page. Delves seasons stay under the expansion they belong to. Delver's Journey, Prey: Season 1, and Preyhunter's Journey show Rank and the progress toward the next rank.

## Mail page

Approved on 2026-10-29. The reference is [mail-page-full.jpg](reference/mail-page-full.jpg). The Mail tab is the only lit tab. A search box sits under the tabs and matches the names on this page.

```
Inbox
Lyra                         28 days
Extra cloth
[uncommon cloth x20]                    [gold] 2  [silver] 0  [copper] 0

Auction House                 2 days
Auction successful
                                    [gold] 15  [silver] 40  [copper] 8

Vex                          12 days
A ring for you
[epic ring]     tooltip: Ring of the Vale

Sylas                          1 day
Herbs from the road
[uncommon herb x5] [rare gem]

Innkeeper                      6 days
Your room is ready
```

- An unread subject is bold. Extra cloth and A ring for you are the unread samples.
- Days left are cream. Fewer than 3 days is gold. In the picture that is 2 days and 1 day.
- The coins on a letter are the money attached to that letter.
- Hovering an item shows the client tooltip. The picture’s tooltip is a sample.
- After login, a character with no new-mail notice says “No new mail”. A character who has never been checked says “Not scanned yet”. A mailbox that was opened and has nothing in it says “Inbox is empty”. Days left count down from the last inbox read. A notice row says New mail and has no coins.
- On WoW Forever the page is that same Inbox. Sent mail and cash-on-delivery stay off. Search matches sender, subject, and attached item names.

## Vault page

Approved on 2026-10-29, including the drawing. The reference is [vault-page-full.jpg](reference/vault-page-full.jpg). The Vault tab is the only lit tab. Midnight only. A search box sits under the tabs and matches the names on this page.

```
Raids
Tier: 2                  Tier: 4                  4/6
Item Level: 305          Item Level: 318          Defeat 6 Midnight Season 2 Bosses
Defeat 2 Midnight Season 2 Bosses

Dungeons
Tier: 8                  2/4                      2/8
Item Level: 312
Complete 8 Dungeons

World
Tier: 6                  2/4                      2/8
Item Level: 305
Complete 6 activities
```

- A ready slot does not show 1, 2, or 3. The first line is Tier: and the client’s tier number, in bold bright green, with a bright gold-yellow border. Under that is Item Level: and the reward item level, such as Item Level: 305. The requirement sentence stays under that.
- A locked slot does not show 1, 2, or 3. It shows progress such as 4/8, in bold cream, with a dull gold border. Under that is the same Item Level: line when the reward item level is known. The requirement sentence stays under that.
- There is no Taken state. The items inside a ready slot are not on this page. Raids, Dungeons, World, and the numbers above are samples.

## Overview page

Approved on 2026-10-29, including the drawing. The reference is [overview-page-full.jpg](reference/overview-page-full.jpg). The Overview tab is the only lit tab. It is the first tab, and it is the page shown when a character is selected. A search box sits under the tabs and matches the names on this page.

```
Class: Warrior
Hero: Sample Hero
Specialization: Arms

Stats
Strength                         1,240
Stamina                          2,480
Armor                            4,200
Critical Strike                  12%
Haste                            8%
Mastery                          15%
Versatility                      6%

Guild
Not in Guild

Hearthstone Location
Stormwind City

Delver's Journey                         Prey
Delver's Progress  2800 / 4200  Rank  2    Prey Progress  800 / 1600  Rank  1

Traveler's Journey
Traveler's Journey Progress  1500 / 3000  Rank  3

Talents
[icon] Sample class talent
[icon] Second class talent

Hero talent
[icon] Sample hero talent
[icon] Second hero talent

Specialization talent
[icon] Sample spec talent
[icon] Second spec talent
```

- Class, Hero, Specialization, and each stat label are bold bright yellow. The name or number beside the label is bold bright white.
- Guild is its own header, in bold gold. The guild name under it is bold bright white. This sample says Not in Guild.
- Guild is its own header, in bold gold. The guild name under it is bold bright white. This sample says Not in Guild.
- Hearthstone Location is the next header, aligned to the left like Guild. Charlotte corrected that on 2026-10-30. The place under it is bold bright white.
- Under Guild, Delver's Journey sits beside Prey, then Traveler's Journey. The first three show progress and rank. The progress label and the word Rank are bold bright yellow. The current / maximum and the rank number are bold bright white. Prey, Traveler's Journey, and Stormwind City in the picture are samples. Delver's Progress 2800 / 4200 Rank 2 is the example on the drawing. Each heading line stays below its title.
- A talent row is the client’s talent icon and the name in bold bright yellow. Only talents the player has taken are listed.
- Hovering a talent name shows the client’s full talent tooltip. The picture leaves one tooltip open. The tooltip text is not stored.
- Hero, specialization, the stat numbers, and the talent names in the picture are samples.

## Auction page

The reference is [auction-page-full.jpg](reference/auction-page-full.jpg). Charlotte approved this drawing on 2026-10-29, including the bold gold headers and the bold white column labels.

- **Auctions** is a bold gold header. It lists what that character has posted. A row is the client item icon, the item name in its quality color, time left, the current bid, and the buyout.
- **Bids** is a bold gold header. It lists auctions that character has bid on. A row is the icon, the name, that character’s bid, and the time left.
- Both headers collapse and expand. Search matches item names. The lists are read on login, so the Auction House does not have to be opened. A character who has never been logged in says **Not scanned yet**. A login check with nothing posted says **No auctions**, and nothing bid says **No bids**.
- A posted auction that has sold is left off. A posted auction with no bid says **No bids**. A posted auction with no buyout says **None**. A whole-gold price shows the gold coin. Silver and copper show when that price has them.
- Time left uses the Auction House bands. A listing the clock shows as 2d says **2 days**. The other bands say **30 min**, **2 hours**, and **12 hours**. The label moves to the next band as time passes. Hovering the icon uses the stored item link. The tooltip text is not stored.
- On WoW Forever the page is those same two headers. The modern auction cache is read on login. The older auction house is read while it is open. Search matches item names.

## Quests page

The reference is [quests-page-full.jpg](reference/quests-page-full.jpg). Charlotte approved this drawing on 2026-10-30. On 2026-10-31 she asked for the completed list to split into Character and Warband. **Current Quest** and **Completed Quest** are bold gold headers, in that order. **Character** sits under Current Quest. **Character**, then **Warband**, sit under Completed Quest. Character lists that character’s own quests. Warband lists account-wide quests. Under each, the groups are world, then content, then zone. Quest names sit under the zone. There is no Quest header. Azeroth, Northrend, and Borean Tundra are the examples: world, content, and zone. The client does not return a zone for most finished quests, so the map id comes from the client’s quest-pin table, and from a stored map id when that pin is missing. When Quest Completist is installed, its zone is used before that pin. When BtWQuests is installed, its quest location fills a quest that still has no zone. A Rumble appearance quest and a Renowned renown quest stay on Warband. A quest titled Tracking Quest, or titled only Level and a number, is left off. The client still names the zone from that map. A quest that still has no zone stays on the list, after the zones. Headers are bold gold. A current row is the quest name and its level. A completed row adds the date. Level is the quest’s level. Dungeon, Raid, Scenario, or Delve is added when the client marks the quest that way. Date is the day this addon saw the quest turned in. The client does not keep older completion days, so those dates stay blank. Headers collapse and expand. An open header points down. A closed header points up. Sections start open. Search matches quest names in both parts, and a header with no match hides. Both parts are scanned on login. When the list is taller than the page, it scrolls, and only the rows on screen are drawn. A character who has never been logged in says **Not scanned yet**. No current quests says **No quests**. An empty Character or Warband list says **No quests**. Hovering a quest name shows the client’s full quest tooltip beside that name. The quest names and levels in the picture are samples. On WoW Forever the page is those same headers. Warband is shown only when the client marks a finished quest account-wide. A quest with no zone stays on the list. Search matches quest names.

## Achievements page

The reference is [achievements-page-full.jpg](reference/achievements-page-full.jpg). Charlotte approved this drawing on 2026-10-30. On 2026-10-31 she asked for Blizzard’s own categories, the date, and who earned it. Each header is one of the client’s categories, in the client’s order, in bold gold. Children stay under their parent. Statistics are not listed. Headers start closed. The column labels under an open category are **Points**, **Date**, and **Who**, in bold white. An earned achievement name is bold bright green, with the client’s date and the character who earned it. Who is the character who completed it, not the character who is logged in. When that character cannot be told apart from the one logged in, Who says Account Wide. An achievement that is not earned has a bold yellow name. Clicking an achievement opens its steps. A finished step shows the date it was completed. A step that is not finished shows what is left, in white. An objective wraps onto extra lines so the whole sentence can be read. Steps of one chain, such as Got My Mind On My Money, stay on that one achievement. Every achievement in those categories is listed, earned and not earned, whether it is for one character or for the warband, including the other steps in a chain. Search matches achievement names and category names. A meta achievement is included with the others. An achievement that is not earned shows its progress on the row, such as 4/12. Hovering it shows that status and each requirement. A finished requirement is dim. One that is still needed is cream. Hovering an achievement name shows the client’s full achievement tooltip beside that name. The categories and names in the picture are samples. On WoW Forever the categories are the ones this client returns. Statistics stay off. Who says Account Wide when the client marks the achievement account-wide. Search matches achievement names and category names.

## Collections page

The reference is [collections-page-full.jpg](reference/collections-page-full.jpg). Charlotte approved this drawing on 2026-10-30, including the item icon beside each name. On 2026-10-31 she asked for Collected and Not Collected as the first two headers. Both start closed. Under each, the types are Mounts, Manuscripts, Pets, Transmog, Transmog Sets, Toys, and Decor, and each of those starts closed. A type that client does not have is left off. Manuscripts are listed on every character. Druid forms are grouped by Bear Form, Cat Form, Moonkin Form, Travel Form, Flight Form, Aquatic Form, Treant Form, and Mount Form. Hunter tomes are grouped by pet family. A family a hunter's race already knows counts as collected only on a hunter. Every item in those types is listed, whether it is collected or not. A row is the client’s icon beside the name. A collected name is bold in that item’s quality color. A name that is not collected is bold bright yellow. Clicking a name opens how to obtain it, in white, and that line wraps so the whole sentence can be read. Hovering a name shows the client’s tooltip when the client has one. Search matches the names and the obtain text. Swift Palomino, Reins of the Raven Lord, Panda Cub, and Golden Crown are picture samples. On WoW Forever a type is listed only when this client returns rows for it. Manuscripts and Decor stay off. Heirlooms are included when this client has them. The icon stays beside the name.

## Settings page

Approved on 2026-10-29, including the Export / Import header. The reference is [settings-page-full.jpg](reference/settings-page-full.jpg). It opens from the gold gear. No tab is lit. The earlier settings page, without that header, is not kept.

```
Settings
Show minimap button                 On
Read under the mouse                F6
Slash command                       /avread

Export / Import                     [Import]  [Export]
```

- On WoW Forever this is the same page. Export writes this Forever copy only, and the saved data is marked `client = "forever"`. A retail code does not load. The message says that code is not a Forever export.
- A click on Show minimap button turns it On or Off, and the row shows that state.
- Reading aloud happens only for F6 or `/avread`, and it reads what is under the mouse.
- **Export / Import** is a header with two buttons. **Import** opens a popup with an empty text field, and the cursor is in that empty field. The player pastes a code there. **Load** replaces this flavor’s stored data. **Close** leaves the stored data as it is. A code that cannot be read does not change the stored data. **Export** opens a popup with the code of this flavor’s stored data, and that code is already selected. Copying it does not change the stored data. The settings picture shows the header, both buttons, and both popups so the two fields can be seen. In the addon, only the popup for the button that was clicked is open. `BMGAM-sample` in that picture is a sample, not a real code.

Every full-page picture uses the thirteen-tab row. Overview is first. Vault is last. Only the open page’s tab is lit. Settings leaves every tab resting. Gear has no search box. Every other tab has one.
