"""RUN headless ship gate: compliance scan, then load the addon in a Lua VM
(lupa) exactly as each TOC orders it and run the selftest. THE gate for any
addon-logic change; also runs in-game via /ra selftest.

Gates BOTH flavors: RUN.toc (WoW: Forever, Interface 16001) and
RUN_Vanilla.toc (Classic Era, Interface 11508). Each TOC's file list loads
fresh in its OWN Lua runtime and runs the full selftest; version sync checks
every TOC's ## Version against RUN.version.

NOTE the dialect gap: the client is Lua 5.1, lupa is newer - the compliance
scan's dialect lint is what keeps us honest about constructs that differ.
"""

from __future__ import annotations

import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).parent.parent
ADDON_DIR = ROOT / "RUN"
TOCS = [ADDON_DIR / "RUN.toc", ADDON_DIR / "RUN_Vanilla.toc"]


def toc_files(toc: Path) -> list[Path]:
    files = []
    # utf-8-sig: tolerate a BOM (Windows editors add them silently)
    for line in toc.read_text(encoding="utf-8-sig").splitlines():
        line = line.strip()
        if not line or line.startswith("##"):
            continue
        files.append(ADDON_DIR / line.replace("\\", "/"))
    return files


def toc_version(toc: Path) -> str:
    m = re.search(r"^## Version:\s*(\S+)", toc.read_text(encoding="utf-8"), re.M)
    return m.group(1) if m else ""


def gate_toc(toc: Path):
    """Load one TOC's file list in a FRESH Lua runtime, check version sync,
    run the selftest. Returns (passed, file_count, version) or None (red)."""
    from lupa import LuaRuntime

    lua = LuaRuntime(unpack_returned_tuples=True)
    loader = lua.eval(
        "function(code, name)\n"
        "  local f, err = (load or loadstring)(code, name)\n"
        "  if not f then error(name .. ': ' .. tostring(err)) end\n"
        "  return f\n"
        "end"
    )
    shared = lua.table()
    files = toc_files(toc)
    for path in files:
        if not path.exists():
            print(f"GATE RED [{toc.name}]: TOC lists missing file {path.name}")
            return None
        try:
            chunk = loader(path.read_text(encoding="utf-8"), "@" + path.name)
            chunk("RUN", shared)
        except Exception as err:  # lua load/runtime error - name the file
            print(f"GATE RED [{toc.name}]: {path.name} failed to load: {err}")
            return None

    if toc_version(toc) != shared.version:
        print(f"GATE RED [{toc.name}]: version drift - TOC {toc_version(toc)!r} "
              f"vs init {shared.version!r}")
        return None

    passed, failures = shared.selftest()
    fail_list = list(failures.values()) if failures is not None else []
    if fail_list:
        print(f"GATE RED [{toc.name}]: selftest {passed} passed, {len(fail_list)} FAILED:")
        for f in fail_list:
            print("  - " + str(f))
        return None
    return passed, len(files), str(shared.version)


def main() -> int:
    # 1) compliance first - a red scan blocks everything else.
    comp = subprocess.run(
        [sys.executable, str(Path(__file__).parent / "check_compliance.py")],
        capture_output=True, text=True,
    )
    print(comp.stdout.strip())
    if comp.returncode != 0:
        print(comp.stderr.strip())
        return 1

    # 1b) crowd-schema drift gate: the generated mirrors (addon allow-list,
    # rules partial, web mirror) must match data/rare-kills-schema.json.
    drift = subprocess.run(
        [sys.executable, str(Path(__file__).parent / "gen_crowd_schema.py"), "--check"],
        capture_output=True, text=True,
    )
    if drift.returncode != 0:
        print("GATE RED: crowd-schema mirrors drifted - run gen_crowd_schema.py")
        print((drift.stdout or "").strip())
        print((drift.stderr or "").strip())
        return 1
    print("crowd-schema mirrors in sync")

    # 2) load + selftest EVERY flavor TOC, each in a fresh runtime.
    try:
        from lupa import LuaRuntime  # noqa: F401 - presence check only
    except ImportError:
        print("GATE RED: lupa not installed (pip install lupa)")
        return 1

    results = []
    for toc in TOCS:
        if not toc.exists():
            print(f"GATE RED: {toc.name} missing")
            return 1
        res = gate_toc(toc)
        if res is None:
            return 1
        results.append((toc.name, *res))

    # 3) flavors must agree on the addon version (both load the same init.lua,
    # and each TOC already matched its own ## Version against it).
    versions = {v for _, _, _, v in results}
    if len(versions) != 1:
        print(f"GATE RED: flavor version drift - {sorted(versions)}")
        return 1

    summary = ", ".join(f"{name} selftest {p}/{p} ({c} files)"
                        for name, p, c, _ in results)
    print(f"gate green: {summary}, version {results[0][3]}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
