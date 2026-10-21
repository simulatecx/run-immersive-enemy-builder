# The Ecosystem Plan - two apps x two games, one backend

> HANDOFF SPEC (written 2026-10-21). A fresh session executes against this.
> Executor rules: re-pin the baselines below FIRST; if a repo moved, append a
> dated BASELINE RECONCILIATION section at the top - never edit this text
> silently. Decisions here are FINAL unless the owner reopens them.

## 0. Self-contained header

**The products.** Two sibling addons, one studio (SimulateCX), one backend:
- **Foresight** - "the layman's oracle": build analysis, talent impact,
  odds-of-everything for YOUR character. Live on CurseForge (project
  1744126) for WoW: Forever. v0.48.0 shipped 2026-10-15.
- **RUN** - "Immersive Enemy Builder - enhancing the Azeroth we know and
  love": the world grows with every player it fells. Nemesis notoriety
  tiers + earned titles, nearby pings, P2P death network, RISK IT wagers,
  guild wipes, Account Ledger. WAITLIST-FIRST (deliberately NOT on
  CurseForge). v0.8.0, dual-flavor.

**The games.** WoW: Forever (mainline 12.x API over classic mechanics,
Interface 16001, launches 2026-11-04, Hardcore kickoff ~2026-12-04) and
Classic Era (Interface ~11508, Hardcore population live TODAY - the fork's
commercial reason). RUN ships BOTH from one folder: `RUN.toc` +
`RUN_Vanilla.toc`. Foresight is Forever-only (multi-version was rejected on
the record in its triage history; revive only by owner decision).

**Repos + baselines (re-pin before building).**
- `C:\Users\BradsPC_2022\orca\workspaces\overlay\run-forever` - RUN. HEAD at
  writing: v0.8.0, gate green BOTH flavors (`python pipeline/run_tests.py` ->
  compliance + crowd-schema drift + dual-TOC selftest 239/239). Deployed to
  both local installs (`D:\Games\World of Warcraft\_classic_beta_` and
  `_classic_era_`). Zip: `dist\RUN-v0.8.0-forever-and-era.zip`.
- `C:\Users\BradsPC_2022\orca\workspaces\overlay\marketing` - Foresight +
  the SHARED deployable surface (web/functions/rules). Branch
  `simulatecx/marketing`. Foresight's own gate: `python pipeline/run_tests.py`
  (293/293 at writing). Doc spine synced through the "Record loop: ARR
  license batch + RUN shared-surface spine sync" commit.
- Firebase project: `wow-foresight` (the ONLY backend). RUN's rules blocks +
  `functions/rareKills.js` are COMMITTED BUT NOT DEPLOYED.

**House laws binding every future change** (full text: run-forever
`docs/NOTES.md`, marketing `CLAUDE.md`): display-and-advice only, Lua 5.1,
secrets via Guards, addons never network (share-link + bake only), no PII
(realm/account/guild/real-name forbidden; named tiers are opt-in chosen
handles), generated data regenerates, additive-only on the shared surface,
every feature ships with registered selftests, gate green before any
zip/deploy/commit.

## 1. The holistic data architecture (FINAL)

ONE Firebase project, TWO partition layers. This section is the mental
model everything else hangs off.

**Layer 1 - products never share collections.**
```
Foresight: contributions, feedback  ->  aggregates, leaderboards,
                                        crowdInsights, verifiedRules
RUN:       rareKills, runWaitlist   ->  rareKillCounts, giantSlayers
                                        (+ seasonArchive/* at resets)
```
Separate write paths, separate functions (`rebuild()` vs
`rareKillsOnWrite`), separate public reads. A bug in one cannot touch the
other. All additions to the shared surface remain ADDITIVE-ONLY commits in
the marketing repo (new files, appended rules blocks before the final deny,
one-line exports).

**Layer 2 - games never share numbers: the season namespace.**
Forever and Era are the SAME classic world - npcIDs match across games
(Sunscale Lashtail is one id everywhere). Counts must therefore be
partitioned or they blend into a number true of nowhere. The partition IS
the season tag stamped on every RUN event and carried on every rollup doc:
**Forever = `s0, s1, ...`; Classic Era = `c0, c1, ...`** (doctrine:
`docs/SEASONS.md`). Ladders, bakes, and archives all filter by season, so
"87 player kills" is always per-game, per-season.
- Creature NAMES (sightings harvest) are game-data and identical across
  games - the k-of-n name bake MAY merge them later (safe); counts NEVER.
- The P2P layer (death-pings/acks/wipe-pings) needs no partition: game
  chat is physically separate.
- Local RUNDB ledgers never mix either: each install has its own WTF.
- Foresight-Classic, if ever revived, partitions the same way via its
  existing `build` field on contributions.

**Why one project stays correct for now**: one ruleset + one functions
source (the deploy reality), one bill, shared App Check posture. The
collection partition keeps the escape hatch open - if RUN outgrows the
project, per-collection export/import splits it cleanly.

## 2. Current truth (what exists, what is staged, what is pending)

| Piece | State |
|---|---|
| Foresight addon v0.48.0 | LIVE on CurseForge (Forever) |
| Foresight crowd (contributions/aggregates/champions/verifiedRules) | LIVE |
| RUN addon v0.8.0 dual-flavor | Deployed to both local installs; private zip; 239/239 |
| RUN crowd backend (schema->mirrors, share link, function, rules) | COMMITTED, NOT DEPLOYED (emulator 40/40) |
| Armory "The Deadliest" boards + web/run.html (waitlist + receiver) | COMMITTED, NOT DEPLOYED |
| RUN marketing set (6 cards + 1600x900 composite, ember/blood brand) | `marketing/marketing-site/export/run-cards/` + `run-gallery-1600x900.png` |
| Foresight marketing set + microsite | `marketing-site/` (uncommitted assets by choice) |
| App Check write-gate | DISABLED project-wide (inherited Firebase backend issue; restore on both `contributions` and `rareKills` together) |
| ForesightAPI bridge (RUN reads Foresight's real EHP/TTK verdict) | DEFERRED - RUN probes `_G.ForesightAPI` defensively; Foresight has not exposed it yet |
| Companion uploader app | Designed only (`marketing/docs/COMPANION-APP.md`) |

## 3. The work queue for the new chat (in order)

**W1 - Era season stamp (THE known gap; do first, small).** Both flavors
currently stamp `s0`. Make `Share.season()` platform-aware: era client ->
`c0`. Detection by API presence (the same signal quests.lua uses:
`C_QuestLog.GetInfo` missing = era), NEVER version numbers; headless default
stays `s0`; selftests prove the era path stamps `c0` and Forever stays `s0`.
Owner of truth: `RUN/core/share.lua` + `RUN/core/init.lua` comment. ~10
lines + checks. Without this, era shares would pollute Forever counts on
go-live - nothing may deploy W3 before W1 lands.

**W2 - Field verification pass (owner plays, session fixes).** Forever
beta AND era HC realm: `/ra selftest` (both flavors), `/ra diag`, the
`docs/ERA.md` 10-step checklist (confirms the 11508 interface number, era
quest path, channel join on era, HC-mode detection), tier frames on a
titled target, RISK IT arm->win/lose, Ledger drag/X/Heard page, the
expansiveStats odds render (the one unresolved field bug - `/ra panel`
self-check splits frame vs data path). Every bug found becomes a permanent
selftest (the incident-to-gate habit that caught the attribution bug).

**W3 - Backend go-live (owner-gated, scripted order).**
`firebase deploy --only firestore:rules` -> `--only
functions:rareKillsOnWrite` -> `--only hosting` (rules-before-code law).
Then: one end-to-end share from each flavor -> verify rollups land with
the right season tags -> `pipeline/fetch_counts.py` bake -> confirm
notoriety blends the third source. The dry-run 403s flip to reads.

**W4 - Waitlist open + RUN marketing.** Post the teaser (the run-cards
set), link `web/run.html`. Consent copy + privacy section already shipped
together. CurseForge for RUN stays OFF (waitlist-first stands).

**W5 - Launch-window items.** `strictTrust` default flip consideration at
launch (k-of-n needs population); App Check restore on BOTH write
collections when the Firebase backend issue clears; Forever launch
2026-11-04; Hardcore kickoff ~2026-12-04 runs `pipeline/season_archive.py`
per the `docs/SEASONS.md` runbook (non-destructive; bump `RUN.season`
s0->s1, era c0->c1 if its season turns too).

**W6 - The bridge + the companion (bigger, owner-prioritized).**
(a) ForesightAPI: Foresight exposes `GetDangerVerdict(npcID, ctx)` over its
EHP/TTK engine in its OWN release train (additive; RUN already consumes it
defensively) - this is "install both, odds get sharp", the two-app synergy
story. (b) The companion uploader (read SavedVariables -> auto-share,
consent-gated) makes "play = contribute" real for BOTH apps; its
prerequisite (single-source allow-lists) is done on both sides.

## 4. Out of scope (do not build without the owner reopening)

- Foresight Classic (rejected-on-record; the partition pattern is ready if
  revived).
- Guild names in ANY Firebase payload (local + in-guild P2P only until an
  opt-in guild-tag tier is designed through the generated allow-list).
- Deleting anything at season reset (the archive op contains no delete
  call by design).
- A second Firebase project (the partition makes it unnecessary today).
- CurseForge publication of RUN (waitlist-first is the owner's standing
  decision).

## 5. Done criteria for "the ecosystem is live"

Both flavors field-verified green; backend deployed in order; one share
from each game visible on the correctly-filtered ladder; the waitlist
taking consented emails; the spine synced in both repos (RUN SPRINTS +
marketing CHANGELOG/FEATURES carry whatever ships); memory updated.

## 6. Paste-ready for the new chat's first message

"Read `run-forever/docs/ECOSYSTEM.md` and execute W1 (era season stamp),
then walk me through W2's field checklist while I'm in game."
