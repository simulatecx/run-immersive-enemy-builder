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

## Beta 0.3.0 - what's in the file

**RUN is fully automatic - no commands needed to play with it.** The slash
(`/ra`) exists only to change options.

- **Nearby ping, tiered (new)**: any enemy whose nameplate spawns in range
  (camera view, up to the nameplate distance) can trigger a top-centre banner
  - "ENEMY / ELITE / RARE / RARE ELITE / BOSS NEARBY" - with sound, the
  kill-rank line, and (rares+) a map pin. THREE TIER OPTIONS: `pingNormal`
  (normal mobs - OFF by default, turn on for total awareness or easy
  testing), `pingElite` (elites - on), `pingUnique` (rares + rare elites +
  bosses - on); `nearbyPing` is the master switch. Signals:
  `NAME_PLATE_UNIT_ADDED` (needs enemy nameplates on; RUN nudges once if
  they're off) + `C_VignetteInfo` wired defensively (TRUE coordinates where
  Forever emits vignettes). Once per creature, 10-min cooldown.
- **P2P death-ping (new, the Hardcore-addon pattern)**: when you die to a
  creature, your addon automatically broadcasts a small ANONYMOUS ping (npcID,
  map, level bracket, checksum - never a player name) over a shared addon
  channel + guild. Every online RUN user hears it: tooltips gain "N player
  deaths heard" and ranks grow LIVE. In-game chat transport only - nothing
  leaves the game client. Spoof dampening: strict shape + Fletcher16 checksum,
  per-sender rate limit (5/hour), dedupe; heard counts are session flavour,
  kept separate from the future server-verified crowd count. Toggle:
  `shareDeaths` (on by default, visible opt-out).

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
- **Selftest**: `/ra selftest` (77 checks, same suite the ship gate runs).

Deferred (by design, per the spec): the RISK IT wager button, the crowd
killcount + Deadliest Rares ladder, the rares DB bake, seasons.

## Install (beta testers)

1. Unzip so you have `Interface\AddOns\RUN\RUN.toc`.
2. `/reload` or relog.
3. Options live under `/runadvisor`, `/runa`, or `/ra`. (Plain `/run` is
   Blizzard's built-in script command - an addon can never take it.)
   Keys: `flags`, `expansiveStats`, `autoMark`, `recordDeaths`, `nearbyPing`,
   `pingNormal`, `pingElite`, `pingUnique`, `shareDeaths`.

### Five-minute test checklist

1. `/ra selftest` - expect "92/92 green".
2. `/ra set pingNormal on`, then walk into any mob camp (enemy nameplates ON,
   key V) -> "ENEMY NEARBY" banners prove the sensor works on anything. Turn
   it back off, then walk near an elite or a silver-dragon rare -> "ELITE /
   RARE NEARBY" + sound + (rares) a map pin, before you ever click it.
3. Mouse over any hostile elite -> tooltip shows "RUN: Elite". Mouse over a
   silver-dragon rare -> "RUN: Rare (silver dragon)" and a map pin lands at
   your feet (autoMark).
4. `/ra set expansiveStats on`, then target a grey mob -> tooltip + panel say
   FIGHT with high %; a red elite -> RISKY/FLEE; a skull -> "~no chance".
5. Die to something (beta heroism) -> chat line "death recorded: ..." and
   `/ra deaths` lists it; fall off something tall -> the killer is "a fall".
   Die to the same mob twice -> its tooltip now ranks it "Dangerous
   (killed you 2x)".
6. Two-client test (or a guildmate with RUN): die to a creature on one -> the
   other hears the ping and that creature's tooltip gains "1 player deaths
   heard".
7. `/ra set flags off` -> tooltip lines gone; `/ra set autoMark off` -> no
   more pins.

## Development

- `python pipeline/run_tests.py` - THE ship gate (compliance scan + 44-check
  headless selftest via lupa). Green before any zip/deploy/commit.
- `python pipeline/deploy.py` - gate-then-copy to the live Forever install.
- House laws: display-and-advice only (never a protected action), Lua 5.1
  dialect, every possibly-secret read through `core/guards.lua`, no PII ever,
  generated data regenerates (edit `data/overrides.lua`, never `generated/`).

License: All Rights Reserved (source-available). Copyright 2026 SimulateCX.
