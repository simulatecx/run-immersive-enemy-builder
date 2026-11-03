"""Package RUN for release - gate first, then zip.

Produces dist/RUN-v<version>-forever-and-era.zip with the RUN/ folder at the
zip root (extracts straight into Interface/AddOns/). ONE zip serves BOTH
flavors - it carries RUN.toc (Forever) and RUN_Vanilla.toc (Classic Era) and
the client picks. This is the file you upload to CurseForge (and hand to
beta testers).

Usage: python package.py [--skip-gate]

CurseForge upload reminders (printed on success):
  - mark BOTH game versions on the one file (Forever 1.60.x + Classic Era
    1.15.x);
  - changelog = the version's SPRINTS.md shipped entry;
  - publishing is OWNER-GATED, like every deploy.
"""

from __future__ import annotations

import argparse
import re
import subprocess
import sys
import zipfile
from pathlib import Path

ROOT = Path(__file__).parent.parent
ADDON_SRC = ROOT / "RUN"
DIST = ROOT / "dist"


def version() -> str:
    toc = (ADDON_SRC / "RUN.toc").read_text(encoding="utf-8-sig")
    m = re.search(r"^## Version:\s*(\S+)", toc, re.M)
    if not m:
        sys.exit("PACKAGE RED: no ## Version in RUN.toc")
    return m.group(1)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--skip-gate", action="store_true",
                        help="emergency only; the gate is the point")
    args = parser.parse_args()

    if not args.skip_gate:
        gate = subprocess.run(
            [sys.executable, str(Path(__file__).parent / "run_tests.py")],
            capture_output=True, text=True,
        )
        if gate.returncode != 0:
            print("GATE RED - package blocked:\n" + gate.stdout + gate.stderr)
            return 1
        print(gate.stdout.strip().splitlines()[-1])

    ver = version()
    DIST.mkdir(exist_ok=True)
    out = DIST / f"RUN-v{ver}-forever-and-era.zip"
    files = sorted(p for p in ADDON_SRC.rglob("*") if p.is_file())
    with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
        for p in files:
            z.write(p, Path("RUN") / p.relative_to(ADDON_SRC))
    print(f"packaged {len(files)} files -> {out}")
    print("CurseForge upload: mark BOTH game versions (Forever 1.60.x + "
          "Classic Era 1.15.x) on this one file; changelog = the "
          f"v{ver} SPRINTS.md entry; publish is owner-gated.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
