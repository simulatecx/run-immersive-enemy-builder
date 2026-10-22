# RUN on Classic Era - the Hardcore fork (WP-A)

RUN's primary target is WoW: Forever (mainline 12.x API, Interface 16001,
launches 2026-11-04). Hardcore Classic Era (1.15.x) has a live population
TODAY, so the SAME addon folder also ships an era TOC: the client picks
`RUN_Vanilla.toc` on Classic Era and `RUN.toc` everywhere else (multi-TOC
flavor-suffix convention). One codebase, two flavors - every divergence is
handled by API PRESENCE checks at runtime, never by version sniffing.

## Interface number - 11509 (Foresight-verified)

`RUN_Vanilla.toc` declares `## Interface: 11509` - the 1.15.x build number
Foresight verified in the field when it went dual-flavor (v0.53.0; RUN
aligned 2026-10-22, work item W0). If a future era patch bumps the build and
the client flags RUN as out-of-date, tick "Load out of date AddOns" for the
session, read the live number via
`/run print((select(4, GetBuildInfo())))`, and update the `## Interface:`
line to match. Everything else is unaffected - the gate loads the file list,
not the interface number.

## The real API delta: the quest log

The only confirmed structural difference is the quest-log read in
`RUN/model/quests.lua`:

| Capability | Forever / mainline | Classic Era 1.15.x |
| --- | --- | --- |
| Entry count | `C_QuestLog.GetNumQuestLogEntries()` | global `GetNumQuestLogEntries()` (first return; counts headers too) |
| Entry info | `C_QuestLog.GetInfo(index)` -> info table | global `GetQuestLogTitle(index)` -> `title, level, suggestedGroup, isHeader, isCollapsed, isComplete, frequency, questID, ...` |
| Objectives | `C_QuestLog.GetQuestObjectives(questID)` | SAME - exists on era |

`quests.lua` handles this inline: era is detected by presence
(`C_QuestLog.GetInfo` missing AND `GetQuestLogTitle` present), each path
normalizes its shape, and BOTH feed the same pure helpers
(`Quests.normalizeEraEntry`, `Quests.monsterObjectives`) into the unchanged
pure matcher (`Quests.setTargets` / `Quests.isTarget`). The helpers are
selftested headless via `RUN.selftestChecks`, so the gate covers the era
parse path on every run. `isHeader` tolerates both `1/nil` (old clients) and
booleans (1.15.x).

## The season stamp: era shares carry `c0`, never `s0`

npcIDs are identical across the two games, so crowd counts are partitioned by
the season tag's prefix: Forever stamps `RUN.season` (`s0`, `s1`, ...), era
stamps `RUN.seasonEra` (`c0`, `c1`, ...) - both constants live in
`core/init.lua`, and `Share.season()` (`core/share.lua`) selects between them
with the same API-presence signal as the quest log (`C_QuestLog.GetInfo`
absent + global `GetQuestLogTitle` present). The shape clamp fails WITHIN its
partition (`c0` on era), so a bad edit can never stamp one game's counts into
the other's buckets. Headless resolves to the Forever side (`s0`), keeping
gate fixtures stable; the selection, the clamp, and the detection truth table
are selftested on every gate run. Full doctrine: docs/SEASONS.md.

## Already era-safe by construction (presence checks in place)

- Tooltips: `ui/tooltip.lua` uses `TooltipDataProcessor.AddTooltipPostCall`
  when present, else falls back to `GameTooltip:HookScript("OnTooltipSetUnit")`
  - the era path.
- Vignettes: `model/nearby.lua` checks `C_VignetteInfo` presence per call;
  era rares simply arrive via the reliable trio (nameplate / target /
  mouseover), which all exist on era.
- Options panel: `ui/options.lua` requires the modern `Settings` API shapes
  and wraps the whole registration in pcall; when absent the Account Ledger
  (minimap button / `/ra log`) remains the canonical options surface.
- Hardcore detection: `model/attribution.lua` pcalls
  `C_GameRules.IsHardcoreActive` behind a presence check - this API EXISTS on
  era HC realms (same mechanism the Forever HC season will use).
- Death-ping transport: `model/deathping.lua` pcalls `JoinTemporaryChannel`
  (exists on era), `C_ChatInfo.RegisterAddonMessagePrefix` and
  `C_ChatInfo.SendAddonMessage` behind presence checks.
- Everything else (CLEU, nameplate events, `UnitClassification`,
  `UnitGUID` npcID parsing, `C_Timer`) exists on era; all possibly-missing or
  possibly-secret reads already route through `core/guards.lua`.

## Flavor plumbing

- `pipeline/run_tests.py` gates BOTH TOCs: each file list loads fresh in its
  own Lua runtime, runs the full selftest, and has its `## Version` checked
  against `RUN.version`. A version bump must touch `RUN.toc`,
  `RUN_Vanilla.toc`, and `core/init.lua` together or the gate goes red.
- Any file added to `RUN.toc` must be mirrored into `RUN_Vanilla.toc` (same
  list, same order) unless it is genuinely flavor-specific.
- `pipeline/deploy.py` default targets cover both installs: the Forever beta
  (`_classic_beta_`) and Classic Era (`_classic_era_`). The copy is the whole
  `RUN/` folder including both TOCs; the client picks its own.

## Era HC field-test checklist (10 steps, first era login)

1. Load check: log an era HC character, confirm RUN loads (login banner
   prints). If flagged out-of-date, verify the interface number per above.
2. `/ra selftest` - expect all green, same count as the headless gate.
3. Hardcore detection: `/run print(C_GameRules.IsHardcoreActive())` - expect
   `true` on an HC realm (this drives death `mode = "hc"` classification).
4. Channel join: wait ~15s after login, then `/ra status` - expect
   "death-ping channel: joined (rundeathping)".
5. Tooltip flags: mouse over a rare or elite - expect the flag line
   (classification + notoriety) on the tooltip via the HookScript fallback.
6. Mouseover rank: mouse over any mob that has killed you before - expect
   the kill-rank line from the journal.
7. Quest target via the ERA API path: accept any kill quest ("X slain: 0/N"),
   wait a few seconds, then `/ra status` - expect "quest targets tracked" > 0;
   mouse over the quest mob - expect the QUEST TARGET flag.
8. Nearby ping: approach an elite/rare with enemy nameplates on - expect the
   banner (tier title) and alert.
9. Death ping end-to-end: with a second account/client (or a guildmate on an
   era realm) in range, die to a creature - expect the peer to hear the ping
   (heard log entry + alert); verify the dedupe/corroboration mark.
10. Death journal: after the death above, `/ra deaths` and the Ledger -
    expect the entry with killer, zone, and HC mode; reload UI and confirm it
    persisted (SavedVariables RUNDB).
11. Season stamp: with at least one journal entry recorded, `/ra share` -
    the link's payload must carry the era tag: search the URL text for `c0`
    (appears on the envelope and every event) and confirm `s0` appears
    nowhere. Do NOT paste the link anywhere unless you mean to contribute
    the data.
