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

> CONTEXT SHIFT 2026-10-22 (owner): **the Forever BETA is over** - no Forever
> field environment exists until launch (2026-11-04). Development stays
> dual-flavor (LAW 2 unchanged: every change still gates on BOTH TOCs), but
> field work is CLASSIC ERA-FIRST: W2's Forever-side checks are DEFERRED to
> launch day, when Forever gets a fresh verification pass against the new
> data set (re-pin Interface 16001, re-check API presence assumptions, rerun
> the full field checklist there). v0.8.2 shipped the quest-target nameplate
> badge (ui/plates.lua, `questPlates` setting) - era field checklist step 7
> now covers it.

> LAUNCH CLIENT 2026-10-29: the live WoW: Forever product is installed -
> flavor `wowf`, version **1.60.1.70685**, folder `_forever_` (NOT the old
> beta folder). The `_classic_beta_` product is DEAD: removed from
> .build.info; its folder remains on disk with a stranded RUN 0.8.2 copy -
> ignore it. Interface numbers verified against the live products: Forever
> 1.60.1 -> **16001** (RUN.toc already correct; live Foresight 0.53.0
> concurs), era **1.15.9**.70576 -> **11509** (RUN_Vanilla.toc correct
> post-W0). The `wowf` client loads the unsuffixed RUN.toc (Foresight's
> live CurseForge packaging proves the convention). pipeline/deploy.py now
> targets `_forever_` + `_classic_era_`; RUN v0.8.2 deployed to BOTH live
> installs 2026-10-29. No RUNDB SavedVariables exist in ANY install (the
> dead beta had none to migrate; the era W2 pass has not started) - W2 now
> covers BOTH live environments. NEW-DATA RE-CHECK queued: the Creature.db2
> "hotfix-sparse" verdict (SPRINTS RUN-B) was pinned on beta build 70338 -
> re-verify against live build 70685 via pipeline/gen_rares.py before
> assuming the sightings harvest stays the only rares source.
> RE-CHECK DONE 2026-11-03: the verdict HOLDS on BOTH live builds - Forever
> 70685's Creature.db2 is a 184-row hotfix stub (every row Classification 0,
> names blank) and era 70576's is effectively empty; creature names remain
> server-side in both clients. The sightings harvest + data/overrides.lua
> stay the ONLY rares sources - do not revisit without a new build.
> gen_rares.py DEFAULT_BUILD bumped to 70685; rares.lua header re-stamped
> (table unchanged: empty).

> LAUNCH DAY 2026-11-04: WoW: Forever went live and patched to build
> **1.60.1.70790** (was 70685; Wow.exe stamped 13:14). Era UNCHANGED
> (1.15.9.70576). Re-verified against the launch build: Interface **16001**
> STILL CORRECT (the whole 1.60.1 line 70450->70790 maps to 16001 -
> cross-checked online; a hotfix build bump within 1.60.1 is not an API
> patch, so no TOC change and RUN's presence-detection is unaffected). DB2
> re-check on 70790: Creature.db2 is STILL an 11 KB hotfix stub (0 rares) -
> the server-side-names verdict holds on the launch build. gen_rares.py
> DEFAULT_BUILD -> 70790; both live installs redeployed (v0.8.3, gate
> 251/251). No RUNDB exists in the Forever install yet (owner has not run a
> RUN character far enough to save on the new build) - the W2 Forever field
> pass is still outstanding; the login-banner "out of date?" check is the
> final interface confirm.

> LAUNCH-DAY INCIDENT + FIX 2026-11-04 (v0.8.4): first live login CRASHED
> ~14s into a packed starter zone - client dump = Out of Memory with the
> SYSTEM at 94% RAM and one RUN Lua error; the client then disabled RUN on
> relog (newest addon; NOT out-of-date - Foresight 0.54.0 at the same 16001
> stayed enabled, and RUNDB saved clean at 0.8.3). Whether or not RUN caused
> the OOM, the owner directive is "never conflict with the game": v0.8.4
> ships core/safety.lua - the firewall. Every periodic job + hook now routes
> through RUN.safeCall / RUN.ticker (one shared guarded throttled OnUpdate),
> the one unbounded table is pruned, and /ra diag reports swallowed-error
> count. RUNDB is on 0.8.3 but fully forward-compatible (additive law).
> OWNER ACTION OUTSTANDING: RUN is still `disabled` in the Forever AddOns
> list (AddOns.txt) from the post-crash prompt - re-enable it in-game,
> /reload, then /ra diag should read "firewall: 0 RUN errors". That re-enable
> + the W2 Forever field pass are the launch-day to-dos.
> FIND-THE-ERROR TOOLING (v0.8.4, same day): the crash dump is C++-only (no
> Lua stack), so the exact line is not in it. Built pipeline/client_smoke.py
> - a WoW-API mock harness (with a faithful secret-value sentinel) that
> loads + drives the client paths the pure gate skips; it is now a REQUIRED
> gate step and is GREEN both flavors (common + secret paths proven robust -
> the launch edge is narrower). AND the firewall now persists swallowed
> errors to RUNDB.safetyLog (black-box recorder); `/ra errors` dumps it.
> TO PIN THE EXACT LINE: re-enable RUN, play ~15 min on Forever, then
> `/ra errors` or pull `_forever_\WTF\...\SavedVariables\RUN.lua`
> (db.safetyLog) - that names the file + message; turn it into a targeted
> selftest. Deploy to Curse is SAFE regardless: the firewall degrades any
> residual edge silently (worst case = one cosmetic feature no-ops, never a
> crash or a disable).

> 2026-11-03 (owner): **CurseForge REOPENED** - W4 is revised: the launch
> channel is a CF listing (one project, both flavors, the Foresight
> pattern) INSTEAD of waitlist-only; canonical paste-ready copy +
> screenshots: `marketing/curseforge/LISTING.md`. Publish stays
> owner-gated and is independent of W3 (the listing promises no live
> leaderboards). Shipped same day: v0.8.3 tier glow (`ui/glow.lua`,
> `tierGlow` setting) - the owner-asked target-frame treatment that
> expands around the stock frame without touching it.

> 2026-11-08: **v1.0.0 PUBLIC LAUNCH - RUN is LIVE on CurseForge + Wago +
> GitHub Releases (~2000 users).** §1's "WAITLIST-FIRST / NOT on CurseForge"
> and W4's waitlist framing are SUPERSEDED (the 2026-11-03 CF-reopen
> decision executed). The 1.0.0 number cleared the 0.9.x string-sort trap -
> the lesson is recorded in SPRINTS Shipped. Users are REAL now: every law
> about frozen wire tags, additive RUNDB, and rules-before-code is live-fire.

> 2026-11-10 - RUN-P CALIBRATION CAPTURE (executed from the overlay/Foresight
> chat; THIS block is the bridge into this project): **v1.1.0 BUILT +
> COMMITTED + PUSHED (master `bd75e77`); the CurseForge tag is HELD** for the
> deploy order below. Baseline at this block: gate green BOTH flavors
> 293/293 (`python pipeline/run_tests.py`), emulator suite 51/51, version
> trio 1.1.0, deployed to both live installs. Design record:
> `docs/QUESTIETRACE-ANALYSIS.md`; story: SPRINTS Wave 2b "RUN-P".
>
> WHAT SHIPPED (locate by content, not line numbers):
> `RUN/model/calibration.lua` - tri-state `RUNDB.captureConsent` (nil=never
> asked / true / false="never ask again"; OWN dialog frame, never
> StaticPopup), `/ra capture on|off|status`, login transparency line,
> >=1h+resting inn share reminder; pairs the LAST odds assessment of a
> creature (hooked in `Odds.forUnit`, guarded) with a solo PARTY_KILL /
> PLAYER_DEAD outcome into `db.calib` (cap 200, no GUIDs/names/positions).
> `Share.eventFromCalib` (core/share.lua) re-clamps every journal row through
> `Calibration.clampEvent` before the allow-list build - the `calib` kind now
> rides `/ra share` (schema `data/rare-kills-schema.json`: kinds cap 4->5;
> ALL mirrors regenerated + parity green, including the worktree rules
> block). Backend (`functions-run/index.js` = worktree `functions/
> rareKills.js`, same bytes): `validCalib` RECOMPUTES predicted odds from
> pl/cl/cls (client p stays advisory), per-npc `tally.calib
> {fights,wins,sumP,sumPc}`, public `calib {fights,winPct,predPct}` block
> only at MIN_BUCKET, per-season decile doc `rareKillMeta/calcurve-<season>`.
> Daily review: `pipeline/review_calibration.py` (owner gcloud = full
> volume/curve/gaps/deadliest digest; no auth = public fallback; saves to
> pipeline/collected/, gitignored). Worktree commit `528579f`; branch
> `simulatecx/marketing` now exists on origin.
>
> QUEUE DELTAS: **W3 is THE critical path and now carries the calib surface.
> run.html is 404 TODAY - 2000 live users' shares land NOWHERE.** Owner
> order, from the worktree: deploy rules -> functions -> hosting, verify one
> end-to-end share per flavor, THEN `git tag v1.1.0 && git push origin
> v1.1.0` (rules-before-code: a calib payload against the OLD deployed rules
> fails `kinds.hasOnly` and bounces the user's WHOLE share). W2's field list
> grows three checks: the first-login consent dialog, `/ra capture` tri-state
> persistence (decline must survive /reload - the gate caught the crashed
> session's `db.x or nil` idiom collapsing a stored false into nil; a
> selftest pins it now - NEVER use and/or for tri-state reads), and the inn
> reminder. DAILY RITUAL once W3 lands: `python
> pipeline/review_calibration.py` (or tell the agent "review RUN data");
> odds-curve changes go through `data/overrides.lua` + a reviewed commit,
> never auto-tuned.
>
> TOOLING PIN (emulator): use `npx -y firebase-tools@14 emulators:start
> --only firestore,functions,auth --project demo-wow-foresight` FROM the
> `firebase/` directory - v15 requires Java 21 (machine has 17), v13 cannot
> load firebase-functions v7, and running from the repo root hits a
> config-resolution quirk. Refresh `firebase/firestore.test.rules` from the
> worktree's `web/firestore.rules` first (the firebase.json `$doc` says how),
> then `python functions-run/test/emulator_test.py`.
>
> OUT OF SCOPE unless the owner reopens: auto-tuning the odds model from
> crowd data; capturing GROUP fights (solo-only by design - the odds are a
> solo prediction, group outcomes would poison the curve); any new
> identifying field; wiring the curve into `Odds.compute` (that is the
> phase-E consumer, a FUTURE story - it ships only with baked, human-reviewed
> data).

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
