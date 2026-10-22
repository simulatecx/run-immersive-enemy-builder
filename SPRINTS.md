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
