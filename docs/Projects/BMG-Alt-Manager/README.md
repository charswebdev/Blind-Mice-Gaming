# BMG Alt Manager — design pack

Planning notes for the addon. This folder holds the notes and the reference pictures. Phase 1 code is in `BMGAM` at the repo root. The product record is [`../BMG-Alt-Manager.md`](../BMG-Alt-Manager.md).

Charlotte approved this pack as the plan on 2026-10-29. A page is not built until the talk for that page is approved.

## Files

| File | What it holds |
|------|----------------|
| [01-decisions.md](01-decisions.md) | What we already decided, and whether each piece is approved |
| [02-still-to-discuss.md](02-still-to-discuss.md) | The approved pages, and the questions still open |
| [03-implementation-plan.md](03-implementation-plan.md) | Flavors, packages, scan rules, and the build order |
| [04-style.md](04-style.md) | Colors, type, original art, and Blizzard textures |
| [05-layout.md](05-layout.md) | The window, the character card, the tab row, and the Gear row |
| [06-drawings.md](06-drawings.md) | The pictures, with the approval state of each one |
| [07-data-pack-plan.md](07-data-pack-plan.md) | How the scanner and client notes were added. All four batches are approved |
| [08-character-record.md](08-character-record.md) | Batch 1. What one character snapshot stores |
| [09-shell-behavior.md](09-shell-behavior.md) | Batch 1. How the window opens, closes, scrolls, and remembers its size. Approved |
| [10-gear-data.md](10-gear-data.md) | Batch 2. Worn slots, durability, enchants, sockets, and how an item link is read. Approved |
| [11-client-apis.md](11-client-apis.md) | Batch 3. What Bags, Bank, Professions, Currency, Reputation, Mail, and Vault store, and which client functions supply them. Approved |
| [12-playtest.md](12-playtest.md) | Batch 4. What to check in game once a coding phase exists. Approved |
| [13-icon-files.md](13-icon-files.md) | Batch 4. Which pictures become TGA files, and which stay client textures. Approved |

Drawings are in [`reference/`](reference/).

## Status on 2026-10-29

The implementation plan is approved. The data pack plan is approved. All four batches of planning notes are approved. Addon code has not started.

Approved: addon icon, close button, Midnight tab pictures for Overview, Gear, Bags, Bank, Professions, Reputation, and Mail, the left character card including Race, and the right header using the race portrait.

Approved on 2026-10-29: settings button, currency coin stack, and vault door.

Approved Gear page with the roster: [reference/gear-page-full.jpg](reference/gear-page-full.jpg).

Approved Bags page with the roster: [reference/bags-page-full.jpg](reference/bags-page-full.jpg). Hovering an item shows the client item tooltip. That text is not stored. A search box matches item names on this page.

Approved Bank page with the roster: [reference/bank-page-full.jpg](reference/bank-page-full.jpg). Personal bank, then the Midnight warband bank, with the same search box.

Approved Professions page with the roster: [reference/professions-page-full.jpg](reference/professions-page-full.jpg). A recipe another character knows shows that character’s name. Search matches recipe names.

Approved Currency page with the roster: [reference/currency-page-full.jpg](reference/currency-page-full.jpg). Bold expansion headers and bold amounts. Gold, silver, and copper are two rows, Character: and Account Wide:, with the coins on the right. Trader’s Tender and PvP Honor sit under Other.

Approved Reputation page with the roster: [reference/reputation-page-full.jpg](reference/reputation-page-full.jpg). Full faction names, colored standing and bar, client groups, and on Midnight a Renown header, a Delver Companion header, and a Warband header. There is no Friendship header. A shared faction says Account.

Approved Mail page with the roster: [reference/mail-page-full.jpg](reference/mail-page-full.jpg). One inbox row per letter, with sender, subject, days left, attached coins, and attached items. An unread subject is bold. Fewer than 3 days turns gold.

Approved Vault page with the roster: [reference/vault-page-full.jpg](reference/vault-page-full.jpg). Midnight only. Each activity is a row, and its three slots go left to right. Ready text is bold bright green with a bright gold-yellow border. Locked text is bold cream with a dull gold border. There is no Taken state.

Approved Overview page with the roster: [reference/overview-page-full.jpg](reference/overview-page-full.jpg). It is the first tab and the page shown when a character is selected. Class, Hero, Specialization, and stat labels are bold bright yellow. The values beside them are bold bright white. Guild has its own header in bold gold, and the guild name is bold bright white. Under Guild, Delver's Journey sits beside Prey, and Traveler's Journey sits beside Hearthstone Location. The first three show progress and rank. Hearthstone Location shows the place. Each heading line sits below its title. A talent row is the client’s icon and a bold bright yellow name. Only talents the player has taken are listed. Hovering a name shows the client’s full talent tooltip. That text is not stored.

Approved Settings page: [reference/settings-page-full.jpg](reference/settings-page-full.jpg). It opens from the gear. No tab is lit. Show minimap button toggles and shows On or Off. Read under the mouse is F6. The slash command is `/avread`. An **Export / Import** header on that page has **Import** and **Export**. The picture shows both popups so the two fields can be seen. Import’s field is empty, with the cursor in it. Export’s field shows a code that is already selected. `BMGAM-sample` is a picture sample. In the addon, only the popup for the button that was clicked is open.

The Midnight addon folder is `BMGAM`. The other flavors add a suffix. The SavedVariables name is `bmgam_SavedVariables`. `/bmgam` opens the window.

A flavor hides a tab it does not have. Midnight’s tab row is Overview, Gear, Bags, Bank, Professions, Currency, Reputation, Mail, Auction, Quests, Achievements, Collections, Vault. The other flavors hide Vault. Gear has no search box. Every other tab has one. Guild bank is a section on the Bank page. The Auction, Quests, Achievements, and Collections pictures are approved. The Quests page has a Current header and a Completed header, and each one groups its quests by zone. Charlotte approved that drawing on 2026-10-30. Sharing between accounts stays out. Charlotte locked that the same day. The trash can is approved: [reference/trash-button.jpg](reference/trash-button.jpg), on the far right of the selected character’s name line in [reference/forget-character.jpg](reference/forget-character.jpg). Hovering it says Forget this character. A confirmation box opens before the snapshot is removed.
