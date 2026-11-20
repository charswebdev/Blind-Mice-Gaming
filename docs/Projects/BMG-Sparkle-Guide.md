# BMG Sparkle Guide

| Field | Value |
|-------|--------|
| Status | **Shipped** |
| Version | **1.0.8** retail and **1.0.8** WoW Forever |
| Type | In-game sparkle and spoken guide for the object in front of you |
| Retail folder | `BMGSparkleGuide/` |
| Forever folder | `BMGSparkleGuide-forever/` |
| Retail clients | `120105`, `120100`, `120007`, `120001` |
| Forever clients | `16002`, `16001`, `16000`, `121500`, `121000` |
| SavedVariables | `BMGSparkleGuideDB` on retail, `BMGSparkleGuideForeverDB` on WoW Forever |
| Slash | `/sg` and `/sparkleguide` |

## Description

A guide for the one object the Interact Key is pointing at. It draws a sparkle on that object and speaks the name with a pre-recorded voice. Herbs, ore, treasure, quest objects, and the fishing bobber start on. Loot, skinning, and other objects start off.

It is its own addon. It does not load NodeSight Sparkles, does not read that addon’s settings, and does not need it installed. The folder, the saved settings, and the `/sg` window belong to BMG Sparkle Guide.

The WoW Forever copy is the same window, the same voice clips, and the same profile code. It loads only in `_forever_`. Do not install `BMGSparkleGuide/` into `_forever_`, and do not install `BMGSparkleGuide-forever/` into `_retail_`.

## Features

- The sparkle follows the nameplate of the soft-interact object. Styles are Light beam, Twinkle, Glints, Pollen, and Star crown. Light beam is the default: a wide column, gold at the base and white at the top, with rising motes and a ground ring. It grows when the camera moves in, so the beacon stays large on the node. Size runs from 60 to 240.
- Colors are Gold and white, Nature, Arcane, Frost, Fire, Shadow, Holy, Blood, White, Sun, Fel, Sea, Royal blue, Rose, Copper, and Moon. Each beam stays in that color, so a green stays green and a blue stays blue. Royal blue is a deep blue with a bright blue core.
- Import and export is a page in the left list. Export fills a box with a code for the sparkle, voice, and track settings. Import reads a pasted code and loads those settings. Size, height, count, and brightness are saved per kind. Each of those has a slider and a box, so the number can be typed. The low and high ends of the slider are written under it. Light beam does not use count.
- The settings window has one preview of that kind’s node, turning on the mount-journal background, with the sparkle on the node. The window fits a 1080p screen. Drag the lower right corner to resize it. The size is kept for the next login. The camera waits until the model has a real size, then stands back so the node and the beam both show. The name under the picture is the kind, such as Herbs. Drag turns the node. The mouse wheel zooms. Height moves where the sparkle sits on that node. The light beam is a soft column with a glow on the ground. Under that, five sample pictures show Light beam, Twinkle, Glints, Pollen, and Star crown. Click a sample to use that style. Loot and skinning have no model, so the preview is the sparkle on the dark frame.
- Every sparkle page has a Track these list. Uncheck a name to leave that object alone. Track all and Track none set the whole list. The list stays inside the window, and the rest of the names scroll. The same window clip holds the text on Announce at, Sparkle settings, and Import and export. A herb, ore node, or chest that is not on its list is still tracked while that page’s box is on. Other objects sparkle only for a checked row: anvil, forge, campfire, cooking fire, alchemy table, enchanting table, workbench, loom, portal, waygate, teleporter, meeting stone, summoning stone, mole machine, elevator, boat, door, guild vault, Great Vault, mission table, transmogrifier, book, bulletin board, lever, fishing pool, crate, barrel, and basket. Seat and Mailbox start unchecked. Quest objects lists the unfinished targets in your quest log. Fishing bobber, Loot, and Skin each list that one target, checked. Flight path is its own page, on at the start, and lists Flight path. A flight master gets the beacon and the spoken line “Flight path.” The kind name sits inside the preview.
- Announce at is on every sparkle page and on its own page. The boxes are 50, 45, 40, 35, 30, 25, 20, 15, 10, 5, and At. At is 0 yards: “At”, then the label. A checked step is spoken when the distance changes to that step. Play sample says “Silverleaf. 10 yards.”
- Voice is Microsoft Zira, a little slow, from short clips. “Silverleaf. 10 yards.” is the name clip, then a shared distance clip. “At Silverleaf.” is “At”, then the label, and that step is 0 yards.
- The spoken line is the tracked label, such as Silverleaf, Portal, Door, or Corpse. It does not substitute Herb, Ore, Treasure, Quest, or Object. A lush, rich, or themed prefix still uses the plain label when that label has a clip. Loot says Corpse. Flight path says Flight path.
- A distance is spoken when the client gives a plain yard number under 80. You hear the label, then 50, 45, 40, 35, 30, 25, 20, 15, 10, or 5. At 0 yards you hear “At”, then the label. When that number is hidden, farther than about 11 yards says 50, and inside that says 10. “At” is also spoken when the loot window opens or a gather cast starts on that object.
- While any sparkle is on, Interact Key is turned on and set to notice objects all around, out to 50 yards. The beacon and the spoken line use that same range. Turning every sparkle off, or logging out, puts those settings back. The guide waits until combat ends before it changes them.
- Hide in combat starts off. Hide in dungeons starts on. The minimap button starts on.
- The addon list groups both copies under Blind Mice Gaming, the same category as the other addons.

## Development plan

1. Playtest on retail: stand near a herb, an ore node, a chest, and a fishing bobber. Confirm the sparkle sits on the object and the spoken line matches what is in front of you.
2. Confirm Interact Key returns to the previous settings after every sparkle is turned off, and again after logout.
3. If a current node name is spoken as the kind instead of its name, add that name to the clip list.

## Sources and data

| Path | Role |
|------|------|
| `softTargetInteract`, `SoftTargetIconGameObject`, `SoftTargetInteractArc`, `SoftTargetInteractRange` | The Interact Key. Saved once, then set to 3, 1, 2, and 50 while sparkles are on |
| `PLAYER_SOFT_INTERACT_CHANGED`, `NAME_PLATE_UNIT_ADDED` | The one object the game is pointing at, and its nameplate |
| Interact icon atlas | Herb, mining, skin, loot, and quest. A loot icon on a game object is treated as treasure |
| Object name | Herb endings, vein or deposit or seam, chest or coffer, and the word bobber. Bobber object id 35591 |
| Quest log objectives | Unfinished objective words, so a quest object can match when the icon does not |
| `UnitDistanceSquared`, then `UnitPosition` | Yards when the number is plain and under 80. A hidden number is still compared when the client allows it. The nameplate is tried first, then `softinteract` |
| `CheckInteractDistance` | When no yard number can be read: about 11 yards or closer says 10, farther says 50 |
| `UNIT_SPELLCAST_SENT`, `LOOT_OPENED` | “At” when a gather cast starts on that name, or the loot window opens |
| `Sounds/*.ogg` | Zira clips at 22050 Hz. Names are the node. Distance, At, and the kind words are shared |

The sparkle drawing uses Blizzard’s star, starburst, and white textures.

## What worked

- Separate clips keep the addon small. One name recording plus a shared clip for each distance covers every step.
- The icon is an uncompressed 32-bit TGA, 256×256, with the same header shape as the other addon icons.
- The preview keeps the sparkle inside its frame. Style is five sample pictures. Announce at picks 20, 15, 10, 5, and At. Each slider has a box for a typed number. Herbs, ore, and chests can be checked one by one. `/sg` opens the window.

## What did not work

- The game does not give a distance for every object. Saying “At” for a missing number called a far node “At loot,” and saying only the name left it as “Loot.” A hidden number is compared when the client allows it. Otherwise farther than about 11 yards says 50, and inside that says 10. “At” is 0 yards, and it is also spoken when the loot window opens or a gather cast starts. The beacon and the spoken line reach 50 yards. The steps are 50, 45, 40, 35, 30, 25, 20, 15, 10, 5, and At.
- A wave file is not a safe sound for this client. The clips are ogg.
- The Interact Key can still notice the object from about 15 yards even when the setting asks for 30. That is the client, not a second scan.
- Putting the sparkle on a nameplate and then changing that frame’s strata stopped the picture and the spoken line together. The sparkle now stays on the nameplate without that strata change. The spoken line plays even when the picture cannot be placed. The guide keeps looking while any sparkle page is on.
- The object’s nameplate unit is what the game can identify. Reading another plate’s unit with a secret value stopped the check before any beacon or speech. Herb, ore, and chest names and icons count even when the object flag is missing.
- The beacon is parented to the object nameplate, anchored to the bottom of that plate, and the column is three times the sparkle size. The beam’s ground is drawn below the frame’s middle, so the frame is lifted by that amount and the glow sits on the chosen height. A game object with no readable name still gets the herb beacon while Herbs is on.
- The preview locked its camera before the model had loaded, and the sparkle was pinned to the middle of the box, so the node and the beam did not line up. The camera now waits for a real model size, and the sparkle hangs from a plate over the node.
- A size of 160 still drew a thin short column, and the preview shrank it further, so the beacon looked small on the plant. The column is wider and taller now, the world beacon grows as the camera comes closer, and the preview keeps most of that size.
- A killed beast gets a nameplate only while that corpse is the one in front of you, and only when Skinning or Loot is on. Loot is spoken when that corpse shows the loot icon and another player does not own the tag. A body tagged by someone else stays quiet. Requiring the corpse to already be lootable hid a fresh kill, because that check stays false until the loot window can open. The loot icon is enough. If Loot is off and Skinning is on, that body uses the skinning beacon.
- Other objects used to sparkle on every leftover object, including every chair and mailbox, and the page did not say which ones. The page now lists each type. Seat and Mailbox start unchecked. Quest objects, the fishing bobber, loot, and skinning had no list. Those pages now list what they track. A flight master had no beacon. Flight path draws one and says “Flight path.” Saying “Object” or “Loot” did not name the thing in front of you. The spoken line now uses the tracked label, and a corpse says “Corpse.”

## Open work

- In-game check with `/reload`, then `/sg`. Confirm a herb, an ore node, a chest, and a fishing bobber on retail and on WoW Forever.
- Drag the lower right corner and confirm the window keeps that size after `/reload`. Confirm a node near 50 yards speaks 50, and one near 45 yards speaks 45.
