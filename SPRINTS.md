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
- ◐ RUN-B rares DB: empty-safe `data/generated/rares.lua` + overrides merge
  SHIPPED; `pipeline/gen_rares.py` (Forever DB2 -> npcID/name/zone/coords) ☐.
- ◐ RUN-C odds panel + waypoint (v0.1.0): coarse logistic model (level delta +
  classification + health, bands over points, always "(p)"), panel anchored
  under TargetFrame (never parented - taint law), mouseover rare preview,
  auto-mark via C_Map.SetUserWaypoint + C_SuperTrack + TomTom. Local death
  journal (CLEU buffer + env codes) shipped ahead of E because it is
  local-only. REMAINING: standalone nearest-threat frame; Foresight bridge
  live test; in-game verify sweep on Forever beta.
- ☐ RUN-D Devil button + Giant Slayers (solo + tier gates; display+record only).
- ☐ RUN-E killcount crowd: `rareKills` schema + one-link share + Cloud Function
  rollup -> `rareKillCounts` (additive on the wow-foresight project), bake-back.
- ☐ RUN-F two-sided web ladder (Deadliest Creatures + Giant Slayers).
- ☐ RUN-G season model + Hardcore-kickoff reset (non-destructive archive).
- ☐ RUN-H waitlist: teaser + signup (owner-led; page on the marketing site;
  any email capture is PII - consent text + privacy policy update ship in the
  same change, per privacy-by-design).

LAUNCH: gated private beta now -> waitlist opens pre-launch; Forever launch
2026-11-04; Hardcore kickoff ~2026-12-04 triggers the RUN-G seasonal reset.

## Shipped

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
