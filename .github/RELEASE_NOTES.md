## 0.9.10 - stability pass

Fixes a UI-blocked ("RUN has been blocked") message some players saw on every reload.
The odds panel used to pin itself to Blizzard's target frame when it had no saved
position; on a custom unit-frame UI that taints the target frame and gets the next
action blocked. The panel is now a free overlay - it opens near the target frame and
you drag it anywhere with /ra move (unlock with /ra move, drag, lock again).

Also under the hood: the minimap pins now ride on HereBeDragons-Pins, the same pin
engine other map addons use, so they place consistently with everything else.

Works on WoW: Forever (1.60.x) and Classic Era (1.15.x). Display-and-advice only,
official APIs only, never networks.
