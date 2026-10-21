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
    return { npc = npc, mapID = tonumber(mapID), bracket = tonumber(bracket),
             sum = tonumber(sum) }
end

-- ---------------------------------------------------------------------------
-- Pure: the companion message types (all strict-decoded, fail-closed).
-- ACK  "RDA1:<sum>"        - a peer echoes a ping's checksum (k-of-n trust)
-- WORDS "RLW1:<sum>:<txt>" - the fallen's last words, tied to their ping
-- HELLO "RVH1:<version>"   - version handshake, so beta zips learn of updates
-- ---------------------------------------------------------------------------
function Deathping.encodeAck(sum)
    sum = tonumber(sum)
    if not sum then return nil end
    return "RDA1:" .. sum
end

function Deathping.decodeAck(msg)
    if type(msg) ~= "string" then return nil end
    local sum = msg:match("^RDA1:(%d+)$")
    return tonumber(sum)
end

-- Last words travel through chat: strip escape pipes, swap the protocol
-- delimiter, trim, cap at 80 chars. Returns nil when nothing survives.
function Deathping.sanitizeWords(s)
    if type(s) ~= "string" then return nil end
    s = s:gsub("|", ""):gsub(":", ","):gsub("^%s+", ""):gsub("%s+$", "")
    if s == "" then return nil end
    if #s > 80 then s = s:sub(1, 80) end
    return s
end

function Deathping.encodeWords(sum, words)
    sum = tonumber(sum)
    words = Deathping.sanitizeWords(words)
    if not sum or not words then return nil end
    return "RLW1:" .. sum .. ":" .. words
end

function Deathping.decodeWords(msg)
    if type(msg) ~= "string" then return nil end
    local sum, words = msg:match("^RLW1:(%d+):(.+)$")
    if not sum then return nil end
    words = Deathping.sanitizeWords(words)
    if not words then return nil end
    return { sum = tonumber(sum), words = words }
end

function Deathping.encodeHello(version)
    if type(version) ~= "string" or not version:match("^%d+%.%d+%.%d+$") then return nil end
    return "RVH1:" .. version
end

function Deathping.decodeHello(msg)
    if type(msg) ~= "string" then return nil end
    local v = msg:match("^RVH1:(%d+%.%d+%.%d+)$")
    return v
end

-- Pure: is version a newer than version b? (semver triplets)
function Deathping.newer(a, b)
    local a1, a2, a3 = tostring(a):match("^(%d+)%.(%d+)%.(%d+)$")
    local b1, b2, b3 = tostring(b):match("^(%d+)%.(%d+)%.(%d+)$")
    if not a1 or not b1 then return false end
    a1, a2, a3 = tonumber(a1), tonumber(a2), tonumber(a3)
    b1, b2, b3 = tonumber(b1), tonumber(b2), tonumber(b3)
    if a1 ~= b1 then return a1 > b1 end
    if a2 ~= b2 then return a2 > b2 end
    return a3 > b3
end

-- Pure: FIFO push for the heard-deaths journal (Hardcore keeps 1000; we 200).
function Deathping.pushHeard(log, entry, cap)
    if type(log) ~= "table" or type(entry) ~= "table" then return end
    table.insert(log, entry)
    cap = tonumber(cap) or 200
    while #log > cap do table.remove(log, 1) end
end

-- Pure: register an ack from a DISTINCT sender; corroborated at 2+ echoes
-- (origin + two peers = Hardcore's proven k=3 witnesses).
function Deathping.corroborate(entry, sender)
    if type(entry) ~= "table" or type(sender) ~= "string" then return false end
    if type(entry.ackers) ~= "table" then entry.ackers = {} end
    if not entry.ackers[sender] then
        entry.ackers[sender] = true
        entry.acks = (tonumber(entry.acks) or 0) + 1
    end
    entry.corro = (tonumber(entry.acks) or 0) >= 2
    return entry.corro
end

-- Pure: per-sender rate limiter. state[sender] = list of send times; returns
-- allowed(bool). Injected clock for headless tests; optional max override
-- (death pings 5/hr; ack echoes are chattier and get a higher cap).
function Deathping.allowSender(state, sender, now, max)
    if type(state) ~= "table" or type(sender) ~= "string" then return false end
    max = tonumber(max) or RATE_MAX
    local times = state[sender] or {}
    local fresh = {}
    for i = 1, #times do
        if (now - times[i]) < RATE_WINDOW then table.insert(fresh, times[i]) end
    end
    if #fresh >= max then state[sender] = fresh; return false end
    table.insert(fresh, now)
    state[sender] = fresh
    return true
end

-- Heard counts live in RUNDB (type-validated; user-editable like everything).
-- Two parallel ledgers: db.heard counts EVERY valid ping; db.heardStrict counts
-- only pings that flipped to corroborated (2+ distinct ack witnesses). The
-- strictTrust setting decides which one feeds publicly-shown counts.
local function rawCount(map, npc)
    if type(map) ~= "table" then return 0 end
    local n = map[npc]
    return (type(n) == "number" and n >= 0) and n or 0
end

function Deathping.strictHeardBy(npc)
    npc = tonumber(npc)
    if not npc then return 0 end
    return rawCount(RUN.db().heardStrict, npc)
end

function Deathping.heardBy(npc)
    npc = tonumber(npc)
    if not npc then return 0 end
    if RUN.Settings and RUN.Settings.get("strictTrust") then
        return Deathping.strictHeardBy(npc)
    end
    local db = RUN.db()
    if type(db.heard) ~= "table" then db.heard = {} end
    return rawCount(db.heard, npc)
end

function Deathping.recordHeard(npc)
    npc = tonumber(npc)
    if not npc then return end
    local db = RUN.db()
    if type(db.heard) ~= "table" then db.heard = {} end
    db.heard[npc] = rawCount(db.heard, npc) + 1
end

-- Bumped by the ack receive path when an entry FLIPS to corroborated - never
-- more than once per heard entry (the flip happens exactly once).
function Deathping.recordHeardStrict(npc)
    npc = tonumber(npc)
    if not npc then return end
    local db = RUN.db()
    if type(db.heardStrict) ~= "table" then db.heardStrict = {} end
    db.heardStrict[npc] = rawCount(db.heardStrict, npc) + 1
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

-- Best display name we have for a species: curated DB, then the sightings
-- harvest (someone on this account SAW it), then the journal, then #id.
-- Pure (db-backed): headless-tested.
function Deathping.npcName(npc)
    local known = RUN.raresMerged()[npc]
    if known and known.name then return known.name end
    local seen = RUN.Detect.sightingFor and RUN.Detect.sightingFor(npc)
    if seen then return seen.name end
    local deaths = RUN.db().deaths
    for i = #deaths, 1, -1 do
        local e = deaths[i]
        if type(e) == "table" and e.npc == npc and type(e.killer) == "string" then
            return e.killer
        end
    end
    return "creature #" .. tostring(npc)
end

-- ---------------------------------------------------------------------------
-- Package-registered selftests (pure; run headless AND in-game).
-- ---------------------------------------------------------------------------
table.insert(RUN.selftestChecks, function(check)
    local db = RUN.db()
    local savedHeard, savedStrict = db.heard, db.heardStrict

    -- strict counts only grow on the corroboration FLIP (the ack call-site
    -- pattern: bump recordHeardStrict only when corroborate turns false->true)
    db.heardStrict = nil
    local entry, flips = { npc = 448, acks = 0 }, 0
    local function ackFrom(sender)
        local was = entry.corro and true or false
        if Deathping.corroborate(entry, sender) and not was then
            flips = flips + 1
            Deathping.recordHeardStrict(entry.npc)
        end
    end
    ackFrom("Peer1"); ackFrom("Peer1"); ackFrom("Peer2"); ackFrom("Peer3")
    check("strict count grows on flip only",
        flips == 1 and rawCount(db.heardStrict, 448) == 1)

    -- heardBy honors the strictTrust toggle
    db.heard = { [448] = 5 }
    db.heardStrict = { [448] = 1 }
    local before = RUN.Settings.get("strictTrust")
    RUN.Settings.set("strictTrust", false)
    local allN = Deathping.heardBy(448)
    RUN.Settings.set("strictTrust", true)
    local strictN = Deathping.heardBy(448)
    local strictMiss = Deathping.heardBy(777)
    RUN.Settings.set("strictTrust", before)
    db.heard, db.heardStrict = savedHeard, savedStrict
    check("heardBy honors strictTrust", allN == 5 and strictN == 1 and strictMiss == 0)
    check("strictTrust default off", RUN.Settings.get("strictTrust") == false)
end)

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

-- Send helper: channel first, guild as a bonus (dedupe handles double-receive).
local function broadcast(msg)
    if not msg or not (_G.C_ChatInfo and _G.C_ChatInfo.SendAddonMessage) then return end
    local idx = channelIndex()
    if idx then pcall(_G.C_ChatInfo.SendAddonMessage, PREFIX, msg, "CHANNEL", idx) end
    if Guards.call(_G.IsInGuild) then
        pcall(_G.C_ChatInfo.SendAddonMessage, PREFIX, msg, "GUILD")
    end
end

-- The last thing we said (for last words). Public chat only - it was already
-- said out loud; we just let it ride your death-ping if the option is on.
local lastSaid = nil
local function trackSay(text, playerName)
    local who = tostring(playerName or ""):match("^[^-]+")
    if who ~= myName() then return end
    local words = Deathping.sanitizeWords(text)
    if words then lastSaid = { words = words, t = _G.GetTime and _G.GetTime() or 0 } end
end
RUN.on("CHAT_MSG_SAY", trackSay)
RUN.on("CHAT_MSG_YELL", trackSay)
RUN.on("CHAT_MSG_PARTY", trackSay)
RUN.on("CHAT_MSG_PARTY_LEADER", trackSay)
RUN.on("CHAT_MSG_GUILD", trackSay)

local saidHello = false
RUN.on("PLAYER_LOGIN", function()
    if _G.C_ChatInfo and _G.C_ChatInfo.RegisterAddonMessagePrefix then
        pcall(_G.C_ChatInfo.RegisterAddonMessagePrefix, PREFIX)
    end
    -- the chat system needs a moment after login before channel joins stick
    if _G.C_Timer and _G.C_Timer.After then
        _G.C_Timer.After(8, function()
            if RUN.Settings.get("shareDeaths") then joinChannel() end
        end)
        _G.C_Timer.After(14, function()
            if not saidHello and RUN.Settings.get("shareDeaths") and channelIndex() then
                saidHello = true
                broadcast(Deathping.encodeHello(RUN.version))
            end
        end)
    end
end)

-- Broadcast our own creature-death (+ last words when fresh and opted in).
-- Runs after attribution recorded it (attribution loads first in the TOC).
RUN.on("PLAYER_DEAD", function()
    if not RUN.Settings.get("shareDeaths") then return end
    local last = RUN.Attribution.lastDeath
    if not last or not last.npc then return end   -- env/unknown deaths never ping
    local bracket = math.floor((tonumber(last.level) or 0) / 10) * 10
    local msg = Deathping.encode(last.npc, last.mapID or 0, bracket)
    if not msg then return end
    broadcast(msg)
    if RUN.Settings.get("lastWords") and lastSaid then
        local now = _G.GetTime and _G.GetTime() or 0
        if (now - lastSaid.t) <= 120 then
            broadcast(Deathping.encodeWords(Deathping.decode(msg).sum, lastSaid.words))
        end
    end
end)

-- Receive: four message kinds, all strict-decoded, deduped, rate-limited.
local ackRate = {}
local versionNotified = false

local function findRecentHeard(sum, sender, now)
    local log = RUN.db().heardLog
    if type(log) ~= "table" then return nil end
    for i = #log, 1, -1 do
        local e = log[i]
        if type(e) == "table" and e.sum == sum and (now - (e.t or 0)) <= 180 then
            if not sender or e.sender == sender then return e end
        end
        if type(e) == "table" and (now - (e.t or 0)) > 300 then break end
    end
    return nil
end

local function onPing(ping, who, now)
    Deathping.recordHeard(ping.npc)
    local db = RUN.db()
    if type(db.heardLog) ~= "table" then db.heardLog = {} end
    local entry = { npc = ping.npc, mapID = ping.mapID, bracket = ping.bracket,
                    sum = ping.sum, t = now, sender = who,
                    ackers = {}, acks = 0, corro = false }
    Deathping.pushHeard(db.heardLog, entry, 200)

    -- echo the checksum so the network corroborates (k-of-n, Hardcore-proven)
    if Deathping.allowSender(ackRate, "me", now, 30) then
        broadcast(Deathping.encodeAck(ping.sum))
    end

    -- display: only notable deaths speak up (known/seen rares or notorious species)
    local noto = RUN.Notoriety.describe(ping.npc, "normal")
    local known = RUN.raresMerged()[ping.npc]
        or (RUN.Detect.sightingFor and RUN.Detect.sightingFor(ping.npc))
    local notable = (known ~= nil) or noto.tier >= 3
    if not notable then return end
    local name = Deathping.npcName(ping.npc)
    local titled = noto.title and (name .. " \"" .. noto.title .. "\"") or name
    local line
    if RUN.Settings.get("eulogy") then
        line = who .. " has fallen to " .. titled .. " (" .. noto.total .. " kills)"
    else
        line = titled .. " has slain another player (" .. noto.total .. " kills)"
    end
    RUN.print("heard: " .. line)
    if RUN.Settings.get("heardAlerts") and RUN.Alert then
        RUN.Alert.show(titled, "has claimed another victim - " .. noto.total .. " and counting")
    end
end

RUN.on("CHAT_MSG_ADDON", function(prefix, msg, _, sender)
    if prefix ~= PREFIX then return end
    if not RUN.Settings.get("shareDeaths") then return end
    local who = tostring(sender or ""):match("^[^-]+") or "?"
    if who == myName() then return end            -- our own echo; we have the journal
    local now = _G.GetTime and _G.GetTime() or 0

    local hello = Deathping.decodeHello(msg)
    if hello then
        if not versionNotified and Deathping.newer(hello, RUN.version) then
            versionNotified = true
            RUN.print("a newer RUN (v" .. hello .. ") is out there - update when you can.")
        end
        return
    end

    local ack = Deathping.decodeAck(msg)
    if ack then
        local entry = findRecentHeard(ack, nil, now)
        if entry then
            local was = entry.corro and true or false
            if Deathping.corroborate(entry, who) and not was then
                -- the flip to corroborated happens exactly once per entry:
                -- this is the only place the strict ledger grows
                Deathping.recordHeardStrict(entry.npc)
            end
        end
        return
    end

    local lw = Deathping.decodeWords(msg)
    if lw then
        local entry = findRecentHeard(lw.sum, who, now)
        if entry then
            entry.words = lw.words
            if RUN.Settings.get("eulogy") then
                RUN.print(who .. "'s last words: \"" .. lw.words .. "\"")
            end
        end
        return
    end

    local ping = Deathping.decode(msg)
    if not ping then return end
    if not Deathping.allowSender(rateState, who, now) then return end
    local key = msg .. "#" .. who
    if seenSums[key] and (now - seenSums[key]) < 30 then return end
    seenSums[key] = now
    onPing(ping, who, now)
end)

return Deathping
