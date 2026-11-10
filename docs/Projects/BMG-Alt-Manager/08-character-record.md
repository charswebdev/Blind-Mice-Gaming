# Character record

Batch 1 of the data pack. Approved on 2026-10-29. Phase 1 stores the roster fields and the Overview fields in `bmgam_SavedVariables`. Later tabs are not stored yet.

## Database

The SavedVariables name is `bmgam_SavedVariables` in every flavor. Charlotte locked that name on 2026-10-29. Each flavor still has its own copy, because each addon is installed in a different client. They use this same record shape. They do not share one database.

The database is account-wide. It holds one record per character on that account, plus one account block for settings, the window, and the Midnight warband bank. It does not hold another account’s characters. Quests, achievements, the shared collection catalog, and character manuscripts are saved by their own addons so those lists are not copied into this file. Forgetting a character removes that character from those files too.

This file is the SavedVariables list for every tab and for Settings. Later notes say where each value comes from. They do not add a second database.

## Key

The key is the player GUID plus the realm name.

The GUID is the stable id the client gives that character. The realm name is stored beside it so two realms can never be merged by name alone. The character’s name is for the card. It is not the key.

“Logged in now” is not stored. While the window is open, the addon compares the current character’s GUID with the record’s GUID. A match shows “Logged in now”. Any other record does not.

Forgetting a character deletes that character’s record from this flavor’s database. It does not delete the WoW character, and it does not touch another flavor’s copy. The trash can, the tooltip **Forget this character**, and the confirmation box are approved in [forget-character.jpg](reference/forget-character.jpg). Nothing is removed until **Forget** is chosen.

## Export and import

The code is not a stored field. **Export** makes a text code from this flavor’s saved data and the popup shows that code already selected. The code starts with `BMGAM2`. It holds the roster file (`bmgam_SavedVariables`, the account block and every character record), quests, achievements, the shared collection catalog, and character manuscripts. The box shows 4000 letters at a time. Copy the selected page, then Next. On Import, Add each page, then Load. **Import** opens an empty text field with the cursor in it. **Load** replaces those files with the pasted code. **Close** leaves the stored data as it is. A code that cannot be read does not change the stored data. Copying the export code does not change the stored data. Another flavor’s database is not included. On WoW Forever the code holds this copy’s `bmgam_SavedVariables` only, and the account block is marked `client = "forever"`. A retail code is refused and does not replace the saved data.

## What the roster record stores

Captured on login for the character who just logged in.

| Field | What it is | Ares sample |
|-------|------------|-------------|
| GUID | Client player id | `Player-0-00000000` — sample only, not a real character |
| Realm | Realm name | Stormrage |
| Name | Display name | Ares |
| Class file | Unlocalized class token | `WARRIOR` |
| Race file | Unlocalized race token | `Human` |
| Sex | Client sex value | `2` (male). `3` is female. `1` is unknown and is not used for a portrait |
| Level | Level | 70 |
| Side | `Alliance` or `Horde` | `Alliance` |
| Money | Total copper | 501234, which is 50 gold, 12 silver, 34 copper |
| Item level | The number on the card | 624 |
| Item level quality | Quality id used to color that number | `4` (epic). The approved card shows 624 in epic purple |
| Scanned at | When this login scan was saved | Sample date 2026-10-28 |

Class file, race file, and sex are stored so the class icon and the race portrait can be drawn while that character is offline. The localized name “Human” is not enough, because the portrait also depends on sex.

Money is stored as copper so the card can split it into gold, silver, and copper beside the coin icons. 10,000 copper is 1 gold. 100 copper is 1 silver.

The item level quality on the sample is epic because that is the color on the approved card. A live scan saves the quality id at scan time. Which equipped items produce that quality stays with the Gear talk.

## Sample record

This is the Ares example. The GUID is a placeholder.

```text
key: Player-0-00000000
realm: Stormrage
name: Ares
classFile: WARRIOR
raceFile: Human
sex: 2
level: 70
side: Alliance
moneyCopper: 501234
itemLevel: 624
itemLevelQuality: 4
scannedAt: 2026-10-28
```

Lyra, Sylas, and Vex stay the sample cards in [01-decisions.md](01-decisions.md). Their sex was never chosen, so they do not get a portrait record in this file.

## Account block

One copy for the whole account. Not inside a character record.

| Field | What it is |
|-------|------------|
| Minimap button | On or Off. A click on Settings switches it. The row shows this stored state. The picture’s default is On |
| Window position | Point, relative point, x, and y. Saved when the window is moved |
| Window scale | Saved when the window is scaled. The first open uses scale 1 |
| Sort by | Class, Faction, Item Level, Gold, Level, Race, or Realm. The roster starts on Class |
| Sort order | Ascending or Descending. The roster starts on Ascending |
| Warband bank scanned | Midnight only. True only after that bank has been open |
| Warband bank scanned at | When that scan was saved |
| Warband bank slots | Same item fields as a bag slot. Shared by every character on the account |

The Read under the mouse key is not in this database. WoW stores it as the binding **Read under the mouse** in the **BMG Alt Manager** section. The default is F6. **Open or close** is the other command in that section. It has no default key, and it is not stored here either. The Settings page reads the read-under-mouse binding. `/avread` is a slash command and is not stored.

Account Wide money on the Currency page is not stored. It is the sum of `moneyCopper` on every character record that exists.

## Overview, on the character record

Captured on login. A client that does not have a hero, a journey, or a vault simply omits that part.

| Field | What it is |
|-------|------------|
| Class name | Localized class name at scan time. The class file is already on the roster record |
| Hero name | Localized hero name. Absent when that client has no hero talents |
| Specialization name | Localized specialization name |
| Guild name | The guild, or empty. Empty shows “Not in Guild” |
| Stats | Strength, Stamina, Armor, Critical Strike, Haste, Mastery, and Versatility. The last four are percents |
| Talents | Only nodes the player has taken. Each one stores the entry id, the name, the rank, and the tree: class, hero, or specialization |
| Delver's Journey | Current, maximum, and rank. Absent when that client has no such track |
| Prey | Current, maximum, and rank. Absent when that client has no such track |
| Traveler's Journey | Current, maximum, and rank. Absent when that client has no such track |
| Hearthstone | The place name |

The talent icon and the talent tooltip are not stored. Hover uses the entry id and asks the client. Tooltip text is not written into the snapshot.

## Worn gear

On the character record. Captured on login. The slot rules are in [10-gear-data.md](10-gear-data.md).

Each equipped slot stores: slot number, empty or not, item id, link, name, quality, icon, upgrade track and rank when the item has one, durability current and maximum when the item has them, enchant id, enchant name, and one entry per socket with the gem id, gem name, and gem quality, or empty. An empty slot is stored, and the Gear page shows it as **Empty Slot**. A flavor that has no ranged slot does not store one. The tooltip text is not stored. At 0 durability the page shows `0%` and `0 / maximum` in red. It does not say Broken.

## Guild bank, auctions, quests, achievements, and collections

Guild bank slots are stored when that guild bank has been opened. The scan belongs to that guild on that realm. Auctions and bids are stored on that character at login. The Auction House does not have to be opened. On WoW Forever the modern auction cache is read on login. The older auction house is read while it is open. A posted row stores the item id, link, name, quality, icon, count, time left, the current bid, and the buyout. For a commodity, the buyout is the unit price times the stack. A bid row stores the same item fields, that character’s bid, and the time left. A sold auction is not stored. Quests that character is on are stored under Current. Quests that character has finished are stored under Completed. A current row stores the quest name, its level, the zone, the activity when the client marks it Dungeon, Raid, Scenario, or Delve, and the quest id. A finished row also stores the world, the content, and whether it is account-wide. Account-wide quests are the Warband list. The others are the Character list. World, content, and zone come from that quest’s map. The client does not return a zone for most finished quests, so the map id comes from the client’s quest-pin table, and from a stored map id when that pin is missing. When Quest Completist is installed, its zone is used before that pin. When BtWQuests is installed, its quest location fills a quest that still has no zone. A Rumble appearance quest and a Renowned renown quest are stored as account-wide. A quest titled Tracking Quest, or titled only Level and a number, is left off. When a current quest still has no zone, it keeps the quest log header it sits under. A finished quest that still has no zone is still stored. The completion day is stored when this addon sees the quest turned in. The client does not keep older completion days. The quest id keeps the same quest from being stored twice. Tooltip text is not stored. Achievements store the client’s categories in the client’s order, the name, the points, whether it is earned, the date the client recorded, and the character who earned it. When that character cannot be determined, Who is Account Wide. Earned and unearned achievements are both stored, including a character achievement and a warband achievement, and the other steps in a chain. Steps of one chain are stored on that achievement, including the date a finished step was earned and what an unfinished step still needs. An achievement that is not earned also stores its progress and each requirement. A meta achievement is stored with the others. Hovering a row asks the client for the full tooltip and shows that status and those requirements. The tooltip text is not stored. Hovering a quest asks the client for the full quest tooltip. Statistics are not stored. Collections store Mounts, Pets, Transmog, Transmog Sets, Toys, and Decor once for the account, including an item that is not collected. Manuscripts are stored on every character: druid form unlocks and the tomes that teach a hunter a pet family. A row stores the name, the icon, the quality when the client has one, whether it is collected, and how to obtain it. Tooltip text is not stored. Another account’s data is not stored. On WoW Forever a quest stores the name, the level, the activity when the client has one, and the zone from the quest’s map or from the quest log header. A finished quest also stores world and content when the map climb has them, and account-wide only when the client says so. Achievements store this client’s categories, with Statistics left off, the points, the earned flag, the date, who earned it, and the progress of an achievement that is not earned. Collections store the types this client returns. Manuscripts and Decor are not stored. Heirlooms are stored when this client returns them. Tooltip text is not stored.

## Bags

On the character record. Captured on login. The page rules are in [11-client-apis.md](11-client-apis.md).

Each carried bag stores the bag identity, and when the bag is an item: id, name, quality, and slot count. The backpack has no bag item. Each slot is empty, or it stores item id, link, name, quality, icon, and stack count. The reagent bag is Midnight and WoW Forever. An unequipped reagent bag is left off.

## Personal bank

On the character record. Written only while the bank is open.

| Field | What it is |
|-------|------------|
| Scanned | True only after the personal bank has been open |
| Scanned at | When that scan was saved |
| Slots | Same item fields as a bag slot |

## Warband bank

On the account, not on one character. Written only while the bank is open. Every character on this flavor shows the same warband grid. Midnight only.

## Guild bank

Saved for that guild on that realm. Written only while the guild bank is open. The Bank page shows the guild that the selected character belongs to.

## Professions

On the character record. The profession list is written on login. Each profession’s learned recipes are written when that profession window opens.

Each profession stores the base name, the icon, whether it is primary or secondary, and one entry per expansion from newest to oldest. An expansion stores its name, skill, maximum, and each recipe as recipe id, name, icon, learned flag, quality, and link. A learned flag of false is why the row says Missing. Unlearned recipes are stored when that profession window is open so the page can show whether this character has the recipe. Other characters’ names are computed from their learned flags and shown after Missing. The selected character’s name is not shown. Two saved rows with the same expansion name are kept as one row. On WoW Forever that row is the skill line the client returns, not a Midnight expansion name.

## Currencies

On the character record. Captured on login. Money stays the roster `moneyCopper` field. It is not copied here.

Each currency stores id, name, icon file id, the client header it sits under, amount, maximum when the client has a cap, and a tag when the row needs one. The header is the client’s own name, such as Crests or War Within, not a renamed group. Trader’s Tender is tagged Account. Honor is tagged PvP. The page also keeps the header list in the client’s order, including a header that has other headers under it, such as Legacy. On WoW Forever the stored list is Honor Points, Rank Points, Tarnished Undermine Real, Merchant's Favor, and Darkmoon Prize Ticket, under Player vs. Player, Dungeon and Raid, Professions & Tradeskills, and Miscellaneous. An amount this character does not have is stored as 0.

## Reputations

On the character record. Captured on login. Alliance and Horde are not rows. They are the roster `side` field.

Each faction stores id, name, group header, kind (`standard`, or on Midnight `renown` or `companion`), standing label, current, maximum, the standing floor, and shared. The page keeps those rows under the client’s headers, in the client’s order. A renown row’s standing label is Renown and its level. A companion row sits under Delver's Companion, including at level 0, and its standing label is its level. A faction that can be earned stays on the list at zero. A friendship rank, such as Guest or Mastermind, is the standing label on that faction. There is no Friendship header. Shared true is why the row says Account. Paragon and renown rewards are not stored. On WoW Forever every stored row is the normal standing bar, under Alliance, Alliance Forces, Horde, Horde Forces, Steamwheedle Cartel, or Other. A faction this character has not discovered is stored at Neutral, current 0 and maximum 3,000. Renown, Delver Companion, and Warband are not stored.

## Mail

On the character record. The full inbox is written while the mailbox is open. Login writes the new-mail notice for the logged-in character. A letter sent to another character on this account is written on that character at send time. On WoW Forever this is the same inbox. Sent mail and cash-on-delivery are not stored.

| Field | What it is |
|-------|------------|
| Scanned | True after a full inbox read |
| Scanned at | When that full inbox was saved |
| Notice | Up to three sender names from the new-mail notice |
| Sent | Letters sent to this character, until the next full inbox read |
| Letters | Sender, subject, attached copper, days left, the time those days were saved, read flag, and each attachment’s id, name, quality, count, icon, and link |

Sent mail is not an outbox. Cash-on-delivery is not stored. Tooltip text is not stored. Days left count down from the saved time.

## Vault

On the character record. Midnight only. Captured on login, and again when the vault itself updates. Not copied to the other flavors.

Each activity the client returns is stored: Raids, Dungeons, World, and PvP when that row exists. Each slot stores its index, the tier number, the reward item level, status `locked` or `ready`, progress, threshold, and the client’s requirement line. The page does not show the index. A ready slot shows Tier: and that number, then Item Level: and the reward item level. A locked slot shows progress/threshold, such as 4/8. A collected reward stays `ready`. No claimed flag. The item choices inside a ready slot are not stored.

## What is not a SavedVariables field

| Shown on a page | Where it comes from |
|-----------------|---------------------|
| “Logged in now” | GUID compare at display time |
| Account Wide money | Sum of each character’s `moneyCopper` |
| Missing recipe, and the other character’s name | Compared from each character’s learned recipes |
| Item tooltip, bag tooltip, mail tooltip, talent tooltip | The client, from the stored link or talent entry id |
| Read under the mouse key | WoW’s own keybind for BMG Alt Manager |
| `/avread` | A slash command |

## Empty states

Approved with batch 1:

| Situation | What the player sees |
|-----------|----------------------|
| This character is the one logged in | “Logged in now” under the name |
| This character is an alt | The race portrait and the name. No “Logged in now” line |
| This character has never logged in on this addon | No card. A card appears after the first login scan |
| Bank has never been opened on that character | “Not scanned yet” on the personal bank. Not an empty bank |
| Warband bank has never been opened | “Not scanned yet” on that grid. Midnight only |
| Mail has not been checked on that character | “Not scanned yet” on the Mail page |
| Login found no new mail | “No new mail” |
| Mailbox was opened and has no letters | “Inbox is empty” |
| A profession window has never been opened | “Not scanned yet” on that profession |
| The character is in no guild | “Not in Guild” under the Guild header |

Not stored in any record: secrets, full tooltip text, or another account.
