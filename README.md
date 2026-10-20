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

## Beta 0.1.0 - what's in the file

- **Detection**: target / mouseover / nameplate-adjacent reads -> npcID +
  classification; rares flagged "RARE SPOTTED".
- **The odds panel**: anchored under the Blizzard target frame; band + ~% (p),
  coarse model (level delta + classification + your current health). Wide
  honest bands; every number carries "(p)" in beta.
- **Waypoints**: notable sightings auto-mark your position with the native
  supertracked map arrow (TomTom supported). `/ra mark`, `/ra clear`.
- **Death journal (local only)**: on death, the combat log names your killer
  (environmental deaths say "a fall", never a creature). `/ra deaths`.
  Nothing ever leaves your machine in this beta - RUN does not network, ever.
- **Selftest**: `/ra selftest` (44 checks, same suite the ship gate runs).

Deferred (by design, per the spec): the RISK IT wager button, the crowd
killcount + Deadliest Rares ladder, the rares DB bake, seasons.

## Install (beta testers)

1. Unzip so you have `Interface\AddOns\RUN\RUN.toc`.
2. `/reload` or relog.
3. Commands: `/runadvisor`, `/runa`, or `/ra`. (Plain `/run` is Blizzard's
   built-in script command - an addon can never take it.)

### Five-minute test checklist

1. `/ra selftest` - expect "44/44 green".
2. Target a grey mob -> panel says FIGHT with high %. Target something
   red/elite -> RISKY or FLEE. A skull-level mob -> FLEE, "~no chance".
3. Mouse over a silver-dragon rare with no target -> panel flashes RARE
   SPOTTED and a map pin lands at your feet (autoMark).
4. `/ra odds` prints the same verdict to chat.
5. Die to something (beta heroism) -> chat line "death recorded: ..." and
   `/ra deaths` lists it; fall off something tall -> the killer is "a fall".
6. `/ra set autoMark off` then re-check 3 - no pin.

## Development

- `python pipeline/run_tests.py` - THE ship gate (compliance scan + 44-check
  headless selftest via lupa). Green before any zip/deploy/commit.
- `python pipeline/deploy.py` - gate-then-copy to the live Forever install.
- House laws: display-and-advice only (never a protected action), Lua 5.1
  dialect, every possibly-secret read through `core/guards.lua`, no PII ever,
  generated data regenerates (edit `data/overrides.lua`, never `generated/`).

License: All Rights Reserved (source-available). Copyright 2026 SimulateCX.
