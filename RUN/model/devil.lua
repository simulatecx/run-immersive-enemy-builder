-- The RISK IT wager (the Devil button): formally stake your run on a bad
-- matchup. SOLO only, odds below 50%. Arming records intent; a solo kill of
-- that creature becomes a GIANT SLAYER (<25%) or UNDERDOG (25-50%) entry in
-- your ledger; dying hands the creature another notch instead. DISPLAY AND
-- RECORD ONLY - the button never targets, casts, or attacks anything.
-- The state machine is pure and headless-tested.

local _, RUN = ...
if not RUN then RUN = _G.RunAdvisor or {}; _G.RunAdvisor = RUN end

local Devil = {}
RUN.Devil = Devil

local ARM_TTL = 300   -- an armed wager expires after 5 minutes

-- Pure: which wager tier do these odds allow? nil = no wager (too easy).
function Devil.tierForOdds(p)
    p = tonumber(p)
    if not p then return nil end
    if p < 0.25 then return "giantslayer" end
    if p < 0.50 then return "underdog" end
    return nil
end

function Devil.tierLabel(tier)
    if tier == "giantslayer" then return "GIANT SLAYER" end
    if tier == "underdog" then return "UNDERDOG" end
    return nil
end

-- Pure: arm a wager. Returns the armed state or nil (not allowed).
-- snapshot: { npc, name, p, solo, when }
function Devil.arm(snapshot, now)
    if type(snapshot) ~= "table" then return nil end
    if not snapshot.npc or snapshot.solo ~= true then return nil end
    local tier = Devil.tierForOdds(snapshot.p)
    if not tier then return nil end
    return {
        npc = snapshot.npc, name = snapshot.name, p = snapshot.p,
        tier = tier, t = tonumber(now) or 0,
    }
end

-- Pure: resolve an armed wager against an event. Events:
--   { type = "kill",  npc = n, solo = bool }  -> "won" if it matches, solo, fresh
--   { type = "death", npc = n }               -> "lost" if the creature got us
--   { type = "expire" }                       -> "abandoned" when past TTL
-- Returns outcome ("won"|"lost"|"abandoned"|nil = still armed), always with
-- the armed table for recording.
function Devil.resolve(armed, event, now)
    if type(armed) ~= "table" or type(event) ~= "table" then return nil, armed end
    now = tonumber(now) or 0
    if (now - (armed.t or 0)) > ARM_TTL then return "abandoned", armed end
    if event.type == "kill" then
        if event.npc == armed.npc and event.solo == true then return "won", armed end
        return nil, armed
    elseif event.type == "death" then
        if event.npc == armed.npc then return "lost", armed end
        return "abandoned", armed   -- died to something else entirely
    elseif event.type == "expire" then
        return "abandoned", armed
    end
    return nil, armed
end

-- Pure: validate a stored slay entry (RUNDB is user-editable).
function Devil.validSlay(e)
    return type(e) == "table" and type(e.when) == "number"
        and type(e.npc) == "number" and type(e.p) == "number"
end

-- Everything below wires the client.
if not _G.CreateFrame then return Devil end

local Guards = RUN.Guards
local armed = nil

local function isSolo()
    local inGroup = Guards.call(_G.IsInGroup)
    local inRaid = Guards.call(_G.IsInRaid)
    return not inGroup and not inRaid
end

function Devil.armed() return armed end

-- Called by the panel's RISK IT button (a click IS a hardware event; we only
-- write our own saved variables and update display).
function Devil.tryArm(verdict)
    if armed then RUN.print("a wager is already armed: " .. tostring(armed.name)) return end
    if not verdict or not verdict.creature then return end
    if not isSolo() then RUN.print("wagers are SOLO only - leave your group first.") return end
    local c = verdict.creature
    local snap = {
        npc = c.npcID, name = c.name, p = verdict.p, solo = true,
        -- the server recomputes the wager tier from these (crowd law: the
        -- client's asserted % is advisory) - snapless slays earn no ladder spot
        odds = {
            pLevel = Guards.number(Guards.call(_G.UnitLevel, "player")),
            cLevel = c.level, cls = c.classification,
        },
    }
    armed = Devil.arm(snap, _G.GetTime and _G.GetTime() or 0)
    if armed then armed.odds = snap.odds end
    if not armed then RUN.print("no wager here - the odds are too good.") return end
    RUN.print("WAGER ARMED (" .. Devil.tierLabel(armed.tier) .. "): slay "
        .. tostring(armed.name) .. " solo at ~" .. math.floor((armed.p or 0) * 100 + 0.5)
        .. "%. Die, and it feeds its legend.")
end

local function record(outcome)
    if not armed then return end
    local now = _G.GetTime and _G.GetTime() or 0
    if outcome == "won" then
        local db = RUN.db()
        if type(db.slays) ~= "table" then db.slays = {} end
        local hc = false
        local GR = _G.C_GameRules
        if GR and GR.IsHardcoreActive then
            local okHC, v = pcall(GR.IsHardcoreActive)
            hc = okHC and v and true or false
        end
        table.insert(db.slays, {
            when = _G.time and _G.time() or 0,
            npc = armed.npc, name = armed.name, p = armed.p, tier = armed.tier,
            snap = armed.odds,                 -- server-recomputable inputs
            mode = hc and "hc" or "pve",
            who = Guards.call(_G.UnitName, "player"),
        })
        while #db.slays > 50 do table.remove(db.slays, 1) end
        RUN.print("|cff8dffc4" .. Devil.tierLabel(armed.tier) .. "!|r You slew "
            .. tostring(armed.name) .. " at ~" .. math.floor((armed.p or 0) * 100 + 0.5) .. "%.")
        if RUN.Alert then
            RUN.Alert.show(Devil.tierLabel(armed.tier) .. "!",
                "you beat " .. tostring(armed.name) .. " at ~"
                .. math.floor((armed.p or 0) * 100 + 0.5) .. "% - it goes in the ledger",
                0.55, 1.0, 0.77)
        end
    elseif outcome == "lost" then
        RUN.print("the wager is settled - " .. tostring(armed.name) .. " adds you to its legend.")
    end
    armed = nil
    if RUN.Panel and RUN.Panel.refresh then RUN.Panel.refresh() end
end

-- Kill detection: CLEU PARTY_KILL where we are the killer and the victim is
-- the armed species.
RUN.on("COMBAT_LOG_EVENT_UNFILTERED", function()
    if not armed then return end
    local ok, outcome = pcall(function()
        local info = { _G.CombatLogGetCurrentEventInfo() }
        local subevent, sourceGUID, destGUID = info[2], info[4], info[8]
        if RUN.Guards.isSecret(subevent) or RUN.Guards.isSecret(destGUID) then return nil end
        if subevent ~= "PARTY_KILL" then return nil end
        local npc = RUN.Detect.npcIdFromGUID(destGUID)
        if not npc then return nil end
        local myGUID = RUN.Guards.call(_G.UnitGUID, "player")
        local mine = (sourceGUID == myGUID)
        local o = Devil.resolve(armed, { type = "kill", npc = npc, solo = mine and isSolo() },
            _G.GetTime and _G.GetTime() or 0)
        return o
    end)
    if ok and outcome then record(outcome) end
end)

RUN.on("PLAYER_DEAD", function()
    if not armed then return end
    local last = RUN.Attribution.lastDeath
    local outcome = Devil.resolve(armed, { type = "death", npc = last and last.npc },
        _G.GetTime and _G.GetTime() or 0)
    if outcome then record(outcome) end
end)

return Devil
