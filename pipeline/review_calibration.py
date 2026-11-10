"""The daily calibration review (RUN-P): read the crowd rollups, print the digest.

The QuestieTrace-pattern loop closes HERE: consent-gated capture in the addon ->
/ra share -> run.html -> Firestore -> rareKillsOnWrite aggregates -> THIS script
reads the aggregates and prints what a human should look at today:

  - share VOLUME (submissions + distinct clients per day, from the rate-limit docs)
  - the season calibration CURVE (recomputed-p deciles vs actual win rate)
  - per-creature calibration GAPS (predicted vs actual, biggest first)
  - the DEADLIEST creatures (lowest actual solo win rate at/above the floor)

Modes:
  - OWNER mode (full digest): authenticates with `gcloud auth print-access-token`
    (the bake-script pattern; tokens last ~1h - re-auth with `gcloud auth login`).
    Reads the admin-only `rareKillMeta` tallies + calcurve docs.
  - PUBLIC fallback: no gcloud -> reads only the public `rareKillCounts` calib
    blocks (pre-suppressed). Volume + curve sections are unavailable there.

READ-ONLY: this script never writes Firestore. Decisions that change the odds
curve go through data/overrides.lua + a reviewed commit - crowd data NEVER
auto-tunes the model (the same human-review law as every other crowd input).
Digest is printed AND saved to pipeline/collected/calib-digest-<date>.md.

Usage: python pipeline/review_calibration.py [--days 7]
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import shutil
import subprocess
import sys
import urllib.parse
import urllib.request
from pathlib import Path

ROOT = Path(__file__).parent.parent
OUT_DIR = ROOT / "pipeline" / "collected"

PROJECT = "wow-foresight"
BASE = (f"https://firestore.googleapis.com/v1/projects/{PROJECT}"
        "/databases/(default)/documents")
PAGE_SIZE = 300
MAX_PAGES = 50          # hard bound; the digest SAYS so if it truncates
TIMEOUT = 20

FLOOR = 5               # MIN_BUCKET parity: never show buckets below this
GAP_FLAG = 15           # per-creature |pred - actual| percentage points to flag
CURVE_FLAG = 10         # per-decile flag threshold
TOP_N = 15              # list caps per section


# ---- Firestore REST decode (the fetch_counts.py idioms) -----------------------

def _fv(v):
    if not isinstance(v, dict):
        return None
    if "integerValue" in v:
        return int(v["integerValue"])
    if "doubleValue" in v:
        return float(v["doubleValue"])
    if "stringValue" in v:
        return v["stringValue"]
    if "booleanValue" in v:
        return v["booleanValue"]
    if "mapValue" in v:
        return {k: _fv(x) for k, x in (v["mapValue"].get("fields") or {}).items()}
    if "arrayValue" in v:
        return [_fv(x) for x in (v["arrayValue"].get("values") or [])]
    return None


def decode(doc: dict) -> dict:
    out = {k: _fv(v) for k, v in (doc.get("fields") or {}).items()}
    out["_id"] = doc.get("name", "").rsplit("/", 1)[-1]
    return out


def owner_token() -> str | None:
    """The maintainer's gcloud OAuth token, or None (public fallback)."""
    exe = shutil.which("gcloud") or shutil.which("gcloud.cmd")
    if not exe:
        return None
    try:
        r = subprocess.run([exe, "auth", "print-access-token"],
                           capture_output=True, text=True, timeout=30)
    except (OSError, subprocess.TimeoutExpired):
        return None
    tok = (r.stdout or "").strip()
    return tok if r.returncode == 0 and tok else None


def list_collection(collection: str, token: str | None):
    """Yield decoded docs; prints an explicit truncation note at MAX_PAGES."""
    page_token, pages = None, 0
    while True:
        qs = {"pageSize": str(PAGE_SIZE)}
        if page_token:
            qs["pageToken"] = page_token
        url = f"{BASE}/{collection}?" + urllib.parse.urlencode(qs)
        req = urllib.request.Request(url)
        if token:
            req.add_header("Authorization", f"Bearer {token}")
        with urllib.request.urlopen(req, timeout=TIMEOUT) as resp:
            body = json.loads(resp.read().decode("utf-8"))
        for doc in body.get("documents", []):
            yield decode(doc)
        page_token = body.get("nextPageToken")
        pages += 1
        if not page_token:
            return
        if pages >= MAX_PAGES:
            print(f"NOTE: {collection} truncated at {MAX_PAGES * PAGE_SIZE} docs - "
                  "raise MAX_PAGES for a full read")
            return


# ---- digest assembly -----------------------------------------------------------

def pct(x: float) -> str:
    return f"{round(x):d}%"


def creature_label(t: dict) -> str:
    name = t.get("name")
    npc = t.get("npc")
    return f"{name} ({npc})" if isinstance(name, str) and name else f"npc {npc}"


def section_volume(rl_docs: list[dict], days: int, lines: list[str]) -> None:
    by_day: dict[str, dict] = {}
    for d in rl_docs:
        # rl-<clientId>-<YYYYMMDD>; clientIds never reach the digest (dedup only)
        day = d["_id"].rsplit("-", 1)[-1]
        if not (len(day) == 8 and day.isdigit()):
            continue
        slot = by_day.setdefault(day, {"subs": 0, "clients": 0})
        slot["subs"] += int(d.get("n") or 0)
        slot["clients"] += 1
    lines.append("## Share volume (from the rate-limit tallies)")
    if not by_day:
        lines.append("- no submissions recorded yet")
        return
    today = dt.date.today()
    for i in range(days):
        day = (today - dt.timedelta(days=i)).strftime("%Y%m%d")
        s = by_day.get(day)
        if s:
            lines.append(f"- {day}: {s['subs']} submission(s) from "
                         f"{s['clients']} distinct client(s)")
    total = sum(s["subs"] for s in by_day.values())
    lines.append(f"- all-time: {total} submission(s) across {len(by_day)} client-day(s)")


def section_curve(curves: list[dict], lines: list[str]) -> None:
    lines.append("")
    lines.append("## Calibration curve (recomputed-p decile -> actual, per season)")
    if not curves:
        lines.append("- no curve data yet")
        return
    for cur in sorted(curves, key=lambda c: c.get("season") or c["_id"]):
        season = cur.get("season") or cur["_id"].removeprefix("calcurve-")
        lines.append(f"- season {season}:")
        deciles = cur.get("deciles") or {}
        for i in range(10):
            d = deciles.get(f"d{i}")
            if not isinstance(d, dict) or not d.get("fights"):
                continue
            fights = int(d["fights"])
            if fights < FLOOR:
                lines.append(f"    d{i} ({i*10}-{i*10+10}%): n={fights} (below floor)")
                continue
            actual = 100.0 * (d.get("wins") or 0) / fights
            pred = 100.0 * (d.get("sumP") or 0) / fights
            flag = "  <-- MISCALIBRATED" if abs(actual - pred) >= CURVE_FLAG else ""
            lines.append(f"    d{i} ({i*10}-{i*10+10}%): pred {pct(pred)} "
                         f"actual {pct(actual)} (n={fights}){flag}")


def calib_rows(tallies: list[dict]) -> list[dict]:
    rows = []
    for t in tallies:
        cal = t.get("calib")
        if not isinstance(cal, dict):
            continue
        fights = int(cal.get("fights") or 0)
        if fights < FLOOR or t.get("npc") is None:
            continue
        rows.append({
            "label": creature_label(t),
            "season": t.get("season") or "s0",
            "fights": fights,
            "actual": 100.0 * (cal.get("wins") or 0) / fights,
            "pred": 100.0 * (cal.get("sumP") or 0) / fights,
            "claimed": (100.0 * (cal.get("sumPc") or 0) / fights)
                       if cal.get("sumPc") is not None else None,
        })
    return rows


def section_gaps(rows: list[dict], lines: list[str]) -> None:
    lines.append("")
    lines.append(f"## Per-creature calibration gaps (|pred - actual| >= {GAP_FLAG}pts, "
                 f"fights >= {FLOOR})")
    flagged = sorted((r for r in rows if abs(r["pred"] - r["actual"]) >= GAP_FLAG),
                     key=lambda r: -abs(r["pred"] - r["actual"]))
    if not flagged:
        lines.append("- none - the curve holds at the per-creature level")
        return
    for r in flagged[:TOP_N]:
        direction = "OVERCONFIDENT" if r["pred"] > r["actual"] else "underconfident"
        claimed = (f", client-claimed {pct(r['claimed'])}"
                   if r["claimed"] is not None else "")
        lines.append(f"- [{r['season']}] {r['label']}: pred {pct(r['pred'])} vs "
                     f"actual {pct(r['actual'])} (n={r['fights']}) {direction}{claimed}")
    if len(flagged) > TOP_N:
        lines.append(f"- ... and {len(flagged) - TOP_N} more")


def section_deadliest(rows: list[dict], tallies: list[dict], lines: list[str]) -> None:
    lines.append("")
    lines.append(f"## Deadliest (lowest actual solo win rate, fights >= {FLOOR})")
    worst = sorted(rows, key=lambda r: r["actual"])[:TOP_N]
    if worst:
        for r in worst:
            lines.append(f"- [{r['season']}] {r['label']}: actual {pct(r['actual'])} "
                         f"win rate over {r['fights']} fight(s), pred {pct(r['pred'])}")
    else:
        lines.append("- no calibration pairs at the floor yet")
    # The death-journal view (kills of players), independent of calib consent:
    deaths = []
    for t in tallies:
        counts = t.get("counts")
        if isinstance(counts, dict) and t.get("npc") is not None:
            total = sum(int(counts.get(m) or 0) for m in ("pve", "pvp", "hc"))
            if total >= FLOOR:
                deaths.append((total, creature_label(t)))
    if deaths:
        lines.append("")
        lines.append("## Most player-kills (death journals, all modes)")
        for total, label in sorted(deaths, reverse=True)[:TOP_N]:
            lines.append(f"- {label}: {total} recorded kill(s)")


def public_fallback(lines: list[str]) -> None:
    """No owner token: the pre-suppressed public calib blocks only."""
    lines.append("(public fallback - run `gcloud auth login` for the full digest)")
    rows = []
    try:
        for d in list_collection("rareKillCounts", None):
            cal = d.get("calib")
            if isinstance(cal, dict) and d.get("npc") is not None:
                rows.append(d)
    except Exception as e:  # noqa: BLE001 - a review tool reports, never crashes
        lines.append(f"- public read failed ({e}) - are the RUN rules deployed yet?")
        return
    lines.append("")
    lines.append("## Public calibration blocks (pre-suppressed)")
    if not rows:
        lines.append("- none published yet (needs the backend deploy + shares)")
        return
    for d in sorted(rows, key=lambda r: (r["calib"].get("winPct") or 0)):
        label = f"{d.get('name')} ({d['npc']})" if d.get("name") else f"npc {d['npc']}"
        cal = d["calib"]
        lines.append(f"- {label}: actual {cal.get('winPct')}% vs pred "
                     f"{cal.get('predPct')}% over {cal.get('fights')} fight(s)")


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--days", type=int, default=7, help="volume window (default 7)")
    args = ap.parse_args()

    today = dt.date.today().isoformat()
    lines = [f"# RUN calibration digest - {today}", ""]

    token = owner_token()
    if token:
        try:
            meta = list(list_collection("rareKillMeta", token))
        except Exception as e:  # noqa: BLE001
            print(f"owner read failed ({e}); falling back to the public rollups")
            meta, token = [], None
    if token:
        tallies = [d for d in meta if d["_id"].startswith("tally-")]
        curves = [d for d in meta if d["_id"].startswith("calcurve-")]
        rl = [d for d in meta if d["_id"].startswith("rl-")]
        section_volume(rl, args.days, lines)
        section_curve(curves, lines)
        rows = calib_rows(tallies)
        section_gaps(rows, lines)
        section_deadliest(rows, tallies, lines)
        if not (tallies or curves or rl):
            lines.append("")
            lines.append("No crowd data at all yet - the share loop goes live only "
                         "after the owner deploys the RUN backend surface "
                         "(rules -> functions -> hosting).")
    else:
        public_fallback(lines)

    lines += ["", "Model changes go through data/overrides.lua + a reviewed commit -",
              "crowd data never auto-tunes the odds curve."]

    digest = "\n".join(lines)
    print(digest)
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    out = OUT_DIR / f"calib-digest-{today}.md"
    out.write_text(digest + "\n", encoding="utf-8")
    print(f"\nsaved {out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
