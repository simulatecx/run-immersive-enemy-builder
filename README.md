# "RUN" - Immersive Enemy Builder

**Enhancing the Azeroth we know and love.** Enemies grow with every player
they fell: ranks, earned titles, banners - and your honest odds against them.
RUN makes the world feel alive and gamified for everyone playing, on
**WoW: Forever** (Interface 16001).

The mob that killed you is not "a Sunscale Lashtail" anymore. It is
*Sunscale Lashtail "the Widowmaker" - Deadly, 11 kills and counting* - and
when it prowls near the next player, they get the banner.

Sibling to [Foresight](https://github.com/simulatecx/foresight-forever);
fully standalone, sharper when Foresight is installed (future bridge).

**Distribution: waitlist-first.** Private beta, deliberately NOT on
CurseForge yet - access via the waitlist; betas ship as direct zips.

## Beta 0.6.0 - what's in the file

**RUN is fully automatic - no commands needed.** The minimap button opens
the Account Ledger (stats + options); `/ra` is just the power-user lever.

- **The Nemesis layer (new)**: every player death GROWS the killer species.
  A 10-tier notoriety ladder (1 kill -> 100+), with **deterministic earned
  titles** - the same creature carries the same name for everyone, every
  session. Tier 3+ "normals" become **soft elites**: banner treatment
  ("NOTORIOUS ENEMY NEARBY"), tier-coloured tooltip lines, and they ping
  even with normal-mob pings off. The game says trivial; the body count
  says otherwise. Display-only, always - reputation, never mob power.
- **Most Wanted board**: the Ledger opens with the account's deadliest
  species, wearing their titles - your journal + deaths heard, blended.
- **The social death layer (Hardcore parity)**: deaths heard nearby keep a
  journal (last 200); notable deaths banner ("X has claimed another victim -
  N and counting"); **last words** ride your death-ping (your final public
  chat line, on by default, opt-out); **eulogy mode** (off by default) names
  the fallen on heard deaths.
- **Trust layer**: peer ack echoes corroborate heard deaths (the Hardcore
  addon's proven k-of-n model); per-sender rate limits + strict decoding +
  checksums throughout.
- **Death discipline**: resurrection stamps, double-fire guard, and every
  death records its mode (hardcore / pvp / pve).
- **Version handshake**: your addon quietly learns when a newer RUN exists.
- Plus everything since 0.1.0: tooltip flags + kill ranks, tiered nearby
  pings (normal off / elite / unique / quest targets), Civ-style odds panel
  behind `expansiveStats`, auto map-marks, the local death journal
  (account-wide, character-stamped), ESC options panel, minimap button.

RUN never networks. Deaths travel ONLY as in-game addon messages (anonymous
payload - no names inside; eulogy display reads the transport sender that
addon messages already expose). The future global ladder is strictly
share-link + server-verified.

## Install (beta testers)

1. Unzip so you have `Interface\AddOns\RUN\RUN.toc`.
2. `/reload` or relog.
3. Everything is automatic. Options: minimap button, ESC -> Options ->
   AddOns -> RUN, or `/ra set <key> <on/off>`.

### Test checklist

1. `/ra selftest` - expect "150/150 green".
2. Mouse over any enemy you have died to - it now wears a TITLE once kills
   reach tier 1+ ("the Blooded" and up).
3. Die repeatedly to one normal mob type (5+ total): its species turns
   NOTORIOUS - banner on approach, tier-coloured tooltip, soft-elite status.
4. Minimap button -> Most Wanted shows your deadliest species, titled.
5. Say something in /say, then die: with a second RUN client in the channel,
   they hear the ping; with eulogy on they see your name and last words.
6. ESC -> Options -> AddOns -> RUN: the checkbox panel (report if missing -
   the Ledger always has the full set).

## Development

- `python pipeline/run_tests.py` - THE ship gate (compliance scan + 150-check
  headless selftest via lupa). Green before any zip/deploy/commit.
- `python pipeline/deploy.py` - gate-then-copy to the live Forever install.
- House laws: display-and-advice only, Lua 5.1, secrets through
  `core/guards.lua`, no PII ever, generated data regenerates.
- Design notes + Nemesis research: `docs/NOTES.md`.

License: All Rights Reserved (source-available). Copyright 2026 SimulateCX.
