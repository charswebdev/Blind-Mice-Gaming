# Exploration — regression checklist

Use after route/filter/UX changes. Shadowlands stays excluded (no-fly).

## Core loop
- [ ] Discover toast clears the matching fog pin (this character only)
- [ ] Travel / navigation pins clear on proximity (or zone/buff/cast as authored)
- [ ] Travel Next advances without Mark/Discover confirmation popup
- [ ] Wrong-coord fog pin: Mark Discovered skips for this character; confirm if far away
- [ ] Stuck ~10s at fog pin with no toast → Mark tip in chat

## Progress
- [ ] Start / Resume / Park / Abandon behave per character (no alt bleed)
- [ ] Fog pins clear only on Discover toast (or Mark); no Explore-achievement pre-clear
- [ ] Discover-XP secondaries still need toast or Mark
- [ ] Route stays zone-complete: finish a map’s fog pins before the next zone
- [ ] Nearest undiscovered (On): only retargets within the current zone
- [ ] `forgetDiscoveries` with `{ name, map }` clears only that map’s key after `dataVersion` bump

## Content / policy
- [ ] No Shadowlands chapter
- [ ] Cataclysm Mainland shared; Finale = south path only
- [ ] Classic Kalimdor present (Mulgore + Thunder Bluff outdoor); Teldrassil stays out
- [ ] After Classic EK: Getting There runs before Classic Kalimdor (no instant continent jump)
- [ ] Cataclysm Alliance: Travel To Mainland between Deepholm and Mainland
- [ ] Prefer fix coords over remove for Discover-XP secondaries

## Gate 5
- [ ] Settings → Nearest undiscovered On: arrow targets closest fog pin in **current zone** only
- [ ] Nearest Off: route order restored
- [ ] Non-enUS: Discover toasts parse via `ERR_ZONE_EXPLORED*`; areaID pins match localized area names

## Tools
- [ ] Do not run `areatable_audit_nn.py --apply` blindly
- [ ] Edit Manual + Generated together when moving pins; bump `dataVersion`
