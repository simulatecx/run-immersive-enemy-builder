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

-- Pure: banner title per classification (headless-tested).
local TITLES = {
    worldboss = "BOSS NEARBY", rareelite = "RARE ELITE NEARBY",
    rare = "RARE NEARBY", elite = "ELITE NEARBY",
}
function Nearby.titleFor(classification)
    return TITLES[classification] or "ENEMY NEARBY"
end

-- Pure: which settings key gates this classification's ping?
function Nearby.settingFor(classification)
    local tier = RUN.Detect.tierOf(classification)
    if tier == "unique" then return "pingUnique" end
    if tier == "elite" then return "pingElite" end
    return "pingNormal"
end

-- Pure: gate + title for a full info table. Quest targets and NOTORIOUS
-- species ("soft elites" - normals with a body count) outrank their
-- classification: a plain mob that has killed enough players earns the
-- banner real elites get.
function Nearby.gateFor(info)
    if info and info.quest then return "pingQuest" end
    if info and info.notorious then return "pingUnique" end
    return Nearby.settingFor(info and info.classification)
end

function Nearby.bannerTitle(info)
    if info and info.quest then return "QUEST TARGET NEARBY" end
    if info and info.notorious then return "NOTORIOUS ENEMY NEARBY" end
    return Nearby.titleFor(info and info.classification)
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
    local noto = RUN.Notoriety.describe(info.npcID, info.classification)
    if noto.softElite then info.notorious = true end
    if not RUN.Settings.get(Nearby.gateFor(info)) then return end
    if alreadyPinged(info.guid or info.npcID) then return end

    local line = Nearby.rankLine(noto.kills, noto.heard)
    if noto.title then
        line = "\"" .. noto.title .. "\" - " .. line
    end
    if info.quest and info.quest ~= "" then
        line = "for " .. info.quest .. " - " .. line
    end
    local title = Nearby.bannerTitle(info)

    -- the sightings harvest: a real rare+ seen = a named, located species
    if RUN.Detect.isNotable(info.classification) then
        if mapID and x and y then
            RUN.Detect.recordSighting(info, mapID, x, y)
        else
            RUN.Detect.recordSighting(info, RUN.Waypoint.playerPos())
        end
    end

    local r, g, b
    if noto.tier >= 1 then r, g, b = RUN.Notoriety.colorFor(noto.tier) end
    RUN.Alert.show(title .. ": " .. tostring(info.name or "Unknown"), line, r, g, b)
    RUN.print(title:lower() .. ": " .. tostring(info.name or "Unknown") .. " - " .. line)

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

-- Signal 1: nameplates. Any hostile qualifies; Nearby.ping applies the
-- per-tier option gates (pingNormal / pingElite / pingUnique).
RUN.on("NAME_PLATE_UNIT_ADDED", function(unit)
    if not RUN.Settings.get("nearbyPing") then return end
    local info = RUN.Detect.unitInfo(unit)
    if info and info.hostile and not info.dead and not info.isPlayer then
        info.quest = RUN.Quests.isTarget(info.name)
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
