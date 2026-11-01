# Style

The addon uses dark panels with gold trim. Every approved page uses this look.

## Window

- Near-black background, about `(14, 12, 10)` outside the panels and `(22, 18, 15)` inside them.
- Gold trim, about `(224, 180, 74)` for active edges and titles. Dim gold, about `(120, 90, 36)`, for resting borders.
- Character names are gold, with a slight dark edge so they read as raised type.
- Body text is a warm cream, about `(236, 224, 196)`.
- Secondary labels are a dim warm gray, about `(148, 136, 112)`.
- The selected character card uses a brighter gold border. The others use the dim gold border.
- Close and Settings are matching metal plates in the title bar. Close is the red glass X. Settings is the gold gear on its left. They are the same size.

## Meaning colors

These colors carry information. They are not decoration.

| Meaning | Color |
|---------|--------|
| Item uncommon | `#1eff00` |
| Item rare | `#0070dd` |
| Item epic | `#a335ee` |
| Item legendary | `#ff8000` |
| Alliance | about `(70, 140, 255)` |
| Horde | about `(220, 40, 40)` |
| Durability 60% and above | green, about `(90, 196, 96)` |
| Durability from 25% up to 60% | gold, about `(232, 176, 64)` |
| Durability under 25% | red, about `(214, 72, 64)` |
| Needs attention: not enchanted, empty socket | the same gold as mid durability |
| Cannot apply: no durability, cannot be enchanted, no gem slot | the dim warm gray |

“Needs attention” and “cannot apply” are different. A missing enchant is gold so it can be fixed. A shirt that cannot be enchanted is dim so it does not look like a problem.

## Original art

Used where Blizzard does not have an icon for our button.

| Art | Rule |
|-----|------|
| Addon icon | Gold vault, realistic mouse, happy face, pointed snout, fur, whiskers. Not a cartoon mouse. This same picture is the minimap button and the icon in WoW’s addon list |
| Close | Beveled dark iron, glowing red glass X |
| Settings | Same plate as Close, glowing gold gear |
| Tab pictures | One object, centered, dark studio background, warm light, no words, no border in the file. The button chrome is drawn by the addon |

Tab pictures that are approved or shown:

| Tab | Object |
|-----|--------|
| Overview | Gold closed helmet and breastplate. No face, no mouse, no words |
| Gear | Gold breastplate |
| Bags | Leather backpack |
| Bank | Dark wooden chest with a lock. This is storage, not the vault |
| Professions | Round flask of gold liquid, a blue gem, and a green herb. Not a hammer and anvil |
| Currency | Three coins stacked: gold, silver, copper. Not the reputation medal |
| Reputation | Round gold medal, sunburst, red and gold ribbon. Not a flag |
| Mail | Sealed paper envelope with a gold wax seal |
| Vault | Round iron vault door, gold wheel, violet light in the seam. Not the wooden bank chest, and not the addon icon’s mouse |

The addon draws the tab button. The picture sits inside it. The open page’s tab is brighter. The others rest on a darker plate. When a character is selected, Overview is the open page.

## Blizzard textures

These are never redrawn and never shipped as files inside the addon.

| Use | Source |
|-----|--------|
| Class icon on the character card | The client class-icon set. Warrior is the sword, mage the staff, hunter the bow, warlock the fel hand |
| Race portrait on the right header | The client race portrait. Ares, a human man, uses the human male portrait |
| Item icon on Gear, Bags, Bank, and Mail | The item’s own icon |
| Coins on the money line | The client gold, silver, and copper coin textures |
| Talent icon on Overview | The client’s icon for that talent |

`SetTexture` points at the client file. A generated painting is not a stand-in for these.

## Text on buttons

Tab buttons have no words. The tooltip names the tab: Overview, Gear, Bags, Bank, Professions, Currency, Reputation, Mail, Auction, Quests, Achievements, Collections, Vault, and Settings for the gear in the title bar.

On Overview, Class, Hero, Specialization, and the stat labels are bold bright yellow, about `(255, 236, 64)`. The name or number beside each label is bold bright white. Talent names are bold bright yellow. The Guild header is bold gold, and the guild name is bold bright white. Every expandable header title on a tab page is bold gold. Other pages keep cream body text.

A filled item slot on the Bags page and the Bank page uses a second tooltip: the client’s item tooltip for that item. The bag item in a header uses it too. That text is not stored.

The search box on those two pages is a dark field with a gold edge. The placeholder says Search. A small gold glass sits at the left of the field.

Character cards do use words, in the four-line order in the layout file. Names are not cut off. Reputation names, when that page exists, are not cut off either.
