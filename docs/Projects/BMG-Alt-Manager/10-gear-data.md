# Gear data

Batch 2 of the data pack. Approved on 2026-10-29. Phase 2 reads these slots in `BMGAM` as of 2026-10-30.

This file says what a worn-item snapshot stores. The two-column Gear page is approved in [gear-page-full.jpg](reference/gear-page-full.jpg). The snapshot keeps every slot that flavor has. On screen, a stored empty slot says **Empty Slot**. A flavor with no ranged slot does not store slot 18 and does not show that row. Midnight does not store slot 18.

Socket count uses `C_Item.GetItemNumSockets` on the item link. If that call is missing, the count is the `EMPTY_SOCKET` keys from `C_Item.GetItemStats`. A `0` gem field in the link is not an empty socket. The enchant name is the Enchantment line from `C_TooltipInfo.GetInventoryItem`, saved at scan time. The rest of the tooltip is not stored.

## Slots

Slot numbers are the client inventory slots. Paper-doll order is the order a character sheet uses. The two-column picture in the Gear drawing can use a different visual order. Storage uses these slot numbers.

| Paper-doll order | Slot | Number | Midnight | Era | Anniversary | MoP |
|------------------|------|--------|----------|-----|-------------|-----|
| 1 | Head | 1 | Yes | Yes | Yes | Yes |
| 2 | Neck | 2 | Yes | Yes | Yes | Yes |
| 3 | Shoulder | 3 | Yes | Yes | Yes | Yes |
| 4 | Back | 15 | Yes | Yes | Yes | Yes |
| 5 | Chest | 5 | Yes | Yes | Yes | Yes |
| 6 | Shirt | 4 | Yes | Yes | Yes | Yes |
| 7 | Tabard | 19 | Yes | Yes | Yes | Yes |
| 8 | Wrist | 9 | Yes | Yes | Yes | Yes |
| 9 | Hands | 10 | Yes | Yes | Yes | Yes |
| 10 | Waist | 6 | Yes | Yes | Yes | Yes |
| 11 | Legs | 7 | Yes | Yes | Yes | Yes |
| 12 | Feet | 8 | Yes | Yes | Yes | Yes |
| 13 | Finger | 11 | Yes | Yes | Yes | Yes |
| 14 | Finger | 12 | Yes | Yes | Yes | Yes |
| 15 | Trinket | 13 | Yes | Yes | Yes | Yes |
| 16 | Trinket | 14 | Yes | Yes | Yes | Yes |
| 17 | Main hand | 16 | Yes | Yes | Yes | Yes |
| 18 | Off hand | 17 | Yes | Yes | Yes | Yes |
| 19 | Ranged | 18 | No | Yes | Yes | No |

Midnight has no ranged slot. MoP removed the ranged slot. Era and Anniversary keep it. Confirm the MoP and Anniversary lists on those clients before those flavors are coded. Forever is not in this table. Its slot list is written when the Forever client is in front of us.

Profession tools are not gear slots. They stay with the Professions talk.

## Durability, enchant, sockets

| Slot | Durability | Enchant | Socket |
|------|------------|---------|--------|
| Neck, both fingers, both trinkets, shirt, tabard | No durability | — | — |
| Shirt, tabard, both trinkets | — | Cannot be enchanted | No gem slot |
| Both fingers | No durability | Can be enchanted | The item may have sockets |
| Neck | No durability | Can be enchanted | The item may have sockets |
| Head, shoulder, back, chest, wrist, hands, waist, legs, feet, main hand, off hand, ranged | Whatever the client reports for that item | Can be enchanted | The item may have sockets |

“Can be enchanted” means a missing enchant is stored as not enchanted. “Cannot be enchanted” means the slot itself cannot take one.

A few items in an enchantable slot still cannot take an enchant. The client call that says so is **unconfirmed**. Until that call is confirmed on Midnight, the snapshot uses “cannot be enchanted” only for shirt, tabard, and trinkets. Every other worn item with no enchant id is stored as not enchanted.

An off-hand, a cloak, or a weapon can come back with no durability. Store “no durability” when the client does. Do not invent a maximum.

Sockets belong to the item, not the slot. Shirt, tabard, and trinkets have no gem slot. Any other slot stores the item’s real sockets.

## Fields saved at scan time

Saved while that character is logged in. Names are saved then. They are not looked up later from another character.

| Field | Contents |
|-------|----------|
| Slot number | The number in the table above |
| Empty | True when nothing is equipped. The slot is still stored |
| Item id | The item’s id. Absent when empty |
| Link | The item link. Absent when empty |
| Name | The item name at scan time |
| Quality | The quality id that colors the name and the icon border |
| Icon | The client file id for the item icon |
| Durability | Current and maximum, or neither when the item has no durability |
| Enchant id | The id from the link. `0` means no enchant |
| Enchant name | The enchant’s name, or the token `not-enchanted`, or the token `cannot` |
| Sockets | One entry per socket. A filled socket stores the gem id and the gem name. An empty socket stores empty. No list means no gem slot |

The enchant name is the single enchant line read at scan time. The rest of the tooltip is discarded and is not stored. The upgrade track and rank, such as Hero 1/6, come from `C_Item.GetItemUpgradeInfo` and are saved on the slot. An item with no track leaves that field off.

The gem name is read from the gem’s item id at scan time. If the client does not know that gem yet, store the id and leave the name pending. Fill the name when the client answers during that same login. Do not leave it for a different character.

## How the link is read

Take the `item:` section of the link and split it on colons.

| Position | Midnight | Era, Anniversary, MoP | Forever |
|----------|----------|------------------------|---------|
| 1 | Item id. Known | Item id. Known on current classic links | **Unconfirmed** |
| 2 | Enchant id. Known | Enchant id. Treat as known. Confirm before that flavor is coded | **Unconfirmed** |
| 3 through 6 | Gem ids. Known. `0` or blank means that field has no gem | **Unconfirmed.** Do not assume four gem fields until that client is checked | **Unconfirmed** |

A `0` gem field is not an empty socket. Midnight links carry four gem fields even when the item has no sockets. The socket count comes from `C_Item.GetItemNumSockets` on the item link. If that call is missing, the count is the `EMPTY_SOCKET` keys from `C_Item.GetItemStats`. The gem ids in the link are the filled gems.

Fields after the gems, such as bonus ids, are not stored. Name, quality, and icon are already saved at scan time.

## Sample rows

Samples, not live items.

Head, filled, one gem, enchanted:

```text
slot: 1
empty: false
itemID: 0
name: Helm of the Titan
quality: 4
upgrade: Hero 1/6
durabilityCurrent: 100
durabilityMax: 100
enchantID: 0
enchantName: Mark of the Claw
sockets:
  - gemID: 0
    name: Quick Sapphire
```

The zeros on item id, enchant id, and gem id in this sample are placeholders. A live scan stores the real ids.

Shirt, empty:

```text
slot: 4
empty: true
```

Neck, no durability, no socket, enchanted:

```text
slot: 2
empty: false
durability: none
enchantName: Gift of Haste
sockets: none
```

## What this file does not decide

- Forever’s link and Forever’s slot list. The two-column layout is already approved in [gear-page-full.jpg](reference/gear-page-full.jpg). Forever shows a ranged row only if that client has the slot.
