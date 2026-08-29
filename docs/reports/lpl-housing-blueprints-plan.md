# LPL Retail — Housing Blueprints plan

**Status:** **Shipped** in Light Paws Loadouts **1.1.4** (29 Aug 2026).  
**Product:** Light Paws Loadouts Retail only (`lpl/`). Not Era / Anniversary / MoP.  
**Pattern:** Macro Manager / Addons Manager — named list of **strings**. No house apply from LPL.

**Locked icon:** `lpl/icons/housing_64.png` (brighter cyan floor-plan glow). Convert to `.tga`/`.blp` only if PNG looks soft in-game.

---

## Phase 0 — done (tab + approved icon)

- Sidebar tab **Housing Blueprints** (after Addons Manager).
- New / edit / delete / list search.
- Name + notes + blueprint code.
- Import from the tab (`OpenImport("housing")`) and Export copies the raw code.
- Saved in `LPLDB.housing` (`housing_1`, …).
- Editor text: paste in House Editor on your plot; re-save in-game after a good import.

---

## Phase 1 — icon formats (optional, if PNG is soft)

- Export `.tga` / `.blp` like the other tab icons.
- Do **not** add the tab to `lpl-classic-era/` or planned Classic flavors.

---

## Phase 2 — done (detect + Import hub)

Detect locked from four public clipboard samples (all 24 chars, `Ag` prefix, `A-Za-z0-9+/=`):

- `AgK4uUr/GmFPA4G3yhZFI95G` — WoWDB Kaldorei refuge
- `AgIVtMYjUK1Hzaqx85qWNlyC` — official forums
- `AgF3nlpajedJ2Z7rJAqzcDnf` — forums Stormwulf house
- `AgQ8F4uPnHdDsqx+JoPhz9NK` — forums Halloween WIP

`HousingStore:Detect` accepts a single trimmed token, length 22–28, `^Ag[%w+/=]+$`. Runs **after** AddonCatalog so `!WA:` / ElvUI / Plater still win.

Generic Import hub: if detect matches, save to Housing. Vault chooser stays **Macro vs Addon Profile** (no third button). Housing-tab Import still accepts any paste (future format).

---

## Phase 3 — done (player apply helper)

- List button **Copy for House** (not Activate-as-loadout).
- Copies the code (`CopyToClipboard`) and speaks via Accessibility Helper when loaded; otherwise prints the steps.
- Reminder: Housing HUD → Blueprint → Import; re-save after a good import; if the creator deletes their save, the code dies.
- Still no LPL API that places rooms. Blizzard owns apply.

---

## Explicit non-goals

- Rebuilding a house from a decor shopping list.
- Selling or buying codes.
- Housing on Classic-family LPL.
- Treating the code as a full payload like a talent string (it is a **server pointer**).
- Bundled public-code catalog (codes go stale if the creator deletes the save).

---

## How to try Phases 0–3

1. Retail `/reload` with this `lpl/` folder.
2. `/lpl` → Housing Blueprints tab.
3. New Blueprint → paste a code → Save.
4. Select a row → **Copy for House** (clipboard + speech/print).
5. Generic Import (sidebar Import, not the housing tab): paste a 24-char `Ag…` code — should save to Housing, not open the Macro/Addon chooser.
6. Export still shows the same string for Ctrl+C.
