## 1.2.3 - sturdier death attribution (Hardcore audit)

A hardening pass after cross-checking our death code against the Hardcore addon.
On WoW: Forever even a target's name can be a protected ("secret") value, and
using one can error - which could drop a death's killer. RUN now guards those
reads the same way Hardcore does: a hidden or missing attacker name falls back to
"an unknown enemy" instead of being lost. No change to how you play; deaths just
record more reliably in PvP and on Forever.

Works on WoW: Forever (1.60.x) and Classic Era (1.15.x). Display-and-advice only,
official APIs only, never networks - you auto-update through your addon manager.
