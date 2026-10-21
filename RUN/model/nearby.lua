-- The nearby-rare ping: sense a rare BEFORE you look at it. Two signals:
--   1. NAME_PLATE_UNIT_ADDED - fires when any enemy nameplate spawns in range
--      (~60yd), even behind you. Reliable, but needs enemy nameplates enabled.
--   2. C_VignetteInfo - the mainline "silver dragon on the minimap" system.
--      The API exists on Forever; whether classic-era rares EMIT vignettes is
--      unverified - wired defensively as a bonus (and it gives TRUE coords).
-- Ping = banner + sound + kill-rank line + auto-mark. Once per creature.
-- Display-only throughout.

local _, RUN = ...
if not RUN then RUN = _G.RunAdvisor or {}; _G.RunAdvisor = RUN end

local Nearby = {}
RUN.Nearby = Nearby

-- Pure: the rank/body-count line for a ping (headless-tested).
function Nearby.rankLine(kills, heard)
    kills = tonumber(kills) or 0
    heard = tonumber(heard) or 0
    local rank = RUN.Attribution.rankForKills(kills + heard)
    if not rank then return "no recorded kills yet" end
    local bits = {}
    if kills > 0 then table.insert(bits, "killed you " .. kills .. "x") end
    if heard > 0 then table.insert(bits, heard .. " deaths heard") end
    return rank.label .. " - " .. table.concat(bits, " + ")
end

if not _G.CreateFrame then return Nearby end

local Guards = RUN.Guards
local seen = {}   -- [guid or npcID] = GetTime() of last ping (10 min cooldown)

local function alreadyPinged(key)
    if not key then return false end
    local now = _G.GetTime and _G.GetTime() or 0
    if seen[key] and (now - seen[key]) < 600 then return true end
    seen[key] = now
    return false
end

function Nearby.ping(info, mapID, x, y)
    if not RUN.Settings.get("nearbyPing") then return end
    if alreadyPinged(info.guid or info.npcID) then return end

    local kills = RUN.Attribution.killsBy(info.npcID)
    local heard = RUN.Deathping.heardBy(info.npcID)
    local line = Nearby.rankLine(kills, heard)

    RUN.Alert.show("RARE NEARBY: " .. tostring(info.name or "Unknown"), line)
    RUN.print("rare nearby: " .. tostring(info.name or "Unknown") .. " - " .. line)

    -- true coords from a vignette beat "at your feet"
    if mapID and x and y then
        if RUN.Settings.get("autoMark") then
            RUN.Waypoint.setAt(mapID, x, y, info.name or "RUN rare")
            RUN.print("marked its position - follow the map arrow.")
        end
    else
        RUN.Waypoint.autoMarkFor(info)
    end
end

-- Signal 1: nameplates.
RUN.on("NAME_PLATE_UNIT_ADDED", function(unit)
    if not RUN.Settings.get("nearbyPing") then return end
    local info = RUN.Detect.unitInfo(unit)
    if info and info.hostile and info.notable and not info.dead then
        Nearby.ping(info)
    end
end)

-- Signal 2: vignettes (defensive - may simply never fire on Forever).
RUN.on("VIGNETTE_MINIMAP_UPDATED", function(vignetteGUID)
    if not RUN.Settings.get("nearbyPing") then return end
    local CV = _G.C_VignetteInfo
    if not (CV and CV.GetVignetteInfo) then return end
    local ok, v = pcall(CV.GetVignetteInfo, vignetteGUID)
    if not ok or type(v) ~= "table" then return end
    local npcID = RUN.Detect.npcIdFromGUID(v.objectGUID)
    local info = {
        guid = v.objectGUID, npcID = npcID,
        name = v.name, classification = "rare", notable = true,
    }
    local mapID = Guards.call(_G.C_Map and _G.C_Map.GetBestMapForUnit, "player")
    local x, y
    if mapID and CV.GetVignettePosition then
        local okP, pos = pcall(CV.GetVignettePosition, vignetteGUID, mapID)
        if okP and pos then
            local okXY, px, py = pcall(pos.GetXY, pos)
            if okXY then x, y = px, py end
        end
    end
    Nearby.ping(info, mapID, x, y)
end)

-- One-time nudge: the nameplate signal needs enemy nameplates on.
RUN.on("PLAYER_LOGIN", function()
    local v = Guards.call(_G.GetCVar, "nameplateShowEnemies")
    if v == "0" then
        RUN.print("tip: enable enemy nameplates (default key V) so RUN can sense rares near you before you see them.")
    end
end)

return Nearby
