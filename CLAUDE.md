# RUN - "Immersive Enemy Builder" (WoW: Forever + Classic Era)

Enhancing the Azeroth we know and love: enemies grow with every player they
fell - notoriety tiers, earned titles, banners, honest odds. Sibling to
Foresight (`..\marketing`); both ride ONE Firebase project (`wow-foresight`).
The ecosystem map + work queue: `docs/ECOSYSTEM.md`. Platform research:
`docs/NOTES.md`, `docs/ERA.md`, `docs/SEASONS.md`. Tracker: `SPRINTS.md`.

## Commands

- `python pipeline/run_tests.py` - THE ship gate: compliance scan +
  crowd-schema drift check + BOTH flavors' TOCs loaded headless (lupa) with
  the full selftest. Green before any zip/deploy/commit.
- `python pipeline/deploy.py` - gate-then-copy to BOTH local installs
  (Forever beta + Classic Era).
- `python pipeline/gen_crowd_schema.py` - regenerate the allow-list mirrors
  from `data/rare-kills-schema.json` (never hand-edit generated files).

## THE TWO LAWS OF NEW ADDITIONS (owner directive 2026-10-21)

**LAW 1 - never step on an existing deployment (either app).**
- The shared Firebase surface (marketing repo: `web/firestore.rules`,
  `functions/`, `web/`) is ADDITIVE-ONLY: new files, new collections, rules
  blocks APPENDED before the final deny, one-line exports. Never modify an
  existing rules block, `rebuild()`, or any Foresight addon/gate/packaging
  file. Canonical copies of RUN's surface live HERE (`functions-run/`,
  `firebase/`); the marketing repo carries the deployable copies.
- Deploys are owner-gated and ORDERED: rules -> functions -> hosting
  (rules-before-code). Emulator-test before proposing any deploy.
- Wire formats are FROZEN (RDP1/RDA1/RLW1/RVH1/RWP1). New behavior = a NEW
  tag with strict fail-closed decode; never change an existing tag - old
  clients are already in the field.
- RUNDB is additive + type-validated on every read; never rename/retype a
  stored key (old SavedVariables are already on players' disks).
- Version bumps touch THREE files together: `RUN.toc`, `RUN_Vanilla.toc`,
  `core/init.lua` (the gate reds on drift).

**LAW 2 - build for BOTH, always (flavors AND apps).**
- Every change gates on BOTH TOCs; any `RUN.toc` file-list change is
  MIRRORED into `RUN_Vanilla.toc` in the same change.
- Client APIs are PRESENCE-DETECTED (pcall + nil-checks), never
  version-number branches; an API absent on one flavor degrades silently
  (the quests.lua era shim is the pattern).
- The game-partition law: any data that leaves the machine carries the
  season namespace - Forever `s0/s1...`, Classic Era `c0/c1...` - because
  npcIDs are IDENTICAL across the two games; counts must never blend.
  Creature NAMES may merge across games (same Azeroth); numbers never.
- Two apps, one job each: character analysis belongs in Foresight, the
  living-world enemy layer in RUN. Never duplicate a capability across
  apps - integrate through the bridge (`ForesightAPI`, probed defensively)
  or the shared backend, never by copying code.

## Pre-ship checklist for every addition

1. Gate green, BOTH flavors, including the schema drift check.
2. New logic ships WITH selftests, registered from the owning file via
   `RUN.selftestChecks` (slash subcommands via `RUN.commands`) - never by
   editing `selftest.lua`/`init.lua` routers.
3. Frozen wire tags untouched; new tags strict-decoded + rate-limited.
4. TOC mirror law satisfied; version-bump trio if shipping.
5. Marketing-repo touches additive-only; both repos' gates green.
6. Season/game stamp correct for anything that leaves the machine.
7. Record loop: SPRINTS.md shipped line in the same change.

## House laws (unchanged, bind everything)

Display-and-advice only (compliance scan is the gate's first step); Lua 5.1
dialect; every possibly-secret read through `core/guards.lua`; the addon
NEVER networks (share-link out, pipeline bake back); no PII ever - realm/
account/guild/real-name forbidden, named tiers are opt-in chosen handles;
pure logic above the `if not _G.CreateFrame` guard so the headless gate
covers it; generated data regenerates (edit `data/overrides.lua`, never
`data/generated/`).
