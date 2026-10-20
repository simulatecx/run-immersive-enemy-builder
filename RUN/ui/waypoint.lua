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

-- Mark the player's current position (see the honesty note above).
function Waypoint.markHere(label)
    local mapID = Guards.call(_G.C_Map and _G.C_Map.GetBestMapForUnit, "player")
    if not mapID then
        RUN.print("can't resolve your map position here.")
        return false
    end
    local pos = Guards.call(_G.C_Map.GetPlayerMapPosition, mapID, "player")
    if not pos then
        RUN.print("no map coordinates available in this area.")
        return false
    end
    local okXY, x, y = pcall(pos.GetXY, pos)
    if not okXY or not x then
        RUN.print("no map coordinates available in this area.")
        return false
    end
    if Waypoint.setAt(mapID, x, y, label) then
        RUN.print("marked this spot - the map arrow points back here. /ra clear removes it.")
        return true
    end
    return false
end

-- Mark a DB-known rare's true position (used once the rares table has coords).
function Waypoint.markKnown(npcID)
    local known = RUN.raresMerged and RUN.raresMerged()[npcID]
    if known and known.zone and known.x and known.y then
        return Waypoint.setAt(known.zone, known.x, known.y, known.name or "RUN rare")
    end
    return false
end

function Waypoint.clear()
    if _G.C_Map and _G.C_Map.ClearUserWaypoint then pcall(_G.C_Map.ClearUserWaypoint) end
    RUN.print("waypoint cleared.")
end

return Waypoint
