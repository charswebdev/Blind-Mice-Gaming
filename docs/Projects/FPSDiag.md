# FPSDiag

| Field | Value |
|-------|--------|
| Status | **Shipped** |
| Version | **0.3.1** |
| Type | In-game FPS / addon-cost diagnostic |
| Folder | `FPSDiag/` |
| Clients | Retail 11.0.7+ profiler API through Midnight `120100` |
| SavedVariables | `FPSDiagDB` |
| Slash | `/fps` panel · `overlay` · `record` · `mem` · `vram` · `av` · `help` |

## Description

Tells the player whether **addons** or the **game client** are eating FPS, names the heaviest addon, and offers HyperFrame-style maintenance (clear Lua memory, compact VRAM, restart audio/video).

Uses Blizzard `C_AddOnProfiler` only. It does **not** enable the old `scriptProfile` CVar. Overlay samples the 60-tick average about once a second. The ranked panel does heavier work only while open.

`Tools.lua` is **runtime Lua** (memory/VRAM/AV). It is not an author-tools folder — do not delete it in a “move tools out” cleanup.

## Features

- Overlay: FPS, cause (`OK`, `Addon`, `Game`, `Lag`, `Settings`), heaviest name (or `Game UI`).
- Panel: addon time vs leftover client time; ranked list with Game UI mixed in; hitch count; memory; zone/combat/nameplates/latency/CPU-bound.
- Last-60-seconds hardest hit on the dashboard (addon or Game UI peak) so a tank can be named after it happens.
- Record a fight so numbers are from combat, not town.
- Clear memory / compact VRAM / restart A/V (graphics hitch expected).
- 0.3.0: lighter sampler and named heaviest overlay.
- **0.3.1:** dashboard lists Hardest and Next peaks from the last 60 seconds so a tank can be named after it happens.

## Development plan

Phase 1 required Retail 11.0.7+ (`C_AddOnProfiler`). Overlay was kept cheap; panel is on-demand. Later bump (0.3.0) reduced overlay work and named the heaviest addon in the HUD.

## Sources and data

- `C_AddOnProfiler` tick averages, frame time, Lua memory APIs, graphics restart.
- Cannot see GPU load, other Windows processes, drivers, or which CVar is expensive beyond coarse hints (e.g. Render Scale).
- Cannot name Blizzard UI modules the way it names WeakAuras.

## What worked

- Not turning on `scriptProfile` (that path is hostile to performance and to other addons).
- Mixing **Game UI** into the ranked list so “addons are fine, the client is not” is speakable.

## What did not work

- Scanning every addon every overlay tick — too heavy; 0.3.0 backs off.
- Treating `FPSDiag/Tools.lua` as `Tools/` during repo cleanup — must stay in the addon.

## Open work

- Classic clients have no profiler API; toc does not list them.
- Advice strings are heuristic, not a GPU profiler.
