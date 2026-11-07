"""RUN compliance gate - the first step of the ship gate.

Statically scans RUN/**/*.lua for anything that could be construed as automation,
a sandbox escape, a taint vector, or a Lua 5.1 dialect violation. Red blocks the
ship. Justified false positives need `-- compliance-allow: <reason>` on the line.
Never weaken the banned list to make a feature fit; redesign the feature.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

ADDON_DIR = Path(__file__).parent.parent / "RUN"

# Protected-action / automation calls: display-and-advice only, always.
BANNED_CALLS = [
    r"\bCastSpell\w*\s*\(", r"\bCastShapeshiftForm\s*\(", r"\bTargetUnit\s*\(",
    r"\bTargetNearest\w*\s*\(", r"\bAttackTarget\s*\(", r"\bStartAttack\s*\(",
    r"\bPetAttack\s*\(", r"\bUseItem\w*\s*\(", r"\bUseContainerItem\s*\(",
    r"\bUseInventoryItem\s*\(", r"\bRunMacro\w*\s*\(", r"\bRunBinding\s*\(",
    r"\bMoveForward\w*\s*\(", r"\bMoveBackward\w*\s*\(", r"\bTurnLeft\w*\s*\(",
    r"\bTurnRight\w*\s*\(", r"\bJumpOrAscend\w*\s*\(", r"\bFollowUnit\s*\(",
    r"\bAcceptQuest\s*\(", r"\bInteractUnit\s*\(",
]

# Sandbox escapes + taint hazards.
BANNED_ESCAPES = [
    r"\bos\s*\.", r"\bio\s*\.", r"\brequire\s*\(", r"\bloadstring\s*\(",
    r"\bdofile\s*\(", r"\bloadfile\s*\(",
    r"\bmath\.random\b", r"\bmath\.randomseed\b",
    r"C_SpecializationInfo\s*[.(]",
]

# Taint law: never write onto / parent into / anchor onto Blizzard frames.
# Two incident-to-gate defences:
#  * Minimap:CreateTexture/FontString - the 2026-11-06 load taint: creating
#    REGIONS on the secure Minimap taints the EditMode layout.
#  * SetPoint(... TargetFrame/PlayerFrame ...) - the 2026-11-06 reload taint:
#    tethering an insecure frame TO a secure unit frame taints its layout and
#    blocks the next target/player-frame secure action ("RUN has been blocked").
# Our own frames are free overlays on UIParent; pins go through HereBeDragons-
# Pins, which parents its OWN frames (that is fine).
BANNED_TAINT = [
    r"\bTargetFrame\s*\.\s*[A-Za-z_]\w*\s*=",
    r"\bPlayerFrame\s*\.\s*[A-Za-z_]\w*\s*=",
    r"\bMinimap\s*\.\s*[A-Za-z_]\w*\s*=",
    r"SetParent\s*\(\s*TargetFrame", r"SetParent\s*\(\s*PlayerFrame",
    r'CreateFrame\s*\([^)]*,\s*TargetFrame\s*[,)]',
    r"SetPoint\s*\([^)]*\bTargetFrame\b", r"SetPoint\s*\([^)]*\bPlayerFrame\b",
    r"\bMinimap\s*:\s*CreateTexture\b", r"\bMinimap\s*:\s*CreateFontString\b",
]

# Lua 5.1 dialect: the client's Lua. The harness runs newer Lua, so constructs
# that differ are banned outright.
DIALECT = [
    (r"\bgoto\b", "goto (not in 5.1)"),
    (r"::\s*[A-Za-z_]\w*\s*::", "label (not in 5.1)"),
    (r"(?<!:)(?<!/)//(?!/)", "integer division // (not in 5.1)"),
    (r"(?<![<>=~])<<", "bit shift << (not in 5.1)"),
    (r">>(?![>=])", "bit shift >> (not in 5.1)"),
    (r"(?<=[\w\s)])&(?=[\w\s(])", "bitwise & (not in 5.1)"),
]

ALLOW = "compliance-allow:"


def strip_lua(text: str) -> str:
    """Remove comments and string literals so scans see only code."""
    out, i, n = [], 0, len(text)
    while i < n:
        ch = text[i]
        two = text[i:i + 2]
        if two == "--":
            if text[i + 2:i + 4] == "[[":
                end = text.find("]]", i + 4)
                i = n if end == -1 else end + 2
            else:
                end = text.find("\n", i)
                i = n if end == -1 else end  # keep the newline
            out.append(" ")
            continue
        if ch in "'\"":
            q, j = ch, i + 1
            while j < n:
                if text[j] == "\\":
                    j += 2
                    continue
                if text[j] == q:
                    break
                j += 1
            out.append('""')
            i = j + 1
            continue
        if two == "[[":
            end = text.find("]]", i + 2)
            out.append('""')
            i = n if end == -1 else end + 2
            continue
        out.append(ch)
        i += 1
    return "".join(out)


def scan() -> int:
    problems = []
    # Libs/ is vendored third-party (HereBeDragons stack) - keeps its own
    # license + conventions; RUN's house laws apply only to RUN's own code.
    files = [f for f in sorted(ADDON_DIR.rglob("*.lua"))
             if "Libs" not in f.relative_to(ADDON_DIR).parts]
    if not files:
        print("COMPLIANCE RED: no lua files found under RUN/")
        return 1
    rules = (
        [(p, "automation") for p in BANNED_CALLS]
        + [(p, "sandbox-escape") for p in BANNED_ESCAPES]
        + [(p, "taint") for p in BANNED_TAINT]
        + [(p, f"dialect: {label}") for p, label in DIALECT]
    )
    for path in files:
        raw_lines = path.read_text(encoding="utf-8").splitlines()
        code_lines = strip_lua("\n".join(raw_lines)).splitlines()
        for lineno, (code, raw) in enumerate(zip(code_lines, raw_lines), 1):
            if ALLOW in raw:
                continue
            for pattern, kind in rules:
                if re.search(pattern, code):
                    rel = path.relative_to(ADDON_DIR.parent)
                    problems.append(f"{rel}:{lineno} [{kind}] {raw.strip()[:90]}")
    if problems:
        print(f"COMPLIANCE RED - {len(problems)} finding(s):")
        for p in problems:
            print("  " + p)
        return 1
    print(f"compliance green ({len(files)} files scanned)")
    return 0


if __name__ == "__main__":
    sys.exit(scan())
