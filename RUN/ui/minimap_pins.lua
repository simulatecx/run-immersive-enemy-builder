-- Minimap blips: a tier-coloured dot where a rare / elite / notorious creature
-- was seen. Positioning is handled by HereBeDragons-Pins (Libs/) - the SAME
-- engine RareScanner and the rest of the ecosystem use - so RUN's pins behave
-- consistently with every other addon (zoom, rotation, indoor/outdoor, shape,
-- edge handling, map transforms) and RUN maintains none of that math itself.
--
-- RUN owns only the LIFECYCLE: pool a pin frame per sighting, hand it to
-- HBD-Pins at the creature's map coords, tint it by tier, expire it after 10
-- minutes. Session-transient (no SavedVariables change), behind the minimapPins
-- option. Fed by the nearby ping. Display-only; the stock minimap is untouched
-- (HBD-Pins parents its OWN frames - RUN never creates regions on the Minimap).

local _, RUN = ...
if not RUN then RUN = _G.RunAdvisor or {}; _G.RunAdvisor = RUN end

local MinimapPins = {}
RUN.MinimapPins = MinimapPins

-- Pure: dedup key for a sighting, and the 10-minute expiry test. (The hard
-- placement math now lives in HereBeDragons-Pins, not here.)
local EXPIRE_SECONDS = 600
function MinimapPins.pinKey(npcID, name, x, y)
    return npcID or name or (tostring(x) .. ":" .. tostring(y))
end
function MinimapPins.expired(when, now)
    return ((tonumber(now) or 0) - (tonumber(when) or 0)) > EXPIRE_SECONDS
end

-- Selftests (registered): RUN's own lifecycle logic. HBD-Pins' positioning is
-- the library's responsibility (and is exercised live, not headless).
if type(RUN.selftestChecks) == "table" then
    table.insert(RUN.selftestChecks, function(check)
        check("pins key prefers npcID, falls back to name then coords",
            MinimapPins.pinKey(7024, "Rare", 0.5, 0.6) == 7024
            and MinimapPins.pinKey(nil, "Rare", 0.5, 0.6) == "Rare"
            and MinimapPins.pinKey(nil, nil, 0.5, 0.6) == "0.5:0.6")
        check("pins expire after the 10-minute window", MinimapPins.expired(0, 601) == true
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
    p:SetSize(14, 14)
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

-- Record a sighting to blip. Called by the nearby ping with the best position
-- we have (vignette coords, else the player's spot) - normalized map coords.
function MinimapPins.add(npcID, name, mapID, x, y, tier)
    if not HBDPins or not RUN.Settings.get("minimapPins") then return end
    x, y = tonumber(x), tonumber(y)
    if not (mapID and x and y) then return end
    local key = MinimapPins.pinKey(npcID, name, x, y)
    local e = active[key]
    if not e then e = { pin = acquirePin() }; active[key] = e end
    local r, g, b = RUN.Notoriety.colorFor(tonumber(tier) or 0)
    e.pin.tex:SetVertexColor(r, g, b)
    e.when = (_G.GetTime and _G.GetTime()) or 0
    HBDPins:RemoveMinimapIcon(MinimapPins, e.pin)   -- clean reposition if re-pinged
    HBDPins:AddMinimapIconMap(MinimapPins, e.pin, mapID, x, y, false, false)
    e.pin:Show()
end

-- Expire old pins + honour the toggle, through the firewall ticker. HBD-Pins
-- drives the per-frame positioning itself, so RUN only needs this slow sweep.
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
