"""RUN headless ship gate: compliance scan, then load the addon in a Lua VM
(lupa) exactly as the TOC orders it and run the selftest. THE gate for any
addon-logic change; also runs in-game via /ra selftest.

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
TOC = ADDON_DIR / "RUN.toc"


def toc_files() -> list[Path]:
    files = []
    for line in TOC.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("##"):
            continue
        files.append(ADDON_DIR / line.replace("\\", "/"))
    return files


def toc_version() -> str:
    m = re.search(r"^## Version:\s*(\S+)", TOC.read_text(encoding="utf-8"), re.M)
    return m.group(1) if m else ""


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

    # 2) load the addon headless.
    try:
        from lupa import LuaRuntime
    except ImportError:
        print("GATE RED: lupa not installed (pip install lupa)")
        return 1

    lua = LuaRuntime(unpack_returned_tuples=True)
    loader = lua.eval(
        "function(code, name)\n"
        "  local f, err = (load or loadstring)(code, name)\n"
        "  if not f then error(name .. ': ' .. tostring(err)) end\n"
        "  return f\n"
        "end"
    )
    shared = lua.table()
    for path in toc_files():
        if not path.exists():
            print(f"GATE RED: TOC lists missing file {path.name}")
            return 1
        chunk = loader(path.read_text(encoding="utf-8"), "@" + path.name)
        chunk("RUN", shared)

    # 3) version sync: TOC ## Version must equal RUN.version.
    if toc_version() != shared.version:
        print(f"GATE RED: version drift - TOC {toc_version()!r} vs init {shared.version!r}")
        return 1

    # 4) selftest.
    passed, failures = shared.selftest()
    fail_list = list(failures.values()) if failures is not None else []
    if fail_list:
        print(f"GATE RED: selftest {passed} passed, {len(fail_list)} FAILED:")
        for f in fail_list:
            print("  - " + str(f))
        return 1

    print(f"gate green: selftest {passed}/{passed}, version {shared.version}, "
          f"{len(toc_files())} files loaded")
    return 0


if __name__ == "__main__":
    sys.exit(main())
