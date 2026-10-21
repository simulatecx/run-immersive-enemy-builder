-- Group wipes: "X has killed Y raids." Two signals: ENCOUNTER_END with
-- success=0 (bosses tell us outright), and group-death correlation for the
-- open world (>=80% of the group dead inside a 20s window). Local-first; the
-- crowd phase adds server-side k-of-n before any public counter. Pure core.

local _, RUN = ...
if not RUN then RUN = _G.RunAdvisor or {}; _G.RunAdvisor = RUN end

local Wipes = {}
RUN.Wipes = Wipes

local WINDOW = 20

-- Pure: is this a wipe? deaths = list of timestamps, size = group size.
function Wipes.isWipe(deathTimes, groupSize, now)
    groupSize = tonumber(groupSize) or 0
    if groupSize < 2 or type(deathTimes) ~= "table" then return false end
    local recent = 0
    for i = 1, #deathTimes do
        local t = tonumber(deathTimes[i])
        if t and (now - t) <= WINDOW then recent = recent + 1 end
    end
    return recent >= math.ceil(groupSize * 0.8)
end

-- Wipe counts live in RUNDB.wipes, keyed by npcID (number) or "enc:<name>".
function Wipes.countFor(key)
    local db = RUN.db()
    if type(db.wipes) ~= "table" then db.wipes = {} end
    local n = db.wipes[key]
    return (type(n) == "number" and n >= 0) and n or 0
end

function Wipes.record(key)
    if key == nil then return end
    local db = RUN.db()
    if type(db.wipes) ~= "table" then db.wipes = {} end
    db.wipes[key] = Wipes.countFor(key) + 1
    return db.wipes[key]
end

function Wipes.total()
    local db = RUN.db()
    if type(db.wipes) ~= "table" then return 0 end
    local t = 0
    for _, n in pairs(db.wipes) do
        if type(n) == "number" and n > 0 then t = t + n end
    end
    return t
end

-- Everything below wires the client.
if not _G.CreateFrame then return Wipes end

local Guards = RUN.Guards
local groupDeaths = {}   -- timestamps of group-member deaths (incl. ours)

local function rosterSize()
    local n = Guards.call(_G.GetNumGroupMembers)
    return tonumber(n) or 0
end

local function inMyGroup(guid)
    if type(guid) ~= "string" or not guid:find("^Player%-") then return false end
    local myGUID = Guards.call(_G.UnitGUID, "player")
    if guid == myGUID then return true end
    local prefix = (Guards.call(_G.IsInRaid) and "raid") or "party"
    local count = rosterSize()
    for i = 1, math.min(count, 40) do
        if Guards.call(_G.UnitGUID, prefix .. i) == guid then return true end
    end
    return false
end

-- Boss encounters say it plainly.
RUN.on("ENCOUNTER_END", function(_, encounterName, _, groupSize, success)
    if success == 0 and (tonumber(groupSize) or 0) >= 2 then
        local n = Wipes.record("enc:" .. tostring(encounterName))
        RUN.print(tostring(encounterName) .. " has wiped your group - "
            .. n .. " wipe" .. (n == 1 and "" or "s") .. " on the account record.")
    end
end)

-- Open-world correlation: group member deaths from the combat log.
RUN.on("COMBAT_LOG_EVENT_UNFILTERED", function()
    if rosterSize() < 2 then return end
    local ok = pcall(function()
        local info = { _G.CombatLogGetCurrentEventInfo() }
        local subevent, destGUID = info[2], info[8]
        if RUN.Guards.isSecret(subevent) or RUN.Guards.isSecret(destGUID) then return end
        if subevent ~= "UNIT_DIED" then return end
        if not inMyGroup(destGUID) then return end
        local now = _G.GetTime and _G.GetTime() or 0
        table.insert(groupDeaths, now)
        while #groupDeaths > 45 do table.remove(groupDeaths, 1) end
        if Wipes.isWipe(groupDeaths, rosterSize(), now) then
            groupDeaths = {}
            local last = RUN.Attribution.lastDeath
            local key = (last and last.npc) or nil
            if key then
                local n = Wipes.record(key)
                RUN.print(RUN.Deathping.npcName(key) .. " has wiped your group - "
                    .. n .. " on the account record.")
            end
        end
    end)
    if not ok then return end
end)

return Wipes
