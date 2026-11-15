## 1.2.2 - record PvP deaths + name the killer

Deaths to another player are now recorded and show who killed you. Before, a
player-vs-player death often logged as "unknown cause": on WoW: Forever the PvP
combat log can be hidden from addons, and RUN's fallback (your target when you
were hit) deliberately ignored players. Now that fallback includes players, so
the enemy you're fighting is credited - "/ra deaths" shows "<Player> (another
player)" with your zone and level.

Heads-up on the limits: if you're jumped by someone you never targeted (a
stealth gank from behind), there may be no readable signal and it can still log
as unknown - that's a hard client restriction, not something RUN can see around.

Works on WoW: Forever (1.60.x) and Classic Era (1.15.x). Display-and-advice only,
official APIs only, never networks - you auto-update through your addon manager.
