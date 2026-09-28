# Light Paws Loadouts - WoW Forever

| Field | Value |
|-------|--------|
| Status | **Shipped** (phase 4 Edit Mode and loadouts) |
| Version | **1.4.8** |
| Type | In-game composite loadout vault |
| Folder | `lpl-forever/` |
| Clients | `_classic_beta_` (ForeverBeta) |
| SavedVariables | `LPLForeverDB` |
| Slash | `/lpl` |
| Install | BMG Updater folder `lpl-forever` |

## Description

Phase 2 uses the same window layout as the other Light Paws Loadouts packages: title bar, centered paw, lock, close, icon rail, saved-build list, and a tree editor with a bottom bar. Nothing opens on login. `/lpl` opens the window.

Phase 3, started in 1.2.8, turns on Action Bars, Keybinding Profiles, and Equipment. A new set opens empty. The empty Action Bars list shows only the center **New Action Bar Set** button. The editor uses the same rows as the other Light Paws packages: gold-bordered slots, a lock on each bar, and the pet bar. Drag a spell, item, or macro from the spellbook, the macro window, or your bars onto a slot. Drag one slot onto another to move it. Drag a slot onto your action bar to place that spell, item, or macro there. The saved slot stays in the set. **Update from current character** copies the spells, items, and macros currently on your bars. **Update from current character** copies the bars, keys, or gear on this character. Save stores that snapshot, and Apply puts it back. Right-click a slot to clear it. Shift+left-click ignores that one slot. The row lock ignores the whole bar. Either way, each ignored slot shows the red ignore icon. Apply for bars places spells, items, and macros and clears slots the snapshot left empty. The pet bar is shown and saved, and Apply does not change the live pet bar. Apply for keys writes the snapshot onto both the account and character binding sets. The key list shows every command in collapsible categories, with two gold-bordered key boxes. An empty box says Not Bound. Click a box and press a key to bind it. Apply for gear equips items that are in your bags and leaves shirt and tabard alone. Shift+left-click a gear slot to ignore it. The slot shows the red ignore icon, and Apply leaves that worn item alone. Shift+left-click again to stop ignoring it. An empty set can be saved and applied. Applying an empty action bar set clears those bars, an empty key profile clears your bindings, and an empty gear set unequips those slots. The rail does not include Cooldown Manager, Conditions, or Housing Blueprints. The updater lists 1.4.8.

Phase 4, started in 1.4.5, turns on Edit Mode layouts and composite loadouts. A new layout has a paste box. Paste a Blizzard Edit Mode string there, or click **Update from current character** to read the custom layout active in Edit Mode. Apply puts that layout back on the screen. The saved layout string stays after `/reload`. A new loadout shows a dropdown for talents, action bars, keybindings, equipment, and Edit Mode. Open a dropdown to attach a saved set. **+** adds another link for that piece. **X** removes it. Apply uses the first link in each piece, the same way as the other Light Paws packages. **Update from current character** selects the sets that already match this character.

Icons are this package’s own files in `lpl-forever/icons/` (98 files, copied from Retail `lpl/icons/` on 2026-09-26). The AddOns list icon is `Interface\AddOns\lpl-forever\icons\lpl_32.blp`. The window uses `lpl_64.blp` from that same folder. Do not point Forever at Retail `lpl\icons`. Do not install Retail `lpl/` into `_classic_beta_`.

## Features

- The window matches the other LPL packages: title **Light Paws Loadouts - WoW Forever**, icon rail, **Saved Talent Builds** list, and a tree editor. **New Build** uses the same maroon button with a green glow as the other packages. Edit, Apply, Delete, and the editor bar use the same dark button with a class-colored border. The saved-build list has a search box, a collapsible class header, and a green dot on the build that matches the character. Double-click a build to edit it. The editor matches the Blizzard talent window’s icon layout, without the parchment background. Gray lines run through a short gap between talents. Each talent has a square border: gray when locked, green when the plan can take another rank, gold when it already has points and cannot take another. The editor can save a full 51-point plan. Apply spends the character's unspent points toward that plan, top rows first, and stops when those points are gone. Hovering a talent shows the talent name, the rank in this build, and the effect of each point. The next point is marked in gold. The rank already in the build is marked in green. Action Bars, Keybinding Profiles, and Equipment are in 1.2.8 as snapshot lists with the same green dot. Other rail icons say that section is not in this version yet. Import / Export holds the `!LPLF1!` code.

## Development plan

Phase 1 is the skeleton and the save test. Phase 2, shipped in 1.2.7, is Classic-style class talents (three trees, no hero talents). Phase 3, shipped in 1.4.3, is action bars, key bindings, and equipment as snapshots you can save and apply. Phase 4, shipped in 1.4.8, is Edit Mode layouts and composite loadouts (talents, action bars, keybindings, equipment, and an Edit Mode layout). Phase 5, unstarted, is PvP talents, Macro Manager, Addon Sets, and Addons Manager. Cooldown Manager, Conditions, and Housing Blueprints are not part of this addon. Legacy trees are a separate account system, not the class talent tab. Desktop LPLM / LPTM Forever stay unassigned.

## Sources and data

Forever’s client does not have `GetTalentInfo`. Class trees are read with `C_Traits` (build 1.2.7). Talent tooltips read `C_TooltipInfo.GetTraitEntry` once per rank so each point can show its own effect. The specialization list on this client is only the class name, and the talent nodes do not carry a tree name. Column headers use the class’s tree names, left to right. For a priest that is Discipline, Holy, Shadow. Spellbook skill lines are not used, because that list came back as Holy, Shadow Magic, Discipline. All three trees share one icon spacing.

Action bars in 1.2.8 use `GetActionInfo` on the classic slot map: main bar, page 2, bars 2–8, and form bars. Possess and skyriding slots are not managed. Key bindings use `GetBinding`, `SetBinding`, and `SaveBindings`. Equipment stores item ids from the worn slots and skips shirt and tabard.

Tree names and talent lists are checked against [WoW Forever Talent Calculator](https://wowforevertalent.com/) (9 classes, 51 points, snapshot of the Forever beta). Priest is Discipline, Holy, Shadow on that site. A second calculator, [wowclassicforever.info](https://wowclassicforever.info/), reads beta client 1.60.1.70009 and sometimes labels the priest third tree Shadow Magic; the in-game header is Shadow.

## What worked

Copying the Retail icon set into `lpl-forever/icons/` gives Forever its own art. On 2026-09-26 the phase 1 window kept its load count across `/reload` (`LPLForeverDB.phase1.loads`). A saved talent build stayed after `/reload`. Apply warns in a popup when every point is already spent on a different build.

## What did not work

The previous Forever package never reliably showed Edit Mode layouts after `/reload`. That package was removed. Builds 1.1.3 through 1.1.6 still showed Tree 1, Tree 2, and Tree 3. `GetSpecializationInfoForClassID` returns only the class name. Talent nodes, subtree info, and tooltips do not include the column title. Through 1.2.1 the first `/lpl` hid the window, because a newly created frame starts shown and the toggle treated that as already open. Through 1.2.2 the editor only accepted as many points as the character had that level, so a full plan could not be saved early. Through 1.2.3 a talent hover showed only the name and rank. Through 1.2.5 Apply only printed to chat, so a different build with no unspent points looked like nothing happened. In 1.3.3, moving a slot onto another slot errored (`attempt to call a nil value` in `SectionUI.lua` DropOn). The drop called `RefreshEditor` before that function’s local was declared, so Lua called a nil global. 1.3.4 declares the refresh first. In 1.3.4 a drag out of the editor followed the mouse with Light Paws’ own icon, so the character action bar never received a cursor item and the icon stayed stuck. 1.3.5 puts the spell, item, or macro on the real game cursor. Through 1.3.5 a key with nothing assigned was left off the list, and an empty profile said “No keys in this profile.” 1.3.6 shows those boxes as Not Bound.

## Open work

- Phase 4 shipped in 1.4.8: Edit Mode layouts and composite loadouts. Phase 5 (PvP talents, Macro Manager, Addon Sets, Addons Manager) stays unstarted until asked. Cooldown Manager, Conditions, and Housing Blueprints are not part of this addon. Phase 3 shipped in 1.4.3: action bars, keybinding profiles, and equipment. Build 1.4.4 removes those three rail icons. No hero talents. No private talent database. Desktop LPLM / LPTM Forever stay later.
