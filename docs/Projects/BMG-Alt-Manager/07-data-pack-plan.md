# Data pack plan

Approved on 2026-10-29. These are planning notes, not addon code. All four batches are approved. The settings button, the currency picture, the vault picture, and the full Gear page were approved later the same day. The Gear reference is [gear-page-full.jpg](reference/gear-page-full.jpg).

No Lua is created in any batch. Each batch is shown and approved before the next batch starts.

## Why these notes exist

The design pack has the look and the phase order. It does not yet say what a character record stores, which equipment slots exist on each flavor, or which WoW functions a page is allowed to call. These notes are that missing information. A later coding phase has to follow them.

## Rules for every batch

- Write what is known. If a function or an item-link position is not certain, mark it **unconfirmed**. Do not guess a Forever function. Forever is filled in when that flavor starts, from the Forever client.
- Save display names at scan time. Item names, enchant names, and gem names are stored on the snapshot. They are not looked up later from a different character, because the client often has not cached them.
- Store a class file (`WARRIOR`) and a race file, plus sex, not only the localized words. The class icon and the race portrait depend on those. A human woman does not use the human male portrait.
- The character key is the player GUID plus the realm. The name is for display. Two realms can share a name.
- Do not copy AltVault or Altoholic code or data files into these notes.
- Do not store secrets or full tooltip text. That rule is already locked.
- Midnight-only systems stay in their own section: warband bank, renown, and the Great Vault. They are not copied onto Era, Anniversary, MoP, or Forever. The reagent bag is Midnight and WoW Forever. Era, Anniversary, and MoP do not get one.

## Batch 1 — the character record and the shell

Two files.

[08-character-record.md](08-character-record.md) will hold:

- The account-wide SavedVariables shape, one record per character.
- The key: player GUID and realm.
- Fields the roster needs: name, realm, class file, race file, sex, level, side, money in copper, item level, and the time of the last login scan.
- A filled example for Ares, using the sample already on the character card, plus sex (male) and a placeholder GUID labeled as a sample.
- Empty-state words, written as proposals inside the file: an alt who is not logged in has no “Logged in now” line; a bank or mailbox that has never been opened says it is not scanned, not that it is empty.

[09-shell-behavior.md](09-shell-behavior.md) will hold the window rules the first Midnight slice needs:

- The window stays hidden until the minimap button or the slash command opens it.
- Recommended: Escape does not close it. That matches BMG Event Tracker. This recommendation is approved or changed when batch 1 is reviewed.
- The roster scrolls when the cards are taller than the window.
- Position and scale are remembered. The first-open size follows the mockup’s proportions and can be scaled. The exact first-open pixel size is proposed in the file for approval, not invented in code.
- The addon folder is `BMGAM`. The SavedVariables name is `bmgam_SavedVariables`. The slash command that opens the window is `/bmgam`.

Batch 1 stops there. Charlotte reviews those two files before batch 2.

## Batch 2 — Gear data

[10-gear-data.md](10-gear-data.md) will hold:

- Midnight equipment slots, in paper-doll order, including shirt, tabard, both rings, both trinkets, main hand, and off hand.
- A separate column for Era, Anniversary, and MoP where the slot list differs. Era’s ranged slot is included. Midnight’s list does not gain a ranged slot.
- For each slot: has durability or not, can be enchanted or not, can have a socket or not. Neck, rings, trinkets, shirt, and tabard have no durability. Trinkets, shirt, and tabard cannot be enchanted. Rings can be enchanted.
- The item fields stored at scan time: item id, item link, name, quality, icon file id, durability current and maximum when the item has them, enchant id and enchant name, and each socket as filled (gem id and gem name) or empty.
- How the item link is read. One map for Midnight and one map for the classic clients, naming which position is the enchant and which positions are the gems. Any position that is not certain is marked unconfirmed.
- An empty slot is stored as an empty slot, not omitted. The Gear page keeps that row and says **Empty Slot**.

## Batch 3 — one note per later page

[11-client-apis.md](11-client-apis.md) will have a section for Bags, Bank, Professions, Currency, Reputation, Mail, and Vault.

Each section will say:

- What the snapshot stores for that page.
- The Midnight function family that supplies it.
- The older-client function when it is known, or **unconfirmed** when it is not.
- Forever left as “not written until the Forever client is in front of us.”
- What that page must not store.

Midnight-only notes in that file:

- Bags: the reagent bag.
- Bank: the warband bank, kept separate from the personal bank and saved once for the account.
- Reputation: renown, Delver Companion level, and warband reputation, separate from the classic standing bar.
- Vault: all 9 Great Vault slots, with tier, item level, and what the next slot needs. No vault section is copied to the other flavors.

The same file will include one currency sample and one reputation sample, in the same spirit as Ares’s card, so those pages have a real shape to design against. The samples are labeled as samples.

## Batch 4 — playtest list and icon files

[12-playtest.md](12-playtest.md) will be the first in-game check, used when a coding phase exists. It will list:

- One Alliance character and one Horde character.
- A woman, so the race portrait can be checked against the stored sex.
- An empty socket, a slot that cannot be enchanted, and an item under 25% durability.
- An alt whose bank has never been opened, so the “not scanned” line can be checked.
- Two realms, so the GUID-plus-realm key can be checked.

[13-icon-files.md](13-icon-files.md) will record how original art is packed. WoW draws an addon icon from a 32-bit TGA, not from the jpg in `reference/`. The jpg files stay the art reference. TGA files are made only for pictures Charlotte has approved, and only when a coding phase needs them. The approved addon icon and the approved close button are packed with the other approved tab and settings pictures. Those pictures are approved. Class icons, race portraits, item icons, and coins are client textures and are not packed into the addon.

## What this plan does not do

- It does not start addon folders, `.toc` files, or catalog rows.
- The Gear page layout was approved afterward. The reference is [gear-page-full.jpg](reference/gear-page-full.jpg).
- Settings is approved. Its build step is phase 14 in [03-implementation-plan.md](03-implementation-plan.md). It is not a tab.
- The folder name `BMGAM`, the SavedVariables name `bmgam_SavedVariables`, and the slash command `/bmgam` are locked.
- It does not research Forever by guessing.

## After approval

1. Batch 1 is approved: [08-character-record.md](08-character-record.md) and [09-shell-behavior.md](09-shell-behavior.md).
2. Batch 2 is approved: [10-gear-data.md](10-gear-data.md).
3. Batch 3 is approved: [11-client-apis.md](11-client-apis.md).
4. Batch 4 is approved: [12-playtest.md](12-playtest.md) and [13-icon-files.md](13-icon-files.md).

Then the design talks continue with Gear, using the Gear data note alongside the drawing.
