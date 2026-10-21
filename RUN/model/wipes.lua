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

-- ---------------------------------------------------------------------------
-- Guild attribution (PRIVACY LAW: guild data stays LOCAL + in-guild P2P only;
-- `guild` is FORBIDDEN in any crowd/Firebase payload).
-- ---------------------------------------------------------------------------

-- Pure: the raid-majority guild. names = dense list, one entry per group
-- member: guild-name string, or false/anything-else for the unguilded.
-- A guild is THE majority when it covers >=50% of the whole group; an exact
-- two-guild tie is ambiguous and attributes to nobody.
function Wipes.majorityGuild(names)
    if type(names) ~= "table" then return nil end
    local total = #names
    if total < 2 then return nil end
    local counts, best, bestN, tied = {}, nil, 0, false
    for i = 1, total do
        local g = names[i]
        if type(g) == "string" and g ~= "" then
            counts[g] = (counts[g] or 0) + 1
            if counts[g] > bestN then
                best, bestN, tied = g, counts[g], false
            elseif counts[g] == bestN and g ~= best then
                tied = true
            end
        end
    end
    if not best or tied or bestN * 2 < total then return nil end
    return best
end

-- Pure: bump store[guild][key] (store = RUNDB.guildWipes shape - user-editable
-- SavedVariables, so every layer is validated/rebuilt). key matches RUNDB.wipes
-- keys: npcID (number >= 1) or "enc:<name>". Returns the new count, or nil
-- when the inputs are unusable.
function Wipes.recordGuildWipe(store, guild, key)
    if type(store) ~= "table" then return nil end
    if type(guild) ~= "string" or guild == "" then return nil end
    local validKey = (type(key) == "number" and key >= 1)
        or (type(key) == "string" and key:match("^enc:.") ~= nil)
    if not validKey then return nil end
    if type(store[guild]) ~= "table" then store[guild] = {} end
    local n = store[guild][key]
    n = (type(n) == "number" and n >= 0) and n or 0
    store[guild][key] = n + 1
    return n + 1
end

-- ---------------------------------------------------------------------------
-- Package-registered selftests (pure; run headless AND in-game).
-- ---------------------------------------------------------------------------
table.insert(RUN.selftestChecks, function(check)
    local MG = Wipes.majorityGuild
    check("majority guild clear winner",
        MG({ "Alpha", "Alpha", "Alpha", "Beta", false }) == "Alpha")
    check("majority guild at exactly half",
        MG({ "Alpha", "Alpha", false, false }) == "Alpha")
    check("majority guild below half -> nil",
        MG({ "Alpha", "Alpha", false, false, false }) == nil)
    check("majority guild two-way tie -> nil",
        MG({ "Alpha", "Alpha", "Beta", "Beta" }) == nil)
    check("majority guild tie broken by count",
        MG({ "Alpha", "Beta", "Alpha" }) == "Alpha")
    check("majority guild all unguilded -> nil", MG({ false, false, false }) == nil)
    check("majority guild garbage tolerated",
        MG(nil) == nil and MG("junk") == nil and MG({}) == nil and MG({ "Solo" }) == nil
        and MG({ 7, true, "Alpha", "Alpha" }) == "Alpha")

    local store = {}
    check("guild wipe record counts", (function()
        local a = Wipes.recordGuildWipe(store, "Alpha", 448)
        local b = Wipes.recordGuildWipe(store, "Alpha", 448)
        local c = Wipes.recordGuildWipe(store, "Alpha", "enc:Hogger")
        local d = Wipes.recordGuildWipe(store, "Beta", 448)
        return a == 1 and b == 2 and c == 1 and d == 1
            and store.Alpha[448] == 2 and store.Alpha["enc:Hogger"] == 1
            and store.Beta[448] == 1
    end)())
    check("guild wipe record validates inputs",
        Wipes.recordGuildWipe(nil, "Alpha", 448) == nil
        and Wipes.recordGuildWipe(store, nil, 448) == nil
        and Wipes.recordGuildWipe(store, "", 448) == nil
        and Wipes.recordGuildWipe(store, "Alpha", 0) == nil
        and Wipes.recordGuildWipe(store, "Alpha", "enc:") == nil
        and Wipes.recordGuildWipe(store, "Alpha", "notakey") == nil
        and Wipes.recordGuildWipe(store, "Alpha", nil) == nil)
    check("guild wipe record heals tampered store", (function()
        local s = { Alpha = "junk" }
        local a = Wipes.recordGuildWipe(s, "Alpha", 448)
        local s2 = { Alpha = { [448] = "junk" } }
        local b = Wipes.recordGuildWipe(s2, "Alpha", 448)
        return a == 1 and b == 1 and s.Alpha[448] == 1 and s2.Alpha[448] == 1
    end)())
end)

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

-- Roster guild names, one dense entry per member (false = unguilded). In a
-- raid, raid1..N includes the player; in a party, party1..4 does not.
local function rosterGuilds()
    local names = {}
    local count = rosterSize()
    local function push(unit)
        if Guards.call(_G.UnitExists, unit) then
            local g = Guards.call(_G.GetGuildInfo, unit)
            table.insert(names, (type(g) == "string" and g ~= "") and g or false)
        end
    end
    if Guards.call(_G.IsInRaid) then
        for i = 1, math.min(count, 40) do push("raid" .. i) end
    else
        push("player")
        for i = 1, math.min(count - 1, 4) do push("party" .. i) end
    end
    return names
end

-- Every wipe lands here: the account tally always; when the group is a
-- majority-guild group, the LOCAL guild tally too, and - only when that
-- majority guild is OUR OWN - the in-guild RWP1 ping (receivers resolve
-- their own guild, so pinging about another guild's group would lie).
local function recordGroupWipe(key, size)
    local n = Wipes.record(key)
    local guild = Wipes.majorityGuild(rosterGuilds())
    if guild then
        local db = RUN.db()
        if type(db.guildWipes) ~= "table" then db.guildWipes = {} end
        Wipes.recordGuildWipe(db.guildWipes, guild, key)
        local mine = Guards.call(_G.GetGuildInfo, "player")
        if mine == guild and RUN.Deathping and RUN.Deathping.sendWipePing then
            RUN.Deathping.sendWipePing(key, size)
        end
    end
    return n
end

-- Boss encounters say it plainly.
RUN.on("ENCOUNTER_END", function(_, encounterName, _, groupSize, success)
    if success == 0 and (tonumber(groupSize) or 0) >= 2 then
        local n = recordGroupWipe("enc:" .. tostring(encounterName), tonumber(groupSize))
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
                local n = recordGroupWipe(key, rosterSize())
                RUN.print(RUN.Deathping.npcName(key) .. " has wiped your group - "
                    .. n .. " on the account record.")
            end
        end
    end)
    if not ok then return end
end)

return Wipes
