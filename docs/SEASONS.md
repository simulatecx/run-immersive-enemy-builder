# RUN seasons - the doctrine (WP-G / RUN-G)

One home for every season fact: what a season is, what the reset does and does
NOT do, the exact runbook, and who runs it. The code artifacts are
`RUN/core/init.lua` (the one constant), `RUN/core/share.lua` (the stamps),
`pipeline/season_archive.py` (the archive op).

## What a season is

A season is a TAG, not a database. Every crowd payload stamps its GAME
LINE's constant (`RUN/core/init.lua`: Forever = `RUN.season`, Classic Era =
`RUN.seasonEra`; `core/share.lua` selects by API presence) on its envelope
and on every event; the schema locks the shape to lowercase `[a-z0-9]`, max
8 (`data/rare-kills-schema.json`). The Cloud Function
(`functions-run/index.js`) keys its rollups by that tag, and the web ladders
filter by it. Because everything downstream keys by season, "starting a new
season" is nothing more than new submissions arriving under a new tag - old
data keeps its old tag and is never touched.

- `s0` - Forever Season 0: everything from the private beta through Forever
  launch (2026-11-04) until the Hardcore kickoff.
- `s1`, `s2`, ... - the Forever Hardcore seasons that follow.
- `c0`, `c1`, ... - the Classic Era line's tags (its own calendar; see the
  last section).

## What the kickoff reset does - and does NOT do

The Hardcore kickoff (~2026-12-04) fires the one owner decision this doc
exists for: **a NON-destructive archive** (owner decision 2026-10-15,
SPRINTS.md). Concretely:

DOES:
- Copy every active-season doc in `rareKillCounts` and `giantSlayers` to
  `seasonArchive/{season}/{collection}/{id}` on the live `wow-foresight`
  project (verbatim fields, read-back verified).
- Write a local timestamped JSON backup under `pipeline/backups/` first.
- Flip the active tag: bump `RUN.season` in `RUN/core/init.lua` and redeploy
  the web ladders' default-season filter.

DOES NOT - EVER:
- Delete anything. `pipeline/season_archive.py` contains no delete call by
  design; the originals stay in place. The "reset" a player sees is the
  ladders defaulting to the new season's (initially empty) buckets while the
  archived season remains browsable under its tag.
- Wipe local player data. `RUNDB` journals (deaths, slays, sightings, wipes,
  heard log) are the player's own history and are untouched; only the tag
  stamped on FUTURE shares changes.
- Rewrite old payloads. A share built under `s0` stays `s0` forever - the
  server trusts the stamp only as a bucket key, never as identity.

## The runbook (exact order - safe-data-ops law)

Owner-gated. Dry-run -> backup -> write -> read-back, always in that order:

1. **Dry-run**: `python pipeline/season_archive.py --dry-run`
   (public reads only; prints how many docs per collection would be copied).
2. **Archive**: `python pipeline/season_archive.py --archive --season s0
   --next s1 --yes`
   - needs an authed admin shell (`gcloud auth login`; the script takes its
     OAuth bearer from `gcloud auth print-access-token` and aborts honestly
     without it);
   - backs up to `pipeline/backups/season-s0-<UTC stamp>.json` BEFORE any
     write;
   - copies every `s0` doc to `seasonArchive/s0/...` (PATCH = idempotent;
     re-running is safe);
   - read-back verifies every copy field-for-field and aborts loudly on any
     mismatch (originals untouched either way).
3. **Constant bump**: edit `RUN/core/init.lua` -> `RUN.season = "s1"`; ship
   through the normal gate (`python pipeline/run_tests.py` - the share
   selftests prove the new tag rides every payload verbatim). An ERA-line
   flip edits `RUN.seasonEra` the same way; the two lines flip independently.
4. **Ladder default**: redeploy the web ladders' default-season to `s1`
   (marketing repo; owner-gated scoped deploy, per docs/AGENT-PLAN.md).

Steps 3 and 4 are the script's printed checklist; it cannot and must not do
them itself - both are owner-reviewed changes.

## Who runs it

The OWNER (or an owner-supervised session). Live-project mutations are on the
owner-gated list in `docs/AGENT-PLAN.md`; agents implement, selftest, and
dry-run - they never flip a season. The `--yes` flag is the explicit consent
act, and the script aborts before any read without it.

## Forever vs Classic Era season naming (shipped 2026-10-22, v0.8.1)

`s0`/`s1`/... are the **Forever** line's tags (launch 2026-11-04, Hardcore
kickoff ~2026-12-04); `c0`/`c1`/... are the **Classic Era** line's - a
population whose seasons will not align with Forever's calendar, so the two
lines flip independently, each within the same schema shape. The split is
LIVE: `init.lua` carries both constants (`RUN.season = "s0"`,
`RUN.seasonEra = "c0"`) and `Share.season()` (`core/share.lua`) picks by API
presence (the quests.lua signal: `C_QuestLog.GetInfo` absent + global
`GetQuestLogTitle` present = era), never by version numbers. The clamp
fail-safe is partition-local - an off-shape or missing constant falls back
to `s0`/`c0` on its OWN side, never across games - because npcIDs are
identical across the two games and the prefix is the only wall between
their counts. Tags are never retrofitted into old data - they are forever,
exactly like the archive.
