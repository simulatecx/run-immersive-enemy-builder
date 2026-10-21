"""The season-flip archive op (WP-G / RUN-G): NON-destructive, owner-gated.

At the Hardcore-kickoff reset (~2026-12-04) Season 0 is ARCHIVED, never wiped:
every active-season doc in the public ladder collections (`rareKillCounts`,
`giantSlayers`) is COPIED to `seasonArchive/{season}/{collection}/{id}` on the
LIVE Firestore (project wow-foresight). NOTHING is deleted - rollups and
ladders key by season, so new-season docs simply accrue under the new tag and
the "reset" is the ladders filtering on it. Full doctrine: docs/SEASONS.md.

Safe-data-ops discipline (docs/NOTES.md house laws), in order and enforced:
  dry-run first -> local timestamped JSON backup -> write (copy only) ->
  read-back verify -> print the manual follow-ups. Idempotent: re-running
  re-copies the same docs to the same archive paths (PATCH overwrites).

Modes:
  python pipeline/season_archive.py                      # --dry-run (default)
      Public, unauthenticated reads only: counts every rareKillCounts /
      giantSlayers doc of the active season (what --archive would copy).
      Expected failures pre-deploy (403 while rules aren't live, empty
      collections) are handled gracefully and reported honestly.

  python pipeline/season_archive.py --archive --season s0 --next s1 --yes
      The real op. Requires an explicit --yes. Needs an OAuth bearer from
      `gcloud auth print-access-token` (an authed owner/admin shell); fails
      honestly when gcloud is absent or unauthed. Steps:
        (a) read all active-season docs (both collections, paged),
        (b) back them up to pipeline/backups/season-<season>-<stamp>.json
            (gitignored local artifact - never committed),
        (c) copy each doc to seasonArchive/{season}/{collection}/{id},
        (d) delete NOTHING (there is no delete call in this file),
        (e) read back every archive copy and verify fields verbatim,
        (f) print the two manual follow-ups: bump RUN.season in
            RUN/core/init.lua to --next, and redeploy the web ladders'
            default-season to --next.

Who runs it: THE OWNER (or a supervised session), per the owner-gated list in
docs/AGENT-PLAN.md. Agents implement and dry-run; they never flip a season.
"""

from __future__ import annotations

import argparse
import json
import re
import shutil
import subprocess
import sys
import urllib.error
import urllib.parse
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).parent.parent
INIT_LUA = ROOT / "RUN" / "core" / "init.lua"
BACKUP_DIR = Path(__file__).parent / "backups"

PROJECT = "wow-foresight"
BASE = (f"https://firestore.googleapis.com/v1/projects/{PROJECT}"
        "/databases/(default)/documents")
COLLECTIONS = ["rareKillCounts", "giantSlayers"]
ARCHIVE_ROOT = "seasonArchive"
PAGE_SIZE = 300
TIMEOUT = 30

SEASON_RE = re.compile(r"^[a-z0-9]{1,8}$")  # the schema's season shape, exactly


# ---------------------------------------------------------------------------
# Small helpers.
# ---------------------------------------------------------------------------

def active_season_from_init() -> str:
    """The addon's one season constant (RUN/core/init.lua) is the default."""
    try:
        m = re.search(r'^RUN\.season\s*=\s*"([a-z0-9]{1,8})"',
                      INIT_LUA.read_text(encoding="utf-8"), re.M)
        if m:
            return m.group(1)
    except OSError:
        pass
    return "s0"


def doc_id(doc: dict) -> str:
    """Firestore document id = the last path segment of its resource name."""
    return doc.get("name", "").rsplit("/", 1)[-1]


def doc_season(doc: dict) -> str:
    """A doc's season tag; docs written before the tag existed count as s0
    (the function's own default), so legacy docs are archived, not stranded."""
    v = doc.get("fields", {}).get("season", {})
    s = v.get("stringValue")
    return s if isinstance(s, str) and SEASON_RE.match(s) else "s0"


def request_json(url: str, token: str | None = None, method: str = "GET",
                 body: dict | None = None) -> dict:
    headers = {"Accept": "application/json"}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    data = None
    if body is not None:
        headers["Content-Type"] = "application/json"
        data = json.dumps(body).encode("utf-8")
    req = urllib.request.Request(url, data=data, headers=headers, method=method)
    with urllib.request.urlopen(req, timeout=TIMEOUT) as resp:
        return json.loads(resp.read().decode("utf-8"))


def list_collection(collection: str, token: str | None = None) -> list[dict]:
    """Every doc in a top-level collection (paged). Raises on HTTP errors so
    callers can report them honestly per mode."""
    docs: list[dict] = []
    page_token = None
    while True:
        qs = {"pageSize": str(PAGE_SIZE)}
        if page_token:
            qs["pageToken"] = page_token
        url = f"{BASE}/{collection}?" + urllib.parse.urlencode(qs)
        body = request_json(url, token=token)
        docs.extend(body.get("documents", []))
        page_token = body.get("nextPageToken")
        if not page_token:
            return docs


def gcloud_access_token() -> str:
    """OAuth bearer from the owner's authed gcloud. Fails honestly: no gcloud
    or no auth means this op is not yours to run."""
    exe = shutil.which("gcloud") or shutil.which("gcloud.cmd")
    if not exe:
        sys.exit("ABORT: gcloud not found on PATH. The archive op needs an "
                 "authed admin shell (`gcloud auth login`); it cannot and "
                 "will not run anonymously.")
    try:
        out = subprocess.run([exe, "auth", "print-access-token"],
                             capture_output=True, text=True, timeout=60)
    except (OSError, subprocess.TimeoutExpired) as e:
        sys.exit(f"ABORT: gcloud auth print-access-token failed to run: {e}")
    token = (out.stdout or "").strip()
    if out.returncode != 0 or not token:
        sys.exit("ABORT: gcloud auth print-access-token returned no token "
                 f"(exit {out.returncode}): {(out.stderr or '').strip()}")
    return token


# ---------------------------------------------------------------------------
# --dry-run (default): public reads only, counts only, never a token.
# ---------------------------------------------------------------------------

def dry_run(season: str) -> int:
    print(f"DRY RUN - project {PROJECT}, active season '{season}'. "
          "Public read API only; nothing is written.")
    for collection in COLLECTIONS:
        try:
            docs = list_collection(collection)
        except urllib.error.HTTPError as e:
            # Pre-deploy this is the expected honest stop (default-deny rules
            # or the collection not existing yet) - report, don't crash.
            print(f"  {collection}: unreadable over the public API "
                  f"(HTTP {e.code}) - expected before the ladder rules are "
                  "live; the authed --archive mode reads it regardless.")
            continue
        except (urllib.error.URLError, TimeoutError, json.JSONDecodeError) as e:
            print(f"  {collection}: fetch failed ({e}) - offline or the API "
                  "is unreachable; re-run when connected.")
            continue
        move = sum(1 for d in docs if doc_season(d) == season)
        other = len(docs) - move
        print(f"  {collection}: {len(docs)} doc(s) total - {move} of season "
              f"'{season}' would be COPIED to "
              f"{ARCHIVE_ROOT}/{season}/{collection}/ "
              f"({other} of other seasons left untouched; nothing is ever "
              "deleted either way)")
    print("Dry run complete. The real op: --archive --season <active> "
          "--next <new> --yes (owner-gated).")
    return 0


# ---------------------------------------------------------------------------
# --archive: backup -> copy -> read-back. No delete call exists in this file.
# ---------------------------------------------------------------------------

def write_backup(season: str, by_collection: dict[str, list[dict]]) -> Path:
    BACKUP_DIR.mkdir(parents=True, exist_ok=True)
    stamp = datetime.now(timezone.utc).strftime("%Y%m%d-%H%M%SZ")
    path = BACKUP_DIR / f"season-{season}-{stamp}.json"
    payload = {
        "project": PROJECT,
        "season": season,
        "takenAt": datetime.now(timezone.utc).isoformat(),
        "collections": by_collection,
    }
    path.write_text(json.dumps(payload, indent=2, sort_keys=True),
                    encoding="utf-8")
    return path


def archive_path(season: str, collection: str, did: str) -> str:
    return (f"{BASE}/{ARCHIVE_ROOT}/{urllib.parse.quote(season, safe='')}"
            f"/{urllib.parse.quote(collection, safe='')}"
            f"/{urllib.parse.quote(did, safe='')}")


def archive(season: str, next_season: str, yes: bool) -> int:
    if not yes:
        sys.exit("ABORT: --archive mutates the LIVE project and requires an "
                 "explicit --yes. Run --dry-run first; read docs/SEASONS.md.")
    if season == next_season:
        sys.exit("ABORT: --next must differ from --season (the flip IS the "
                 "reset; archiving a season onto itself is a no-op mistake).")

    print(f"ARCHIVE - project {PROJECT}: season '{season}' -> archive; "
          f"'{next_season}' becomes active AFTER the manual follow-ups.")
    token = gcloud_access_token()

    # (a) read every active-season doc, both collections.
    by_collection: dict[str, list[dict]] = {}
    for collection in COLLECTIONS:
        try:
            docs = list_collection(collection, token=token)
        except urllib.error.HTTPError as e:
            sys.exit(f"ABORT: reading {collection} failed (HTTP {e.code}: "
                     f"{e.reason}). Nothing was written. An admin bearer "
                     "should read everything - check the account's access "
                     "to the wow-foresight project.")
        picked = [d for d in docs if doc_season(d) == season]
        by_collection[collection] = picked
        print(f"  read {collection}: {len(picked)} season-'{season}' doc(s) "
              f"of {len(docs)} total")
    total = sum(len(v) for v in by_collection.values())
    if total == 0:
        print("Nothing to archive (0 active-season docs). No backup, no "
              "writes. Done.")
        return 0

    # (b) local timestamped backup BEFORE any write.
    backup = write_backup(season, by_collection)
    print(f"  backup written: {backup} ({total} doc(s))")

    # (c) copy each doc verbatim to seasonArchive/{season}/{collection}/{id}.
    #     PATCH = create-or-overwrite: idempotent, and NEVER a delete.
    copied = 0
    for collection, docs in by_collection.items():
        for doc in docs:
            did = doc_id(doc)
            url = archive_path(season, collection, did)
            try:
                request_json(url, token=token, method="PATCH",
                             body={"fields": doc.get("fields", {})})
            except urllib.error.HTTPError as e:
                sys.exit(f"ABORT after {copied}/{total} copies: writing "
                         f"{ARCHIVE_ROOT}/{season}/{collection}/{did} failed "
                         f"(HTTP {e.code}: {e.reason}). A 403 means this "
                         "account lacks admin write access - the correct "
                         "stop for anyone but the owner. The backup at "
                         f"{backup} is intact; originals are untouched; "
                         "re-running is safe (copies are idempotent).")
            copied += 1
    print(f"  copied {copied}/{total} doc(s) to {ARCHIVE_ROOT}/{season}/...")

    # (d) delete NOTHING - by design there is no delete in this file. Old
    #     docs stay put; ladders simply filter by the new active season.

    # (e) read-back verify every archive copy, field-for-field.
    mismatches = 0
    for collection, docs in by_collection.items():
        for doc in docs:
            did = doc_id(doc)
            try:
                got = request_json(archive_path(season, collection, did),
                                   token=token)
            except urllib.error.HTTPError as e:
                print(f"  READ-BACK MISS {collection}/{did}: HTTP {e.code}")
                mismatches += 1
                continue
            want = json.dumps(doc.get("fields", {}), sort_keys=True)
            have = json.dumps(got.get("fields", {}), sort_keys=True)
            if want != have:
                print(f"  READ-BACK MISMATCH {collection}/{did}")
                mismatches += 1
    if mismatches:
        sys.exit(f"ABORT: read-back verification failed for {mismatches} "
                 f"doc(s). Originals are untouched; backup at {backup}. "
                 "Investigate before flipping the season constant.")
    print(f"  read-back verified {total}/{total} archive cop(y/ies)")

    # (f) the flip itself is two MANUAL, owner-reviewed changes.
    print("")
    print("Archive complete and verified. NOW the manual follow-ups "
          "(docs/SEASONS.md runbook):")
    print(f"  1. Bump the one season constant: RUN/core/init.lua -> "
          f'RUN.season = "{next_season}"  (ship via the normal gate)')
    print(f"  2. Redeploy the web ladders' default-season to '{next_season}' "
          "(marketing repo; owner-gated scoped deploy).")
    print("Old-season docs remain readable forever under "
          f"{ARCHIVE_ROOT}/{season}/ and in the originals. Nothing was "
          "deleted.")
    return 0


def main() -> int:
    ap = argparse.ArgumentParser(
        description="RUN season archive op - NON-destructive, owner-gated "
                    "(docs/SEASONS.md).")
    mode = ap.add_mutually_exclusive_group()
    mode.add_argument("--dry-run", action="store_true",
                      help="count what --archive would copy (DEFAULT; public "
                           "reads only, writes nothing)")
    mode.add_argument("--archive", action="store_true",
                      help="backup + copy the active season to seasonArchive/ "
                           "(requires --yes and an authed gcloud)")
    ap.add_argument("--season", default=None,
                    help="active season tag (default: RUN.season from "
                         "RUN/core/init.lua)")
    ap.add_argument("--next", dest="next_season", default=None,
                    help="the new season tag (required with --archive)")
    ap.add_argument("--yes", action="store_true",
                    help="explicit consent for --archive; without it the op "
                         "aborts before any read")
    args = ap.parse_args()

    season = args.season or active_season_from_init()
    if not SEASON_RE.match(season):
        sys.exit(f"ABORT: season tag {season!r} is off-shape (need "
                 "lowercase [a-z0-9], max 8 - the schema's season rule).")

    if args.archive:
        if not args.next_season:
            sys.exit("ABORT: --archive requires --next <new season tag>.")
        if not SEASON_RE.match(args.next_season):
            sys.exit(f"ABORT: next season tag {args.next_season!r} is "
                     "off-shape (need lowercase [a-z0-9], max 8).")
        return archive(season, args.next_season, args.yes)
    return dry_run(season)


if __name__ == "__main__":
    sys.exit(main())
