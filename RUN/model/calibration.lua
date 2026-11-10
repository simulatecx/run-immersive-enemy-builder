-- Calibration capture (CAL, 2026-11-10): the QuestieTrace pattern applied to RUN.
-- Opt-in, local-first collection of (predicted odds, actual outcome) pairs so the
-- odds curve can be calibrated against reality - the empty-safe "crowd calibration
-- hook (phase E)" in model/odds.lua is the consumer. docs/QUESTIETRACE-ANALYSIS.md
-- is the design record.
--
-- THE CONSENT LAW (QuestieTrace's shape, our words):
--   RUNDB.captureConsent is tri-state: nil = never asked (first login shows our OWN
--   dialog - never a Blizzard StaticPopup, their shared lists carry taint), true =
--   capture runs, false = never ask again (/ra capture on to change your mind).
--   Declining DISCARDS the pending assessment cache rather than saving it. While
--   enabled, every login prints one transparency line. Data stays on this machine
--   until the player builds a /ra share link themselves.
--
-- WHAT IS CAPTURED (and nothing else): when RUN assesses a hostile creature's odds
-- (target/mouseover) and that same creature then dies to you solo, or kills you
-- solo, within the pairing window, ONE pair is journaled:
--   { npc, pl (your level), cl (creature level), cls (classification),
--     p (predicted win %, 1..99), out ("win"|"death"), t }
-- No GUIDs, no names, no positions, no group members - pure game data, the same
-- allow-list philosophy as every RUN journal. Capped; oldest dropped.

local _, RUN = ...
if not RUN then RUN = _G.RunAdvisor or {}; _G.RunAdvisor = RUN end

local Calibration = {}
RUN.Calibration = Calibration

local JOURNAL_MAX = 200          -- QuestieTrace caps sessions; we cap pairs
local PAIR_WINDOW = 600          -- seconds an assessment stays pairable
local CACHE_MAX = 6              -- distinct creatures tracked at once
local REMIND_AFTER = 3600        -- the inn reminder: >= 1h since start/last

local VALID_OUT = { win = true, death = true }
local VALID_CLS = { normal = true, elite = true, rare = true, rareelite = true,
                    worldboss = true, trivial = true, minus = true }

-- ---- pure core (headless-tested; everything above the CreateFrame guard) ----

-- Shape-clamp a journal event; nil when invalid (untrusted-store law: RUNDB is
-- user-editable, so share-side reads re-clamp through THIS same function).
function Calibration.clampEvent(e)
    if type(e) ~= "table" then return nil end
    local npc = tonumber(e.npc)
    local pl, cl = tonumber(e.pl), tonumber(e.cl)
    local p = tonumber(e.p)
    if not (npc and npc >= 1 and npc <= 10000000) then return nil end
    if not (pl and pl >= 1 and pl <= 100) then return nil end
    if not (cl and cl >= -1 and cl <= 103) then return nil end
    if not (p and p >= 1 and p <= 99) then return nil end
    if not VALID_OUT[e.out] then return nil end
    local cls = VALID_CLS[e.cls] and e.cls or "normal"
    return { npc = math.floor(npc), pl = math.floor(pl), cl = math.floor(cl),
             cls = cls, p = math.floor(p), out = e.out, t = tonumber(e.t) or 0 }
end

-- Pair the LAST assessment of a creature with an outcome for that creature.
-- Pure: cache = { [npc] = {p=0..1, pl, cl, cls, t} }, outcome = {npc, out, t}.
-- Returns a clamped journal event, or nil (no assessment / stale / mismatch).
function Calibration.pair(cache, outcome, now)
    if type(cache) ~= "table" or type(outcome) ~= "table" then return nil end
    local a = cache[outcome.npc]
    if not a then return nil end
    now = tonumber(now) or 0
    if (now - (tonumber(a.t) or 0)) > PAIR_WINDOW then return nil end
    local pct = math.floor((tonumber(a.p) or 0) * 100 + 0.5)
    if pct < 1 then pct = 1 elseif pct > 99 then pct = 99 end
    return Calibration.clampEvent({
        npc = outcome.npc, pl = a.pl, cl = a.cl, cls = a.cls,
        p = pct, out = outcome.out, t = outcome.t or now,
    })
end

-- Keep the assessment cache small: drop the oldest entries beyond CACHE_MAX.
function Calibration.trimCache(cache)
    local keys = {}
    for npc, a in pairs(cache) do keys[#keys + 1] = { npc = npc, t = a.t or 0 } end
    if #keys <= CACHE_MAX then return cache end
    table.sort(keys, function(x, y) return x.t > y.t end)
    for i = CACHE_MAX + 1, #keys do cache[keys[i].npc] = nil end
    return cache
end

-- The inn reminder decision (QuestieTrace's shape: >= 1h played AND resting;
-- never on a login/interval alone). Pure over injected state.
function Calibration.reminderDue(state, now, resting, consent)
    if consent ~= true or not resting then return false end
    state = type(state) == "table" and state or {}
    local anchor = math.max(tonumber(state.sessionStart) or 0,
                            tonumber(state.lastAt) or 0)
    return (now - anchor) >= REMIND_AFTER
end

-- Consent read (tri-state) off an injected db table - the live wrapper passes
-- RUN.db(); selftests pass fixtures.
function Calibration.consentOf(db)
    -- NOT `db.x or nil`: the and/or idiom would collapse a stored FALSE
    -- ("never ask again") into nil ("never asked") and re-show the dialog.
    if type(db) ~= "table" then return nil end
    local v = db.captureConsent
    if v == true or v == false then return v end
    return nil
end

-- ---- live state --------------------------------------------------------------

local cache = {}     -- npc -> last assessment (only populated while consent==true)

function Calibration.consent()
    return Calibration.consentOf(RUN.db and RUN.db() or nil)
end

local function setConsent(v)
    local db = RUN.db and RUN.db()
    if db then db.captureConsent = v end
    if v ~= true then cache = {} end   -- decline/withdraw discards, never saves
end

-- Called from Odds.forUnit (one defensive hook): remember the latest assessment
-- for this creature while capture is on.
function Calibration.noteAssessment(verdict)
    if Calibration.consent() ~= true then return end
    if type(verdict) ~= "table" or type(verdict.creature) ~= "table" then return end
    local c = verdict.creature
    local npc = tonumber(c.npcID)
    if not npc or verdict.skull then return end  -- skull odds are a floor, not a prediction
    local me = RUN.Detect and RUN.Detect.playerInfo and RUN.Detect.playerInfo() or {}
    cache[npc] = {
        p = tonumber(verdict.p) or 0,
        pl = tonumber(me.level) or 1,
        cl = tonumber(c.level) or -1,
        cls = c.classification,
        t = _G.GetTime and _G.GetTime() or 0,
    }
    Calibration.trimCache(cache)
end

-- Journal an outcome if it pairs with a recent assessment. solo-only: the odds
-- are a SOLO prediction; a grouped fight would poison the curve.
local function recordOutcome(npc, out)
    if Calibration.consent() ~= true or not npc then return end
    local now = _G.GetTime and _G.GetTime() or 0
    local e = Calibration.pair(cache, { npc = npc, out = out, t = _G.time and _G.time() or 0 }, now)
    if not e then return end
    cache[npc] = nil   -- one assessment, one pair - never double-counted
    local db = RUN.db and RUN.db()
    if not db then return end
    if type(db.calib) ~= "table" then db.calib = {} end
    db.calib[#db.calib + 1] = e
    while #db.calib > JOURNAL_MAX do table.remove(db.calib, 1) end
end

-- ---- selftests (pure core only; registered the house way) ---------------------

if type(RUN.selftestChecks) == "table" then
    table.insert(RUN.selftestChecks, function(check)
        local now = 1000
        local c = { [42] = { p = 0.62, pl = 20, cl = 21, cls = "elite", t = now - 30 } }
        local e = Calibration.pair(c, { npc = 42, out = "win", t = 111 }, now)
        check("calib: pair matches npc within the window", e ~= nil and e.p == 62
            and e.out == "win" and e.cls == "elite" and e.npc == 42)
        check("calib: stale assessment never pairs",
            Calibration.pair(c, { npc = 42, out = "win" }, now + PAIR_WINDOW + 61) == nil)
        check("calib: unassessed creature never pairs",
            Calibration.pair(c, { npc = 7, out = "death" }, now) == nil)
        check("calib: clamp rejects junk + heals classification", (function()
            if Calibration.clampEvent({ npc = 0, pl = 20, cl = 20, p = 50, out = "win" }) then return false end
            if Calibration.clampEvent({ npc = 5, pl = 20, cl = 20, p = 50, out = "nope" }) then return false end
            local ok = Calibration.clampEvent({ npc = 5, pl = 20, cl = 20, p = 50,
                                                out = "death", cls = "weird" })
            return ok ~= nil and ok.cls == "normal"
        end)())
        check("calib: consent is honestly tri-state", (function()
            if Calibration.consentOf({}) ~= nil then return false end
            if Calibration.consentOf({ captureConsent = true }) ~= true then return false end
            if Calibration.consentOf({ captureConsent = false }) ~= false then return false end
            if Calibration.consentOf({ captureConsent = "yes" }) ~= nil then return false end
            return true
        end)())
        check("calib: cache trims to the newest few", (function()
            local big = {}
            for i = 1, CACHE_MAX + 4 do big[i] = { p = 0.5, t = i } end
            Calibration.trimCache(big)
            local n = 0
            for _ in pairs(big) do n = n + 1 end
            return n == CACHE_MAX and big[CACHE_MAX + 4] ~= nil and big[1] == nil
        end)())
        check("calib: inn reminder needs consent + rest + the hour", (function()
            local st = { sessionStart = 0, lastAt = 0 }
            if Calibration.reminderDue(st, REMIND_AFTER + 1, true, false) then return false end
            if Calibration.reminderDue(st, REMIND_AFTER + 1, false, true) then return false end
            if Calibration.reminderDue(st, REMIND_AFTER - 10, true, true) then return false end
            if not Calibration.reminderDue(st, REMIND_AFTER + 1, true, true) then return false end
            return not Calibration.reminderDue({ sessionStart = 0, lastAt = REMIND_AFTER },
                REMIND_AFTER + 60, true, true)
        end)())
    end)
end

if not _G.CreateFrame then return Calibration end

-- ---- in-game wiring ------------------------------------------------------------

-- Outcome detection mirrors devil.lua: PARTY_KILL where we are the killer (solo),
-- and PLAYER_DEAD paired with Attribution's killer. Solo-ness guard-read, the
-- devil.lua shape exactly.
local function isSolo()
    local inGroup = RUN.Guards.call(_G.IsInGroup)
    local inRaid = RUN.Guards.call(_G.IsInRaid)
    return not inGroup and not inRaid
end

RUN.on("COMBAT_LOG_EVENT_UNFILTERED", function()
    if Calibration.consent() ~= true then return end
    pcall(function()
        local info = { _G.CombatLogGetCurrentEventInfo() }
        local subevent, sourceGUID, destGUID = info[2], info[4], info[8]
        if RUN.Guards.isSecret(subevent) or RUN.Guards.isSecret(destGUID) then return end
        if subevent ~= "PARTY_KILL" then return end
        if not isSolo() then return end
        local npc = RUN.Detect.npcIdFromGUID(destGUID)
        if not npc then return end
        local myGUID = RUN.Guards.call(_G.UnitGUID, "player")
        if sourceGUID == myGUID then recordOutcome(npc, "win") end
    end)
end)

RUN.on("PLAYER_DEAD", function()
    if Calibration.consent() ~= true then return end
    if not isSolo() then return end
    local last = RUN.Attribution and RUN.Attribution.lastDeath
    if last and last.npc then recordOutcome(last.npc, "death") end
end)

-- ---- consent dialog (our OWN frame; the QuestieTrace taint lesson) -------------

local consentFrame
local function showConsentDialog()
    if consentFrame then consentFrame:Show(); return end
    local f = _G.CreateFrame("Frame", "RUNCaptureConsent", _G.UIParent)
    consentFrame = f
    f:SetSize(420, 150)
    f:SetPoint("TOP", _G.UIParent, "TOP", 0, -180)
    f:SetFrameStrata("DIALOG")
    f:SetClampedToScreen(true)
    local bg = f:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(); bg:SetColorTexture(0.05, 0.05, 0.07, 0.95)
    for _, edge in ipairs({ "TOPLEFT;TOPRIGHT;1", "BOTTOMLEFT;BOTTOMRIGHT;1" }) do
        local a, b = edge:match("^(%w+);(%w+)")
        local line = f:CreateTexture(nil, "BORDER")
        line:SetPoint(a); line:SetPoint(b); line:SetHeight(1)
        line:SetColorTexture(0.9, 0.3, 0.2, 0.7)
    end
    local title = f:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    title:SetPoint("TOP", 0, -10)
    title:SetText("|cffff5a3cRUN|r - help calibrate the odds?")
    local text = f:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    text:SetPoint("TOPLEFT", 16, -32); text:SetPoint("TOPRIGHT", -16, -32)
    text:SetJustifyH("LEFT"); text:SetWordWrap(true)
    text:SetText("Allow RUN to record anonymized fight outcomes on this device - the creature, your level, the predicted odds, and whether you won? No names, no positions. Data stays on your machine unless you build a /ra share link yourself.")
    local yes = _G.CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    yes:SetSize(120, 22); yes:SetPoint("BOTTOMLEFT", 60, 12); yes:SetText("Yes, help out")
    yes:SetScript("OnClick", function()
        f:Hide(); setConsent(true)
        RUN.print("thank you - fight outcomes are being recorded locally (/ra capture off anytime).")
    end)
    local no = _G.CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    no:SetSize(120, 22); no:SetPoint("BOTTOMRIGHT", -60, 12); no:SetText("No thanks")
    no:SetScript("OnClick", function()
        f:Hide(); setConsent(false)
        RUN.print("declined - nothing is recorded. /ra capture on if you change your mind.")
    end)
end

-- ---- the inn share reminder -----------------------------------------------------

local function reminderState()
    local db = RUN.db and RUN.db()
    if not db then return { sessionStart = 0, lastAt = 0 } end
    if type(db.calibReminder) ~= "table" then db.calibReminder = {} end
    return db.calibReminder
end

local function maybeRemind()
    local st = reminderState()
    local now = _G.GetTime and _G.GetTime() or 0
    local resting = _G.IsResting and _G.IsResting() or false
    if Calibration.reminderDue(st, now, resting, Calibration.consent()) then
        st.lastAt = now
        RUN.print("you've gathered fresh fight data this session - |cffffd24d/ra share|r when you have a minute (it stays local until you paste the link).")
    end
end

RUN.on("PLAYER_UPDATE_RESTING", maybeRemind)

RUN.on("PLAYER_LOGIN", function()
    local st = reminderState()
    st.sessionStart = _G.GetTime and _G.GetTime() or 0
    local consent = Calibration.consent()
    if consent == nil then
        -- First login since install: ask ONCE, with our own frame.
        if _G.C_Timer and _G.C_Timer.After then
            _G.C_Timer.After(5, showConsentDialog)
        else
            showConsentDialog()
        end
    elseif consent == true then
        -- The QuestieTrace transparency line, once per login.
        RUN.print("fight-outcome capture is ON (local only; /ra capture off anytime).")
    end
end)

-- ---- /ra capture -----------------------------------------------------------------

RUN.commands["capture"] = function(rest)
    rest = (rest or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    local db = RUN.db and RUN.db()
    if rest == "on" then
        setConsent(true)
        RUN.print("capture ON - anonymized fight outcomes are recorded locally.")
    elseif rest == "off" then
        setConsent(false)
        RUN.print("capture OFF - pending observations discarded; the journal keeps what you already had.")
    else
        local consent = Calibration.consent()
        local n = (db and type(db.calib) == "table") and #db.calib or 0
        RUN.print(("capture is %s - %d fight pair(s) journaled locally. /ra capture on|off; /ra share to contribute.")
            :format(consent == true and "ON" or consent == false and "OFF" or "undecided", n))
    end
end

return Calibration
