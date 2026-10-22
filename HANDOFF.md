# RUN - Full Project Handoff (for the new Orca project)

> Written 2026-10-22 at the repo move to its permanent home. SELF-CONTAINED:
> a fresh session with zero prior context (and a fresh memory directory)
> executes from this document alone. Executor law: re-pin every baseline in
> §2 FIRST; if anything moved, append a dated BASELINE RECONCILIATION at the
> top - never silently edit the text below.

> EXECUTION RECONCILIATION 2026-10-22 (baseline unmoved - executed at
> ed0c527, the commit this spec shipped in): **W0 + W1 are DONE - do not
> rebuild** (v0.8.1, gate 241/241 BOTH flavors). W1 mechanism: a second
> constant `RUN.seasonEra = "c0"` beside `RUN.season` in `core/init.lua`
> (init.lua stays the one flip home; the two lines flip independently per
> docs/SEASONS.md), `Share.season()` selects via `Share.detectEra` (API
> presence, the quests.lua signal), and the clamp fail-safe is
> PARTITION-LOCAL (era falls back to `c0`, never `s0`). One recorded
> deviation: the version trio was bumped 0.8.0 -> 0.8.1 (spec silent on
> versioning) so the W2 field pass can confirm the deployed build from the
> login banner. docs/ERA.md gained checklist step 11 (the `c0` stamp
> field-check). The queue resumes at W2.

## 1. What this product is

**RUN - "Immersive Enemy Builder: enhancing the Azeroth we know and love."**
A passive WoW addon where ENEMIES GROW with every player they fell
(Shadow-of-Mordor Nemesis research, platform-honest): a 10-tier notoriety
ladder with deterministic earned titles ("Sunscale Lashtail 'the
Widowmaker'"), tier-styled unit frames, nearby-enemy banners (rares, soft
elites, quest targets), a P2P death network (anonymous creature-centric
death-pings + last words + eulogy mode, Hardcore-addon pattern), the RISK IT
solo wager (Giant Slayer <25% / Underdog 25-50%), group-wipe records, guild
wipe ledgers (local-only), and the account-wide Ledger with its Most Wanted
board. Fully automatic - slash (`/ra`) is options-only (`/run` is
Blizzard's). Display-and-advice ONLY, enforced by a static compliance gate.

Sibling to **Foresight** ("the layman's oracle" - character/build analysis).
One studio (SimulateCX), one Firebase backend, two apps with one job each:
character analysis = Foresight; the living-world enemy layer = RUN.
Integration happens via the (future) `ForesightAPI` bridge and the shared
backend - never by copying code between apps.

**Distribution: WAITLIST-FIRST.** RUN is deliberately NOT on CurseForge;
access via the waitlist page; private-beta zips by hand. License: All
Rights Reserved (source-available), bundled libs keep their own.

## 2. Repos, paths, baselines (re-pin before building)

- **THIS repo (RUN)**: `E:\Development_Related\development_projects\wowforever_addons\run-forever`
  (moved here 2026-10-22 from the orca workspace; git history intact).
  Baseline: **v0.8.0**, gate green BOTH flavors - `python
  pipeline/run_tests.py` -> compliance + crowd-schema drift + dual-TOC
  headless selftest **239/239 each**. Zip:
  `dist\RUN-v0.8.0-forever-and-era.zip`.
- **Foresight main repo**: `E:\Development_Related\development_projects\wowforever_addons\overlay`
  (branch `main`, **v0.53.0** at writing - see the reconciliation in §3).
- **The orca worktree** `C:\Users\BradsPC_2022\orca\workspaces\overlay\marketing`
  (branch `simulatecx/marketing`) - **this branch, NOT main, currently
  carries RUN's deployable shared surface**: `functions/rareKills.js` (+1
  export line), the appended `web/firestore.rules` blocks, `web/run.html`,
  `web/run-crowd-schema.js`, the armory "The Deadliest" boards in
  `web/app.js`/`index.html`, the privacy RUN section, and the RUN marketing
  set (`marketing-site/export/run-cards/*` + `run-gallery-1600x900.png`).
  Canonical sources for the backend pieces live in THIS repo
  (`functions-run/`, `firebase/`); `pipeline/gen_crowd_schema.py` parity-
  checks the deployed copies (resolver order: `RUN_MARKETING_ROOT` env ->
  `../overlay` -> `../marketing` -> the orca worktree; it picks whichever
  carries `web/run-crowd-schema.js`, so it follows the surface when the
  branch merges).
- **Firebase**: project `wow-foresight` - the ONLY backend. RUN's rules +
  function are committed on the branch above, **NOT deployed**.
- **Game installs** (deploy targets in `pipeline/deploy.py`):
  `D:\Games\World of Warcraft\_classic_beta_` (Forever) and
  `_classic_era_` (Classic Era) - both have RUN v0.8.0 deployed.
- Key docs IN THIS REPO: `CLAUDE.md` (the Two Laws - auto-loads),
  `docs/ECOSYSTEM.md` (architecture + original work queue),
  `docs/NOTES.md` (platform research: Forever facts, RareScanner/Hardcore
  teardowns, Nemesis mapping), `docs/ERA.md` (fork deltas + field
  checklist), `docs/SEASONS.md` (reset doctrine), `docs/AGENT-PLAN.md`
  (how the v0.8.0 fleet build was structured), `SPRINTS.md` (tracker).

## 3. BASELINE RECONCILIATION vs older docs (important)

1. **Foresight is now DUAL-FLAVOR itself**: v0.53.0 ships Forever
   (Interface 16001) + **Classic Era (Interface 11509)** from one repo/one
   CurseForge project (1744126). Older statements that "Foresight is
   Forever-only / multi-version rejected" (ECOSYSTEM §0/§4) are SUPERSEDED.
   Consequences: (a) the ForesightAPI bridge becomes valuable on era too;
   (b) Foresight's crowd data partitioning across games (its `build` field)
   is now a REAL concern for its own ladders - flag it when working that
   repo.
2. **RUN_Vanilla.toc says Interface 11508 (an estimate); Foresight VERIFIED
   11509 on era.** Align RUN to 11509 - this is W0 below.
3. ECOSYSTEM §0/§2 path references to the orca workspace are stale for RUN
   (repo moved here); the marketing worktree path is still valid for the
   shared surface until that branch merges.

## 4. The architecture in one breath (full detail: docs/ECOSYSTEM.md)

ONE Firebase project, TWO partitions. Products never share collections
(Foresight: contributions->aggregates/leaderboards/verifiedRules; RUN:
rareKills->rareKillCounts/giantSlayers, + runWaitlist). Games never share
NUMBERS: the season namespace partitions them - **Forever `s0,s1...`,
Classic Era `c0,c1...`** - which is load-bearing because npcIDs are
IDENTICAL across the two games (same classic world). Creature NAMES may
merge across games later (game data); counts never. The P2P layer and local
RUNDB ledgers are physically game-separated already. The addon NEVER
networks: data leaves only via the user's `/ra share` one-link into
`web/run.html`; verified counts return via `pipeline/fetch_counts.py` bakes.

## 5. The Two Laws (full text: CLAUDE.md - they auto-load; recap)

1. **Never step on an existing deployment of either app**: shared surface
   additive-only; wire tags frozen (RDP1/RDA1/RLW1/RVH1/RWP1 - new tags,
   never changed ones); RUNDB keys additive; version bumps = the trio
   (RUN.toc + RUN_Vanilla.toc + core/init.lua); deploys owner-gated,
   ordered rules -> functions -> hosting.
2. **Build for both** (flavors AND apps): dual-TOC gate + TOC mirror law;
   API presence-detection, never version branches; the s*/c* season stamp
   on anything leaving the machine; one job per app, integrate via
   bridge/backend.

## 6. Work queue (ordered; W0-W1 before ANY backend deploy)

- **W0 - Era interface alignment**: `RUN_Vanilla.toc` `## Interface:` 11508
  -> **11509** (Foresight-verified). One line + gate.
- **W1 - Era season stamp (the known data gap)**: both flavors currently
  stamp season `s0`. Make `Share.season()` (RUN/core/share.lua) platform-
  aware: era client -> `c0`. Detect era by API presence (the quests.lua
  signal: `C_QuestLog.GetInfo` absent + `GetQuestLogTitle` present), never
  version numbers; headless default stays `s0`; register selftests (era
  stamps c0, Forever stays s0, headless safe). Without this, era shares
  would pollute Forever counts on go-live.
- **W2 - Field verification** (owner in game, session fixes): both flavors:
  `/ra selftest`, `/ra diag`, the `docs/ERA.md` 10-step era checklist
  (confirms 11509, era quest path, channel join, HC detection), tier frames
  on a titled target, RISK IT arm->win/lose, Ledger drag/X/Heard page, and
  the ONE unresolved field bug: expansiveStats odds render (`/ra panel`
  self-check splits frame-vs-data-path). Every field bug becomes a
  permanent selftest.
- **W3 - Backend go-live (owner-gated)**: FIRST merge/land the
  `simulatecx/marketing` branch's surface into the Foresight repo's deploy
  state (owner's call: merge to main vs deploy from branch), THEN
  `firebase deploy --only firestore:rules` -> `--only
  functions:rareKillsOnWrite` -> `--only hosting`. Then one end-to-end
  share from EACH flavor -> verify season-tagged rollups -> run
  `pipeline/fetch_counts.py` -> confirm notoriety blends the third source.
- **W4 - Waitlist open**: post the teaser (run-cards set), link
  `wow-foresight.web.app/run.html`. Consent + privacy already shipped.
  CurseForge for RUN stays OFF.
- **W5 - Launch window**: Forever launch 2026-11-04; Hardcore kickoff
  ~2026-12-04 -> `pipeline/season_archive.py` per `docs/SEASONS.md`
  (non-destructive; bump `RUN.season` trio-style). Consider `strictTrust`
  default flip when population supports k-of-3. App Check restore on BOTH
  write collections when the Firebase backend issue clears (inherited).
- **W6 - The synergy plays**: (a) ForesightAPI bridge - Foresight exposes
  `GetDangerVerdict(npcID, ctx)` over its EHP/TTK engine in its own release
  train (RUN already probes `_G.ForesightAPI` defensively); now doubly
  valuable since Foresight runs on era too. (b) The companion uploader
  (reads SavedVariables -> auto-share, consent-gated; design:
  overlay repo `docs/COMPANION-APP.md`) - makes "play = contribute" real
  for BOTH apps; prerequisites (single-source allow-lists) done on both
  sides.

## 7. Out of scope without the owner reopening

Guild names in ANY Firebase payload (local + in-guild RWP1 only until an
opt-in guild-tag tier is designed through the generated allow-list);
deletes at season reset (the archive op contains no delete call by
design); a second Firebase project; RUN on CurseForge; changing frozen
wire tags.

## 8. Orca-project notes for the new chat

- This repo is the project root. The old chat's auto-memory lived under the
  previous project key and will NOT load here - THIS DOCUMENT is the
  bridge; `CLAUDE.md` carries the laws; seed new memory from §1-§6 as you
  work.
- The gate is the truth: `python pipeline/run_tests.py` green (both
  flavors) before any zip/deploy/commit. `pipeline/deploy.py` copies to
  both game installs. Commit style: no agent co-author trailers, plain
  dashes, record loop (SPRINTS.md) in the same change.
- Paste-ready opener: **"Read HANDOFF.md, execute W0+W1, then walk me
  through W2's field checklist - I'll be in game."**
