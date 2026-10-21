"""Emulator tests for the RUN crowd backend (WP-B): rules + rareKillsOnWrite.

Runs against the LOCAL Firebase emulator only (demo project; never live):

    cd functions-run && npm install
    firebase emulators:start --only firestore,functions,auth \
        --project demo-wow-foresight --config firebase/firebase.json   (from repo root)
    python functions-run/test/emulator_test.py

Covers the contract in functions-run/test/fixtures.md: envelope shape-lock + PII
rejection + the named gate (rules), and recompute / rate-limit / k-of-n /
MIN_BUCKET suppression (function). Client calls use unsigned anonymous-auth JWTs
(the emulator accepts them); internal tallies are read with the owner bypass.
Exit 0 = all green.
"""

from __future__ import annotations

import base64
import json
import sys
import time
import urllib.error
import urllib.request

PROJECT = "demo-wow-foresight"
FIRESTORE = "http://127.0.0.1:8785"
BASE = f"{FIRESTORE}/v1/projects/{PROJECT}/databases/(default)/documents"

PASS, FAIL = [], []


def check(label: str, cond: bool, detail: str = "") -> None:
    if cond:
        PASS.append(label)
    else:
        FAIL.append(f"{label}{(' - ' + detail) if detail else ''}")
        print(f"  FAIL {label} {detail}")


# ---- auth ---------------------------------------------------------------------

def _b64(d: dict) -> str:
    return base64.urlsafe_b64encode(json.dumps(d).encode()).rstrip(b"=").decode()


def fake_token(uid: str) -> str:
    """Unsigned anonymous-auth JWT; the emulator accepts alg=none tokens."""
    now = int(time.time())
    header = {"alg": "none", "typ": "JWT"}
    payload = {
        "iss": f"https://securetoken.google.com/{PROJECT}", "aud": PROJECT,
        "iat": now - 10, "exp": now + 3600, "auth_time": now - 10,
        "sub": uid, "user_id": uid,
        "firebase": {"sign_in_provider": "anonymous", "identities": {}},
    }
    return f"{_b64(header)}.{_b64(payload)}."


# ---- Firestore REST encoding ---------------------------------------------------

def fv(v):
    if isinstance(v, bool):
        return {"booleanValue": v}
    if isinstance(v, int):
        return {"integerValue": str(v)}
    if isinstance(v, float):
        return {"doubleValue": v}
    if isinstance(v, str):
        return {"stringValue": v}
    if isinstance(v, list):
        return {"arrayValue": {"values": [fv(x) for x in v]}}
    if isinstance(v, dict):
        return {"mapValue": {"fields": {k: fv(x) for k, x in v.items()}}}
    raise TypeError(type(v))


def from_fv(v):
    if "integerValue" in v:
        return int(v["integerValue"])
    if "doubleValue" in v:
        return v["doubleValue"]
    if "stringValue" in v:
        return v["stringValue"]
    if "booleanValue" in v:
        return v["booleanValue"]
    if "mapValue" in v:
        return {k: from_fv(x) for k, x in (v["mapValue"].get("fields") or {}).items()}
    if "arrayValue" in v:
        return [from_fv(x) for x in (v["arrayValue"].get("values") or [])]
    return None


def decode_doc(body: dict):
    return {k: from_fv(v) for k, v in (body.get("fields") or {}).items()}


def req(method: str, url: str, data: dict | None = None, token: str | None = None):
    """Returns (status, parsed-json-or-None)."""
    headers = {"Content-Type": "application/json"}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    r = urllib.request.Request(url, method=method, headers=headers,
                               data=json.dumps(data).encode() if data is not None else None)
    try:
        with urllib.request.urlopen(r, timeout=30) as resp:
            return resp.status, json.loads(resp.read().decode() or "null")
    except urllib.error.HTTPError as e:
        return e.code, None


def create(collection: str, doc: dict, token: str | None):
    return req("POST", f"{BASE}/{collection}",
               {"fields": {k: fv(v) for k, v in doc.items()}}, token)


def get_doc(path: str, token: str | None = None):
    status, body = req("GET", f"{BASE}/{path}", None, token)
    return status, (decode_doc(body) if status == 200 and body else None)


def poll(fn, timeout=45, every=1.0):
    deadline = time.time() + timeout
    while time.time() < deadline:
        v = fn()
        if v:
            return v
        time.sleep(every)
    return None


# ---- fixtures -------------------------------------------------------------------

def baseline(client_id: str, npc=448, sight_npc=5786, **extra) -> dict:
    d = {
        "v": 1,
        "kinds": ["death", "slay", "sighting", "wipe"],
        "season": "s0",
        "clientId": client_id,
        "events": [
            {"k": "death", "npc": npc, "mode": "hc", "bracket": 20, "zone": 1429, "season": "s0"},
            {"k": "slay", "npc": npc, "p": 0.2,
             "snap": {"pLevel": 10, "cLevel": 17, "cls": "rare"}, "mode": "pve", "season": "s0"},
            {"k": "sighting", "npc": sight_npc, "nm": "Snagglefang", "cls": "rare",
             "zone": 1413, "season": "s0"},
            {"k": "wipe", "npc": npc, "mode": "pve", "season": "s0"},
            {"k": "wipe", "enc": "Hogger", "mode": "pve", "season": "s0"},
        ],
    }
    d.update(extra)
    return d


def main() -> int:
    user = fake_token("emu-user-1")

    # sanity: emulator up?
    status, _ = req("GET", f"{BASE}/rareKillCounts/0")
    if status not in (200, 404, 403):
        print(f"emulator not reachable at {FIRESTORE} (status {status}) - start it first")
        return 2

    print("== rules: envelope shape-lock ==")
    s, _ = create("rareKills", baseline("rulesok0001"), user)
    check("R1 baseline allowed", s == 200, f"status {s}")
    s, _ = create("rareKills", baseline("rulesok0002"), None)
    check("R2 unauthenticated denied", s == 403, f"status {s}")
    s, _ = create("rareKills", {**baseline("evil0001"), "realm": "Stitches"}, user)
    check("R3 PII key realm denied", s == 403, f"status {s}")
    s, _ = create("rareKills", {**baseline("evil0002"), "name": "Brad Smith"}, user)
    check("R4 PII key name denied", s == 403, f"status {s}")
    s, _ = create("rareKills", {**baseline("evil0003"), "handle": "Bold"}, user)
    check("R5 handle without named denied", s == 403, f"status {s}")
    s, _ = create("rareKills", {**baseline("namedok01"), "named": True, "handle": "Bold"}, user)
    check("R6 named+handle allowed", s == 200, f"status {s}")
    s, _ = create("rareKills", {**baseline("evil0004"), "named": False, "handle": "Bold"}, user)
    check("R7 named=false + handle denied", s == 403, f"status {s}")
    s, _ = create("rareKills", {**baseline("evil0005"), "named": True, "handle": "x" * 25}, user)
    check("R8 oversize handle denied", s == 403, f"status {s}")
    s, _ = create("rareKills", {**baseline("evil0006"), "events": []}, user)
    check("R9 empty events denied", s == 403, f"status {s}")
    s, _ = create("rareKills", {**baseline("evil0007"), "kinds": ["death", "hack"]}, user)
    check("R11 unknown kind denied", s == 403, f"status {s}")
    s, _ = create("rareKills", {**baseline("evil0008"), "season": "S0!"}, user)
    check("R12 bad season denied", s == 403, f"status {s}")
    s, _ = get_doc("rareKills/anything", user)
    check("R13 raw rareKills unreadable", s == 403, f"status {s}")
    s, _ = create("rareKillCounts", {"npc": 1, "total": 999}, user)
    check("R14a client write rareKillCounts denied", s == 403, f"status {s}")
    s, _ = create("giantSlayers", {"handle": "Spoof", "npc": 1}, user)
    check("R14b client write giantSlayers denied", s == 403, f"status {s}")
    s, _ = create("rareKillMeta", {"n": 0}, user)
    check("R14c client write rareKillMeta denied", s == 403, f"status {s}")
    s, _ = get_doc("rareKillCounts/448")
    check("R15 public read rareKillCounts", s in (200, 404), f"status {s}")

    print("== rules: runWaitlist ==")
    s, _ = create("runWaitlist", {"email": "a@b.co", "consent": True, "source": "runpage"}, user)
    check("R16 valid waitlist allowed", s == 200, f"status {s}")
    s, _ = create("runWaitlist", {"email": "a@b.co", "consent": False, "source": "runpage"}, user)
    check("R17a consent=false denied", s == 403, f"status {s}")
    s, _ = create("runWaitlist", {"email": "a@b.co", "consent": True, "source": "runpage",
                                  "notes": "x"}, user)
    check("R17b extra key denied", s == 403, f"status {s}")
    s, _ = create("runWaitlist", {"email": "not-an-email", "consent": True, "source": "x"}, user)
    check("R17c junk email denied", s == 403, f"status {s}")
    s, _ = get_doc("runWaitlist/anything", user)
    check("R18 waitlist unreadable", s == 403, f"status {s}")

    print("== rules: Foresight regression (existing blocks untouched) ==")
    s, _ = create("contributions", {"v": 1, "class": "SHAMAN", "level": 12,
                                    "lenses": {"healing": 3}, "talents": {"1": 1},
                                    "items": {"5": 1}, "observed": {}}, user)
    check("R19a contributions still writable", s == 200, f"status {s}")
    s, _ = create("feedback", {"type": "bug", "message": "hi"}, user)
    check("R19b feedback still writable", s == 200, f"status {s}")
    s, _ = get_doc("aggregates/whatever")
    check("R19c aggregates still public-read", s in (200, 404), f"status {s}")

    print("== function: rollups, suppression, recompute, k-of-n, rate limit ==")
    # F1: one submission for a dedicated npc -> low:true doc (1 death + 1 wipe < 5)
    npc = 9000101
    s, _ = create("rareKills", baseline("fclient0001", npc=npc, sight_npc=9000201), user)
    check("F1 write accepted", s == 200, f"status {s}")
    doc = poll(lambda: get_doc(f"rareKillCounts/{npc}")[1])
    check("F1 low doc appears", bool(doc) and doc.get("low") is True
          and "total" not in doc and doc.get("npc") == npc, f"doc {doc}")

    # F2: four more distinct clients -> total 5 publishes, suppression lifts
    for i in range(2, 6):
        s, _ = create("rareKills", baseline(f"fclient000{i}", npc=npc, sight_npc=9000201), user)
        check(f"F2 write {i} accepted", s == 200, f"status {s}")
    doc = poll(lambda: (lambda d: d if d and d.get("total") == 5 else None)(
        get_doc(f"rareKillCounts/{npc}")[1]))
    check("F2 suppression lifts at MIN_BUCKET", bool(doc) and doc.get("total") == 5
          and doc.get("wipes") == 5 and doc.get("counts", {}).get("hc") == 5, f"doc {doc}")

    # F8: the sighting rode 5 distinct clientIds -> name published (k-of-n=3)
    doc = poll(lambda: (lambda d: d if d and d.get("name") else None)(
        get_doc("rareKillCounts/9000201")[1]))
    check("F8 k-of-n name published", bool(doc) and doc.get("name") == "Snagglefang", f"doc {doc}")

    # F3: named slay -> ONE giantSlayers entry with the RECOMPUTED pct
    def slayers_for(npc_id):
        s2, body = req("GET", f"{BASE}/giantSlayers")
        if s2 != 200 or not body or "documents" not in body:
            return []
        return [decode_doc(x) for x in body["documents"]
                if decode_doc(x).get("npc") == npc_id]
    npc_slay = 9000301
    sub = baseline("fslayer0001", npc=npc_slay, sight_npc=9000401)
    sub["named"] = True
    sub["handle"] = "Bold"
    s, _ = create("rareKills", sub, user)
    check("F3 named slay accepted", s == 200, f"status {s}")
    entries = poll(lambda: slayers_for(npc_slay) or None)
    check("F3 giantSlayers entry", bool(entries) and len(entries) == 1
          and entries[0].get("handle") == "Bold" and entries[0].get("tier") == "giantslayer"
          and isinstance(entries[0].get("pct"), int) and entries[0]["pct"] < 50,
          f"entries {entries}")

    # F4: implausible snap (recomputed p >= 0.5) -> NO entry despite claimed p=0.1
    npc_easy = 9000302
    sub = baseline("fslayer0002", npc=npc_easy, sight_npc=9000402)
    sub["named"] = True
    sub["handle"] = "Spoofer"
    sub["events"][1] = {"k": "slay", "npc": npc_easy, "p": 0.1,
                        "snap": {"pLevel": 60, "cLevel": 10, "cls": "normal"},
                        "mode": "pve", "season": "s0"}
    s, _ = create("rareKills", sub, user)
    check("F4 write accepted", s == 200, f"status {s}")
    # wait until its death rollup landed, then assert no slayer entry was created
    poll(lambda: get_doc(f"rareKillCounts/{npc_easy}")[1])
    check("F4 implausible slay earns nothing", slayers_for(npc_easy) == [],
          f"{slayers_for(npc_easy)}")

    # F5: no snap -> fail closed
    npc_nosnap = 9000303
    sub = baseline("fslayer0003", npc=npc_nosnap, sight_npc=9000403)
    sub["named"] = True
    sub["handle"] = "NoSnap"
    sub["events"][1] = {"k": "slay", "npc": npc_nosnap, "p": 0.1, "mode": "pve", "season": "s0"}
    s, _ = create("rareKills", sub, user)
    poll(lambda: get_doc(f"rareKillCounts/{npc_nosnap}")[1])
    check("F5 snapless slay earns nothing", slayers_for(npc_nosnap) == [],
          f"{slayers_for(npc_nosnap)}")

    # F10: rate limit - 20/day per clientId; the 21st is dropped before any rollup
    npc_rl = 9000501
    for i in range(21):
        create("rareKills", {"v": 1, "kinds": ["death"], "season": "s0",
                             "clientId": "ratelimit01",
                             "events": [{"k": "death", "npc": npc_rl, "mode": "pve",
                                         "season": "s0"}]}, user)
    tally = poll(lambda: (lambda d: d if d and (d.get("counts") or {}).get("pve", 0) >= 20
                          else None)(get_doc(f"rareKillMeta/tally-{npc_rl}", "owner")[1]),
                 timeout=90)
    time.sleep(3)  # let any stray 21st trigger finish before the final read
    _, tally = get_doc(f"rareKillMeta/tally-{npc_rl}", "owner")
    check("F10 rate limit caps rollups at 20",
          bool(tally) and (tally.get("counts") or {}).get("pve") == 20, f"tally {tally}")

    # F12: an event with a stray key is skipped; the rest of the batch still lands
    npc_mixed = 9000601
    sub = {"v": 1, "kinds": ["death"], "season": "s0", "clientId": "fmixed0001",
           "events": [
               {"k": "death", "npc": npc_mixed, "mode": "pve", "season": "s0", "who": "Alta"},
               {"k": "death", "npc": npc_mixed, "mode": "pve", "season": "s0"},
           ]}
    s, _ = create("rareKills", sub, user)
    check("F12 write accepted", s == 200, f"status {s}")
    tally = poll(lambda: get_doc(f"rareKillMeta/tally-{npc_mixed}", "owner")[1])
    check("F12 stray-key event skipped, clean one lands",
          bool(tally) and (tally.get("counts") or {}).get("pve") == 1, f"tally {tally}")

    print()
    print(f"emulator tests: {len(PASS)} passed, {len(FAIL)} failed")
    for f in FAIL:
        print("  FAILED: " + f)
    return 1 if FAIL else 0


if __name__ == "__main__":
    sys.exit(main())
