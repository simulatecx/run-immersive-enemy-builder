# RUN - the remaining board, planned for a multi-agent build

Owner directive 2026-10-21: plan everything remaining, then spin up multiple
agents to build it all. Hardcore Classic has a LIVE population TODAY, so the
classic fork is elevated to the front of the queue.

Baseline at planning: v0.7.1, gate 172/172 across 24 files, repo
`C:\Users\BradsPC_2022\orca\workspaces\overlay\run-forever` (git). Foresight
repo (shared Firebase surface only): `...\overlay\marketing`. Era install for
fork testing: `D:\Games\World of Warcraft\_classic_era_\Interface\AddOns\`
(the Hardcore addon is there - same client the fork targets).

## Laws that bind every agent

1. Gate green before any commit: `python pipeline/run_tests.py` (compliance +
   headless selftest). New logic ships WITH its selftest checks.
2. House laws: display-and-advice only; Lua 5.1 dialect; secrets through
   Guards; no PII (realm/account/guild/real names FORBIDDEN in any payload);
   generated data regenerates; confidence tags on presumed facts.
3. File ownership below is EXCLUSIVE per wave - an agent never edits another
   package's files. Shared-file edits (settings.lua defs, window.lua,
   SPRINTS.md shipped list) happen only in the package that OWNS them that
   wave; others list needs in their report for integration.
4. Wire formats are FROZEN contracts: RDP1 (death ping), RDA1 (ack), RLW1
   (last words), RVH1 (version hello). New messages get NEW tags (e.g. RWP1)
   and strict decode + selftests, never changes to existing tags.
5. Foresight-repo touches are ADDITIVE ONLY (new files, appended rules blocks,
   one require line, one new web section) - never its gate, addon, packaging.
6. Each agent's final report: what shipped, gate count, files touched,
   anything deferred, and the SPRINTS/README lines to merge.

## Wave 1 (parallel - no file overlap)

### WP-A: Hardcore Classic fork (RUN-O) - PRIORITY
The same social death layer where the audience already is.
- `RUN/core/platform.lua` (NEW): flavor detection (interface/WOW_PROJECT_ID)
  + shims. Known era deltas: quest-log API is the OLD shape (GetQuestLogTitle
  by index; C_QuestLog exists but GetInfo does not - shim quests.lua through
  the adapter), TooltipDataProcessor absent (HookScript fallback already in),
  C_VignetteInfo absent (already optional), modern Settings API absent
  (options.lua already pcall'd), C_GameRules.IsHardcoreActive EXISTS on era
  HC realms. Verify each with presence checks, degrade silently.
- `RUN/RUN_Vanilla.toc` (NEW): Interface 11508 (confirm current era build),
  same file list. Packager multi-TOC convention.
- `pipeline/run_tests.py`: gate loads BOTH TOCs (shared file list is fine);
  `pipeline/deploy.py`: second target, the era install above.
- AC: era zip deploys to the classic install; /ra selftest green in era;
  detection + tooltip flags + death journal + death-ping channel work on an
  HC realm; quests shim resolves a live quest target.
- OWNS: core/platform.lua, RUN_Vanilla.toc, model/quests.lua, pipeline/*.

### WP-B: Crowd backend (RUN-E + Devil crowd post + sightings aggregation)
The share-link -> Firebase -> bake loop, per the S35 handoff spec (plans file
+ docs/NOTES.md §6 contracts).
- `data/rare-kills-schema.json` (NEW, single source): kinds death | slay |
  sighting | wipe; fields npc, mode (pve/pvp/hc), bracket, zone(mapID),
  season, clientId, sum, snap (slay), name+classification (sighting only -
  game data), handle/armory under named==true. realm/guild/real-name
  FORBIDDEN.
- `pipeline/gen_crowd_schema.py` (NEW, ported pattern): emits
  `RUN/data/generated/crowd_schema.lua` + `firebase/rareKills.rules.partial`
  (validRareKill between generated markers); `--check` drift gate wired into
  run_tests.
- `RUN/core/share.lua` (NEW): allow-listed payload builder + `/ra share`
  one-link (#d= fragment; copyable editbox via ui/export.lua) covering
  deaths, slays, sightings, wipes since last share.
- `functions-run/index.js` (NEW, canonical): rareKillsOnWrite - plausibility
  (known npc or sighted-by-k), server-recomputed slay tier from snap,
  per-clientId rate limits, MIN_BUCKET=5 suppression; rollups:
  rareKillCounts (npc x mode x season), giantSlayers (opt-in named),
  sightings k-of-n (same npc+name from 3+ clientIds -> candidate bake).
- Foresight repo ADDITIVE: `functions/rareKills.js` + one require line in
  functions/index.js; two match blocks appended in web/firestore.rules
  before the final deny. Scoped deploys. Emulator tests for rules + function.
- `pipeline/fetch_counts.py` (NEW): bake public counts ->
  `RUN/data/generated/crowd_counts.lua` (empty-safe); Notoriety.describe
  blends it as the third source (label: server-verified).
- AC: emulator green (shape accept/reject, PII rejected, recompute, caps);
  a share link round-trips to rareKillCounts; bake file loads headless.
- OWNS: run-forever share/schema/gen/functions-run/firebase/fetch_counts,
  model/notoriety.lua (blend), ui/export.lua; marketing repo
  functions/* + web/firestore.rules (rules ONLY).

### WP-C: Web ladder + waitlist (RUN-F + RUN-H)
- Armory (marketing repo, additive): "Deadliest Creatures" (notoriety tiers,
  titles via the same deterministic hash ported to JS) + "Giant Slayers"
  sections in web/app.js + web/index.html reading rareKillCounts /
  giantSlayers; season/mode filters; esc() every crowd string;
  graceful-empty; mobile baseline.
- Waitlist: `marketing-site/run.html` - the RUN teaser in the house brand
  ("RUN" Immersive Enemy Builder; Nemesis pitch, tier-frame mock, the
  slogan) + email signup -> write-only `waitlist` collection (shape-locked
  rules appended; email = PII: explicit consent line, purpose-bound copy,
  and the privacy page updated IN THE SAME CHANGE).
- AC: 0 console errors; ladders render with fixture data; waitlist write
  passes rules emulator; privacy page names the waitlist data.
- OWNS: marketing repo web/app.js, web/index.html, web/privacy.html,
  marketing-site/run.html. (Rules additions for waitlist: hand the block to
  WP-B's report for a single rules apply - do NOT edit firestore.rules.)

### WP-E: Social polish (RUN-I/J/L remainder + field bugs)
- Ledger HEARD-LOG BROWSER: a second page/tab in the window (toggle button):
  scrollable recent heard entries - creature (titled), bracket, time,
  corroboration mark, last words, sender when eulogy on.
- `strictTrust` setting (default off; the launch flag): when on, only
  corroborated heard entries feed PUBLICLY-SHOWN counts (ranks still blend
  everything locally with an "unverified" suffix).
- Nameplate one-click prompt: on login with nameplates off, a small popup
  with an Enable button (user click = allowed CVar set) instead of only the
  chat tip.
- ESC panel + expansiveStats verification hooks: keep Panel.lastErr surfacing;
  add `/ra diag` printing panel/tooltip/options registration state in one go.
- Optional LDB broker (pcall'd, only if trivial).
- AC: browser page scrolls 200 entries; strictTrust honest labels; prompt
  sets CVar only on click; selftests for the pure parts.
- OWNS: ui/window.lua, ui/minimap.lua, core/settings.lua, core/init.lua,
  model/deathping.lua (display paths only - wire formats frozen).

## Wave 2 (after wave 1 merges)

### WP-F: Guild & raid layer (RUN-N remainder)
- Guild attribution: raid-majority guild via roster GetGuildInfo; local
  "Guild G has wiped N times to X" ledger (new Ledger line - window.lua is
  free in wave 2); in-guild wipe ping RWP1 (GUILD channel ONLY, new tag,
  strict decode, rate-limited). Crowd guild ladders stay GATED until the
  opt-in guild-tag tier (privacy law).
### WP-G: Seasons (RUN-G)
- season tag already in the WP-B schema; admin archive script (dry-run ->
  backup -> flip pointer -> read-back, safe-data-ops) + ladder season label
  + addon season display. Fires at Hardcore kickoff (~2026-12-04 Forever;
  the classic fork may want its own season naming).
### Integration pass
- Merge reports, reconcile SPRINTS/README/NOTES, bump version, full gate,
  deploy both flavors, rebuild zips, update memory.

## Owner-gated (not agent work)
- Firebase deploys to the LIVE wow-foresight project (agents prepare + test
  on emulator; owner or a supervised session runs the scoped deploys).
- Waitlist go-live + the CurseForge publish decision (waitlist-first stands).
- In-game field verification on Forever beta + an era HC realm.
