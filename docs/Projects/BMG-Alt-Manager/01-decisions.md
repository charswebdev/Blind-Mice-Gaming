# Decisions

This file records what was said and what Charlotte has approved. A row marked **Approved** is locked. A row marked **Shown** was put on screen and has not been accepted yet. A row marked **Proposed** is a plan, not a decision.

The implementation plan in [03-implementation-plan.md](03-implementation-plan.md) was **approved** on 2026-10-29. That locks the flavor order, the scan rules, and the phase order. The settings button, the currency picture, and the vault picture were approved on 2026-10-29. The full Gear page, roster and list together, was approved on 2026-10-29. The reference is [gear-page-full.jpg](reference/gear-page-full.jpg). The full Bags page, roster and bag grids together, was approved on 2026-10-29. The reference is [bags-page-full.jpg](reference/bags-page-full.jpg). Search was added to that page the same day. The full Bank page was approved on 2026-10-29. The reference is [bank-page-full.jpg](reference/bank-page-full.jpg). The full Professions page was approved on 2026-10-29. The reference is [professions-page-full.jpg](reference/professions-page-full.jpg). The full Currency page was approved on 2026-10-29. The reference is [currency-page-full.jpg](reference/currency-page-full.jpg). The full Reputation page was approved on 2026-10-29. The reference is [reputation-page-full.jpg](reference/reputation-page-full.jpg). The full Mail page was approved on 2026-10-29. The reference is [mail-page-full.jpg](reference/mail-page-full.jpg). The full Vault page was approved on 2026-10-29. The reference is [vault-page-full.jpg](reference/vault-page-full.jpg). The full Overview page was approved on 2026-10-29. The reference is [overview-page-full.jpg](reference/overview-page-full.jpg). It is the page shown when a character is selected.

## Product

| Decision | State |
|----------|--------|
| Name: BMG Alt Manager. Author: Blind Mice Gaming | Approved |
| Graphical, in the spirit of AltVault’s layout. Data gathered in the spirit of Altoholic. Original code and original art | Approved |
| Do not copy AltVault or Altoholic art or code. Do not vendor DataStore | Approved |
| Every flavor except Season of Discovery. Never install into `_classic_beta_` | Approved |
| One addon, one SavedVariables database, and one updater row per flavor | Approved |
| Addon folder `BMGAM` for Midnight. Other flavors add a suffix | **Approved** on 2026-10-29 |
| Midnight first. Then Era, Anniversary, MoP Classic, Forever | Approved |
| Window stays closed until slash or the minimap button | Approved |
| Slash `/bmgam` opens the window | **Approved** on 2026-10-29 |
| SavedVariables `bmgam_SavedVariables` | **Approved** on 2026-10-29. Same global in every flavor. Each client keeps its own copy |
| Search box on Bags, Bank, and Professions | **Approved** on 2026-10-29 |
| Reading aloud | **Approved**. Only F6 or `/avread`, and only what is under the mouse |

## Addon icon and window chrome

| Piece | State | Picture |
|-------|--------|---------|
| Gold vault with a realistic happy mouse | **Approved** (“perfect”) | [addon-icon.jpg](reference/addon-icon.jpg) |
| Close: dark iron plate, red glass X | **Approved** | [close-button.jpg](reference/close-button.jpg) |
| Settings: same plate, gold gear, immediately left of Close | **Approved** on 2026-10-29. The page behind it is [settings-page-full.jpg](reference/settings-page-full.jpg), including the Export / Import header, approved the same day | [settings-button.jpg](reference/settings-button.jpg) |

Rejected icon directions, so they are not reused: a flat cartoon mouse, a dimensional cartoon mouse, a realistic mouse that was not happy enough, and mouse-head shields used as if they were class icons.

## Left roster

**Approved** on 2026-10-28, including the Race field.

Each character has its own border.

1. Real WoW class icon, then the character name in gold. The icon is to the left of the name.
2. `Level: <level>` then `Race: <race name>` then `Item Level: <item level>`. The item level number uses that character’s item-quality color.
3. `Server: <server>` then `Faction: <Alliance or Horde>`. Alliance is blue. Horde is red. This faction is the character’s side, not a reputation.
4. `Money:` then a gold coin and the gold amount, a silver coin and the silver amount, a copper coin and the copper amount.

Sample cards used while designing:

| Character | Class | Race | Level | Item level | Color | Server | Side | Money |
|-----------|--------|------|-------|------------|-------|--------|------|-------|
| Ares | Warrior | Human | 70 | 624 | Epic purple | Stormrage | Alliance | 50g 12s 34c |
| Lyra | Mage | Blood Elf | 70 | 610 | Rare blue | Area 52 | Horde | 125g 0s 8c |
| Sylas | Hunter | Orc | 70 | 580 | Uncommon green | Illidan | Horde | 85g 40s 2c |
| Vex | Warlock | Undead | 70 | 640 | Legendary orange | Sargeras | Horde | 210g 5s 19c |

Ares is the logged-in character in the sample, so his card is the selected one.

Quality colors used on the item level:

| Quality | Color |
|---------|--------|
| Uncommon | `#1eff00` |
| Rare | `#0070dd` |
| Epic | `#a335ee` |
| Legendary | `#ff8000` |

Alliance blue is about `(70, 140, 255)`. Horde red is about `(220, 40, 40)`.

Class icons are the real class buttons (sword, staff, bow, fel hand), from the client. A generated drawing does not replace those files.

## Right header

**Approved.**

- The portrait beside the name is the race icon, not the class icon. Ares uses the human male race portrait.
- Under the name, the logged-in character shows “Logged in now”.
- When the addon opens, that logged-in character is selected.
- A trash can on the far right of this name line is **Approved** on 2026-10-29. The button is [trash-button.jpg](reference/trash-button.jpg), shown on the name line in [forget-character.jpg](reference/forget-character.jpg). It is a dark iron plate with a bright gold border and a dimensional gold can, lid tilted open. When it is built, the tooltip says **Forget this character**. Clicking it opens a confirmation box before that character’s snapshot is removed.

## Tabs

Buttons have pictures and no words. A tooltip will say the name.

Midnight order, left to right:

| Order | Tab | Picture | State |
|-------|-----|---------|--------|
| 1 | Overview | Gold helmet and breastplate | **Approved** on 2026-10-29. This is the page shown when a character is selected |
| 2 | Gear | Gold breastplate | **Approved** for Midnight |
| 3 | Bags | Leather backpack | **Approved** for Midnight |
| 4 | Bank | Locked wooden chest | **Approved** for Midnight |
| 5 | Professions | Flask, blue gem, and herb | **Approved** for Midnight. The anvil was rejected |
| 6 | Currency | Stack of gold, silver, and copper coins | **Approved** on 2026-10-29. Sits immediately before Reputation |
| 7 | Reputation | Gold medal on a red and gold ribbon | **Approved** for Midnight. The flag was rejected |
| 8 | Mail | Sealed envelope | **Approved** for Midnight |
| 9 | Vault | Round vault door with a wheel and a violet seam | **Approved** on 2026-10-29. Midnight only |

Other flavors use the same row without Vault. They do not have a Great Vault to check. Charlotte locked this on 2026-10-29: a flavor hides a tab it does not have. The remaining tabs stay in one row. A player cannot hide a tab that flavor has. A client with no hero talents does not show the Hero line or the Hero talent list on Overview.

Every full-page picture uses the thirteen-tab row. Overview is first. Vault is last. Only the open page’s tab is lit. Settings leaves every tab resting. Gear has no search box. Every other tab has one.

Reputation on this tab means standing with factions (the full faction name and the bar). It does not mean Alliance or Horde.

The full window that shows this row, the approved character cards, and the settings button is [overview-page-full.jpg](reference/overview-page-full.jpg). The earlier shell with eight tabs and an empty gear doll was removed.

## Gear page

**Approved** on 2026-10-29. The reference picture is [gear-page-full.jpg](reference/gear-page-full.jpg).

- Show the worn gear.
- Each item shows durability when it has durability.
- Each item shows whether it has an enchant. If it cannot be enchanted, say so.
- If the item has a gem socket, show the gem that is in it. Also show whether a gem can still be added.

The approved picture shows the neck as “No durability”. Ring of Fire has an enchant. Ring of Earth says “Not enchanted”. “Cannot be enchanted” is for trinkets, the shirt, and the tabard.

Charlotte locked three more Gear rules on 2026-10-29. A slot with nothing equipped stays on the page and says **Empty Slot**. An item at 0 durability shows `0 / maximum` in red and does not say Broken. The ranged slot is shown only on a flavor whose client has it.

The row rules are written in full in [05-layout.md](05-layout.md).

## Bags page

**Approved** on 2026-10-29. The reference picture is [bags-page-full.jpg](reference/bags-page-full.jpg).

- Each bag that character is carrying is its own section: Backpack, then the equipped bags, then the Midnight reagent bag.
- The header shows the bag icon, the bag name, and how full the bag is. Empty slots stay visible.
- Hovering a filled slot shows the client’s item tooltip for the stored link. The tooltip in the picture is open so that hover can be seen. It is not a panel that stays on the page.
- A search box sits under the tabs. It matches item names in these bags. The picture shows the box empty, with the placeholder Search.
- On this picture the Bags tab is the only lit tab. The Gear tab uses the same resting border as the other tabs.

The page rules are written in full in [05-layout.md](05-layout.md).

## Bank page

**Approved** on 2026-10-29. The reference picture is [bank-page-full.jpg](reference/bank-page-full.jpg).

- Personal bank first, then the Midnight warband bank. Each is its own grid, with the same slots as Bags.
- A bank that has never been opened says **Not scanned yet**.
- The same search box sits under the tabs. On this page it matches names in the personal bank and the warband bank.
- The guild bank is not this page.
- On this picture the Bank tab is the only lit tab.

The slot counts in the picture are a sample. The client supplies the real size.

## Professions page

**Approved** on 2026-10-29. The reference picture is [professions-page-full.jpg](reference/professions-page-full.jpg).

Charlotte added two rules on 2026-10-29:

- If another character knows a recipe, that character’s name is shown on the row.
- The page has a search box so a player can search for a recipe.

## Page data locked on 2026-10-29

These are planning rules. Settings is locked with the other pages.

| Page | Rule |
|------|------|
| Bank | Midnight includes the warband bank as its own grid, shared by the account, then the guild bank for that guild on that realm. A flavor with no warband bank or no guild bank leaves that section off |
| Professions | Store learned recipes so one character can be seen as already knowing a recipe another is missing |
| Currency | Midnight shows every current-expansion currency, including zero. That includes crests, Delve, Catalyst, profession currency, and Nebulace cores. Any other currency that Midnight character has is shown too. Other flavors show only currencies the character has. Headers are bold and name the expansion. Currencies that are not from an expansion, such as Trader’s Tender and PvP Honor, sit under a bold Other header. Amounts are bold. Gold, silver, and copper on this page are two rows, Character: and Account Wide:, with the coins on the right |
| Reputation | Full faction name, standing, and bar. Alliance and Horde stay on the character card. Standard factions use the client’s groups and order. Midnight adds Renown, Delver Companion, and Warband headers. There is no Friendship header. Delver Companion shows a level. A shared faction says Account. A warband faction says Account. Paragon and renown rewards stay off. A search box matches the names on this page |
| Mail | Inbox only, one row per letter: sender, subject, days left, attached coins, and attached items. An unread subject is bold. Fewer than 3 days turns gold. Never opened says “Not scanned yet”. Opened and empty says “Inbox is empty”. Sent mail and cash-on-delivery stay off. A search box matches the names on this page |
| Vault | Midnight only. All 9 slots. Each activity is a row, and its three slots go left to right, in the client’s order. Each slot shows Locked or Ready, the tier, the item level, and the client’s requirement line. Locked text is bold cream with a dull gold border. Ready text is bold bright green with a bright gold-yellow border. There is no Taken state. Item choices inside a ready slot stay off. A search box matches the names on this page |
| Settings | Opens from the gear. No tab is lit. Show minimap button toggles On or Off and shows that state. Read under the mouse is F6. The slash command is `/avread`. Nothing is read on its own |
| Quests | Approved on 2026-10-30. Current is a bold gold header. Quests that character is on are grouped by zone under it. Completed is a bold gold header. Finished quests are grouped by zone under it. A row is the quest name and its level. Search matches both parts. Scanned on login |
| Overview | The page shown when a character is selected. Class, Hero, and Specialization labels are bold bright yellow, and the names beside them are bold bright white. Stat labels are the same yellow, and the numbers are the same white. Guild has its own header in bold gold, and the guild name is bold bright white. Under Guild, Delver's Journey sits beside Prey, and Traveler's Journey sits beside Hearthstone Location. The first three show progress and rank. Hearthstone Location shows the place. Each heading line sits below its title and clear of the line under it. Talent rows are the client’s icon and a bold bright yellow name. Only talents the player has taken are listed. Hovering a name shows the client’s full talent tooltip. The tooltip text is not stored. A search box matches the names on this page |

## Data rules already set

These come from the Altoholic-style investigation and stay unless Charlotte changes them.

- The addon writes its own scanner. It does not ship DataStore.
- Bags and worn gear are read on login.
- Bank is read only while the bank window is open. The guild bank is read only while the guild bank is open.
- Mail’s full inbox is read while the mailbox is open. Login reads the new-mail notice. A letter sent to a character on this account is saved on that character when it is sent.
- Professions are read when the profession window opens.
- Each alt has to be logged in once before that alt has a snapshot.
- SavedVariables are account-wide, separate per flavor.
- Do not store secrets or the full tooltip text.
- On the Bags page, hovering a filled slot shows the client’s item tooltip for the stored link. Hovering the bag item in a header does the same. The words of that tooltip are not saved. Empty slots have no item tooltip.
- Drop Midnight and Forever secret values rather than saving them.
- Sharing snapshots across accounts stays out. Charlotte locked that on 2026-10-30.
