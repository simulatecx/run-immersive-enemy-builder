# QuestieTrace analysis -> RUN's calibration capture (2026-11-10)

Owner: "run the analysis on QuestieTrace - it opts users in for capturing on the
machine; we should take the same approach to improve RUN, then daily we review the
new data since we have 2000 users."

Analyzed from the installed addon (v1.9.2, `_forever_` + `_classic_era_`, by
Logon/TheCrux - the Questie data-collection companion).

## How QuestieTrace does it (the pattern)

1. **A separate, single-purpose companion addon.** Collection isn't buried in
   Questie - installing QuestieTrace is itself a deliberate act. Its TOC says
   plainly: "Data collection addon for Questie" (localized into 9 languages).
2. **Tri-state consent, asked ONCE.** `dataCollectionConsent`: nil = not asked
   (first login shows the dialog), true = capture runs, false = never ask again
   (`/qlt consent` to change your mind). Declining DISCARDS any active capture
   rather than saving it. The dialog is an ADDON-OWNED frame, explicitly not
   Blizzard's StaticPopup - their comment: shared popup lists "can carry addon
   taint into Edit Mode" (independent confirmation of our taint-isolation law).
3. **Local-only by default.** The consent text: "Your data stays on your machine
   unless you choose to export and share it." Capture appends time-stamped event
   streams to SavedVariables; sessions are capped (MAX_SESSIONS=10, oldest
   dropped) so the file can't grow unbounded.
4. **Privacy enforced at TWO layers.** At capture: player GUIDs are classified by
   an explicit prefix allowlist and never persisted; player/guild names are
   redacted from captured text by whole-word, escape-sequence-aware substitution
   (they deliberately do NOT trust `issecretvalue()` as a privacy guard). At
   export: the payload is scrubbed AGAIN (player-GUID observations removed from
   every stream). Belt and braces.
5. **User-driven export.** LibDeflate-compressed string with human-readable
   version markers (`!QuestieTrace:1! ... !End:QuestieTrace:1!` - the WeakAuras
   convention), copied by the user and pasted at questie.dev/trace. The addon
   never networks. "Mark reported" is the only deletion path.
6. **A polite, non-spammy reminder.** The export nudge fires only after >= 1 hour
   played AND while resting at an inn; opening the export window resets the
   clock. No login spam, no interval nagging.
7. **Consent transparency every session**: while enabled, each login prints "your
   gameplay data is being collected locally on this device."

## What RUN already has vs. what it was missing

Already aligned (our existing laws): addon never networks; share is a
user-pasted link; allow-list schema with generated mirrors; no PII forever;
capped journals; season/game partition on everything that leaves the machine.

Missing (what this pattern adds):
- **An explicit consent-gated CAPTURE tier** distinct from the product journals.
  RUN's deaths/slays journals exist to power the player's own ledger; the new
  tier captures data whose purpose is improving RUN itself.
- **The capture that matters: odds calibration.** `Odds.compute` has carried an
  empty-safe "crowd calibration hook (phase E)" since day one. The missing input
  is (predicted win chance, actual outcome) pairs per creature. That is exactly
  the kind of anonymized gameplay observation QuestieTrace collects for Questie's
  database - ours improves the odds curve instead of quest data.
- **The inn-based share reminder** (we had no nudge at all).
- **The daily review loop**: with ~2000 users sharing, fresh aggregates deserve a
  daily digest - which creatures are deadlier than predicted, where the curve is
  miscalibrated, what new notorious creatures emerged.

## RUN's implementation (shipped with this doc)

- `RUN/model/calibration.lua`: tri-state `RUNDB.captureConsent` + owned dialog
  (first login after install), `/ra capture on|off|status`, login transparency
  line, capture of {npc, player level, creature level, classification, predicted
  p, outcome win|death, season} pairs - resolved by pairing the last odds
  assessment of a creature with the kill/death that follows. Capped journal,
  no GUIDs, no names, no positions. Inn-based share reminder (>=1h, resting).
- `calib` event kind in the crowd schema (kinds cap 4 -> 5) -> regenerated
  mirrors (addon Lua + rules partial + web sanitize) -> rides the existing
  `/ra share` link via `Share.eventFromCalib` (re-clamped through
  `Calibration.clampEvent`; the pairing timestamp never leaves the machine),
  capped 30 per share, last in line for the envelope cap.
- Backend (canonical `functions-run/index.js` = deployable
  `functions/rareKills.js`, emulator-tested 51/51): `validCalib` deep-validates
  and RECOMPUTES the predicted odds from pl/cl/cls (the client's claimed p
  stays advisory - server-trust law); per-npc tally gains
  `calib {fights, wins, sumP, sumPc}`; the public `rareKillCounts` doc
  publishes `calib {fights, winPct, predPct}` only at MIN_BUCKET; a per-season
  decile curve doc (`rareKillMeta/calcurve-<season>`) feeds the curve review.
  All additive; k-anonymous throughout.
- `pipeline/review_calibration.py`: the daily digest - share volume (from the
  rate-limit tallies), the season calibration curve (predicted vs actual per
  decile), per-creature gaps (flagged at >=15pts), deadliest creatures. Owner
  gcloud auth = full digest; no auth degrades to the public calib blocks.
  Saved to `pipeline/collected/calib-digest-<date>.md` (gitignored).

## The daily ritual (2000 users)

`python pipeline/review_calibration.py` once a day (or tell the agent "review
RUN data"). It prints/saves a digest; decisions that change the odds curve go
through `data/overrides.lua` + a reviewed commit - data NEVER auto-tunes the
model (the same human-review law as every other crowd input).

## Deploy order (owner-gated, rules-before-code)

The RUN backend surface has NEVER deployed (run.html is 404 today - shares
land nowhere). The calib feature goes live in this order, each step owner-run
from the marketing worktree: (1) firestore RULES (now includes the calib
kind - old clients stay valid, hasOnly allows subsets), (2) FUNCTIONS
(rareKills.js), (3) HOSTING (run.html + run-crowd-schema.js). ONLY THEN tag
RUN v1.1.0 so no client can emit a calib payload the deployed rules would
reject wholesale.
