# Light Paws Loadouts - WoW Forever

| Field | Value |
|-------|--------|
| Status | **Shipped** (phase 2 talents) |
| Version | **1.2.7** |
| Type | In-game composite loadout vault |
| Folder | `lpl-forever/` |
| Clients | `_classic_beta_` (ForeverBeta) |
| SavedVariables | `LPLForeverDB` |
| Slash | `/lpl` |
| Install | BMG Updater folder `lpl-forever` |

## Description

Phase 2 uses the same window layout as the other Light Paws Loadouts packages: title bar, centered paw, lock, close, icon rail, saved-build list, and a tree editor with a bottom bar. Nothing opens on login. `/lpl` opens the window.

Icons are this package’s own files in `lpl-forever/icons/` (98 files, copied from Retail `lpl/icons/` on 2026-09-26). The AddOns list icon is `Interface\AddOns\lpl-forever\icons\lpl_32.blp`. The window uses `lpl_64.blp` from that same folder. Do not point Forever at Retail `lpl\icons`. Do not install Retail `lpl/` into `_classic_beta_`.

## Features

- The window matches the other LPL packages: title **Light Paws Loadouts - WoW Forever**, icon rail, **Saved Talent Builds** list, and a tree editor. **New Build** uses the same maroon button with a green glow as the other packages. Edit, Apply, Delete, and the editor bar use the same dark button with a class-colored border. The saved-build list has a search box, a collapsible class header, and a green dot on the build that matches the character. Double-click a build to edit it. The editor matches the Blizzard talent window’s icon layout, without the parchment background. Gray lines run through a short gap between talents. Each talent has a square border: gray when locked, green when the plan can take another rank, gold when it already has points and cannot take another. The editor can save a full 51-point plan. Apply spends the character's unspent points toward that plan, top rows first, and stops when those points are gone. Hovering a talent shows the talent name, the rank in this build, and the effect of each point. The next point is marked in gold. The rank already in the build is marked in green. Other rail icons say that section is not in this version yet. Import / Export holds the `!LPLF1!` code.

## Development plan

Phase 1 is the skeleton and the save test. Phase 2, shipped in 1.2.7, is Classic-style class talents (three trees, no hero talents). Phases 3–5 (bars, Edit Mode, remaining tabs) stay unstarted. Legacy trees are a separate account system, not the class talent tab. Desktop LPLM / LPTM Forever stay unassigned.

## Sources and data

Forever’s client does not have `GetTalentInfo`. Class trees are read with `C_Traits` (build 1.2.7). Talent tooltips read `C_TooltipInfo.GetTraitEntry` once per rank so each point can show its own effect. The specialization list on this client is only the class name, and the talent nodes do not carry a tree name. Column headers use the class’s tree names, left to right. For a priest that is Discipline, Holy, Shadow. Spellbook skill lines are not used, because that list came back as Holy, Shadow Magic, Discipline. All three trees share one icon spacing.

Tree names and talent lists are checked against [WoW Forever Talent Calculator](https://wowforevertalent.com/) (9 classes, 51 points, snapshot of the Forever beta). Priest is Discipline, Holy, Shadow on that site. A second calculator, [wowclassicforever.info](https://wowclassicforever.info/), reads beta client 1.60.1.70009 and sometimes labels the priest third tree Shadow Magic; the in-game header is Shadow.

## What worked

Copying the Retail icon set into `lpl-forever/icons/` gives Forever its own art. On 2026-09-26 the phase 1 window kept its load count across `/reload` (`LPLForeverDB.phase1.loads`). A saved talent build stayed after `/reload`. Apply warns in a popup when every point is already spent on a different build.

## What did not work

The previous Forever package never reliably showed Edit Mode layouts after `/reload`. That package was removed. Builds 1.1.3 through 1.1.6 still showed Tree 1, Tree 2, and Tree 3. `GetSpecializationInfoForClassID` returns only the class name. Talent nodes, subtree info, and tooltips do not include the column title. Through 1.2.1 the first `/lpl` hid the window, because a newly created frame starts shown and the toggle treated that as already open. Through 1.2.2 the editor only accepted as many points as the character had that level, so a full plan could not be saved early. Through 1.2.3 a talent hover showed only the name and rank. Through 1.2.5 Apply only printed to chat, so a different build with no unspent points looked like nothing happened.

## Open work

- Phases 3–5 stay unstarted until asked. No hero talents. No private talent database. Desktop LPLM / LPTM Forever stay later.
