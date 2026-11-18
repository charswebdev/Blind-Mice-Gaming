# BMG Sparkle Guide

| Field | Value |
|-------|--------|
| Status | **Shipped** |
| Version | **1.0.1** retail and **1.0.1** WoW Forever |
| Type | In-game sparkle and spoken guide for the object in front of you |
| Retail folder | `BMGSparkleGuide/` |
| Forever folder | `BMGSparkleGuide-forever/` |
| Retail clients | `120105`, `120100`, `120007`, `120001` |
| Forever clients | `16002`, `16001`, `16000`, `121500`, `121000` |
| SavedVariables | `BMGSparkleGuideDB` on retail, `BMGSparkleGuideForeverDB` on WoW Forever |
| Slash | `/sg` and `/sparkleguide` |

## Description

A guide for the one object the Interact Key is pointing at. It draws a sparkle on that object and speaks the name with a pre-recorded voice. Herbs, ore, treasure, quest objects, and the fishing bobber start on. Loot, skinning, and other objects start off.

The WoW Forever copy is the same window, the same voice clips, and the same profile code. It loads only in `_forever_`. Do not install `BMGSparkleGuide/` into `_forever_`, and do not install `BMGSparkleGuide-forever/` into `_retail_`.

## Features

- The sparkle follows the nameplate of the soft-interact object. Styles are Light beam, Twinkle, Glints, Pollen, and Star crown. Light beam is the default: a tall column, gold at the base and white at the top, with rising motes and a ground ring.
- Colors are Gold and white, Nature, Arcane, Frost, Fire, Shadow, Holy, Blood, White, Sun, Fel, Sea, Royal blue, Rose, Copper, and Moon. Each beam stays in that color, so a green stays green and a blue stays blue. Royal blue is a deep blue with a bright blue core.
- Import and export is a page in the left list. Export fills a box with a code for the sparkle, voice, and track settings. Import reads a pasted code and loads those settings. Size, height, count, and brightness are saved per kind. Each of those has a slider and a box, so the number can be typed. The low and high ends of the slider are written under it. Light beam does not use count.
- The settings window has one preview of that kind’s node, turning on the mount-journal background, with the sparkle on the node. The name under the picture is the kind, such as Herbs. Drag turns the node. The mouse wheel zooms. Height moves where the sparkle sits on that node. The light beam is a soft column with a glow on the ground. Under that, five sample pictures show Light beam, Twinkle, Glints, Pollen, and Star crown. Click a sample to use that style. Loot and skinning have no model, so the preview is the sparkle on the dark frame.
- Herbs, ore, and treasure each have a Track these list. Every name starts checked. Uncheck a name to leave that node alone. Track all and Track none set the whole list. A node that is not on the list is still tracked while that page’s box is on. Quest objects, the fishing bobber, loot, skinning, and other objects are tracked as a whole group.
- Announce at is on every sparkle page and on its own page. The boxes are 20 yards, 15 yards, 10 yards, 5 yards, and At. A checked step is spoken when the distance changes to that step. Play sample says “Silverleaf. 10 yards.”
- Voice is Microsoft Zira, a little slow, from short clips. “Silverleaf. 10 yards.” is the name clip, then a shared distance clip. “At Silverleaf.” is “At”, then the name.
- A node without its own clip says Herb, Ore, Treasure, Quest object, Loot, Skin, Fishing bobber, or Object. A lush, rich, or themed prefix is skipped when the plain name has a clip.
- A distance is spoken only when the client gives a plain yard number under 80. Otherwise the guide says the name when the object is first picked, and “At” when a cast is sent at that same name.
- While any sparkle is on, Interact Key is turned on and set to notice objects all around, out to 30 yards. Turning every sparkle off, or logging out, puts those settings back. The guide waits until combat ends before it changes them.
- Hide in combat starts off. Hide in dungeons starts on. The minimap button starts on.
- The addon list groups both copies under Blind Mice Gaming, the same category as the other addons.

## Development plan

1. Playtest on retail: stand near a herb, an ore node, a chest, and a fishing bobber. Confirm the sparkle sits on the object and the spoken line matches what is in front of you.
2. Confirm Interact Key returns to the previous settings after every sparkle is turned off, and again after logout.
3. If a current node name is spoken as the kind instead of its name, add that name to the clip list.

## Sources and data

| Path | Role |
|------|------|
| `softTargetInteract`, `SoftTargetIconGameObject`, `SoftTargetInteractArc`, `SoftTargetInteractRange` | The Interact Key. Saved once, then set to 3, 1, 2, and 30 while sparkles are on |
| `PLAYER_SOFT_INTERACT_CHANGED`, `NAME_PLATE_UNIT_ADDED` | The one object the game is pointing at, and its nameplate |
| Interact icon atlas | Herb, mining, skin, loot, and quest. A loot icon on a game object is treated as treasure |
| Object name | Herb endings, vein or deposit or seam, chest or coffer, and the word bobber. Bobber object id 35591 |
| Quest log objectives | Unfinished objective words, so a quest object can match when the icon does not |
| `UnitPosition` | Yards, only when both points are plain numbers and the distance is under 80 |
| `UNIT_SPELLCAST_SENT` | “At” when the sent target name matches the live node |
| `Sounds/*.ogg` | Zira clips at 22050 Hz. Names are the node. Distance, At, and the kind words are shared |

The sparkle drawing uses Blizzard’s star, starburst, and white textures. It does not copy another addon’s code. NodeSight Sparkles was the reference for the job: one soft-interact object, the same CVars, and a light beam that is easy to see from far away.

## What worked

- Separate clips keep the addon small. One name recording plus five shared distance lines covers every step.
- The icon is an uncompressed 32-bit TGA, 256×256, with the same header shape as the other addon icons.
- The preview keeps the sparkle inside its frame. Style is five sample pictures. Announce at picks 20, 15, 10, 5, and At. Each slider has a box for a typed number. Herbs, ore, and chests can be checked one by one. `/sg` opens the window.

## What did not work

- The game does not give a distance for every object. Inventing 20, 15, or 10 when the number is missing would be wrong, so those lines stay silent until a real number arrives.
- A wave file is not a safe sound for this client. The clips are ogg.
- The Interact Key can still notice the object from about 15 yards even when the setting asks for 30. That is the client, not a second scan.

## Open work

- In-game check with `/reload`, then `/sg`. Confirm a herb, an ore node, a chest, and a fishing bobber on retail and on WoW Forever.
