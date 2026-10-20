# RUN - fight it or run?

Live combat odds for the enemy in front of you - and the sense to flee - on
**WoW: Forever** (Interface 16001). Target a hostile and RUN shows a
Civilization-style verdict under the target frame: **FIGHT / RISKY / FLEE**,
with an honest "~N% to win (p)" and what we know about the creature. Rares get
spotted, marked on your map, and - in a later phase - carry a crowd-sourced
body count ("this rare has killed ~N players").

Sibling to [Foresight](https://github.com/simulatecx/foresight-forever); fully
standalone, sharper when Foresight is installed (future bridge).

**Distribution: waitlist-first.** RUN is in private beta and is deliberately
NOT on CurseForge yet - access comes via the waitlist. Betas are handed out as
direct zips.

## Beta 0.2.0 - what's in the file

**RUN is fully automatic - no commands needed to play with it.** The slash
(`/ra`) exists only to change options.

- **Passive tooltip flags (always on)**: mouse over or target ANY enemy and
  its tooltip gains a RUN line - Elite / Rare (silver dragon) / Rare Elite /
  World Boss - plus a **danger rank earned from kills**: Blooded (1) ->
  Dangerous (2+) -> Deadly (5+) -> Infamous (10+). Beta ranks count kills of
  YOU from the local journal; the crowd body count feeds the same tiers in a
  later phase.
- **Expansive Enemy Stats (option, off by default)**: `/ra set expansiveStats
  on` adds your chances vs this enemy - a FIGHT / RISKY / FLEE line with
  "~N% to win (p)" on the tooltip, plus the odds panel under your target
  frame. Coarse model (level delta + classification + your current health);
  wide honest bands; every number carries "(p)" in beta.
- **Waypoints**: rare sightings auto-mark your position with the native
  supertracked map arrow (TomTom supported). Toggle with `autoMark`.
- **Death journal (local only)**: on death, the combat log names your killer
  (environmental deaths say "a fall", never a creature). `/ra deaths`.
  Nothing ever leaves your machine in this beta - RUN does not network, ever.
- **Selftest**: `/ra selftest` (61 checks, same suite the ship gate runs).

Deferred (by design, per the spec): the RISK IT wager button, the crowd
killcount + Deadliest Rares ladder, the rares DB bake, seasons.

## Install (beta testers)

1. Unzip so you have `Interface\AddOns\RUN\RUN.toc`.
2. `/reload` or relog.
3. Options live under `/runadvisor`, `/runa`, or `/ra`. (Plain `/run` is
   Blizzard's built-in script command - an addon can never take it.)
   Keys: `flags`, `expansiveStats`, `autoMark`, `recordDeaths`.

### Five-minute test checklist

1. `/ra selftest` - expect "61/61 green".
2. Mouse over any hostile elite -> tooltip shows "RUN: Elite". Mouse over a
   silver-dragon rare -> "RUN: Rare (silver dragon)" and a map pin lands at
   your feet (autoMark).
3. `/ra set expansiveStats on`, then target a grey mob -> tooltip + panel say
   FIGHT with high %; a red elite -> RISKY/FLEE; a skull -> "~no chance".
4. Die to something (beta heroism) -> chat line "death recorded: ..." and
   `/ra deaths` lists it; fall off something tall -> the killer is "a fall".
   Die to the same mob twice -> its tooltip now ranks it "Dangerous
   (killed you 2x)".
5. `/ra set flags off` -> tooltip lines gone; `/ra set autoMark off` -> no
   more pins.

## Development

- `python pipeline/run_tests.py` - THE ship gate (compliance scan + 44-check
  headless selftest via lupa). Green before any zip/deploy/commit.
- `python pipeline/deploy.py` - gate-then-copy to the live Forever install.
- House laws: display-and-advice only (never a protected action), Lua 5.1
  dialect, every possibly-secret read through `core/guards.lua`, no PII ever,
  generated data regenerates (edit `data/overrides.lua`, never `generated/`).

License: All Rights Reserved (source-available). Copyright 2026 SimulateCX.
