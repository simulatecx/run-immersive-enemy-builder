# rareKills emulator test fixtures (WP-B)

How to run (needs firebase-tools + Java for the Firestore emulator):

```
cd functions-run && npm install
firebase emulators:start --only firestore,functions \
  --project wow-foresight --config ../firebase/firebase.json
```

`firebase/firebase.json` points rules at the Foresight repo's `web/firestore.rules`
(the ONE ruleset) and functions at this directory. Write the fixtures below into
`rareKills` via the emulator UI/REST as an anonymous-authed client and assert the
rules verdict + the function's rollup output. Never run against live.

Shared valid envelope (the baseline every case mutates):

```json
{
  "v": 1,
  "kinds": ["death", "slay", "sighting", "wipe"],
  "season": "s0",
  "clientId": "00c0ffee00c0ffee",
  "events": [
    { "k": "death", "npc": 448, "mode": "hc", "bracket": 20, "zone": 1429, "season": "s0" },
    { "k": "slay", "npc": 448, "p": 0.2, "snap": { "pLevel": 10, "cLevel": 17, "cls": "rare" }, "mode": "pve", "season": "s0" },
    { "k": "sighting", "npc": 5786, "nm": "Snagglefang", "cls": "rare", "zone": 1413, "season": "s0" },
    { "k": "wipe", "npc": 448, "mode": "pve", "season": "s0" },
    { "k": "wipe", "enc": "Hogger", "mode": "pve", "season": "s0" }
  ]
}
```

(Note `sum` is optional; when present it must equal fletcher16 of the canonical
string `1|s0|5|death:448,slay:448,sighting:5786,wipe:448,wipe:x` - the function
rejects a wrong sum, tolerates an absent one.)

## Rules cases (client writes to /rareKills)

| # | Mutation | Expect |
|---|----------|--------|
| R1 | baseline, signed-in anonymous | ALLOW |
| R2 | unauthenticated | DENY (signedIn) |
| R3 | add top-level `realm: "Stitches"` | DENY (hasOnly) |
| R4 | add top-level `name: "Brad Smith"` | DENY (hasOnly) |
| R5 | `handle: "Bold"` without `named` | DENY (named gate) |
| R6 | `named: true, handle: "Bold"` | ALLOW |
| R7 | `named: false, handle: "Bold"` | DENY (named gate) |
| R8 | `handle` of 25+ chars or with `<>|` chars | DENY (size/matches) |
| R9 | `events: []` | DENY (size >= 1) |
| R10 | 101 events | DENY (size <= 100) |
| R11 | `kinds: ["death","hack"]` | DENY (kinds hasOnly) |
| R12 | `season: "S0!"` | DENY (matches [a-z0-9]+) |
| R13 | client READ of /rareKills/{id} | DENY (write-only) |
| R14 | client WRITE to /rareKillCounts, /giantSlayers, /rareKillMeta | DENY |
| R15 | client READ of /rareKillCounts and /giantSlayers | ALLOW (public rollups) |
| R16 | /runWaitlist create `{email:"a@b.co",consent:true,source:"runpage"}` signed-in | ALLOW |
| R17 | /runWaitlist with `consent:false`, or extra key, or 121-char email | DENY |
| R18 | /runWaitlist client READ | DENY (write-only PII) |
| R19 | regression: /contributions + /feedback writes with their existing valid shapes | ALLOW (unchanged) |

## Function cases (rareKillsOnWrite, observed via emulator Firestore state)

| # | Fixture | Expect |
|---|---------|--------|
| F1 | baseline x1 | `rareKillMeta/tally-448` counts hc=1, wipes=1; `rareKillCounts/448` = `{ low: true, npc: 448, season: "s0" }` (total 1 + wipe 1 < MIN_BUCKET) |
| F2 | baseline x5 (distinct clientIds) | `rareKillCounts/448` publishes `{ counts: { hc: 5 }, total: 5, wipes: 5 }` - suppression lifts at MIN_BUCKET=5 |
| F3 | slay with `snap {pLevel:10, cLevel:17, cls:"rare"}` (recomputed p~0.23; a cLevel of 13 recomputes to ~0.48 = "underdog") + `named:true, handle:"Bold"` | ONE `giantSlayers` doc `{ handle:"Bold", npc:448, pct:23, tier:"giantslayer", season:"s0" }` |
| F4 | same slay but `snap {pLevel:60, cLevel:10, cls:"normal"}` (recomputed p~1) and client-claimed `p: 0.1` | NO giantSlayers doc (recompute >= 0.5 rejects; the claimed p is ignored) |
| F5 | slay without `snap` | NO giantSlayers doc (unverifiable; fail closed) |
| F6 | valid slay, `named` absent | NO giantSlayers doc; death/wipe rollups still apply |
| F7 | sighting of npc 5786 "Snagglefang" from 2 distinct clientIds | tally has the candidate; `rareKillCounts/5786` has NO name |
| F8 | the same from a 3rd distinct clientId | `rareKillCounts/5786` carries `name: "Snagglefang"` (k-of-n = 3) |
| F9 | 3 sightings of DIFFERENT names / same npc, 1 client each | no name published (no candidate reached 3) |
| F10 | 21 baseline submissions, same clientId, same day | 21st raw doc is DELETED, no rollup delta (20/day cap); a submission with NO clientId falls into the shared "anon" bucket |
| F11 | envelope with `sum: 1` (wrong) | rejected, no rollup |
| F12 | event with extra key `{ ..., "who": "Alta" }` | that EVENT is skipped; the rest of the batch still rolls up |
| F13 | wipe with both `npc` and `enc` | event skipped (exactly-one law) |
| F14 | enc wipe x5 "Hogger" | `rareKillCounts/enc:hogger` publishes `{ enc: "Hogger", wipes: 5, total: 0 }` |

Status note (2026-10-21): firebase-tools 15.12.0 is installed. If the Firestore
emulator's Java requirement is missing on the build host, these cases stand as the
static-review contract until the orchestrator runs them; the function code paths
were reviewed line-by-line against this table.
