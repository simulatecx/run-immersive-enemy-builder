-- Minimap blips: a subtle, tier-coloured dot that TRACKS a rare / elite as it
-- moves on the minimap - fed by the live vignette (the same true-position source
-- RareScanner uses). Positioning is handled by HereBeDragons-Pins (Libs/) - the
-- SAME engine RareScanner and the rest of the ecosystem use - so RUN's pins
-- behave consistently with every other addon (zoom, rotation, indoor/outdoor,
-- shape, edge handling, map transforms) and RUN maintains none of that math.
--
-- RUN owns only the LIFECYCLE: one dot per tracked vignette (keyed by its GUID),
-- (re)placed at the rare's CURRENT coords on every update so it FOLLOWS the rare,
-- tinted by tier, retired when the vignette leaves the minimap (or after a 10-min
-- safety expiry). The dot NEVER lands at the player's own position - no true
-- coords means no dot. Session-transient (no SavedVariables change), behind the
-- minimapPins option. Display-only; the stock minimap is untouched (HBD-Pins
-- parents its OWN frames - RUN never creates regions on the Minimap).

local _, RUN = ...
if not RUN then RUN = _G.RunAdvisor or {}; _G.RunAdvisor = RUN end

local MinimapPins = {}
RUN.MinimapPins = MinimapPins

-- Pure: the 10-minute safety expiry test (backstop for a vignette whose "gone"
-- event we somehow miss). The hard placement math lives in HereBeDragons-Pins.
local EXPIRE_SECONDS = 600
function MinimapPins.expired(when, now)
    return ((tonumber(now) or 0) - (tonumber(when) or 0)) > EXPIRE_SECONDS
end

-- Selftests (registered): RUN's own lifecycle logic. HBD-Pins' positioning is
-- the library's responsibility (and is exercised live, not headless).
if type(RUN.selftestChecks) == "table" then
    table.insert(RUN.selftestChecks, function(check)
        check("pins expire after the 10-minute safety window",
            MinimapPins.expired(0, 601) == true
            and MinimapPins.expired(0, 599) == false
            and MinimapPins.expired(nil, 0) == false)
    end)
end

-- Everything below wires the client.
if not _G.CreateFrame then return MinimapPins end

-- The ecosystem-standard pin engine (vendored in Libs/). Presence-detected so
-- the headless gate (which never loads Libs) degrades to a silent no-op.
local HBDPins = _G.LibStub and _G.LibStub("HereBeDragons-Pins-2.0", true)

local active = {}   -- [key] = { pin = frame, when = seconds }
local pool = {}     -- reusable pin frames (NOT children of the Minimap)

local function acquirePin()
    local p = table.remove(pool)
    if p then return p end
    p = CreateFrame("Frame", nil, _G.UIParent)   -- HBD-Pins reparents to its own layer
    p:SetSize(12, 12)
    p:SetAlpha(0.85)                              -- subtle: a soft marker, not a flare
    local tex = p:CreateTexture(nil, "OVERLAY")
    tex:SetAllPoints()
    tex:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask")
    tex:SetBlendMode("ADD")
    p.tex = tex
    return p
end

local function releasePin(p)
    if HBDPins then HBDPins:RemoveMinimapIcon(MinimapPins, p) end
    p:Hide()
    pool[#pool + 1] = p
end

-- Place OR REPOSITION the tracking dot for `key` at the given map coords. Called
-- on every vignette update, so the dot follows the rare across the minimap. Keyed
-- by the vignette GUID (one dot per live sighting). Gated by minimapPins so it is
-- independent of the louder banner.
function MinimapPins.place(key, mapID, x, y, tier)
    if not HBDPins or not key or not RUN.Settings.get("minimapPins") then return end
    x, y = tonumber(x), tonumber(y)
    if not (mapID and x and y) then return end
    local e = active[key]
    if not e then e = { pin = acquirePin() }; active[key] = e end
    local r, g, b = RUN.Notoriety.colorFor(tonumber(tier) or 0)
    e.pin.tex:SetVertexColor(r, g, b)
    e.when = (_G.GetTime and _G.GetTime()) or 0
    HBDPins:RemoveMinimapIcon(MinimapPins, e.pin)   -- clean reposition as it moves
    HBDPins:AddMinimapIconMap(MinimapPins, e.pin, mapID, x, y, false, false)
    e.pin:Show()
end

-- Retire the tracking dot for `key` (its vignette left the minimap).
function MinimapPins.remove(key)
    local e = key and active[key]
    if not e then return end
    releasePin(e.pin)
    active[key] = nil
end

-- Expire stale dots + honour the toggle, through the firewall ticker. HBD-Pins
-- drives the per-frame positioning itself; this is only the slow safety sweep
-- for a vignette whose removal event we missed.
RUN.ticker("minimap-pins", 5, function()
    if not HBDPins then return end
    local now = (_G.GetTime and _G.GetTime()) or 0
    local on = RUN.Settings.get("minimapPins")
    for key, e in pairs(active) do
        if not on or MinimapPins.expired(e.when, now) then
            releasePin(e.pin)
            active[key] = nil
        end
    end
end)

return MinimapPins
