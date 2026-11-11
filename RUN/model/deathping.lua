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

-- ---------------------------------------------------------------------------
-- Pure: the in-guild wipe ping "RWP1:<npcOrEnc>:<size>:<sum>" (frozen format).
-- npcOrEnc is the RUNDB.wipes key with ":" swapped for "~" in enc keys (decode
-- restores); size = group size (2..40); sum = fletcher16 over the body.
-- PRIVACY LAW: this message is sent to the GUILD channel ONLY - the game
-- itself scopes it, and guild data never reaches the public channel or any
-- crowd/Firebase payload.
-- ---------------------------------------------------------------------------
function Deathping.encodeWipe(key, size)
    size = tonumber(size)
    if not size or size < 2 or size > 40 or size % 1 ~= 0 then return nil end
    local wire
    if type(key) == "number" then
        if key < 1 or key > 10000000 or key % 1 ~= 0 then return nil end
        wire = tostring(key)
    elseif type(key) == "string" then
        local name = key:match("^enc:(.+)$")
        if not name then return nil end
        name = name:gsub("|", ""):gsub("^%s+", ""):gsub("%s+$", "")
        if name == "" then return nil end
        if #name > 60 then name = name:sub(1, 60) end
        wire = ("enc:" .. name):gsub(":", "~")
    else
        return nil
    end
    local body = wire .. ":" .. size
    return "RWP1:" .. body .. ":" .. Deathping.fletcher16(body)
end

-- Pure: strict decode; malformed, tampered, or out-of-range returns nil.
-- Returns { key = npcID-number or "enc:<name>", size, sum }.
function Deathping.decodeWipe(msg)
    if type(msg) ~= "string" or #msg > 120 then return nil end
    local wire, size, sum = msg:match("^RWP1:([^:|]+):(%d+):(%d+)$")
    if not wire then return nil end
    if tonumber(sum) ~= Deathping.fletcher16(wire .. ":" .. size) then return nil end
    size = tonumber(size)
    if size < 2 or size > 40 then return nil end
    local key
    if wire:match("^%d+$") then
        key = tonumber(wire)
        if key < 1 or key > 10000000 then return nil end
    else
        local name = wire:gsub("~", ":"):match("^enc:(.+)$")
        if not name or #name > 60 then return nil end
        key = "enc:" .. name
    end
    return { key = key, size = size, sum = tonumber(sum) }
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

-- Best display name for a WIPE key (RUNDB.wipes/guildWipes shape): numeric
-- keys resolve like any species; "enc:<name>" keys carry their own name.
-- Pure (db-backed): headless-tested.
function Deathping.wipeKeyName(key)
    if type(key) == "number" then return Deathping.npcName(key) end
    local name = tostring(key):match("^enc:(.+)$")
    return name or tostring(key)
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

-- RWP1 guild wipe ping: frozen wire format, strict fail-closed decode.
table.insert(RUN.selftestChecks, function(check)
    local enc, dec = Deathping.encodeWipe, Deathping.decodeWipe
    check("wipe ping npc roundtrip", (function()
        local d = dec(enc(448, 5))
        return d and d.key == 448 and d.size == 5 and type(d.sum) == "number"
    end)())
    check("wipe ping enc roundtrip", (function()
        local d = dec(enc("enc:Hogger", 40))
        return d and d.key == "enc:Hogger" and d.size == 40
    end)())
    check("wipe ping enc colon survives the swap", (function()
        local d = dec(enc("enc:Edge: of Doom", 10))
        return d and d.key == "enc:Edge: of Doom"
    end)())
    check("wipe ping wire has no raw colon in enc key",
        enc("enc:Hogger", 5):match("^RWP1:enc~Hogger:5:%d+$") ~= nil)
    check("wipe ping strips escape pipes", (function()
        local d = dec(enc("enc:|cffBad|rName", 3))
        return d and d.key == "enc:cffBadrName"
    end)())
    check("wipe ping caps enc name at 60", (function()
        local d = dec(enc("enc:" .. string.rep("a", 200), 3))
        return d and #d.key == 64
    end)())
    check("wipe ping bad key rejected", enc(0, 5) == nil and enc(1.5, 5) == nil
        and enc(10000001, 5) == nil and enc("Hogger", 5) == nil
        and enc("enc:", 5) == nil and enc("enc:   ", 5) == nil and enc(nil, 5) == nil)
    check("wipe ping bad size rejected", enc(448, 1) == nil and enc(448, 41) == nil
        and enc(448, 2.5) == nil and enc(448, nil) == nil)
    check("wipe ping tamper rejected", (function()
        local msg = enc(448, 5)
        return dec(msg:gsub("448", "449", 1)) == nil
            and dec(msg:gsub(":5:", ":6:", 1)) == nil
    end)())
    check("wipe ping garbage rejected", dec(nil) == nil and dec("RWP1:::") == nil
        and dec("RWP1:448:5") == nil and dec("RWP1:448:99:" ..
            Deathping.fletcher16("448:99")) == nil
        and dec("RDP1:448:1:10:" .. Deathping.fletcher16("448:1:10")) == nil
        and dec("RWP1:enc~:3:" .. Deathping.fletcher16("enc~:3")) == nil)
    check("wipe key display name", Deathping.wipeKeyName("enc:Hogger") == "Hogger"
        and Deathping.wipeKeyName(999998) == "creature #999998")
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

-- ---------------------------------------------------------------------------
-- The in-guild wipe ping (RWP1). GUILD channel ONLY - never broadcast(): the
-- game itself scopes GUILD addon messages, so guild wipe data stays in-guild
-- (privacy law: guild is forbidden in any crowd/Firebase payload). Called by
-- model/wipes.lua when a majority-guild wipe is recorded for OUR OWN guild.
-- ---------------------------------------------------------------------------
local wipeSendRate, wipeRecvRate = {}, {}

function Deathping.sendWipePing(key, size)
    if not RUN.Settings.get("shareDeaths") then return end
    if not Guards.call(_G.IsInGuild) then return end
    local msg = Deathping.encodeWipe(key, size)
    if not msg then return end
    local now = _G.GetTime and _G.GetTime() or 0
    if not Deathping.allowSender(wipeSendRate, "me", now) then return end   -- 5/hr
    if _G.C_ChatInfo and _G.C_ChatInfo.SendAddonMessage then
        pcall(_G.C_ChatInfo.SendAddonMessage, PREFIX, msg, "GUILD")
    end
end

-- Receive: five message kinds, all strict-decoded, deduped, rate-limited.
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

    local noto = RUN.Notoriety.describe(ping.npc, "normal")
    local name = Deathping.npcName(ping.npc)

    -- the ambient death feed shows EVERY heard death (gated by deathFeed) - the
    -- living-world pulse. The chat line + alert below stay notable-only, so the
    -- feed carries the volume without spamming chat.
    if RUN.Feed then RUN.Feed.add(name, ping.bracket, ping.mapID, noto.total, who, noto.tier) end

    -- display: only notable deaths speak up (known/seen rares or notorious species)
    local known = RUN.raresMerged()[ping.npc]
        or (RUN.Detect.sightingFor and RUN.Detect.sightingFor(ping.npc))
    local notable = (known ~= nil) or noto.tier >= 3
    if not notable then return end
    -- the heard COUNT is already recorded above; only the pop-up is muted in
    -- dungeons/raids (owner 2026-11-05).
    if RUN.Detect.quietHere() then return end
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

RUN.on("CHAT_MSG_ADDON", function(prefix, msg, channel, sender)
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

    local wipe = Deathping.decodeWipe(msg)
    if wipe then
        -- in-guild only: the GUILD distribution is guild-scoped by the game;
        -- an RWP1 arriving any other way is forged and dropped.
        if channel ~= "GUILD" then return end
        if not Deathping.allowSender(wipeRecvRate, who, now) then return end
        local dkey = msg .. "#" .. who
        if seenSums[dkey] and (now - seenSums[dkey]) < 30 then return end
        seenSums[dkey] = now
        -- the receiver resolves their OWN guild - sender and receiver share
        -- the GUILD channel, so the tally lands on the right record.
        local myGuild = Guards.call(_G.GetGuildInfo, "player")
        if type(myGuild) ~= "string" or myGuild == "" then return end
        local db = RUN.db()
        if type(db.guildWipes) ~= "table" then db.guildWipes = {} end
        local n = RUN.Wipes.recordGuildWipe(db.guildWipes, myGuild, wipe.key)
        if not n then return end
        RUN.print(Deathping.wipeKeyName(wipe.key) .. " has wiped a "
            .. myGuild:gsub("|", "") .. " group (" .. n .. " on the guild record)")
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
