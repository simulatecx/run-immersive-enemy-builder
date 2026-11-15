## 1.3.0 - PvP deaths in the feed (the full Hardcore treatment)

Until now the live death feed only carried deaths to creatures. Now, like the
Hardcore addon, player-vs-player deaths ride it too: when a RUN player on your
realm is cut down by another player, it scrolls past in red - "<Victim> was slain
by <Killer> in <Zone>."

- Both names are character names only (the killer's realm is stripped before it's
  ever sent), shown locally over the in-game RUN channel - never to any server.
- On by default with the feed; turn off "Name the fallen (eulogy mode)" for the
  monster-only view and PvP lines are hidden.
- PvP deaths stay a live, local thing - they have no creature, so they're never
  counted in the crowd data.

Works on WoW: Forever (1.60.x) and Classic Era (1.15.x). Display-and-advice only,
official APIs only, never networks - you auto-update through your addon manager.
