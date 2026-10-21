-- The P2P death-ping (the Hardcore-addon pattern, creature-centric): when YOU
-- die to a creature, your addon automatically broadcasts a small anonymous ping
-- over a shared addon channel; every online RUN user hears it and that
-- creature's live "deaths heard" count grows on their tooltips. IN-GAME chat
-- transport only - nothing ever leaves the game client, and the ping carries
-- NO player name (unlike Hardcore's eulogy model, ours is about the monster).
-- Live counts are session flavour, deliberately separate from the durable
-- server-verified crowd count (a later phase). Pure helpers headless-tested.

local _, RUN = ...
if not RUN then RUN = _G.RunAdvisor or {}; _G.RunAdvisor = RUN end

local Deathping = {}
RUN.Deathping = Deathping

local PREFIX = "RUNDP"
local CHANNEL = "rundeathping"
local CHANNEL_PW = "rundp"
local RATE_MAX, RATE_WINDOW = 5, 3600   -- per-sender: max pings per hour

-- ---------------------------------------------------------------------------
-- Pure: Fletcher-16 checksum, arithmetic only (bitwise ops are not Lua 5.1).
-- ---------------------------------------------------------------------------
function Deathping.fletcher16(s)
    s = tostring(s or "")
    local sum1, sum2 = 0, 0
    for i = 1, #s do
        sum1 = (sum1 + s:byte(i)) % 255
        sum2 = (sum2 + sum1) % 255
    end
    return sum2 * 256 + sum1
end

-- Pure: wire format "RDP1:npc:mapID:bracket:sum". bracket = level rounded down
-- to 10s (coarse, non-identifying). sum covers the payload fields.
function Deathping.encode(npc, mapID, bracket)
    npc = tonumber(npc); mapID = tonumber(mapID) or 0; bracket = tonumber(bracket) or 0
    if not npc or npc < 1 then return nil end
    local body = npc .. ":" .. mapID .. ":" .. bracket
    return "RDP1:" .. body .. ":" .. Deathping.fletcher16(body)
end

-- Pure: strict decode; anything malformed or checksum-tampered returns nil.
function Deathping.decode(msg)
    if type(msg) ~= "string" then return nil end
    local npc, mapID, bracket, sum = msg:match("^RDP1:(%d+):(%d+):(%d+):(%d+)$")
    if not npc then return nil end
    local body = npc .. ":" .. mapID .. ":" .. bracket
    if tonumber(sum) ~= Deathping.fletcher16(body) then return nil end
    npc = tonumber(npc)
    if npc < 1 or npc > 10000000 then return nil end
    return { npc = npc, mapID = tonumber(mapID), bracket = tonumber(bracket) }
end

-- Pure: per-sender rate limiter. state[sender] = list of send times; returns
-- allowed(bool). Injected clock for headless tests.
function Deathping.allowSender(state, sender, now)
    if type(state) ~= "table" or type(sender) ~= "string" then return false end
    local times = state[sender] or {}
    local fresh = {}
    for i = 1, #times do
        if (now - times[i]) < RATE_WINDOW then table.insert(fresh, times[i]) end
    end
    if #fresh >= RATE_MAX then state[sender] = fresh; return false end
    table.insert(fresh, now)
    state[sender] = fresh
    return true
end

-- Heard counts live in RUNDB (type-validated; user-editable like everything).
function Deathping.heardBy(npc)
    npc = tonumber(npc)
    if not npc then return 0 end
    local db = RUN.db()
    if type(db.heard) ~= "table" then db.heard = {} end
    local n = db.heard[npc]
    return (type(n) == "number" and n >= 0) and n or 0
end

function Deathping.recordHeard(npc)
    npc = tonumber(npc)
    if not npc then return end
    local db = RUN.db()
    if type(db.heard) ~= "table" then db.heard = {} end
    db.heard[npc] = Deathping.heardBy(npc) + 1
end

-- Total deaths heard across all creatures (the Ledger's tally).
function Deathping.heardTotal()
    local db = RUN.db()
    if type(db.heard) ~= "table" then return 0 end
    local total = 0
    for _, n in pairs(db.heard) do
        if type(n) == "number" and n > 0 then total = total + n end
    end
    return total
end

-- Everything below wires the client.
if not _G.CreateFrame then return Deathping end

local Guards = RUN.Guards
local rateState = {}
local seenSums = {}     -- checksum+npc dedupe window (same ping via GUILD + channel)

local function myName()
    local n = Guards.call(_G.UnitName, "player")
    return type(n) == "string" and n or "?"
end

local function channelIndex()
    local idx = Guards.call(_G.GetChannelName, CHANNEL)
    return (type(idx) == "number" and idx > 0) and idx or nil
end

local function joinChannel()
    if channelIndex() then return end
    if _G.JoinTemporaryChannel then
        pcall(_G.JoinTemporaryChannel, CHANNEL, CHANNEL_PW)
    end
end

-- Surfaced by /ra status and the Ledger.
function Deathping.channelJoined()
    return channelIndex() ~= nil
end

RUN.on("PLAYER_LOGIN", function()
    if _G.C_ChatInfo and _G.C_ChatInfo.RegisterAddonMessagePrefix then
        pcall(_G.C_ChatInfo.RegisterAddonMessagePrefix, PREFIX)
    end
    -- the chat system needs a moment after login before channel joins stick
    if _G.C_Timer and _G.C_Timer.After then
        _G.C_Timer.After(8, function()
            if RUN.Settings.get("shareDeaths") then joinChannel() end
        end)
    end
end)

-- Broadcast our own creature-death. Runs after attribution recorded it
-- (attribution loads first in the TOC, so its PLAYER_DEAD handler ran already).
RUN.on("PLAYER_DEAD", function()
    if not RUN.Settings.get("shareDeaths") then return end
    local last = RUN.Attribution.lastDeath
    if not last or not last.npc then return end   -- env/unknown deaths never ping
    local bracket = math.floor((tonumber(last.level) or 0) / 10) * 10
    local msg = Deathping.encode(last.npc, last.mapID or 0, bracket)
    if not msg or not (_G.C_ChatInfo and _G.C_ChatInfo.SendAddonMessage) then return end
    local idx = channelIndex()
    if idx then pcall(_G.C_ChatInfo.SendAddonMessage, PREFIX, msg, "CHANNEL", idx) end
    if Guards.call(_G.IsInGuild) then
        pcall(_G.C_ChatInfo.SendAddonMessage, PREFIX, msg, "GUILD")
    end
end)

-- Receive pings from others: strict shape, dedupe, per-sender rate limit.
RUN.on("CHAT_MSG_ADDON", function(prefix, msg, _, sender)
    if prefix ~= PREFIX then return end
    if not RUN.Settings.get("shareDeaths") then return end
    local who = tostring(sender or ""):match("^[^-]+") or "?"
    if who == myName() then return end            -- our own echo; we have the journal
    local ping = Deathping.decode(msg)
    if not ping then return end
    local now = _G.GetTime and _G.GetTime() or 0
    if not Deathping.allowSender(rateState, who, now) then return end
    local key = msg .. "#" .. who
    if seenSums[key] and (now - seenSums[key]) < 30 then return end
    seenSums[key] = now
    Deathping.recordHeard(ping.npc)
    local known = RUN.raresMerged()[ping.npc]
    if known and known.name then
        RUN.print("heard: " .. known.name .. " has slain another player ("
            .. Deathping.heardBy(ping.npc) .. " heard)")
    end
end)

return Deathping
