-- Death attribution: when you die, what killed you? LOCAL ONLY in beta - the
-- journal lives in RUNDB and never leaves your machine (the crowd killcount is a
-- later, opt-in phase). Primary signal: a rolling combat-log buffer of damage to
-- you; environmental deaths (falling, drowning...) are named so a cliff is never
-- blamed on a creature. The picker is pure and headless-tested.

local _, RUN = ...
if not RUN then RUN = _G.RunAdvisor or {}; _G.RunAdvisor = RUN end

local Attribution = {}
RUN.Attribution = Attribution

local WINDOW = 8        -- seconds of damage history that can claim the kill
local BUFFER_MAX = 30   -- entries kept
local DEATHS_MAX = 50   -- journal cap

-- ---------------------------------------------------------------------------
-- Pure: pick the killer from a buffer of { t, name, npc, guid, env } entries.
-- Most recent damage inside the window wins (the killing blow is the last hit);
-- entries outside the window are ignored. Returns the entry or nil.
-- ---------------------------------------------------------------------------
function Attribution.pick(buffer, now)
    if type(buffer) ~= "table" then return nil end
    local best = nil
    for i = 1, #buffer do
        local e = buffer[i]
        if type(e) == "table" and type(e.t) == "number" and (now - e.t) <= WINDOW then
            if not best or e.t >= best.t then best = e end
        end
    end
    return best
end

-- Pure: environmental type -> display name (codes mirror the combat log's
-- environmentalType strings; kept short for the journal).
local ENV_NAMES = {
    Falling = "a fall", Drowning = "drowning", Fatigue = "fatigue",
    Fire = "fire", Lava = "lava", Slime = "slime",
}
function Attribution.envName(envType)
    return ENV_NAMES[envType] or (envType and ("the environment (" .. tostring(envType) .. ")")) or nil
end

-- Pure: validate one stored death entry (RUNDB is user-editable).
function Attribution.validEntry(e)
    return type(e) == "table" and type(e.when) == "number"
        and (type(e.killer) == "string" or e.killer == nil)
end

-- ---------------------------------------------------------------------------
-- Kill ranking: how dangerous has this creature PROVEN itself? Beta = kills of
-- YOU from the local journal; the crowd body count feeds these same tiers in a
-- later phase. Pure + headless-tested.
-- ---------------------------------------------------------------------------
local RANKS = {
    { min = 10, label = "Infamous",  r = 1.00, g = 0.25, b = 0.25 },
    { min = 5,  label = "Deadly",    r = 1.00, g = 0.45, b = 0.30 },
    { min = 2,  label = "Dangerous", r = 1.00, g = 0.65, b = 0.30 },
    { min = 1,  label = "Blooded",   r = 0.95, g = 0.85, b = 0.55 },
}

-- n kills -> { label, r, g, b } or nil below one kill (clean tooltips).
function Attribution.rankForKills(n)
    n = tonumber(n) or 0
    for i = 1, #RANKS do
        if n >= RANKS[i].min then return RANKS[i] end
    end
    return nil
end

-- How many times has npcID killed you (valid journal entries only)?
function Attribution.killsBy(npcID)
    if not npcID then return 0 end
    local count = 0
    for _, e in ipairs(RUN.db().deaths) do
        if Attribution.validEntry(e) and e.npc == npcID then count = count + 1 end
    end
    return count
end

-- Everything below wires the client.
if not _G.CreateFrame then return Attribution end

local buffer = {}

local function pushDamage(entry)
    entry.t = _G.GetTime and _G.GetTime() or 0
    table.insert(buffer, entry)
    while #buffer > BUFFER_MAX do table.remove(buffer, 1) end
end

-- Rolling damage buffer from the combat log. Only damage TO the player matters.
RUN.on("COMBAT_LOG_EVENT_UNFILTERED", function()
    if not RUN.Settings.get("recordDeaths") then return end
    local info = { _G.CombatLogGetCurrentEventInfo() }
    local subevent, sourceGUID, sourceName, destGUID = info[2], info[4], info[5], info[8]
    if type(subevent) ~= "string" or not subevent:find("_DAMAGE", 1, true) then return end
    local myGUID = RUN.Guards.call(_G.UnitGUID, "player")
    if destGUID ~= myGUID then return end
    if subevent == "ENVIRONMENTAL_DAMAGE" then
        pushDamage({ env = info[12] })
    else
        pushDamage({
            guid = sourceGUID,
            name = sourceName,
            npc = RUN.Detect.npcIdFromGUID(sourceGUID),
        })
    end
end)

RUN.on("PLAYER_DEAD", function()
    if not RUN.Settings.get("recordDeaths") then return end
    local now = _G.GetTime and _G.GetTime() or 0
    local hit = Attribution.pick(buffer, now)
    local db = RUN.db()

    local killer, npc
    if hit and hit.env then
        killer = Attribution.envName(hit.env)
    elseif hit and hit.name then
        killer, npc = hit.name, hit.npc
    end

    local entry = {
        when = _G.time and _G.time() or 0,
        killer = killer,            -- nil = unknown (honest)
        npc = npc,
        level = RUN.Guards.number(RUN.Guards.call(_G.UnitLevel, "player")),
        zone = RUN.Guards.call(_G.GetZoneText),
        mapID = RUN.Guards.call(_G.C_Map and _G.C_Map.GetBestMapForUnit, "player"),
    }
    table.insert(db.deaths, entry)
    while #db.deaths > DEATHS_MAX do table.remove(db.deaths, 1) end
    Attribution.lastDeath = entry   -- read by the death-ping broadcaster

    RUN.print("death recorded: " .. (killer or "unknown cause")
        .. (entry.zone and (" in " .. entry.zone) or "") .. " (stays on your machine)")
end)

-- "/ra deaths" - the local journal, newest first.
function Attribution.printDeaths()
    local deaths = RUN.db().deaths
    local shown = 0
    for i = #deaths, 1, -1 do
        local e = deaths[i]
        if Attribution.validEntry(e) then
            shown = shown + 1
            local when = (_G.date and _G.date("%m/%d %H:%M", e.when)) or tostring(e.when)
            RUN.print(when .. " - " .. (e.killer or "unknown cause")
                .. (e.level and (" (you were L" .. e.level .. ")") or "")
                .. (e.zone and (" - " .. e.zone) or ""))
            if shown >= 10 then break end
        end
    end
    if shown == 0 then RUN.print("no deaths recorded yet. Long may it stay that way.") end
end

return Attribution
