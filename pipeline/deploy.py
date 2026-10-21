"""Deploy RUN to the local WoW installs - gate first, then copy.

Default targets cover BOTH flavors: the Forever beta install and the Classic
Era install (the Hardcore fork). One folder copy serves both - the client
picks its TOC by flavor suffix (RUN.toc on Forever/mainline, RUN_Vanilla.toc
on Classic Era), so the copy always includes every TOC.

Usage: python deploy.py [--target <AddOns\\RUN path>] [--skip-gate]
The gate (compliance + selftest, both TOCs) must be green before any copy;
a red gate blocks the deploy outright.
"""

from __future__ import annotations

import argparse
import shutil
import subprocess
import sys
from pathlib import Path

ADDON_SRC = Path(__file__).parent.parent / "RUN"
DEFAULT_TARGETS = [
    Path(r"D:\Games\World of Warcraft\_classic_beta_\Interface\AddOns\RUN"),
    # Classic Era (Hardcore fork): same folder, client loads RUN_Vanilla.toc.
    Path(r"D:\Games\World of Warcraft\_classic_era_\Interface\AddOns\RUN"),
]


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--target", type=Path, default=None)
    parser.add_argument("--skip-gate", action="store_true",
                        help="emergency only; the gate is the point")
    args = parser.parse_args()

    if not args.skip_gate:
        gate = subprocess.run(
            [sys.executable, str(Path(__file__).parent / "run_tests.py")],
            capture_output=True, text=True,
        )
        if gate.returncode != 0:
            print("GATE RED - deploy blocked:\n" + gate.stdout + gate.stderr)
            return 1
        print(gate.stdout.strip().splitlines()[-1])

    targets = [args.target] if args.target else [t for t in DEFAULT_TARGETS if t.parent.exists()]
    if not targets:
        print("no deploy target found - pass --target <...\\Interface\\AddOns\\RUN>")
        return 1

    for target in targets:
        if target.exists():
            shutil.rmtree(target)
        shutil.copytree(ADDON_SRC, target, ignore=shutil.ignore_patterns("*.pyc"))
        files = len(list(target.rglob("*.*")))
        print(f"deployed {files} files -> {target}")
    print("in-game: /reload (or relog), then /ra selftest")
    return 0


if __name__ == "__main__":
    sys.exit(main())
