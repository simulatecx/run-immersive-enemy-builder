-- Waypoints: the Blizzard supertracked pin (the native arrow), plus TomTom when
-- present. BETA honesty note: the client cannot read another unit's coordinates,
-- and the rares DB ships empty in 0.1.0 - so marking drops the pin AT YOUR FEET
-- ("this is where I saw it / where I need to run back to"). DB-known rares get
-- true coordinates once gen_rares.py lands. Map-pin APIs are display-only and
-- unprotected: fully compliant.

local _, RUN = ...
if not RUN then RUN = _G.RunAdvisor or {}; _G.RunAdvisor = RUN end

local Waypoint = {}
RUN.Waypoint = Waypoint

if not _G.CreateFrame then return Waypoint end

local Guards = RUN.Guards

-- Set the supertracked waypoint at map position (mapID, x, y in 0..1).
function Waypoint.setAt(mapID, x, y, label)
    if not (_G.C_Map and _G.UiMapPoint and _G.C_SuperTrack) then return false end
    local ok = pcall(function()
        _G.C_Map.ClearUserWaypoint()
        local point = _G.UiMapPoint.CreateFromCoordinates(mapID, x, y)
        _G.C_Map.SetUserWaypoint(point)
        _G.C_SuperTrack.SetSuperTrackedUserWaypoint(true)
    end)
    if ok and _G.TomTom and _G.TomTom.AddWaypoint then
        pcall(_G.TomTom.AddWaypoint, _G.TomTom, mapID, x, y,
            { title = label or "RUN", persistent = false, minimap = true, world = true })
    end
    return ok
end

-- The player's current map position (also feeds the sightings harvest).
function Waypoint.playerPos()
    local mapID = Guards.call(_G.C_Map and _G.C_Map.GetBestMapForUnit, "player")
    if not mapID then return nil end
    local pos = Guards.call(_G.C_Map.GetPlayerMapPosition, mapID, "player")
    if not pos then return nil end
    local okXY, x, y = pcall(pos.GetXY, pos)
    if not okXY or not x then return nil end
    return mapID, x, y
end

-- Mark the player's current position (see the honesty note above).
function Waypoint.markHere(label)
    local mapID, x, y = Waypoint.playerPos()
    if not mapID then
        RUN.print("no map coordinates available in this area.")
        return false
    end
    if Waypoint.setAt(mapID, x, y, label) then
        RUN.print("marked this spot - the map arrow points back here. /ra clear removes it.")
        return true
    end
    return false
end

-- Mark a known rare's position: curated/generated coords first, then the
-- sightings harvest (where a player of this account last SAW it).
function Waypoint.markKnown(npcID)
    local known = RUN.raresMerged and RUN.raresMerged()[npcID]
    if known and known.zone and known.x and known.y then
        return Waypoint.setAt(known.zone, known.x, known.y, known.name or "RUN rare")
    end
    local seen = RUN.Detect.sightingFor(npcID)
    if seen and seen.mapID and seen.x and seen.y then
        return Waypoint.setAt(seen.mapID, seen.x, seen.y, seen.name or "RUN rare")
    end
    return false
end

function Waypoint.clear()
    if _G.C_Map and _G.C_Map.ClearUserWaypoint then pcall(_G.C_Map.ClearUserWaypoint) end
    RUN.print("waypoint cleared.")
end

-- Passive auto-mark: a NOTABLE (rare+) sighting drops the pin once per creature,
-- from whichever surface saw it first (tooltip flag or the odds panel).
local lastMarkGuid
function Waypoint.autoMarkFor(info)
    if not RUN.Settings.get("autoMark") then return end
    if not info or not info.notable or info.dead then return end
    if info.guid and info.guid == lastMarkGuid then return end
    lastMarkGuid = info.guid
    Waypoint.markHere(info.name or "RUN rare")
end

return Waypoint
