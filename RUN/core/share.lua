-- /ra share: the user-initiated crowd share (WP-B / RUN-E). The addon NEVER
-- networks - this builds an allow-listed, de-identified payload from the RUNDB
-- journals (deaths, slays, sightings, wipes since the last share), packs it
-- into ONE link (https://wow-foresight.web.app/run.html#d=<payload>) and shows
-- it in a copyable editbox (ui/export.lua). Pasting that link into a browser is
-- the explicit consent act; the WEB PAGE writes Firestore, never the addon.
-- Every field must pass the generated allow-list (data/rare-kills-schema.json
-- via data/generated/crowd_schema.lua); anything else is stripped. FORBIDDEN
-- forever: realm, account, guild, real name, guid, ip. There is no setting for
-- this - sharing happens only when you ask for the link. Pure + headless-tested.

local _, RUN = ...
if not RUN then RUN = _G.RunAdvisor or {}; _G.RunAdvisor = RUN end

local Share = {}
RUN.Share = Share

-- Season tag rides every event. The constants live in core/init.lua - one per
-- GAME LINE, because npcIDs are identical across the two games and the tag
-- prefix is what keeps their counts from ever blending: WoW Forever stamps
-- RUN.season ("s0", "s1", ...), Classic Era stamps RUN.seasonEra ("c0",
-- "c1", ...). share.lua only READS them: the live client is classified by API
-- presence (the quests.lua signal), never by version numbers, then the tag
-- passes the shape clamp. Off-shape or missing falls back WITHIN its own
-- partition ("s0"/"c0") - a bad edit must never stamp one game's counts into
-- the other game's buckets. Headless (no client API at all) resolves to the
-- Forever side, so the gate's fixtures stay on "s0".

-- Pure: the era signal on injected handles (so selftests probe both shapes on
-- any client). Modern C_QuestLog.GetInfo wins outright; the old global quest
-- log marks era; neither present (headless/unknown) is NOT era.
function Share.detectEra(CQ, getQuestLogTitle)
    if type(CQ) == "table" and CQ.GetInfo ~= nil then return false end
    return type(getQuestLogTitle) == "function"
end

-- Pure: partition-aware select + clamp.
function Share.seasonFor(era)
    local s = era and RUN.seasonEra or RUN.season
    if type(s) == "string" and #s <= 8 and s:match("^[a-z0-9]+$") then return s end
    return era and "c0" or "s0"
end

function Share.season()
    return Share.seasonFor(Share.detectEra(_G.C_QuestLog, _G.GetQuestLogTitle))
end

-- Per-kind caps keep one link honest and the URL short; slays are rarest and
-- most valuable, deaths next. The global cap comes from the generated schema.
local MAX_PER_KIND = { slay = 10, death = 40, sighting = 30, wipe = 20, calib = 30 }
local MAX_WIPES_PER_KEY = 5

local function schema()
    return RUN.gen and RUN.gen.crowdSchema
end

local function toSet(list)
    local set = {}
    if type(list) == "table" then
        for i = 1, #list do set[list[i]] = true end
    end
    return set
end

-- Fletcher16 reuse: model/deathping.lua owns the arithmetic implementation
-- (bitwise ops are not Lua 5.1).
function Share.fletcher16(s)
    return RUN.Deathping.fletcher16(s)
end

-- The canonical event string sum covers: ASCII-safe tokens only (kind + npc id,
-- never free text) so Lua byte() and the web's charCodeAt() always agree.
function Share.canon(payload)
    if type(payload) ~= "table" or type(payload.events) ~= "table" then return "" end
    local toks = {}
    for i = 1, #payload.events do
        local e = payload.events[i]
        local npc = (type(e) == "table" and type(e.npc) == "number") and e.npc or "x"
        toks[i] = tostring(type(e) == "table" and e.k or "?") .. ":" .. npc
    end
    return tostring(payload.v) .. "|" .. tostring(payload.season) .. "|"
        .. #payload.events .. "|" .. table.concat(toks, ",")
end

-- ---------------------------------------------------------------------------
-- Pure: small sanitizers.
-- ---------------------------------------------------------------------------

-- Creature/encounter names are game data but still travel as text: strip UI
-- escape pipes + control chars, trim, cap. Returns nil when nothing survives.
function Share.cleanName(nm, cap)
    if type(nm) ~= "string" then return nil end
    nm = nm:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|", "")
    nm = nm:gsub("%c", ""):gsub("^%s+", ""):gsub("%s+$", "")
    if nm == "" then return nil end
    cap = tonumber(cap) or 48
    if #nm > cap then nm = nm:sub(1, cap) end
    return nm
end

-- A chosen handle is the opt-in named tier: charset-clamped (letters, digits,
-- space, _ and -), trimmed, max 24. nil = stay anonymous.
function Share.clampHandle(h)
    if type(h) ~= "string" then return nil end
    h = h:gsub("[^%w_%- ]", ""):gsub("^%s+", ""):gsub("%s+$", "")
    if h == "" then return nil end
    if #h > 24 then h = h:sub(1, 24):gsub("%s+$", "") end
    return h ~= "" and h or nil
end

local function cleanMode(m)
    if m == "pvp" or m == "hc" then return m end
    return "pve"
end

local function cleanNpc(npc)
    npc = tonumber(npc)
    if not npc or npc < 1 or npc > 10000000 then return nil end
    return math.floor(npc)
end

-- ---------------------------------------------------------------------------
-- Pure: one event builder per journal kind. Each constructs a FRESH table with
-- only schema-allowed keys (allow-list build; nothing is copied wholesale).
-- ---------------------------------------------------------------------------

function Share.eventFromDeath(e)
    if type(e) ~= "table" or type(e.when) ~= "number" then return nil end
    local npc = cleanNpc(e.npc)
    if not npc then return nil end   -- env/unknown deaths never leave the machine
    local ev = { k = "death", npc = npc, mode = cleanMode(e.mode), season = Share.season() }
    if type(e.level) == "number" and e.level >= 1 and e.level <= 200 then
        ev.bracket = math.floor(e.level / 10) * 10
    end
    if type(e.mapID) == "number" then ev.zone = math.floor(e.mapID) end
    return ev
end

function Share.eventFromSlay(e)
    if not (RUN.Devil and RUN.Devil.validSlay(e)) then return nil end
    local npc = cleanNpc(e.npc)
    local p = tonumber(e.p)
    if not npc or not p or p < 0 or p > 1 then return nil end
    local ev = { k = "slay", npc = npc, p = p, mode = cleanMode(e.mode), season = Share.season() }
    local s = e.snap
    if type(s) == "table" and type(s.pLevel) == "number" and type(s.cLevel) == "number"
            and type(s.cls) == "string" then
        -- only the recomputable inputs; anything else in the stored snap is dropped
        ev.snap = { pLevel = s.pLevel, cLevel = s.cLevel, cls = s.cls }
    end
    return ev
end

local SIGHTING_CLS = { rare = true, rareelite = true, worldboss = true }

function Share.eventFromSighting(npcID, s)
    local npc = cleanNpc(npcID)
    if not npc or type(s) ~= "table" then return nil end
    local nm = Share.cleanName(s.name, 48)
    if not nm or not SIGHTING_CLS[s.classification] then return nil end
    local ev = { k = "sighting", npc = npc, nm = nm, cls = s.classification,
                 season = Share.season() }
    if type(s.mapID) == "number" then ev.zone = math.floor(s.mapID) end
    return ev
end

-- Calibration pairs are consent-gated at capture (model/calibration.lua); the
-- stored journal is user-editable, so every row re-clamps through that SAME
-- shape law before a fresh allow-listed event is built. The pairing timestamp
-- never leaves the machine.
function Share.eventFromCalib(e)
    if not (RUN.Calibration and RUN.Calibration.clampEvent) then return nil end
    local c = RUN.Calibration.clampEvent(e)
    if not c then return nil end
    return { k = "calib", npc = c.npc, pl = c.pl, cl = c.cl, cls = c.cls,
             p = c.p, out = c.out, season = Share.season() }
end

function Share.eventFromWipe(key)
    local ev = { k = "wipe", mode = "pve", season = Share.season() }
    if type(key) == "number" then
        ev.npc = cleanNpc(key)
        if not ev.npc then return nil end
    elseif type(key) == "string" then
        local enc = Share.cleanName(key:match("^enc:(.+)$"), 48)
        if not enc then return nil end
        ev.enc = enc
    else
        return nil
    end
    return ev
end

-- ---------------------------------------------------------------------------
-- Pure: wipe deltas. RUNDB.wipes is a count map (no timestamps), so "since the
-- last share" is a snapshot diff against db.wipesShared. Sorted for stability.
-- ---------------------------------------------------------------------------
function Share.wipeDeltas(db)
    local out = {}
    if type(db) ~= "table" or type(db.wipes) ~= "table" then return out end
    local base = (type(db.wipesShared) == "table") and db.wipesShared or {}
    for key, n in pairs(db.wipes) do
        if type(n) == "number" and n > 0 then
            local prev = (type(base[key]) == "number") and base[key] or 0
            if n - prev > 0 then out[#out + 1] = { key = key, delta = n - prev } end
        end
    end
    table.sort(out, function(a, b) return tostring(a.key) < tostring(b.key) end)
    return out
end

-- Pure: mark everything up to `now` as shared (called when a link is BUILT:
-- under-reporting an unpasted link is safe; double-counting never is).
function Share.markShared(db, now)
    if type(db) ~= "table" then return end
    db.lastShare = tonumber(now) or 0
    local snap = {}
    if type(db.wipes) == "table" then
        for key, n in pairs(db.wipes) do
            if type(n) == "number" and n > 0 then snap[key] = n end
        end
    end
    db.wipesShared = snap
end

-- A stable, non-identifying pseudonym (the Foresight technique): wall clock
-- mixed with the high-res profiler - never math.random (reseeding the shared
-- RNG taints it), never any character/account fact.
function Share.ensureClientId(db)
    if type(db) ~= "table" then return nil end
    if type(db.clientId) == "string" and db.clientId:match("^[%w%-]+$")
            and #db.clientId <= 40 then
        return db.clientId
    end
    local t = math.floor(((_G.time and _G.time()) or 0)) % 4294967296
    local prof = math.floor((((_G.debugprofilestop and _G.debugprofilestop()) or 0)) * 1000)
        % 4294967296
    db.clientId = ("%08x%08x"):format(t, prof)
    return db.clientId
end

-- ---------------------------------------------------------------------------
-- Pure: the payload builder. Reads the journals since db.lastShare, builds
-- allow-listed events (slays > deaths > sightings > wipes), returns the
-- envelope or nil when there is nothing to share. opts = { handle = "..." }
-- is the opt-in named tier; omitted = anonymous.
-- ---------------------------------------------------------------------------
function Share.buildPayload(db, now, opts)
    if type(db) ~= "table" then return nil end
    local sc = schema()
    if not sc then return nil end
    local since = (type(db.lastShare) == "number") and db.lastShare or 0
    local maxEvents = tonumber(sc.maxEvents) or 100
    local events, kinds, seen = {}, {}, {}

    local function add(ev)
        if not ev or #events >= maxEvents then return end
        events[#events + 1] = ev
        if not seen[ev.k] then
            seen[ev.k] = true
            kinds[#kinds + 1] = ev.k
        end
    end

    -- slays (the wager wins - rarest, first)
    if type(db.slays) == "table" then
        local n = 0
        for i = 1, #db.slays do
            local e = db.slays[i]
            if type(e) == "table" and type(e.when) == "number" and e.when > since then
                local ev = Share.eventFromSlay(e)
                if ev and n < MAX_PER_KIND.slay then n = n + 1; add(ev) end
            end
        end
    end

    -- deaths (creature kills of you; env deaths never qualify)
    if type(db.deaths) == "table" then
        local n = 0
        for i = 1, #db.deaths do
            local e = db.deaths[i]
            if type(e) == "table" and type(e.when) == "number" and e.when > since then
                local ev = Share.eventFromDeath(e)
                if ev and n < MAX_PER_KIND.death then n = n + 1; add(ev) end
            end
        end
    end

    -- sightings (the harvest; sorted so output is deterministic)
    if type(db.sightings) == "table" then
        local ids = {}
        for npcID, s in pairs(db.sightings) do
            if type(s) == "table" and type(s.when) == "number" and s.when > since then
                ids[#ids + 1] = npcID
            end
        end
        table.sort(ids, function(a, b) return tostring(a) < tostring(b) end)
        local n = 0
        for i = 1, #ids do
            local ev = Share.eventFromSighting(ids[i], db.sightings[ids[i]])
            if ev and n < MAX_PER_KIND.sighting then n = n + 1; add(ev) end
        end
    end

    -- wipes (snapshot delta; one event per wipe, capped per creature)
    local n = 0
    local deltas = Share.wipeDeltas(db)
    for i = 1, #deltas do
        local count = math.min(deltas[i].delta, MAX_WIPES_PER_KEY)
        for _ = 1, count do
            if n < MAX_PER_KIND.wipe then
                local ev = Share.eventFromWipe(deltas[i].key)
                if ev then n = n + 1; add(ev) end
            end
        end
    end

    -- calibration pairs (consent-gated capture; the least rare kind, so last
    -- in line for the envelope cap)
    if type(db.calib) == "table" then
        local nc = 0
        for i = 1, #db.calib do
            local e = db.calib[i]
            if type(e) == "table" and type(e.t) == "number" and e.t > since then
                local ev = Share.eventFromCalib(e)
                if ev and nc < MAX_PER_KIND.calib then nc = nc + 1; add(ev) end
            end
        end
    end

    if #events == 0 then return nil end

    local payload = {
        v = 1, kinds = kinds, events = events, season = Share.season(),
        clientId = Share.ensureClientId(db),
    }
    local handle = opts and Share.clampHandle(opts.handle)
    if handle then
        payload.named = true
        payload.handle = handle
    end
    payload.sum = Share.fletcher16(Share.canon(payload))
    return payload
end

-- ---------------------------------------------------------------------------
-- Pure: validation against the generated schema - the belt on the allow-list
-- braces. Checks envelope keys, required fields, per-event shapes, the
-- identifying-tier gate, and that NO forbidden key appears at ANY depth.
-- ---------------------------------------------------------------------------
local function findForbidden(t, forbiddenSet, depth)
    if (depth or 0) > 4 or type(t) ~= "table" then return nil end
    for k, v in pairs(t) do
        if type(k) == "string" and forbiddenSet[k:lower()] then return k end
        if type(v) == "table" then
            local hit = findForbidden(v, forbiddenSet, (depth or 0) + 1)
            if hit then return hit end
        end
    end
    return nil
end

function Share.validate(payload)
    local sc = schema()
    if not sc then return nil, "schema missing" end
    if type(payload) ~= "table" then return nil, "not a table" end

    local allow = toSet(sc.allow)
    for k in pairs(payload) do
        if type(k) ~= "string" or not allow[k] then
            return nil, "envelope key not in allow-list: " .. tostring(k)
        end
    end
    for _, k in ipairs(sc.required or {}) do
        if payload[k] == nil then return nil, "missing required: " .. k end
    end
    if payload.v ~= 1 then return nil, "bad version" end
    if type(payload.events) ~= "table" or #payload.events < 1
            or #payload.events > (tonumber(sc.maxEvents) or 100) then
        return nil, "bad events list"
    end

    local hit = findForbidden(payload, toSet(sc.forbidden))
    if hit then return nil, "FORBIDDEN key present: " .. hit end

    if (payload.handle ~= nil or payload.armory ~= nil) and payload.named ~= true then
        return nil, "identifying field without named opt-in"
    end

    local kindSet = toSet(sc.kinds)
    for i = 1, #payload.events do
        local e = payload.events[i]
        if type(e) ~= "table" or not kindSet[e.k] then return nil, "bad event kind" end
        local es = sc.events and sc.events[e.k]
        if not es then return nil, "no event schema: " .. tostring(e.k) end
        local eAllow = toSet(es.allow)
        for k in pairs(e) do
            if type(k) ~= "string" or not eAllow[k] then
                return nil, e.k .. " key not in allow-list: " .. tostring(k)
            end
        end
        for _, k in ipairs(es.required or {}) do
            if e[k] == nil then return nil, e.k .. " missing required: " .. k end
        end
        if type(e.snap) == "table" then
            local sAllow = toSet(es.snapAllow)
            for k in pairs(e.snap) do
                if not sAllow[k] then return nil, "snap key not in allow-list: " .. tostring(k) end
            end
        end
    end
    return true
end

-- ---------------------------------------------------------------------------
-- Pure: JSON + the one-link URL (ports of Foresight core/crowd.lua, plus array
-- support - events/kinds are arrays). Lua 5.1-safe escaping.
-- ---------------------------------------------------------------------------
local JSON_ESC = { ['"'] = '\\"', ['\\'] = '\\\\', ['\n'] = '\\n',
                   ['\r'] = '\\r', ['\t'] = '\\t' }

local function isArray(t)
    local n = 0
    for _ in pairs(t) do n = n + 1 end
    return n > 0 and n == #t
end

function Share.toJSON(v)
    local t = type(v)
    if t == "number" then
        if v == math.floor(v) and v == v and v ~= math.huge and v ~= -math.huge then
            return ("%d"):format(v)
        end
        return ("%.4g"):format(v)
    elseif t == "string" then
        return '"' .. v:gsub('[%c"\\]', function(ch)
            return JSON_ESC[ch] or ("\\u%04x"):format(ch:byte())
        end) .. '"'
    elseif t == "boolean" then
        return v and "true" or "false"
    elseif t == "table" then
        if isArray(v) then
            local parts = {}
            for i = 1, #v do parts[i] = Share.toJSON(v[i]) end
            return "[" .. table.concat(parts, ",") .. "]"
        end
        local keys = {}
        for k in pairs(v) do keys[#keys + 1] = k end
        table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
        local parts = {}
        for _, k in ipairs(keys) do
            parts[#parts + 1] = Share.toJSON(tostring(k)) .. ":" .. Share.toJSON(v[k])
        end
        return "{" .. table.concat(parts, ",") .. "}"
    end
    return "null"
end

-- Percent-encode to RFC-3986 unreserved; decodeURIComponent reverses it.
function Share.urlEncode(s)
    return (tostring(s):gsub("[^%w%-_%.~]", function(c)
        return ("%%%02X"):format(c:byte())
    end))
end

function Share.link(payload)
    if not payload then return nil end
    local site = (schema() and schema().site) or "https://wow-foresight.web.app/run.html"
    return site .. "#d=" .. Share.urlEncode(Share.toJSON(payload))
end

-- ---------------------------------------------------------------------------
-- The slash command (registry - parallel-build law). `/ra share` = anonymous;
-- `/ra share <handle>` = the opt-in named tier (typing your chosen handle IS
-- the consent act; it is never remembered between shares).
-- ---------------------------------------------------------------------------
RUN.commands = RUN.commands or {}
RUN.commands["share"] = function(rest)
    local db = RUN.db()
    local handle = Share.clampHandle(rest)
    local now = (_G.time and _G.time()) or 0
    local payload = Share.buildPayload(db, now, handle and { handle = handle } or nil)
    if not payload then
        RUN.print("nothing new to share since your last share link.")
        return
    end
    local ok, err = Share.validate(payload)
    if not ok then
        RUN.print("share blocked by the allow-list gate: " .. tostring(err))
        return
    end
    local url = Share.link(payload)
    Share.markShared(db, now)
    RUN.print("share link built - " .. #payload.events .. " event"
        .. (#payload.events == 1 and "" or "s")
        .. (payload.named and (" as \"" .. payload.handle .. "\"") or " (anonymous)")
        .. ". Paste it into your browser; nothing is sent until you do.")
    if RUN.Export and RUN.Export.show then
        RUN.Export.show(url)
    else
        RUN.print(url)
    end
end

-- ---------------------------------------------------------------------------
-- Selftests (registered; run headless and in-game).
-- ---------------------------------------------------------------------------
if type(RUN.selftestChecks) == "table" then
    table.insert(RUN.selftestChecks, function(check)
        local function fixtureDb()
            return {
                lastShare = 10,
                deaths = {
                    { when = 20, killer = "Hogger", npc = 448, mode = "hc", level = 23,
                      mapID = 1429, who = "Alta", realm = "EvilRealm" },
                    { when = 5, killer = "Hogger", npc = 448 },      -- before lastShare
                    { when = 21, killer = "a fall" },                -- env: no npc
                    { when = "tampered", npc = 448 },                -- invalid entry
                },
                slays = {
                    { when = 25, npc = 448, name = "Hogger", p = 0.2, tier = "giantslayer",
                      who = "Alta", snap = { pLevel = 10, cLevel = 12, cls = "rare", junk = 1 } },
                },
                sightings = {
                    [5786] = { name = "|cffff0000Snagglefang|r", classification = "rare",
                               mapID = 1413, x = 0.5, y = 0.6, when = 30 },
                    [5787] = { name = "Old News", classification = "rare", when = 3 },
                },
                wipes = { [448] = 3, ["enc:Hogger"] = 1 },
                wipesShared = { [448] = 1 },
                calib = {
                    { npc = 448, pl = 23, cl = 25, cls = "elite", p = 38,
                      out = "death", t = 30 },
                    { npc = 448, pl = 23, cl = 25, cls = "elite", p = 62,
                      out = "win", t = 5 },                       -- before lastShare
                    { npc = 0, pl = 23, cl = 25, cls = "elite", p = 38,
                      out = "win", t = 31 },                      -- invalid npc
                    { npc = 449, pl = 23, cl = 25, cls = "weird", p = "junk",
                      out = "win", t = 32 },                      -- tampered row
                },
            }
        end

        local S = RUN.Share
        local db = fixtureDb()
        local payload = S.buildPayload(db, 100)
        check("share payload built", type(payload) == "table" and payload.v == 1)
        check("share validate green", payload and S.validate(payload) == true)
        check("share event census", (function()
            if not payload then return false end
            local n = { death = 0, slay = 0, sighting = 0, wipe = 0, calib = 0 }
            for _, e in ipairs(payload.events) do n[e.k] = n[e.k] + 1 end
            -- 1 fresh death, 1 slay, 1 fresh sighting, 2+1 wipe deltas, 1 calib
            return n.death == 1 and n.slay == 1 and n.sighting == 1 and n.wipe == 3
                and n.calib == 1
        end)())
        check("share death shape", (function()
            if not payload then return false end
            for _, e in ipairs(payload.events) do
                if e.k == "death" then
                    return e.npc == 448 and e.mode == "hc" and e.bracket == 20
                        and e.zone == 1429 and e.season == S.season()
                        and e.killer == nil and e.who == nil and e.level == nil
                end
            end
            return false
        end)())
        check("share slay snap stripped to allow-list", (function()
            if not payload then return false end
            for _, e in ipairs(payload.events) do
                if e.k == "slay" then
                    return e.p == 0.2 and e.snap and e.snap.pLevel == 10
                        and e.snap.junk == nil and e.name == nil and e.who == nil
                end
            end
            return false
        end)())
        check("share sighting cleaned", (function()
            if not payload then return false end
            for _, e in ipairs(payload.events) do
                if e.k == "sighting" then
                    return e.nm == "Snagglefang" and e.cls == "rare" and e.zone == 1413
                        and e.x == nil and e.y == nil
                end
            end
            return false
        end)())
        check("share calib shape - reclamped, timestamp stays local", (function()
            if not payload then return false end
            for _, e in ipairs(payload.events) do
                if e.k == "calib" then
                    return e.npc == 448 and e.pl == 23 and e.cl == 25
                        and e.cls == "elite" and e.p == 38 and e.out == "death"
                        and e.season == S.season() and e.t == nil
                end
            end
            return false
        end)())
        check("share calib junk/stale rows never ship", (function()
            if not payload then return false end
            for _, e in ipairs(payload.events) do
                if e.k == "calib" and (e.npc == 449 or e.npc == 0 or e.out == "win") then
                    return false
                end
            end
            return true
        end)())
        check("share forbidden keys never pass", (function()
            if not payload then return false end
            local json = S.toJSON(payload)
            return json:find("realm", 1, true) == nil and json:find("Alta", 1, true) == nil
                and json:find("who", 1, true) == nil and json:find("guild", 1, true) == nil
        end)())
        check("share forbidden key caught by validate", (function()
            local bad = S.buildPayload(fixtureDb(), 100)
            if not bad then return false end
            bad.events[1].realm = "EvilRealm"
            local ok, err = S.validate(bad)
            return ok == nil and tostring(err):find("FORBIDDEN") ~= nil
        end)())
        check("share unknown envelope key rejected", (function()
            local bad = S.buildPayload(fixtureDb(), 100)
            if not bad then return false end
            bad.extra = 1
            return S.validate(bad) == nil
        end)())
        check("share link round-trip", (function()
            if not payload then return false end
            local url = S.link(payload)
            return type(url) == "string"
                and url:find("https://wow-foresight.web.app/run.html#d=", 1, true) == 1
        end)())
        check("share sum covers canon", payload
            and payload.sum == S.fletcher16(S.canon(payload)))
        check("share empty journal safe", S.buildPayload({}, 100) == nil
            and S.buildPayload(nil, 100) == nil)
        check("share nothing-new safe", (function()
            local quiet = fixtureDb()
            quiet.lastShare = 1000
            quiet.wipesShared = { [448] = 3, ["enc:Hogger"] = 1 }
            return S.buildPayload(quiet, 2000) == nil
        end)())
        check("share named gating", (function()
            local p1 = S.buildPayload(fixtureDb(), 100)
            local p2 = S.buildPayload(fixtureDb(), 100, { handle = "Brad the Bold!!!" })
            return p1 and p1.named == nil and p1.handle == nil
                and p2 and p2.named == true and p2.handle == "Brad the Bold"
                and S.validate(p2) == true
        end)())
        check("share handle clamp", S.clampHandle("  x|y<z>  ") == "xyz"
            and S.clampHandle("") == nil and S.clampHandle(nil) == nil
            and #(S.clampHandle(string.rep("a", 40)) or "") == 24)
        check("share markShared snapshots wipes", (function()
            local d = fixtureDb()
            S.markShared(d, 100)
            return d.lastShare == 100 and d.wipesShared[448] == 3
                and d.wipesShared["enc:Hogger"] == 1
                and #S.wipeDeltas(d) == 0
        end)())
        check("share clientId stable + shaped", (function()
            local d = fixtureDb()
            local a = S.ensureClientId(d)
            local b = S.ensureClientId(d)
            return type(a) == "string" and a == b and a:match("^[%w%-]+$") ~= nil and #a <= 40
        end)())
        check("share json arrays", S.toJSON({ 1, 2, 3 }) == "[1,2,3]"
            and S.toJSON({ k = "v" }) == '{"k":"v"}')
        check("share era detection by API presence", (function()
            local fn = function() end
            -- Forever/mainline: C_QuestLog.GetInfo present - modern wins
            -- outright, even with an era-named global also around
            if S.detectEra({ GetInfo = fn }, fn) ~= false then return false end
            -- era 1.15.x: C_QuestLog exists (GetQuestObjectives) WITHOUT
            -- GetInfo, plus the old global quest log
            if S.detectEra({ GetQuestObjectives = fn }, fn) ~= true then return false end
            -- headless/unknown client: no API at all - never era
            return S.detectEra(nil, nil) == false
        end)())
        check("share season partition prefixes", (function()
            -- each game line stamps its OWN prefix (npcIDs are identical
            -- across the games; the prefix is the partition)
            return S.seasonFor(false):match("^s[0-9]+$") ~= nil
                and S.seasonFor(true):match("^c[0-9]+$") ~= nil
        end)())
        check("share season stamps the platform tag verbatim", (function()
            -- the live wiring: season() resolves through detection, and the
            -- resolved tag rides the envelope AND every event
            local want = S.seasonFor(S.detectEra(_G.C_QuestLog, _G.GetQuestLogTitle))
            if not payload or S.season() ~= want or payload.season ~= want then
                return false
            end
            for _, e in ipairs(payload.events) do
                if e.season ~= want then return false end
            end
            return true
        end)())
        check("share season flip changes the stamp", (function()
            -- flip the constant the LIVE platform reads (era clients read
            -- RUN.seasonEra, Forever reads RUN.season) - green on both
            local era = S.detectEra(_G.C_QuestLog, _G.GetQuestLogTitle)
            local key = era and "seasonEra" or "season"
            local want = era and "c1" or "s1"
            local old = RUN[key]
            RUN[key] = want
            local p = S.buildPayload(fixtureDb(), 100)
            RUN[key] = old
            if not p or p.season ~= want then return false end
            for _, e in ipairs(p.events) do
                if e.season ~= want then return false end
            end
            -- the flipped tag still validates and the checksum follows the canon
            return S.validate(p) == true and p.sum == S.fletcher16(S.canon(p))
        end)())
        check("share season clamp fail-safe stays in-partition", (function()
            local oldS, oldC = RUN.season, RUN.seasonEra
            RUN.season = "NOT A TAG!"           -- off-shape: never stamped
            RUN.seasonEra = "NOT A TAG!"
            local badS, badC = S.seasonFor(false), S.seasonFor(true)
            RUN.season = nil                    -- missing: never errors
            RUN.seasonEra = nil
            local missS, missC = S.seasonFor(false), S.seasonFor(true)
            RUN.season, RUN.seasonEra = oldS, oldC
            -- each line falls back to ITS OWN season-0: a bad edit may lose a
            -- flip, but it must never cross the game partition
            return badS == "s0" and badC == "c0"
                and missS == "s0" and missC == "c0"
                and S.seasonFor(false) == oldS and S.seasonFor(true) == oldC
        end)())
    end)
end

return Share
