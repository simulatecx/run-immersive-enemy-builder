# RUN - CurseForge listing (paste-ready)

> Owner reopened the CurseForge decision 2026-11-03 (supersedes the
> 2026-10-19 waitlist-only stance for Forever launch; recorded in
> SPRINTS.md Decisions). PUBLISHING remains owner-gated: this file is the
> canonical listing copy; nothing here auto-publishes. One CF project
> serves BOTH flavors (the Foresight pattern): the zip carries RUN.toc
> (Forever) + RUN_Vanilla.toc (Classic Era) and the client picks.

## 1. Project name

**Recommended: `RUN: Immersive Enemy Builder`**
- Keeps the brand ("RUN" alone is unsearchable and collides with nothing on
  CF - the /run collision is an in-game slash issue only).
- The descriptor is the product's own one-liner and carries the search
  keywords (enemy, immersive).
- NEVER put "Nemesis System" in the name - that is Warner Bros.' marketing
  term for a patented system; we reference it in body copy as inspiration
  only, which is ordinary comparative speech.

Alternates considered (pick only if the recommended is taken):
1. `RUN: Your Enemies Remember` - the hook as a name; reads great, weaker
   search keywords.
2. `RUN: Notoriety` - short, evocative, but vague for search.

URL slug suggestion: `run-immersive-enemy-builder`.

## 2. Summary line (the short description field)

> Your enemies remember. Every player a creature fells makes it more
> notorious - tiers, earned titles, banners, and your honest odds against
> it. A living-world enemy layer for WoW: Forever and Classic Era,
> inspired by the nemesis-style foes of Shadow of Mordor and Shadow of War.

## 3. Full description (CF Markdown)

---

**Every creature in Azeroth keeps score. Now you can see it.**

RUN is a passive, display-only addon where **enemies grow with every
player they fell** - the same idea that made the nemesis-style enemies of
*Middle-earth: Shadow of Mordor* and *Shadow of War* unforgettable,
rebuilt honestly for what a WoW addon can actually know. No gameplay
changes, no automation, no setup. Mouse over an enemy and RUN tells you
what it is - and what it has done.

**The notoriety ladder.** Ten tiers, earned one kill at a time. A boar
that has never killed anyone is just a boar. A "normal" raptor with ten
confirmed kills is **"Sunscale Screecher 'Fleshrender' - Infamous"** - a
deterministic earned title (same creature, same title, for everyone), a
tier-colored tooltip line, and a presentation to match.

**You will see them coming.** Tier-styled unit frames for titled enemies,
a light ember-to-blood glow around your target frame that deepens with its
tier - the stock frame itself is never modified - gold QUEST TARGET tags
pinned above the nameplates of anything your quest log wants dead, and
NEARBY banners for rares, elites, quest targets, and notorious killers.

**The death network.** When a RUN user falls, nearby RUN users hear it -
an anonymous, creature-centric ping ("Snagglefang has claimed another
victim"), never a player name unless the fallen opted into eulogy mode.
Their last public words can ride along, Hardcore-style. Heard deaths feed
the same notoriety tiers as your own journal.

**RISK IT.** Target something above your weight solo and RUN shows your
honest win chance; if it is under 50%, you can arm the wager. Win a
sub-25% fight and the Ledger records a **Giant Slayer**. Lose and the
creature's legend grows. Either way, it is on the record.

**The Account Ledger.** Your deaths, your slays, your guild's wipes
(local-only), the creatures you have seen, and the **Most Wanted** board -
the enemies that have earned their names at your expense, account-wide.

**Built for Hardcore and the rest of us.** Display and advice ONLY - RUN
never casts, never moves you, never acts for you. Classic's rules stay
classic: silver dragons stay silver dragons; RUN only adds the layer the
world remembers.

### Better together with Foresight

RUN is made by SimulateCX, the studio behind
**[Foresight](https://www.curseforge.com/wow/addons/foresight)** - the
layman's oracle for your own character. One Azeroth, two jobs: Foresight
reads YOUR character; RUN reads the WORLD'S enemies. Install both and RUN
auto-detects Foresight (it ships as an optional dependency) - the
integration deepens with each release, with Foresight's real
survivability engine feeding RUN's odds on the roadmap for both flavors.

### Privacy, up front

- RUN **never networks on its own**. Contributing to the community
  body-count ledger is one `/ra share` link that YOU paste in a browser -
  nothing leaves your machine until you do.
- Anonymous by default. A display handle is opt-in, per share, never
  remembered.
- Realm, account, guild, and real names **never** leave your machine -
  enforced by a generated allow-list the addon cannot bypass.

### The details

- Works on **WoW: Forever** and **Classic Era** (including Hardcore) from
  one install - the client picks its flavor automatically.
- Fully automatic. `/ra` is options-only (plain `/run` is Blizzard's).
- Everything above lives in your SavedVariables. Nothing is required,
  everything notable is a checkbox.

---

## 4. Images (ALL PNGs live beside this file - two folders)

**`cards/`** - the branded ember/blood set (from the v0.8.0 marketing
build, copied out of the marketing worktree so everything uploadable is in
ONE place):
- `run-01-cover.png` - THE PROJECT IMAGE (CF logo/avatar slot).
- `run-gallery-1600x900.png` - the composite; good first gallery slide.
- `run-02-nemesis-tiers.png` / `run-03-nearby-banners.png` /
  `run-04-death-network.png` / `run-05-risk-it.png` / `run-06-ledger.png` -
  one feature card per pillar; upload after the screenshots.

**`screenshots/`** - real in-game captures (gallery slots 2-5, captions
below):

1. `screenshots/01-ledger-most-wanted-infamous.png` - "The Account Ledger:
   Most Wanted, your death record, and every option in one place. On the
   tooltip: 'Fleshrender' - Infamous (killed you 5x + 5 heard)."
2. `screenshots/02-notorious-enemy-banner.png` - "NOTORIOUS ENEMY NEARBY:
   'the Cruel' - Deadly. You hear about killers before you meet them."
3. `screenshots/03-tier-frame-dangerous.png` - "A 'normal' raptor that
   earned its rank: Dangerous - killed you 2x + 2 heard."
4. `screenshots/04-risk-it-odds.png` - "RISKY - ~63% to win. Honest odds
   (and honest about degraded info when health is secret)."

## 5. CF metadata

- Categories: Tooltip, Unit Frames, Quests & Leveling, Roleplay.
- License: All Rights Reserved (source-available; bundled libs keep their
  own licenses).
- Game versions: WoW Forever (1.60.1) + Classic Era (1.15.9) - one file,
  both TOCs.
- Issues link: the in-game F6 creature-report flow + the armory site.

## 6. Publish checklist (owner-gated - do not run without the owner)

1. `python pipeline/package.py` - gate-then-zip; produces
   `dist/RUN-v<version>-forever-and-era.zip` (RUN/ at zip root, both TOCs).
2. Create the CF project with the name above; paste §2 + §3; upload §4 in
   order.
3. The W3 backend go-live is INDEPENDENT of this listing: the description
   deliberately never promises live global leaderboards - the share-link
   flow is real today and the boards light up when W3 ships.
4. Record the ship: SPRINTS.md + ECOSYSTEM §2 truth table in the same
   change.
