# RUN - field notes (distilled from the Foresight/RUN research sessions)

The best of what we learned building Foresight and planning RUN: how WoW:
Forever actually behaves, how the reference addons pull off their tricks, and
the house laws that keep us shippable. Written so a fresh session can build on
it without re-deriving anything.

## 1. The WoW: Forever platform (what "Forever" really is)

- **Interface 16001, client build 1.60.1** - MAINLINE (retail 12.x) API over
  classic-era mechanics and content. Launches **2026-11-04**; Hardcore season
  kickoff ~**2026-12-04** (exact date TBD).
- **Talents are retail C_Traits node trees** - the classic talent globals are
  GONE. (Foresight walks 77 nodes / 7 selected on the beta Shaman; the
  spellID->talent bridge maps 38.) Source of truth for live API shapes:
  Thunderz96/forever-addon-kit (`forever_api.json` presence baseline).
- **Secret values exist** (`issecretvalue`, `C_Secrets.*`): in restricted
  contexts (instances, PvP) combat values can be unreadable. Law: every such
  read goes through a guard layer; features DEGRADE to display-only, never
  error. RUN replicates Foresight's `core/guards.lua` verbatim-in-spirit.
- **Vignettes are uncertain on Forever**: the `C_VignetteInfo` API exists
  (mainline), but classic-era silver-dragon rares may never emit vignettes.
  Treat vignette scanning as a BONUS signal; the reliable detection trio is
  nameplate / target / mouseover + your own rare DB. Verify in-game at launch.
- **Tooltips**: `C_TooltipInfo` works; talent hover hooks are quirky (neither
  SetTraitEntry nor GetTraitEntry fire - Foresight matches the tooltip OWNER
  FRAME NAME to the trait node instead).
- **CurseForge ecosystem is live** for Forever (we ship Foresight to project
  1744126 tagged for 1.60.1; RareScanner and Alenya's Guides also target it).
- `/run` is Blizzard's built-in script slash command - an addon can NEVER own
  it. RUN uses `/runadvisor`, `/runa`, `/ra`.

## 2. How RareScanner does it (mechanisms studied, not copied - ARR code)

- **Detection**: `VIGNETTE_MINIMAP_UPDATED` / `VIGNETTES_UPDATED` ->
  `C_VignetteInfo.GetVignettes()/GetVignetteInfo()`; plus live signals
  `NAME_PLATE_UNIT_ADDED`, `UPDATE_MOUSEOVER_UNIT`, `PLAYER_TARGET_CHANGED`.
  npcID = 6th dash-field of `UnitGUID` (Creature/Vehicle GUIDs).
- **It does NOT draw its own arrow**: it feeds coordinates to Blizzard's
  supertracked user waypoint (`C_Map.SetUserWaypoint` +
  `C_SuperTrack.SetSuperTrackedUserWaypoint(true)`) and optionally TomTom.
  Minimap blips via **HereBeDragons-Pins-2.0** (the library owns the
  per-frame math).
- **Kill/state tracking**: `PARTY_KILL` -> npcID via `C_CreatureInfo`
  -> per-npc timesKilled counter; respawn logic distinguishes eternal death /
  quest reset / weekly reset / custom timers; "recently seen" entries expire
  on a ticker and are distance-deduped (~10yd) for multi-spawn rares.
- **Coordinates limit**: the client cannot read ANOTHER unit's position. All
  rare coords come from vignettes or a shipped DB - which is why RUN's beta
  marks YOUR position ("I saw it here") until our own DB2-generated rares
  table lands.

## 3. How the Hardcore addon does death tracking (classic era)

- **Death = `PLAYER_DEAD`**, deduped by "no new record until the previous one
  has a resurrection timestamp".
- **Killer attribution is deliberately simple**: `UNIT_COMBAT`
  (player, "WOUND") snapshots your CURRENT TARGET's name as the last attack
  source. No combat log at all (classic-era CLEU limits). Environmental
  deaths map to codes: drowning, falling, fatigue, fire, lava, slime.
- **Broadcast is peer-to-peer, no server**: a password-gated chat channel +
  `SendAddonMessage` (prefix "HCDeathAlerts", ChatThrottleLib). Message =
  name~guild~source_id~race~class~level~instance~map~coords (+ last words).
- **Anti-spoof = Fletcher16 checksum + k-of-n peer consensus (k=3)**: a death
  is not trusted/displayed until 3 peers confirm the checksum. This is the
  proven pattern our crowd layer mirrors SERVER-side (shape-lock +
  plausibility + rate limit + MIN_BUCKET suppression).
- **RUN's upgrade**: Forever has modern CLEU, so primary attribution is a
  rolling damage buffer (last hit inside an 8s window wins; env typed); the
  Hardcore target heuristic is the fallback. Never credit an npcID that is
  not in the rares DB (fail-closed); a cliff is never blamed on a creature.

## 4. The odds model (RUN beta) - honesty first

- Coarse logistic: `z = 1.1 - 0.28*levelDelta - classPenalty` ->
  `p = 1/(1+e^-z)`, scaled by your current health fraction (`p *= hf^0.7`).
  Classification penalties (classic-presumed toughness): normal 0, rare .35,
  elite .8, rareelite 1.3; worldboss and skull-level are auto-FLEE.
- Bands over points: **FIGHT >= 65% / RISKY 35-65% / FLEE < 35%**, and every
  beta number carries "(p)". Secret health -> "advice degraded", conservative
  band. We influence permadeath decisions: never fake precision.
- Sharpening path: (1) Foresight bridge `ForesightAPI.GetDangerVerdict`
  (real EHP/TTK model - deferred until Foresight exposes it; RUN probes
  defensively and degrades silently); (2) crowd calibration
  `p *= (1 - w*deadliness)` from the killcount (hook shipped, empty-safe).

## 5. House laws (bind everything; from the Foresight doctrine)

- **Display-and-advice only.** No casting/targeting/movement/item-use/macros.
  Enforced by a static compliance scan (automation calls, sandbox escapes
  os/io/require/loadstring, `math.random` (taints shared RNG),
  `C_SpecializationInfo` calls) that REDS the ship. `-- compliance-allow:`
  for justified false positives; never weaken the list.
- **Taint law**: own frames on UIParent, ANCHORED to Blizzard frames
  (TargetFrame, Minimap) - never parented into, never key-written. Proven by
  two real Foresight incidents (ADDON_ACTION_FORBIDDEN, gamepad taint).
- **Lua 5.1 dialect** (client) vs newer harness Lua: no goto/labels, no `//`,
  no bitwise operators. Fletcher16 must be arithmetic (mod 256/65535).
- **Untrusted input**: SavedVariables are user-editable - type-validate every
  read; never execute imported content (data-only parsing, never loadstring).
- **Generate, don't hand-copy**: game data comes from Forever DB2 via the
  pipeline into `data/generated/` (placeholder ships empty-safe); hand edits
  go in `data/overrides.lua` only.
- **Confidence tags**: unverified-on-Forever facts say so - "(p)",
  classic-presumed. The beta probe upgrades or corrects them.

## 6. Crowd architecture (shared Firebase `wow-foresight`, additive)

- Addons NEVER network. Data leaves only by a user-initiated share: the addon
  builds an allow-listed, de-identified payload -> ONE link (`#d=` fragment)
  -> the web app writes Firestore. In-game readbacks happen via pipeline
  bakes (the `verifiedRules` pattern), not live reads.
- One schema file generates all three gates (addon builder, web sanitizer,
  Firestore rules `hasOnly` shape-lock); the ship gate fails on drift - a new
  field can never leak past one gate. **Forbidden forever**: realm, account,
  guild, real name, raw GUID, IP. Named tiers are OPT-IN chosen handles.
- Server-side trust: write-only raw collections, admin-SDK-only public
  aggregates, MIN_BUCKET(5) small-bucket suppression, per-clientId dedup/rate
  limits, server recomputation of anything valuable (e.g. the Giant Slayer
  odds tier is recomputed from the submitted snapshot - the client's % is
  advisory only).
- Firebase reality: ONE ruleset + ONE functions source per project, so RUN's
  backend pieces land as small ADDITIVE commits in the Foresight repo (rules
  blocks appended before the final deny; a new function file + require line)
  with canonical copies + parity checks here.

## 7. Product + distribution decisions (current)

- RUN = standalone addon, separate repo, ARR source-available license (both
  addons switched MIT->ARR 2026-10-15; bundled libs would keep their own).
- **Waitlist-first (2026-10-19)**: NOT live on CurseForge at launch - a
  waitlist gates access (page on the marketing site; email capture is PII ->
  consent text + privacy-policy update ship together). Betas go out as direct
  zips; the gate (compliance + selftest) must be green before any zip.
- Timeline: private beta now -> waitlist opens pre-launch -> Forever launch
  2026-11-04 -> Hardcore kickoff ~2026-12-04 fires the non-destructive
  seasonal reset of the killcount ladder (archive Season 0, never wipe).
- The marketing system for Foresight already exists and is reusable for the
  RUN waitlist page: the Armory carved-stone + gold brand (Cinzel/Spectral,
  stone #0b0906-#271f13, gold #c8a24c/#efd488, emerald #33ff99 accents) in
  `marketing/marketing-site/` + the Forever Codex plate pattern for imagery.
