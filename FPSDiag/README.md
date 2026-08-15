Retail World of Warcraft addon by **Blind Mice Gaming**. It tells you whether **addons** or the **game client** are affecting your FPS, names the heaviest addons, and includes HyperFrame-style maintenance tools.

It uses Blizzard's built-in `C_AddOnProfiler` API. It does not enable the old `scriptProfile` CVar.

In the Blizzard AddOns list it is grouped under **Blind Mice Gaming**, the same category as Accessibility Helper and the other Blind Mice Gaming addons.

## Install

1. Copy the whole `FPSDiag` folder into:

   `World of Warcraft\_retail_\Interface\AddOns\FPSDiag`

   The folder you copy must contain `FPSDiag.toc` (not a nested extra folder).

2. Restart WoW, or at the character select screen click **AddOns** and enable **FPSDiag**.

3. Log in. You should see a small overlay at the top of the screen and a chat message.

## Use

| Command | What it does |
|---|---|
| `/fps` | Open or close the diagnostic panel |
| `/fps overlay` | Show or hide the overlay |
| `/fps record` | Start or stop recording a fight |
| `/fps mem` | Clear addon Lua memory |
| `/fps vram` | Compact VRAM (graphics restart) |
| `/fps av` | Restart audio and video |
| `/fps help` | List commands |

- **Left-click** the overlay to open the panel.
- **Right-click** the overlay to hide it.
- Drag the overlay or panel to move them. Positions are saved.
- The game menu addon compartment also opens the panel.

## What you will see

The overlay shows current FPS, a cause (`OK`, `Addon`, `Game`, `Lag`, `Settings`), and a one-line detail.

The panel shows:

- Addon time vs leftover game-client time
- Ranked addons (recent, last tick, peak, hitch count over 50 ms, memory)
- Zone, combat, nameplate count, latency, CPU-bound flag
- Recent hitches
- **Clear Memory**, **Compact VRAM**, and **Restart A/V**
- Plain-language advice

**Record** captures samples while you play a pull so the numbers are from combat, not from standing in town.

Compact VRAM and Restart A/V restart the graphics engine. The screen may hitch for a moment. That is expected.

## What it cannot do

It cannot see GPU load, other Windows programs, drivers, or the exact graphics setting that is expensive. It can read Render Scale and warn when that looks likely. It cannot name Blizzard's own UI modules the way it names WeakAuras.

## Files

- `Init.lua` — events, saved variables, slash commands
- `Profiler.lua` — sampling `C_AddOnProfiler` and frame time
- `Classifier.lua` — addon vs game vs lag vs settings
- `Tools.lua` — memory, VRAM, audio/video restarts
- `Overlay.lua` — compact HUD
- `Panel.lua` — diagnostic window
