# RUN - Work Tracker

Single source of truth for RUN work. Status glyphs: ☐ todo · ◐ in progress ·
☑ done · ⚑ superseded. Origin spec: Foresight S35 (relocated here per the
separate-repo decision); full handoff spec kept at
`~/.claude/plans/silly-watching-lollipop.md` at planning time.

## Decisions (owner)

- 2026-10-15: separate repo; ARR license; opt-in named Giant Slayers; killcount
  reporting default ON with visible opt-out; name "RUN" final; Hardcore-kickoff
  seasonal reset is a NON-destructive archive.
- 2026-10-19: **waitlist-first distribution** - RUN does NOT go live on
  CurseForge at launch; access via a waitlist (page to live on the marketing
  site / armory), betas handed out as direct zips. The CurseForge project is
  deferred until the owner flips it.
- Slash is `/runadvisor` (+ `/runa`, `/ra`): plain `/run` is Blizzard's
  built-in script command and can never be taken by an addon.
- 2026-11-03 (owner): **CurseForge REOPENED for RUN** - the 2026-10-19
  waitlist-only stance is superseded for the Forever launch window.
  Canonical listing copy + screenshots live in `marketing/curseforge/`
  (name recommendation: "RUN: Immersive Enemy Builder"; nemesis framing as
  INSPIRATION in body copy only - never "Nemesis System" in the name).
  Actual publish stays owner-gated.
- 2026-10-19 (owner): **passive-first UX** - players must never RELY on slash
  commands. The always-on layer is mouseover/target tooltip FLAGS (Elite /
  Rare / Rare Elite / Boss) + a kill-earned danger rank (Blooded 1 /
  Dangerous 2+ / Deadly 5+ / Infamous 10+; local journal now, crowd body
  count later). Win-chance displays live behind ONE option, "Expansive Enemy
  Stats" (off by default). `/ra` exists only to set options.

## Epic

### RUN - danger/rare advisor (origin: Foresight S35)  ◐
As a hardcore-or-not player, I want a lightweight addon that tells me my odds
vs a nearby rare, points me to/away from it, and shows how many players it has
killed, so I can fight or flee on good information.

- ☑ RUN-A shell + detection (v0.1.0): TOC 16001, RUNDB type-validated, guard
  layer replicated, event hub, slash router, GUID->npcID, UnitClassification
  notability, gate green (compliance + 44-check selftest).
- ◐ RUN-B rares DB - PIVOTED (2026-10-19): DB2 is a DEAD END (Creature.db2
  verified hotfix-sparse on 1.60.1.70338 - zero world creatures; names are
  server-side; `pipeline/gen_rares.py` kept as the fetch/verify tool). The
  path is the SIGHTINGS HARVEST (v0.7.1, shipped): every rare+ seen is
  recorded to RUNDB.sightings (name/classification/map/coords; vignette
  coords when they fire, player pos otherwise), consumed by heard-ping
  names, markKnown pins, and notable-death displays. REMAINING: crowd
  aggregation of sightings into a shared bake (k-of-n on name+npcID) with
  RUN-E; overrides stay the curated layer.
- ◐ RUN-C odds panel + waypoint (v0.1.0): coarse logistic model (level delta +
  classification + health, bands over points, always "(p)"), panel anchored
  under TargetFrame (never parented - taint law), mouseover rare preview,
  auto-mark via C_Map.SetUserWaypoint + C_SuperTrack + TomTom. Local death
  journal (CLEU buffer + env codes) shipped ahead of E because it is
  local-only. REMAINING: standalone nearest-threat frame; Foresight bridge
  live test; in-game verify sweep on Forever beta.
- ◐ RUN-D Devil button + Giant Slayers (v0.7.0 LOCAL CORE): RISK IT button on
  the odds frame (solo + odds<50%; GIANT SLAYER <25% / UNDERDOG 25-50%);
  pure arm/resolve state machine (won on solo PARTY_KILL of the armed npc,
  lost to its kill, abandoned on other-death/5-min expiry); wins recorded to
  RUNDB.slays + gold banner + Ledger "Giant Slayers" section. REMAINING:
  the crowd post (server-recomputed odds tier, opt-in named) with RUN-E.
- ☐ RUN-E killcount crowd: `rareKills` schema + one-link share + Cloud Function
  rollup -> `rareKillCounts` (additive on the wow-foresight project), bake-back.
- ☐ RUN-F two-sided web ladder (Deadliest Creatures + Giant Slayers).
- ☐ RUN-G season model + Hardcore-kickoff reset (non-destructive archive).
- ☐ RUN-H waitlist: teaser + signup (owner-led; page on the marketing site;
  any email capture is PII - consent text + privacy policy update ship in the
  same change, per privacy-by-design).

LAUNCH: gated private beta now -> waitlist opens pre-launch; Forever launch
2026-11-04; Hardcore kickoff ~2026-12-04 triggers the RUN-G seasonal reset.

> 2026-10-21: everything below that remains open is re-planned as parallel
> agent work packages in `docs/AGENT-PLAN.md` (WP-A fork / WP-B backend /
> WP-C web+waitlist / WP-E social polish, then WP-F guilds / WP-G seasons).
> The Hardcore Classic fork is elevated: that population is live TODAY.

## The expansion plan (owner directive 2026-10-19: "match Hardcore, then grow
## the enemy stats - categories, guilds, raid wipes - we will build it all")

### Wave 1 - Hardcore-addon parity (the social death layer)
- ☑ RUN-I Social death layer (v0.6.0): heard-death ENTRIES journal
  (RUNDB.heardLog, FIFO 200), eulogy display toggle (OFF by default),
  LAST WORDS capture + broadcast (RLW1, on by default - your own public
  chat), heard-death BANNERS for known rares + notorious species.
  Remaining polish: a scrollable heard-log browser page in the Ledger.
  Original scope: heard-death ENTRIES journal (not just per-npc
  counts; capped FIFO like Hardcore's 1000), eulogy display toggle - show the
  fallen's character name on heard pings (DEFAULT OFF; honesty note: addon
  messages inherently expose the sender's char name at transport level, this
  is display-only), LAST WORDS capture + broadcast (opt-in; the player's final
  chat line rides the next death-ping), heard-death BANNER alerts for
  unique-tier creatures ("Snagglefang has claimed another victim"), all
  surfaced in the Account Ledger.
- ◐ RUN-J Trust layer (v0.6.0 core): ack echoes live (RDA1 checksum echo,
  30/hr cap), per-entry DISTINCT-sender corroboration at 2+ echoes (origin +
  2 peers = Hardcore's k=3); heardLog entries carry acks/corro. REMAINING:
  strict mode - only corroborated entries feed publicly-shown counts (flip
  at launch; beta population too small for k=3 to ever trigger).
- ☑ RUN-K Death discipline (v0.6.0): rez stamps (PLAYER_ALIVE/UNGHOST ->
  entry.rezzed), 5s double-fire guard, MODE stamped per death
  (classifyMode: hc via C_GameRules.IsHardcoreActive probe > pvp on Player
  killing blow > pve) - feeds the crowd schema's pve/pvp/hc segment.
  First-death-only ENFORCEMENT activates with HC season logic.
- ◐ RUN-L QoL parity (v0.6.0): ESC->Options Settings category registered
  from the same Settings.defs list (whole registration pcall'd - Ledger
  stays canonical; verify the panel appears on Forever), VERSION HANDSHAKE
  live (RVH1 hello on join; "a newer RUN is out there" once). Skipped: LDB.

### Wave 2 - Growing enemy stats (the centerpiece)
- ◐ RUN-M Notoriety system (v0.6.0 CORE SHIPPED): 10-tier ladder
  (1/2/5/10/15/25/40/60/80/100 kills), DETERMINISTIC titles (data/titles.lua,
  6 per tier, hashed by npcID - same name for everyone; math.random is
  banned anyway), SOFT ELITES (normal mobs tier 3+ get NOTORIOUS ENEMY
  NEARBY banners + tier-coloured tooltip lines + they ping even with
  pingNormal off), Most Wanted board in the Ledger, heard-death banners
  ("X has claimed another victim - N and counting"). REMAINING: zone/boss
  categories with per-category thresholds once the rares/boss DB bakes;
  the baked server-verified crowd count joining the blend (RUN-E).
  Vision (owner): "RUN" Immersive Enemy Builder - enhancing the Azeroth we
  know and love; the world grows with player interaction. Original scope: creatures live in CATEGORIES (tier normal/elite/
  unique + quest-named now; zone + dungeon/raid-boss classes once the rares/
  bosses DB bakes) with PER-CATEGORY thresholds - 100 kills on a normal mob
  means more than 100 on a raid boss. Extended ladder: Blooded 1 / Dangerous
  2+ / Deadly 5+ / Infamous 10+ / **Notorious 25+ / Legendary 100+** ->
  displayed as "X has killed ~100 players". Counts blend three sources with
  honest labels: your journal (fact) + corroborated heard (live) + the baked
  server-verified crowd count (durable, RUN-E). Surfaces: tooltip rank line,
  nearby banner, and a "Most Wanted" board in the Ledger (top notoriety
  creatures account-wide).

### Wave 3 - Guilds & raids
- ◐ RUN-N Raid-wipe layer (v0.7.0 LOCAL CORE): wipe detection live -
  ENCOUNTER_END success=0 (bosses) + group-death correlation (>=80% of the
  group dead inside 20s via CLEU UNIT_DIED on roster GUIDs); counts in
  RUNDB.wipes keyed npcID / "enc:<name>"; chat callout + Ledger total.
  REMAINING: guild attribution + in-guild P2P + crowd k-of-n (privacy gate
  unchanged). Original scope: WIPE DETECTION - in a party/raid, if >=80% of the
  group dies to the same encounter npc inside a T-second window, or
  ENCOUNTER_END fires with success=0 while the group is dead -> a WIPE event
  attributed to that creature. "X has killed Y raids" counter beside the
  player killcount; guild attribution (raid-majority guild) -> a local/
  in-guild "Guild G has wiped N times to X" ledger. RAID-WIPE CHECKS
  (anti-spoof): ENCOUNTER_START/END cross-check, boss-npc plausibility vs the
  DB, and server-side k-of-n - multiple distinct clientIds reporting the same
  wipe window - before a wipe counts publicly. PRIVACY GATE: `guild` is on
  the crowd FORBIDDEN list today; public guild ladders require a NEW opt-in
  identifying tier (chosen guild tag, consent-gated - ideally raid-lead
  opt-in) added via the generated allow-list ONLY. Until then guild wipe
  stats stay local + in-guild P2P.

### Wave 4 - the Hardcore Classic fork
- ☐ RUN-O Platform adapter + fork: `core/platform.lua` shimming the classic
  quest-log API, vignettes absent (already optional), TOC multi-flavor
  packaging (`_classic_era_` interface), era HC-realm detection; then the
  fork ships the SAME social layer where it matters most. Explicitly NOT
  ported: Hardcore's rules enforcement / achievements / appeals - different
  product, theirs.

Build order: I -> J -> K -> M -> L -> N -> O, with the crowd phases (RUN-E
killcount backend, RUN-F ladder) interleaving once the waitlist/Firebase work
starts - RUN-M's "~100 players" number is what RUN-E's baked counts feed.

## Shipped

- v1.0.0 (2026-11-08, PUBLIC LAUNCH): promoted the stable 0.9.10 build to 1.0.0 -
  no gameplay change, a version milestone. WHY 1.0.0 not 0.9.11: CurseForge/addon
  managers string-sort versions, so "0.9.10" sorts BELOW "0.9.4" (char-by-char
  0.9.1 < 0.9.4) and Curse was showing 9.4 as newest; 0.9.11 would lose the same
  way. 1.0.0 clears the whole 0.9 line in both string and semver order, so it is
  unambiguously latest - and marks the public launch now that CF + Wago are live.
  RELEASE_NOTES rewritten for the launch. Version trio -> 1.0.0, gate green both
  flavors 284/284; tagged v1.0.0 -> release train uploads to CurseForge + Wago +
  GitHub Releases. LESSON: keep versions semver-clean; the 0.9.10 two-digit patch
  is what triggered the string-sort trap - next line is 1.0.1, 1.0.2, ...
- RELEASE TRAIN (2026-11-07, infra - owner: "same process as our overlay"): RUN
  now mirrors Foresight's publish pipeline. Added `.pkgmeta` (BigWigsMods/
  packager: package-as RUN, move-folders RUN/RUN -> RUN, and the repo-root
  `data/` IGNORED - it collides with the addon's RUN/data/ during the move, the
  exact trap that shipped two broken Foresight zips), `.github/workflows/
  release.yml` (tag vX.Y.Z -> ship gate -> packager uploads to CurseForge + Wago
  + GitHub Releases; action refs SHA-pinned), `.github/workflows/ci.yml` (gate on
  every push/PR to main OR master), `.github/dependabot.yml`, `.github/
  RELEASE_NOTES.md` (player-facing notes, rewritten per tag), `.gitattributes`
  (LF normalization). Both TOCs carry a commented X-Curse-Project-ID / X-Website
  activation block. OWNER ACTIVATION (CI inert until done, like Foresight): (1)
  create the GitHub remote + push; (2) CF/Wago tokens into repo secrets
  CF_API_TOKEN/WAGO_API_TOKEN; (3) fill the project ids in BOTH TOCs; (4) write
  RELEASE_NOTES + `git tag vX.Y.Z && git push --tags`. The addon still never
  networks - players auto-update via their addon manager (the compliant channel).
- v0.9.10 (2026-11-06, private beta): FIX - the "RUN has been blocked" reload
  taint. Root cause (found by auditing RUN's whole secure surface, not just the
  minimap): `ui/panel.lua` still ANCHORED the odds/FIGHT panel to the Blizzard
  `TargetFrame` as its no-saved-position fallback - tethering an insecure frame
  to that secure unit frame taints its layout, so the next target-frame secure
  action is blocked (fires every reload on a fresh RUNDB, since there is no
  saved panelPos yet). The glow was moved off TargetFrame long ago; the panel
  was the last tether and contradicted that same rule. FIX: the panel is now a
  free overlay - no-saved-position opens at a safe UIParent spot in the target-
  frame region; still draggable/saveable via /ra move. INCIDENT-TO-GATE: added
  `SetPoint(... TargetFrame/PlayerFrame ...)` to the compliance taint lint (the
  old lint only caught SetParent/CreateFrame-into, so SetPoint-to slipped
  through). Also closed a broken window: the minimap-button drag `OnUpdate` now
  routes through the firewall (RUN.safeCall) + nil-guards its cursor/minimap
  reads. Gate green BOTH flavors 284/284 (compliance 33 files incl. the new
  rule, client smoke green); both installs redeployed (40 files); dist/
  RUN-v0.9.10 zip (39 files). Version trio bumped.
- v0.9.9 (2026-11-06, private beta): MINIMAP PINS now USE HereBeDragons-Pins
  (owner: "use what they use so it works consistently"). VENDORED the
  ecosystem-standard stack into RUN/Libs/ from RareScanner's Forever-working
  copy: LibStub, CallbackHandler-1.0, HereBeDragons-2.0, HereBeDragons-Pins-
  2.0 (load order in both TOCs, before RUN's files; keep their own licenses
  per the bundled-libs rule). ui/minimap_pins.lua rewritten as a THIN wrapper
  - RUN owns only the lifecycle (pool a pin frame per sighting, hand it to
  HBDPins:AddMinimapIconMap at the creature's coords, tint by tier, expire
  after 10 min via the firewall ticker); HBD owns ALL positioning (zoom,
  rotation, indoor/outdoor, shape, map transforms) so pins behave exactly
  like RareScanner's. Deleted RUN's custom project/radiusYards/offsetYards
  math + its field-watch caveats (rotation sign, indoor radius - all now
  HBD's, correct). GATE CHANGE: Libs/ is third-party + not headless-safe, so
  run_tests.py + client_smoke.py skip it in the Lua loader and
  check_compliance.py skips it in the scan (RUN's own files all still gate;
  pins no-op headless since LibStub is absent - positioning is HBD's job,
  tested in-client). INCIDENT-TO-GATE: added Minimap:CreateTexture/
  CreateFontString to the taint lint so the 2026-11-06 "RUN has been blocked"
  taint class can't recur. New pure selftests (pinKey, expired). Gate:
  compliance + client smoke green, BOTH flavors 284/284; both installs
  redeployed (40 files incl. Libs); dist/RUN-v0.9.9 zip (39 files).
- v0.9.8 (2026-11-06, private beta): MINIMAP PINS match the RareScanner/
  HereBeDragons technique (owner installed RareScanner; scanned its files).
  Findings: RareScanner uses HereBeDragons-Pins, which (a) runs fine on
  FOREVER - so HBD is Forever-viable, my earlier "untested" concern was
  unfounded; (b) parents pin FRAMES to the Minimap and NEVER calls
  Minimap:CreateTexture. That pins down the v0.9.5 taint: RUN was creating
  texture REGIONS on the secure Minimap (the one thing HBD avoids); v0.9.7's
  move to RUN's own host already removed exactly that. Adopted HBD's actual
  math: radius now prefers C_Minimap.GetViewRadius() (modern EXACT api, same
  as HBD/RareScanner) with the zoom-table fallback - resolves the indoor
  approximation EXACTLY; and a rotating minimap with unreadable facing now
  HIDES pins (HBD behaviour) instead of mis-placing. client_smoke mock gained
  C_Minimap.GetViewRadius. Gate BOTH flavors 287/287; both installs
  redeployed; dist/RUN-v0.9.8 zip. NOTE: kept RUN's own gate-clean pins (not
  the HBD library) - HBD isn't headless-safe, so vendoring it would need a
  Libs/ gate exclusion; RUN's version is now technique-equivalent + Forever-
  robust. Offer open: vendor the real HBD-Pins (Forever-working copy exists in
  RareScanner/ExternalLibs) if the library itself is wanted.
- v0.9.7 (2026-11-06, private beta): FIX - minimap pins no longer touch the
  secure Minimap (taint). Owner: "UI error each time I load - RUN has been
  blocked." Diagnosis from the black-box recorder: RUNDB.safetyLog EMPTY + no
  crash dump -> NOT a Lua error RUN throws (the firewall catches those); the
  "blocked from an action only available to the Blizzard UI" message is TAINT
  (pcall can't catch it). The v0.9.5 minimap pins created textures as CHILDREN
  of the secure, EditMode-managed Minimap, which can taint the secure minimap/
  EditMode layout at login. FIX: pins now live on RUN's OWN frame
  (RUNMinimapPinHost on UIParent, SetAllPoints the Minimap rect) - RUN adds
  NOTHING to the Minimap frame; only READS its position/size (reads never
  taint). Plus a world-ready gate (no pin work during the secure login
  layout - waits for PLAYER_ENTERING_WORLD). Gate BOTH flavors 287/287; both
  installs redeployed; dist/RUN-v0.9.7 zip. CONFIRM IN GAME: /reload - the
  error should be gone; if it persists it is NOT the pins - send the exact
  message + `/console taintLog 2` -> reload -> Logs/taint.log names the path.
  Immediate relief if needed: /ra set minimapPins off.
- v0.9.6 (2026-11-06, private beta): MINIMAP PINS use the standard algorithm
  (owner: "use the same approach as the other addons"). The ecosystem standard
  is the HereBeDragons-Pins LIBRARY - evaluated and REJECTED for RUN for two
  concrete reasons: (1) it is NOT headless-safe (GetBuildInfo/CreateFrame at
  load), so it would break RUN's load-every-file gate or force an untested
  excluded black box; (2) it branches on client flavor and never targeted the
  bespoke WoW:Forever client - unverifiable risk. So RUN keeps its own
  C_Map-based, dual-flavor-safe, headless-tested pins and adopts HBD's actual
  positioning METHOD. Fix this version: the indoor/outdoor radius is now the
  canonical Astrolabe/HBD detection (compare live Minimap:GetZoom() to the
  minimapZoom vs minimapInsideZoom CVars; pick the matching diameter table) -
  resolves the v0.9.5 indoor caveat deterministically. radiusYards(zoom,
  indoors) + indoor selftests. Gate: BOTH flavors 287/287; both installs
  redeployed; dist/RUN-v0.9.6 zip. REMAINING field-watch: the rotating-minimap
  sign (FACING_SIGN) - affects only rotateMinimap users; a 1-char flip after an
  in-game check (even the libraries verify this in-client). Offer on the table:
  vendor the real HereBeDragons-Pins + a Libs/ gate exclusion if the owner
  wants the library despite the tradeoffs.
- v0.9.5 (2026-11-06, private beta): MINIMAP BLIPS - where the rare/elite is
  (owner ask). Fit & Overlap - category: awareness layer (RUN-C) / Map &
  Minimap. Verdict: ENHANCE the nearby/sighting flow with a RareScanner-style
  minimap pin surface (RUN's own data). New ui/minimap_pins.lua: tier-coloured
  blips ON the minimap (never modifies it) at the spot a notable creature was
  seen - vignette TRUE coords when available, else the player's position at
  ping time. Session-transient (no RUNDB change), current map only, fade after
  10 min, behind the new `minimapPins` option (default on). The placement MATH
  is pure + headless-tested - MinimapPins.project (yard offset -> pixel offset,
  in-range, exact north-up + a rotation branch for rotateMinimap) +
  radiusYards (zoom table) + offsetYards; 5 selftests. Live wiring reads
  zoom/rotation via Guards and refreshes on the firewall ticker (0.1s).
  Fed from Nearby.ping (same position it already computes). client_smoke
  gained the C_Map player-pos/world-size mocks + drives the pin path. Gate:
  compliance + client smoke green, BOTH flavors 282->287/287; both installs
  redeployed; dist/RUN-v0.9.5 zip built. FIELD-WATCH: (1) blip placement on a
  ROTATING minimap - flip FACING_SIGN in ui/minimap_pins.lua if mirrored;
  (2) indoor radius uses the outdoor table (direction right, distance a touch
  off indoors).
- v0.9.4 (2026-11-06, private beta): THE SHARED SKIN - depth, not flat (owner:
  the UI looks flat; best tool to enhance it?). Decision: WoW-native shared
  skin, no custom art, applied to ALL frames at once. New ui/skin.lua: one
  helper every RUN frame routes through - gradient fill (dark top -> darker
  bottom), a soft radial drop-shadow for lift, a thin accent border (retint-
  able per tier), and a top highlight bevel; plus Skin.title (outline + text
  shadow). Cross-flavor-safe gradient: new SetGradient(CreateColor) ->
  SetGradientAlpha fallback -> flat, all pcall-guarded. Applied: ui/panel.lua
  (odds, border retints per tier), ui/window.lua (Ledger + nameplate prompt),
  ui/alert.lua (nearby banner, tier tint now rides the accent border),
  ui/export.lua (replaced the stock dialog art for a consistent dark-gold
  look). Each frame's hand-rolled flat bg/border deleted in favour of the one
  helper (consistency + the branded texture pack can later swap in behind the
  SAME helper, no caller changes). client_smoke mock gained CreateColor so the
  modern gradient path runs; it skins every frame at load. 1 skin selftest.
  Gate: compliance + client smoke green, BOTH flavors 281->282/282; both
  installs redeployed; dist/RUN-v0.9.4 zip built.
- v0.9.3 (2026-11-05, private beta): QUIET IN DUNGEONS & RAIDS. Fit &
  Overlap - category: passive awareness layer (RUN-C). Verdict: ENHANCE the
  ping/alert system. Owner: "turn off RUN notifications in dungeons." RUN is
  the open-world living-enemy layer; a dungeon full of elites is noise, not
  news. New `quietInstances` setting (default ON) + Detect.quietHere()
  (presence-detected IsInInstance 2nd-return kind; mutes in party/raid/pvp/
  arena). Gated: Nearby.ping (banner/alert/sound/mark) and the Deathping
  heard-death pop-up - both suppressed in instances. DATA KEEPS FLOWING: the
  death journal, heard COUNTS, and broadcasts are recorded above the mute;
  tooltips/panel (on-demand, not notifications) still work. Pure
  Detect.notificationsMuted + isInstanceKind with 2 selftests; client_smoke
  drives an in-instance pass. Option "Quiet in dungeons & raids" (uncheck to
  keep pings in instances). Gate: compliance + client smoke green, BOTH
  flavors 279->281/281; both installs redeployed; dist/RUN-v0.9.3 zip built.
- v0.9.2 (2026-11-05, private beta): THE BRIDGE DEEPENS (offense + mitigation)
  + fainter glow. Owner: make the glow more faint; and "as we build Foresight
  our connection should expand in its math." FAINT: one global dial -
  root:SetAlpha(0.5) on the glow overlay (still additive/see-through, now
  lighter). THE CONNECTION GROWS (the real work): the bridge is now a GROWTH
  SURFACE - Foresight exposes more, RUN reads it defensively, odds deepen with
  no lockstep. Foresight v0.56.0 (API v1->v2): GetCombatProfile() adds `dps`
  (BridgeAPI.estimateDPS - white-swing + AP + spell-power; Foresight's sim can
  refine later), profileFrom now a named `fields` table so new fields append
  cleanly. RUN v0.9.2: Bridge.validProfile accepts dps; Odds.readiness now
  folds in MITIGATION (armor DR + dodge/parry avoidance -> effective health)
  AND prefers Foresight's `dps` for offense (raw AP+spellpower fallback) -
  each field read defensively so future Foresight capability (sustain, burst,
  schools) sharpens the odds automatically. Still bounded [0.5,1.6], still
  (p). 2 new RUN selftests (mitigation lift, dps offense) + 1 Foresight
  (estimateDPS). Gate: RUN 277->279/279 BOTH flavors + client smoke; Foresight
  308/263 BOTH flavors. Both addons redeployed to both installs; dist/RUN-
  v0.9.2 zip built.
- v0.9.1 (2026-11-05, private beta): GLOW = LIGHT SEE-THROUGH (fix for the
  v0.9.0 overcorrection). Field: v0.9.0's opacity bump added a solid
  alpha-BLEND backing that rendered the tier highlight as an OPAQUE disc you
  could not see through. Owner: "we should be able to see through - a light
  glow." Fix: removed every BLEND backing + the helper; all glow effects are
  ADDITIVE again (translucent by construction - adds light, never blocks),
  with moderate alphas (subtle pulse 0.45-0.75, fills ~0.6) so it is present
  but you see the world and your character through it. Only ui/glow.lua
  builders touched. Gate green BOTH flavors 277/277; both installs
  redeployed; dist/RUN-v0.9.1 zip built. Opacity is an easy dial if it needs
  nudging either way.
- v0.9.0 (2026-11-05, private beta): THE FORESIGHT BRIDGE GOES LIVE (W6a) +
  tier-highlight opacity. Owner: build the bridge (no T&Cs impact, stacks as
  addons do) + make the tier highlight more opaque. Fit & Overlap - category:
  RUN-C odds + the synergy play. Verdict: the W6 bridge, built for real.
  ARCHITECTURE (Two Laws): Foresight exposes CHARACTER data, RUN owns the
  ODDS - so the old GetDangerVerdict(npcID) contract (wrong: Foresight does
  not know creatures) is REPLACED by GetCombatProfile(). FORESIGHT SIDE
  (v0.55.0, separate repo, additive): new core/bridge_api.lua publishes
  _G.ForesightAPI.GetCombatProfile() -> { level, stamina, attackPower,
  spellPower, armor, avoidancePct, maxHealth, class } from the live sheet via
  its Guards (secret/missing -> 0); 2 TOC lines + version trio + 2 selftests;
  Foresight gate 262/262. RUN SIDE: core/bridge.lua rewritten to
  combatProfile() (validated - untrusted sibling input); model/odds.lua gains
  Odds.readiness(profile) - a BOUNDED [0.5,1.6] character-readiness multiplier
  (survivability + offense vs presumed per-level baselines) that replaces the
  secret-live-HP term, so Foresight CLEARS the "advice degraded" case and
  sharpens the odds; panel shows "(via Foresight)". Pure, (p) still honest.
  Addon-to-addon only: nothing leaves the client, no backend, no T&Cs/privacy
  touch. Degrades silently without Foresight (coarse model). OPACITY: glow
  effects gained a solid alpha-blended tier-coloured BACKING (reads over
  bright terrain, not just additive wash) + higher pulse floors; panel tier
  border 0.85 -> 1.0. 8 new RUN selftests. Gate: compliance + client smoke
  green, BOTH flavors 269->277/277; both addons redeployed to both installs;
  dist/RUN-v0.9.0 zip built. Field: /ra status should read "Foresight bridge:
  connected"; the odds panel no longer says degraded on your PvP realm.
- v0.8.9 (2026-11-05, private beta): HONEST "degraded" copy + diagnosis of
  the Foresight-math question. Owner asked why the odds read "advice
  degraded" with Foresight installed. DIAGNOSIS (no bug): (1) the ForesightAPI
  bridge is NOT built - verified the Foresight repo exposes no ForesightAPI/
  GetDangerVerdict anywhere, so RUN.Bridge.dangerVerdict returns nil and
  Odds.forUnit falls to the coarse model (the W6 synergy play is still
  roadmap). (2) The coarse model factors current HP; on the owner's PvP
  realm the Forever client returns player health as a SECRET value, so RUN
  can't read it and flagged "degraded". But the shown "~X% to win" is
  already the level+classification estimate = the full-health number; only
  the current-HP adjustment was missing. FIX: reword the panel foot from
  "your health is secret here - advice degraded" to "full-health estimate -
  your current HP is hidden here" (honest, not alarming). The real fix (odds
  that don't need RUN to read secret HP) is the Foresight bridge - owner to
  decide whether to prioritize W6. Gate green BOTH flavors 269/269; both
  live installs redeployed; dist/RUN-v0.8.9 zip built.
- v0.8.8 (2026-11-05, private beta): ODDS PANEL IS DRAGGABLE + /ra move
  (owner field ask: the "FIGHT" odds readout under the unit frame needs to
  move too). Fit & Overlap - category: passive awareness layer (RUN-C).
  Verdict: ENHANCE ui/panel.lua, same pattern as the v0.8.6 glow. The odds/
  tier panel (RUNOddsPanel) is now click-draggable: SetMovable + firewall-
  wrapped drag handlers save RUNDB.ui.panelPos (type-validated); anchor()
  uses the saved pos else the Blizzard target frame else centre-left; mouse
  is on only while unlocked. New panelLocked setting (default locked) +
  "Lock odds panel position" in the options. NEW UNIFIED /ra move command:
  one arrange mode that unlocks BOTH the rank glow and the odds panel to
  drag, then locks both - the single gesture to position RUN's overlays.
  DRY: the position validator is now shared core RUN.validAnchorPos (init.
  lua, selftested); Glow.validGlowPos delegates to it; added Glow.refresh
  for the immediate re-eval. client_smoke.py drives the panel refresh +
  /ra move. Gate: compliance + client smoke green, BOTH flavors 268->269/
  269; both live installs redeployed; dist/RUN-v0.8.8 zip built. Field:
  /ra move, target an enemy, drag the FIGHT panel + the glow, /ra move to
  lock.
- v0.8.7 (2026-11-05, private beta): LEDGER FITS ITS CONTENT (owner field
  bug: the Minimap-button option extended PAST the window frame). Fit &
  Overlap - category: passive awareness layer (RUN-C). Verdict: ENHANCE
  ui/window.lua. Cause: the Account Ledger height was HARD-CODED (588) and
  the checkboxes bottom-anchored at a fixed offset; adding the three v0.8.6
  glow toggles pushed the 11th row (Minimap button) 10px below the frame.
  Fix: the home page is now SELF-SIZING - the options block flows directly
  under the ledger text (optHeader anchored to the stats FontString's
  bottom; checkboxes grow from there), and Window.refresh computes the frame
  height from the live ledger text height (GetStringHeight, with a
  line-count floor for the not-yet-shown case) + the option-block height.
  Result: every toggle is inside the frame no matter how many we add, AND
  the dead gap that showed when the ledger was sparse is gone (window fits
  exactly). Heard page keeps its fixed height. client_smoke.py now drives
  Window.refresh + the page toggle. Gate: compliance + client smoke green,
  BOTH flavors 268/268; both live installs redeployed; dist/RUN-v0.8.7 zip
  built.
- v0.8.6 (2026-11-05, private beta): GLOW = FREE OVERLAY + normal opt-out
  (owner field feedback on ConsolePort). Fit & Overlap - category: passive
  awareness layer (RUN-C). Verdict: ENHANCE ui/glow.lua + settings.
  PROBLEM (screenshot): the glow hard-anchored to Blizzard's TargetFrame;
  on a custom unit-frame UI (ConsolePort hides/moves it) it rendered at the
  stock frame's vanilla spot (center, on the player) at BACKGROUND strata
  (behind everything). FIX: the glow is now a FREE, user-positioned overlay
  - never anchors into a Blizzard frame; HIGH strata (never behind standard
  frames); draggable + lockable (new glowLocked setting, default locked;
  /ra glow toggles; unlocked shows a labelled placeholder you drag;
  position saved per char in RUNDB.ui.glowPos, type-validated to the 9 real
  anchors). Drag handlers routed through the firewall (safeCall). Ask 2:
  new markNormal setting (default on) + pure Glow.markable - turning it off
  suppresses the overlay on NORMAL-classification enemies entirely while
  DEATHS ARE STILL TRACKED (attribution is independent; the gate is
  display-only). 3 new selftests (markable gate, validGlowPos accept/reject,
  + existing). client_smoke.py extended to drive the normal-gate + unlocked
  + /ra glow paths. Gate: compliance + client smoke green, BOTH flavors
  266->268/268; both live installs redeployed; dist/RUN-v0.8.6 zip built.
  Field: /ra glow to place it over your ConsolePort target frame, /ra glow
  to lock.
- v0.8.5 (2026-11-05, private beta): THE RANK EFFECTS LADDER. Fit &
  Overlap - category: passive awareness layer (RUN-C). Verdict: ENHANCE
  ui/glow.lua (the v0.8.3 single two-ring halo) into a VOCABULARY of
  rank-escalating effects, per the owner's reference palette. Owner
  decisions (2026-11-05): (a) effects ESCALATE across rank bands, not a
  picker and not 1:1 - tier 1-2 subtle soft halo, 3-4 aura (ringed glow),
  5-6 reticle (ticked ring), 7 orbit (horizontal ellipse), 8 ripple
  (concentric outward pulse), 9 brackets (locked-on corners), 10 sigil
  (counter-rotating rings + twinkling sparkles); (b) target frame ONLY
  (nameplate surface deferred - Beam + Beacon held back for it). Tint stays
  Notoriety.colorFor (ember->blood), retinted live as kills land mid-fight.
  Built RUN-native: OWN frames anchored around (never touching) TargetFrame
  - taint law intact, a silver elite keeps its dragon; from ONLY
  always-present textures (WHITE8X8 + portrait soft-mask + cooldown star)
  and ONLY Rotation+Alpha animations (the Scale-anim API drifted between
  Classic and modern - avoided on purpose); effects built lazily + cached,
  all re-checks on the firewall ticker. New pure maps effectForTier +
  ringPoint, 3 new selftests (escalation table, ring geometry, + existing
  shouldGlow). client_smoke.py extended to SWEEP all 7 effect builders
  (every band constructs + the switch logic runs) - green both flavors.
  Gate: compliance green, client smoke green, BOTH flavors 266/266; both
  live installs redeployed; dist/RUN-v0.8.5 zip built. FIELD-WATCH: confirm
  the 3 textures render (no green squares) on Classic Era + Forever - any
  miss is a one-line swap of the SOFT/STAR/SHARP constants in ui/glow.lua.
- v0.8.4 (2026-11-04, private beta): THE FIREWALL - never conflict with the
  game (owner directive after the launch-day crash). INCIDENT: first login
  on the live build crashed ~14s into a packed starter zone - client dump
  = ERROR #8 Out of Memory with the SYSTEM at 94% RAM (1.7G free, low page
  file) and <LuaErrors> 1; on relog the client disabled RUN (newest addon).
  Both RUN 0.8.3 + Foresight 0.54.0 had loaded; same Interface 16001, so
  NOT an out-of-date disable. Diagnosis: all RUN.on event handlers were
  already pcall-wrapped (the hub) and the three CLEU buffers capped - but
  the raw per-file OnUpdate tickers (glow, plates, alert) and the tooltip
  hook were UNGUARDED, so a live-client API edge could error every frame
  into a client already at its memory ceiling. FIX (incident-to-gate, fix
  the class): new core/safety.lua firewall - RUN.safeCall (pcall + bounded
  error ring + swallow, never rethrow), RUN.ticker (ONE shared guarded
  throttled OnUpdate every periodic job routes through), Safety.dispatch
  (pure, headless-tested throttle). Refactored glow/plates/alert off raw
  tickers onto RUN.ticker; tooltip inject now wrapped in safeInject. Memory:
  Nearby.pruneSeen caps the one unbounded table (`seen` cooldown map) via a
  60s prune job. /ra diag now prints "firewall: N RUN errors swallowed" +
  the last one (0 = all-clear; field errors are now visible without a
  crash). 12 new selftests (safeCall swallow/passthrough, ring bound,
  dispatch throttle, prune). PLUS the two things that make the error
  FINDABLE, not just survivable: (1) pipeline/client_smoke.py - a
  client-path harness mocking the WoW API (incl. a faithful secret-value
  sentinel that errors on compare/concat like live Forever), that LOADS the
  client code the pure gate skips and drives the full lifecycle (login,
  world, nameplates, target, CLEU, tickers, tooltip) in an open AND a
  restricted/secret pass with a notorious target + expansiveStats on - now
  a REQUIRED gate step (closes the "zero client coverage" gap). GREEN both
  flavors, so the common + secret paths are proven robust; the exact launch
  line is a narrower edge the dump's C++-only trace cannot name. (2) the
  firewall PERSISTS swallowed errors to RUNDB.safetyLog (additive, capped
  25, no PII) - a black-box recorder, so the precise error is recoverable
  from SavedVariables after play; /ra errors dumps it in game, /ra diag
  shows the count. 14 new selftests total. Gate: compliance green, BOTH
  flavors 251->264/264 + client smoke; both live installs redeployed;
  dist/RUN-v0.8.4 zip built. Owner action: re-enable RUN in the AddOns
  list, /reload, play ~15 min, then /ra errors (or send RUN.lua) to pin the
  exact line before the Curse push - the firewall makes it deploy-safe
  either way.
- 2026-11-04 (infra - no addon logic change): FOREVER LAUNCH-DAY BUILD
  VERIFY. WoW: Forever went live and patched 70685 -> 1.60.1.70790 (era
  unchanged 1.15.9.70576). Re-verified against the launch build: Interface
  16001 STILL CORRECT (whole 1.60.1 line maps to 16001, cross-checked
  online; the hotfix bump is not an API patch - RUN's presence-detection
  unaffected, no TOC change). DB2 re-check on 70790: still an 11 KB
  hotfix stub, 0 rares - the server-side-names verdict holds. gen_rares.py
  DEFAULT_BUILD -> 70790; rares.lua header re-stamped (table unchanged:
  empty); both live installs redeployed (v0.8.3, gate 251/251). No RUNDB
  in Forever yet - the W2 Forever field pass (login-banner interface
  confirm first) still outstanding.
- 2026-11-03 (infra): pipeline/package.py - the release zipper (gate-then-
  zip, RUN/ at zip root, one file both flavors, prints the CF upload
  reminders). dist/RUN-v0.8.3-forever-and-era.zip built for the CF project
  creation; cards+screenshots gathered in marketing/curseforge/. No new
  git: the local repo stays the one canonical home; CF updates are manual
  owner-gated uploads (package -> upload -> tag both game versions ->
  changelog from the SPRINTS entry).
- v0.8.3 (2026-11-03, private beta): THE NOTORIETY GLOW + the CurseForge
  kit. Fit & Overlap - category: passive awareness layer (RUN-C). Verdict:
  ENHANCE the tier-presentation family (panel.lua tier frames, tooltip
  ranks) with the owner-asked "expands, never modifies" target-frame
  treatment. New ui/glow.lua (both TOCs, mirror law): two additive rings
  anchored around Blizzard's TargetFrame rect - OWN frame on UIParent at
  BACKGROUND strata, never parented, no keys written, stock art untouched
  (a silver elite's dragon stays Blizzard's); tint = Notoriety.colorFor
  verbatim (the ember -> blood ramp IS the asked "light red/orange hue by
  tier"), lit for any hostile living non-player target at tier >= 1;
  re-evaluates on PLAYER_TARGET_CHANGED + a 1s ticker (mid-fight tier
  rises, target death, toggle). New `tierGlow` setting (default on,
  Ledger + ESC surfaced). Presence-guarded TargetFrame (hidden/absent -
  e.g. ConsolePort - degrades silently; field-watch item). 5 new
  selftests. MARKETING: `marketing/curseforge/` - paste-ready LISTING.md
  (name candidates + recommendation, nemesis-inspiration framing, honest
  Foresight pairing callout - bridge probed, API not yet exposed; no
  live-leaderboard promises pre-W3) + the 4 in-game screenshots named and
  captioned. Gate: compliance green, BOTH flavors selftest 251/251;
  deployed to both live installs.
- 2026-11-03 (infra + review - no addon logic change): THE DB2 RE-CHECK +
  launch-readiness review. Creature.db2 re-verified against BOTH live
  builds via the wago.tools scrape: Forever 70685 = 184-row hotfix stub
  (all Classification 0, names blank), era 70576 = effectively empty - the
  RUN-B hotfix-sparse verdict HOLDS on live; sightings harvest + overrides
  remain the only rares sources (evidence now current, was pinned on dead
  beta 70338). gen_rares.py: DEFAULT_BUILD -> 70685, poisoned-cache hint
  on the red path; rares.lua header re-stamped (table unchanged: empty).
  Code review of v0.8.1/v0.8.2/retarget: season partition fail-directions
  verified self-consistent (a misdetected client stamps its own game's
  quest-path flavor - never crosses buckets); plates lifecycle sound
  (ADDED/REMOVED + 1s sweep, pool bounded by plate recycling, silent
  degrade without C_NamePlate); two cosmetic field-watch items logged for
  W2 (badge ignores plate distance-scale; MEDIUM strata may overdraw
  stacked plates). Gate green 246/246 both flavors; both live installs
  redeployed.
- 2026-10-29 (infra - no addon change): FOREVER LAUNCH CLIENT LANDED.
  Live product `wowf` 1.60.1.70685 in `_forever_`; the beta product is
  dead (dropped from .build.info; stranded folder ignored). Verified:
  Forever Interface 16001 and era 11509 both still correct against the
  live versions (1.60.1 / 1.15.9); the `wowf` client loads unsuffixed
  RUN.toc (live Foresight packaging proves it). pipeline/deploy.py
  retargeted `_classic_beta_` -> `_forever_`; RUN v0.8.2 deployed to both
  LIVE installs, gate green 246/246 both flavors. No RUNDB exists anywhere
  yet - the W2 field pass now covers both live games. Queued: re-check the
  Creature.db2 hotfix-sparse verdict (pinned on beta 70338) against live
  70685 via gen_rares.py.
- v0.8.2 (2026-10-22, private beta): QUEST TARGET ON THE PLATE. Fit &
  Overlap - category: passive awareness layer (RUN-C). Verdict: ENHANCE -
  recognition already existed (model/quests.lua matcher + ui/tooltip.lua
  mouseover flag + nearby.lua QUEST TARGET NEARBY banner, all v0.8.0); the
  gap was nothing persistent ON the enemy. New ui/plates.lua (both TOCs,
  mirror law): gold QUEST TARGET tag anchored above a quest-named mob's
  nameplate - own frames on UIParent anchored to the plate, NEVER parented
  (taint law); reuses Quests.isTarget verbatim (no second matcher); 1s
  self-healing sweep covers quest progress unflagging, newly accepted
  quests, deaths, and the new `questPlates` toggle (default on, in the
  Ledger + ESC options via Settings.defs). Presence-detected C_NamePlate
  (degrades silently if absent); display-only; no new data captured or
  stored beyond the type-validated settings flag; not externally reachable.
  5 new selftests (shouldFlag truth table, nil-safe). CONTEXT SHIFT
  (owner): Forever beta ENDED - field work is era-first; Forever gets a
  fresh verification pass at launch (2026-11-04) against the new data set;
  dual-flavor build law unchanged. Gate: compliance green, BOTH flavors
  selftest 246/246.
- v0.8.1 (2026-10-22, private beta): THE ERA PARTITION LOCK - HANDOFF.md
  W0+W1 executed. [W0] RUN_Vanilla.toc Interface 11508 -> 11509 (the era
  build Foresight field-verified going dual-flavor). [W1] platform-aware
  season stamp: new RUN.seasonEra = "c0" constant beside RUN.season in
  core/init.lua (one flip home, two independent game-line calendars);
  Share.season() selects via Share.detectEra - API presence (C_QuestLog.
  GetInfo absent + global GetQuestLogTitle present = era), never version
  numbers; the shape clamp fails PARTITION-LOCAL (era -> "c0", Forever ->
  "s0") so even a bad edit cannot blend the two games' counts; headless
  resolves Forever-side (gate fixtures stay s0). Selftests: era-detection
  truth table, partition prefixes, platform-tag-verbatim stamp, platform-
  aware season flip, in-partition clamp - written to stay green in-game on
  BOTH flavors. Version trio bumped (0.8.1) so the W2 field pass can
  confirm the build from the login banner. Docs synced: ERA.md (11509
  verified, the c0-stamp section, field checklist step 11), SEASONS.md
  (two-line doctrine now live), ECOSYSTEM.md + HANDOFF.md dated shipped
  notes. Gate: compliance green, BOTH flavors selftest 241/241. NEXT: W2
  field verification (owner in game), then owner-gated W3 backend go-live.
- v0.8.0 (2026-10-21, private beta): THE FLEET BUILD - six agents, two waves,
  everything on the board (owner: "build everything"). WAVE 1: [WP-A] Classic
  Era fork - era-aware quest log (presence-detected), RUN_Vanilla.toc 11508,
  dual-TOC gate, era deploy target, docs/ERA.md. [WP-B] crowd backend -
  data/rare-kills-schema.json single-source -> generated addon/rules/web
  mirrors (drift gate in run_tests), /ra share one-link, functions-run
  rareKillsOnWrite (slay tier recompute, k-of-n sighting names, MIN_BUCKET,
  rate limits; EMULATOR 40/40), fetch_counts bake -> notoriety crowd blend;
  marketing repo additive: functions/rareKills.js + rules blocks (rareKills/
  rareKillCounts/giantSlayers/runWaitlist). [WP-C] web - armory "The
  Deadliest" boards (ported title hash), web/run.html waitlist+contribute
  receiver, marketing-site/run.html teaser, privacy RUN section. [WP-E]
  Ledger heard-log browser page, strictTrust, nameplate one-click prompt,
  /ra diag. WAVE 2: [WP-F] guild layer - majorityGuild attribution,
  RUNDB.guildWipes, RWP1 in-guild wipe ping (GUILD-only, frozen format),
  Ledger guild record line. [WP-G] seasons - RUN.season constant through
  every share stamp, pipeline/season_archive.py (non-destructive, dry-run/
  backup/read-back), docs/SEASONS.md doctrine. INTEGRATION: Vanilla TOC sync
  law, devil slays carry snap+mode (server-recomputable), BOM-tolerant TOCs,
  guildWipes init. Gate: compliance green, BOTH flavors selftest 239/239.
  OWNER-GATED to go live: firebase deploy (rules then function), waitlist
  open, season archive execution, era + Forever field verification.
- v0.7.1 (2026-10-19, private beta): THE SIGHTINGS HARVEST + the DB2 verdict.
  Attempted RUN-B via wago.tools Creature.db2 -> PLATFORM FACT: the client
  table is hotfix-sparse (11 KB, zero world creatures; names are server-
  side) - recorded in NOTES §1. Pivot shipped: Detect.recordSighting /
  sightingFor (RUNDB.sightings, account-wide) harvested on every rare+ ping
  (vignette coords when available, else player pos); Deathping.npcName now
  resolves curated -> sighting -> journal -> #id (pure, headless-tested);
  Waypoint.markKnown falls back to sighting coords; heard-death notability
  includes seen rares; nearby banners tier-tinted. Gate: selftest 172/172.
- v0.7.0 (2026-10-19, private beta): TIER FRAMES + THE WAGER + WIPES CORE
  (owner field-confirmed hearing deaths + level-ups before logging off; asks
  shipped: tier unit frames, movable Ledger, working X). Panel rebuilt as the
  NOTORIETY UNIT FRAME: tier-coloured border + TIER badge + earned-title
  line for any titled target (new `tierFrames` toggle, independent of
  expansiveStats); banners now tier-tinted. Ledger fixed: drag anywhere,
  X above the drag layer w/ bigger hitbox, ESC closes (UISpecialFrames).
  RUN-D local core: RISK IT wager (solo, <50%; pure state machine; wins to
  RUNDB.slays + Ledger section + gold banner). RUN-N local core: wipe
  detection (ENCOUNTER_END + 80%-in-20s correlation) -> RUNDB.wipes +
  Ledger total. RUN-B still blocked on a wago.tools DB2 fetch (no creature
  CSV in the Foresight cache). Gate: selftest 168/168 across 24 files.
- v0.6.0 (2026-10-19, private beta): THE NEMESIS UPDATE - Hardcore parity +
  growing enemies, built while the owner was afk (directive: "all of it").
  NOTORIETY (RUN-M core): 10-tier ladder, deterministic earned titles
  ("Sunscale Lashtail 'the Widowmaker'"), soft elites (normal mobs tier 3+
  banner as NOTORIOUS ENEMY NEARBY + tier-coloured tooltips), Most Wanted
  board. SOCIAL LAYER (RUN-I): heardLog journal (FIFO 200), eulogy toggle
  (off), last words (RLW1, rides your death-ping), heard-death banners.
  TRUST (RUN-J core): RDA1 ack echoes + distinct-sender corroboration (k=3
  model). DISCIPLINE (RUN-K): rez stamps, double-fire guard, mode stamped
  per death (hc/pvp/pve). QoL (RUN-L): ESC Settings panel from
  Settings.defs (pcall'd), RVH1 version handshake. TOC now carries the
  product line: "RUN" Immersive Enemy Builder - enhancing the Azeroth we
  know and love. Nemesis research recorded in docs/NOTES.md §7.
  Gate: compliance green across 22 files, selftest 150/150.
- v0.5.0 (2026-10-19, private beta): the ACCOUNT LEDGER + minimap button.
  `ui/window.lua`: movable window - "What killed us" (account-wide top
  killers w/ counts + last victim), recent deaths (character-stamped),
  totals (recorded + heard), and the OPTIONS menu: every toggle as a
  checkbox (11 keys incl. new `minimapButton`). `ui/minimap.lua`: standard
  ring button (drag-to-move, angle persisted in RUNDB.ui), click opens the
  Ledger. `/ra log|stats|options` aliases; status now shows the death-ping
  channel state (joined/not). Gate: selftest 116/116.
- v0.4.0 (2026-10-19, private beta): QUEST TARGETS + diagnostics + account-wide
  polish. (1) `model/quests.lua`: reads the player's own quest-log monster
  objectives (debounced on QUEST_LOG_UPDATE), extracts EXACT mob names from
  the "X slain: n/m" shape (boundary-prefix fallback for other formats);
  quest-named enemies (the Bruuz case) get a gold "Quest target - <quest>"
  tooltip line and ping as QUEST TARGET NEARBY regardless of classification
  (`pingQuest`, default on; quest gate outranks tier gates). (2) Panel
  diagnostics after the field report that expansiveStats "did nothing":
  showFor errors now captured to Panel.lastErr (surfaced in status), and
  `/ra panel` force-shows a dummy card to split frame-render vs data-path
  failures. (3) Account-wide confirmed: RUNDB is account-level SavedVariables
  by construction - deaths/ranks already stack across alts; journal entries
  now stamp the character name. Field confirms this session: attribution
  fallback worked (Sunscale Screecher named). Gate: selftest 108/108.
- v0.3.1 (2026-10-19, private beta): TIERED nearby pings (owner ask: all-enemy
  sensing for testability + per-group options). `Detect.tierOf` groups
  classifications - normal/trivial/minus = "normal", elite = "elite",
  rare/rareelite/worldboss = "unique"; per-tier toggles `pingNormal` (OFF by
  default), `pingElite` (on), `pingUnique` (on) under the `nearbyPing` master;
  banner titles per classification (ENEMY/ELITE/RARE/RARE ELITE/BOSS NEARBY);
  nameplate handler now senses ANY hostile and lets the tier gates decide.
  Gate: compliance green, selftest 92/92.
- v0.3.0 (2026-10-19, private beta): the "alive world" update - both pings.
  (1) RARE-NEARBY ping: NAME_PLATE_UNIT_ADDED (+ C_VignetteInfo wired
  defensively, true coords when it fires) -> banner + raid-warning sound +
  kill-rank line + auto-mark; once per creature, 10-min cooldown; nameplates-
  off nudge at login. (2) P2P DEATH-PING (Hardcore pattern, creature-centric,
  NO player names): auto-broadcast on creature death over temp channel
  "rundeathping" + GUILD via C_ChatInfo addon messages; strict decode +
  Fletcher16 (arithmetic - 5.1 law) + per-sender rate limit (5/hr) + dedupe;
  heard counts persist in RUNDB.heard and feed the SAME rank tiers as your
  own journal ("Elite - Deadly (killed you 2x + 3 heard)"). TRUST MODEL
  (recorded): live "heard" counts are session flavour, deliberately separate
  from the future server-verified crowd count; full k-of-n deferred to the
  Firebase phase. New settings: nearbyPing (on), shareDeaths (on, opt-out).
  Gate: compliance green across 16 files, selftest 77/77.
- v0.2.0 (2026-10-19, private beta): passive-first redesign. Always-on
  tooltip flags (classification + kill-earned danger rank via
  `ui/tooltip.lua`, TooltipDataProcessor w/ classic HookScript fallback);
  "Expansive Enemy Stats" option gates the win-chance tooltip line + the
  odds panel; auto-mark centralized (`Waypoint.autoMarkFor`, once per
  creature). Gate: compliance green, selftest 61/61.
- v0.1.0 (2026-10-19, private beta): RUN-A + RUN-C core. Gate: compliance
  green, selftest 44/44. Distributed as a direct zip to testers only.
