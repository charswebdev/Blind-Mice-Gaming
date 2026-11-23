# BMG Sparkle Guide

| Field | Value |
|-------|--------|
| Status | **Shipped** |
| Version | **1.2.0** retail and **1.2.0** WoW Forever |
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
- Every sparkle page has a Track these list. Uncheck a name to leave that object alone. Track all and Track none set the whole list. The list stays inside the window, and the rest of the names scroll. The same window clip holds the text on Announce at, Sparkle settings, and Import and export. A herb, ore node, or chest that is not on its list is still tracked while that page’s box is on. A player is never tracked, even when the name ends like a node, such as Vein. A mine you are facing lights from its name or the mining cursor. A tree or other loose object is not turned into a herb. If a player or a tree is in front of a tracked object, that player or tree is skipped and the tracked object is used when it still has a nameplate. Other objects sparkle only for a checked row: anvil, forge, campfire, cooking fire, alchemy table, enchanting table, workbench, loom, portal, waygate, teleporter, meeting stone, summoning stone, mole machine, elevator, boat, door, guild vault, Great Vault, mission table, transmogrifier, book, bulletin board, lever, fishing pool, crate, barrel, and basket. Seat and Mailbox start unchecked. Quest objects lists the unfinished targets in your quest log. Fishing bobber, Loot, and Skin each list that one target, checked. Flight path is its own page, on at the start, and lists Flight path. The beacon is the flight master the interact key is pointing at, recognized by the flight title or the flight cursor. A player is never that beacon. The spoken line is “Flight path.” The kind name sits inside the preview.
- Announce at is on every sparkle page and on its own page. The boxes are 50, 45, 40, 35, 30, 25, 20, 15, 10, 5, and At. At is 0 yards: “At”, then the label. A checked step is spoken when the distance changes to that step. Play sample says “Silverleaf. 10 yards.”
- Voice is Microsoft Zira, a little slow, from short clips. “Silverleaf. 10 yards.” is the name clip, then a shared distance clip. “At Silverleaf.” is “At”, then the label, and that step is 0 yards.
- The spoken line is the tracked label, such as Silverleaf, Portal, Door, or Corpse. It does not substitute Herb, Ore, Treasure, Quest, or Object. A lush, rich, or themed prefix still uses the plain label when that label has a clip. Loot says Corpse. Flight path says Flight path.
- A distance is spoken when the client gives a plain yard number under 80. You hear the label, then 50, 45, 40, 35, 30, 25, 20, 15, 10, or 5. At is a real distance under 2.5 yards, and only when the close interact check agrees: “At”, then the label. A reported 0 is ignored, because that number shows up when the client has no yards. Turning away does not say At again. A hidden yard number is compared directly, so the steps still run out to 50. A flight master is not a group member, so that yard number is often missing. The guide then uses the world position, then item and spell ranges at each 5-yard step. The spoken number is the near side of that gap, so standing on the flight master says At, not 5. 45 and 50 are included. It does not call everything inside 28 yards “25,” and it does not jump from there to 50. “At” is also spoken when the loot window opens or a gather cast starts on that object. The same line is not spoken again for 4 seconds.
- While any sparkle is on, Interact Key is turned on and set to notice objects all around, out to 50 yards. If tab-target range, nameplate distance, or the game-object nameplate distance is shorter than 60, those are raised, so a flight master is not cut off around 25 yards. A herb, mine, chest, quest object, fishing bobber, or other tracked object gets that same nameplate while it is the one in front of you. Loot and Skinning keep that nameplate on. The Corpse beacon is only for a body this player can loot. On a kill this player made, Corpse stays up while that body still has loot for this player, out to 50 yards. Another player looting or skinning does not clear it. The spot is saved once, so it stays past the 5 yard nameplate. Taking the last item clears the Corpse beacon. Skin shows only after this player's loot is gone, until this player skins. Herb, ore, chest, quest, and bobber beacons are not cleared by another player's loot. The game still drops a corpse nameplate at 20 yards, so the guide saves that plate’s spot and keeps the beacon on it out to 50 yards. Turning every sparkle off, or logging out, puts those settings back. The guide waits until combat ends before it changes them.
- Hide in combat starts off. Hide in dungeons starts on. The minimap button starts on.
- The addon list groups both copies under Blind Mice Gaming, the same category as the other addons.

## Development plan

1. Playtest on retail: stand near a herb, an ore node, a chest, and a fishing bobber. Confirm the sparkle sits on the object and the spoken line matches what is in front of you.
2. Confirm Interact Key returns to the previous settings after every sparkle is turned off, and again after logout.
3. If a current node name is spoken as the kind instead of its name, add that name to the clip list.

## Sources and data

| Path | Role |
|------|------|
| `targetNearestDistance`, then `softTargetInteract`, `SoftTargetIconGameObject`, `SoftTargetIconInteract`, `SoftTargetInteractArc`, `SoftTargetInteractRangeIsHard`, `SoftTargetInteractRange` | Tab-target distance is raised first. The Interact Key is then set to 3, 1, 1, 2, 0, and 50. The range cannot pass the tab-target distance, and a hard cap would leave it at 10 yards |
| `nameplateMaxDistance` | Raised to 50 while sparkles are on when the saved value is shorter, then put back |
| `PLAYER_SOFT_INTERACT_CHANGED`, `NAME_PLATE_UNIT_ADDED` | The one object the game is pointing at, and its nameplate |
| Interact icon atlas | Herb, mining, skin, loot, and quest. A loot icon on a game object is treated as treasure |
| Object name | Herb endings, vein or deposit or seam, chest or coffer, and the word bobber. Bobber object id 35591 |
| Quest log objectives | Unfinished objective words, so a quest object can match when the icon does not |
| `UnitDistanceSquared`, then `UnitPosition`, then the map position | Yards when the number is plain, above 0, and under 80. A 0 is ignored. A hidden number is still compared when the client allows it. The nameplate is tried first, then `softinteract`, then `softfriend` when that is the same unit |
| Item and spell ranges | Used when the yard number is missing. Checks run at 2, 5, 10, 15, 20, 25, 30, 35, 40, 45, and 50. The spoken step is the near side of the gap, so 0 yards says At. Item data for 45 and 50 is loaded so those steps are not skipped |
| `CheckInteractDistance` | The 8-yard check can say 10. The 28-yard check can say 25 only when the 25-yard check just failed. It is not used as “everything else is 50” |
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
- The flight beacon sat on a player nameplate, so it stopped around that plate’s distance and a missing yard number was spoken as “At” again and again. The beacon now stays on the flight master. A player is rejected. A distance of 0 is not “At.” The same line waits 4 seconds before it can be spoken again. Tab-target range and nameplate distance are raised to 50 while sparkles are on.
- A player named like a node, such as a name ending in Vein, was marked as ore. Herb, ore, and chest names now count only on a game object. Players are skipped, including when one stands in front of a node. A tree or other loose object is not given a herb beacon. “At” is spoken only for a real distance under 2.5 yards when the close check agrees, so turning away at 15 yards does not say At again.
- The spoken distance stopped at 10 yards. The interact range was applied before the tab-target distance, so the game kept the 10-yard default. A hidden yard number was also compared inside a protected call, which dropped the result and left the short step as 10. The tab-target distance is raised first, the hard range cap is turned off, and the hidden number is compared directly so 15 through 50 can be spoken.
- A flight master at 20 yards was spoken as 25, then the next line was 50. The yard number for that NPC is often 0, so the guide used the only two interact checks it had: inside about 28 yards became 25, and past that became 50. The world position is compared directly now, and item and spell ranges fill the 5-yard steps. 20 yards stays 20.
- Those range checks then read 5 yards high, so standing on the flight master said 5, and 45 and 50 never played. The spoken step is the near side of each gap, so 0 yards says At. The 45 and 50 yard items are loaded before they are checked.
- A mine in front of you did not light. The object flag was read inside a protected call, so a hidden true was dropped and the node was skipped. A vein, deposit, seam, listed ore name, or mining cursor now lights on the node you are facing. The beacon is drawn before the spoken line, so a distance miss cannot hide it.
- Flight path reached 50 yards because a flight master already has a nameplate. A herb, mine, chest, quest object, or bobber did not, so the beacon waited until you were close. Those objects now get the same interact nameplate while they are in front of you.
- A loot or skinnable corpse did not get that nameplate until it was already selected, so it stayed dark past a short range. Loot and Skinning keep the nameplate on, and a skinning cursor is shown out to 50 yards.
- After a kill, that corpse still appeared only at 20 yards and closer. The beam sat on the corpse nameplate, and the plate itself ends around the 8 to 28 yard mark on the target frame. The corpse’s own position cannot be drawn once that plate is gone, so the guide saves the spot from the plate and keeps its own beacon on that spot out to 50 yards. A skinnable corpse, such as a beast, keeps the Skin beacon the same way.
- Every dead body was getting that beacon, including corpses this player cannot loot. The Corpse beacon now stays on a body only when this player can loot it. Someone else’s corpse stays dark. Skin stays on a body this player can skin, or on a beast, dragon, or critter this player can loot.
- The saved spot was guessed again whenever you moved, so the beacon slid around the screen. The spot is saved once, and the beam is drawn from the camera, so it stays on that body while you walk. The Skin beacon uses that same saved spot, so it stays on a skinnable body instead of sliding as you move.
- Drawing the beam from the nameplate’s screen position hid every beacon, because that position is not a plain number. The beam is parented to the nameplate again, which is what shows it. A hidden plate does not block the separate beacon on a targeted corpse.
- Skinning was taking the beacon on a kill that still had loot, because a skinnable beast was marked Skin before Corpse. Corpse now stays while this player can loot. Skin shows after there is nothing left to loot.
- The Corpse beacon stayed after the body was looted. The saved spot was drawn again every tick and never asked if the loot was gone. Taking the last item clears that spot. Skin shows only when the body can still be skinned.
- Treating that loot check as empty from any distance cut the Corpse beacon down to about 5 yards, because the check only says yes beside the body. A no from farther away keeps the beacon. It clears beside the body once the loot is gone, and when the last item is taken.
- The corpse nameplate itself ends around 5 yards, and the saved spot was guessed again every step, so the beacon never stayed out at 50. The spot is saved once. Another player looting or skinning does not clear a beacon. Only this player's loot and this player's skin do.

## Open work

- In-game check with `/reload`, then `/sg`. Walk in from about 50 yards on a herb, a mine, a chest, a quest object, and a fishing bobber. Each should light and speak 50, the same way a flight master does. Kill an enemy and walk out to about 50 yards with Loot on. The corpse should stay lit and say 50, not wait until 20. With Skinning on, a skinnable corpse should do the same. Confirm a tree still does not take the beacon.
- Drag the lower right corner and confirm the window keeps that size after `/reload`. Confirm a node near 50 yards speaks 50, and one near 45 yards speaks 45.
- Stand more than 25 yards from a flight master and confirm the beacon is on that NPC, not on a player, and that it does not say “At” until you are next to them. Walk in from about 50 yards and confirm the spoken steps are 50, 45, 40, 35, 30, 25, 20, 15, 10, and 5, and that standing on the flight master says At. Turn away at about 15 yards and confirm it does not keep saying At. Stand near a player whose name ends like a node and confirm that player is not marked. Confirm a tree in front of a herb does not take the beacon.
