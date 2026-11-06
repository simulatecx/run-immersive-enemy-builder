-- The Account Ledger: one window for "what killed us" (account-wide - RUNDB is
-- account-level SavedVariables, so every alt feeds it) and the OPTIONS menu
-- (every toggle as a checkbox - the slash is just the power-user lever).
-- Opened from the minimap button or /ra log. Own frame on UIParent; display
-- only. Pure aggregation helpers are headless-tested.

local _, RUN = ...
if not RUN then RUN = _G.RunAdvisor or {}; _G.RunAdvisor = RUN end

local Window = {}
RUN.Window = Window

-- ---------------------------------------------------------------------------
-- Pure: aggregate the death journal into "top killers" (count + last victim).
-- Entries are user-editable SavedVariables - validate every one.
-- ---------------------------------------------------------------------------
function Window.topKillers(deaths, maxN)
    maxN = tonumber(maxN) or 8
    if type(deaths) ~= "table" then return {} end
    local byKiller, order = {}, {}
    for i = 1, #deaths do
        local e = deaths[i]
        if RUN.Attribution.validEntry(e) and e.killer then
            local k = byKiller[e.killer]
            if not k then
                k = { name = e.killer, count = 0 }
                byKiller[e.killer] = k
                table.insert(order, k)
            end
            k.count = k.count + 1
            k.lastWho = e.who or k.lastWho
            k.lastZone = e.zone or k.lastZone
            k.lastWhen = e.when
        end
    end
    table.sort(order, function(a, b)
        if a.count ~= b.count then return a.count > b.count end
        return (a.lastWhen or 0) > (b.lastWhen or 0)
    end)
    local out = {}
    for i = 1, math.min(#order, maxN) do out[i] = order[i] end
    return out
end

-- Pure: the MOST WANTED board - species ranked by total notoriety (your
-- journal + deaths heard), wearing their earned titles. The Nemesis showpiece.
function Window.mostWanted(deaths, heard, maxN)
    maxN = tonumber(maxN) or 5
    local byNpc, order = {}, {}
    local function bucket(npc)
        local b = byNpc[npc]
        if not b then
            b = { npc = npc, kills = 0, heard = 0 }
            byNpc[npc] = b
            table.insert(order, b)
        end
        return b
    end
    if type(deaths) == "table" then
        for i = 1, #deaths do
            local e = deaths[i]
            if RUN.Attribution.validEntry(e) and e.npc then
                local b = bucket(e.npc)
                b.kills = b.kills + 1
                b.name = e.killer or b.name
            end
        end
    end
    if type(heard) == "table" then
        for npc, n in pairs(heard) do
            if type(npc) == "number" and type(n) == "number" and n > 0 then
                bucket(npc).heard = n
            end
        end
    end
    for _, b in ipairs(order) do
        b.total = b.kills + b.heard
        b.tier = RUN.Notoriety.tierFor(b.total)
        b.title = RUN.Notoriety.titleFor(b.npc, b.tier)
        b.name = b.name or ("creature #" .. tostring(b.npc))
    end
    table.sort(order, function(a, b) return a.total > b.total end)
    local out = {}
    for i = 1, math.min(#order, maxN) do out[i] = order[i] end
    return out
end

-- Pure: newest-first valid entries.
function Window.recent(deaths, maxN)
    maxN = tonumber(maxN) or 8
    local out = {}
    if type(deaths) ~= "table" then return out end
    for i = #deaths, 1, -1 do
        local e = deaths[i]
        if RUN.Attribution.validEntry(e) then
            table.insert(out, e)
            if #out >= maxN then break end
        end
    end
    return out
end

-- Pure: is this heard-log entry shaped right? (SavedVariables = untrusted.)
function Window.validHeard(e)
    return type(e) == "table"
        and type(e.npc) == "number" and e.npc >= 1
        and type(e.t) == "number"
end

-- Pure: one page of the heard-log FIFO, newest-first, invalid entries skipped.
-- Returns slice, clampedPage, pageCount, validTotal (page 1 = most recent).
function Window.heardPage(log, page, per)
    per = tonumber(per) or 14
    if per < 1 then per = 1 end
    page = tonumber(page) or 1
    local valid = {}
    if type(log) == "table" then
        for i = #log, 1, -1 do
            local e = log[i]
            if Window.validHeard(e) then table.insert(valid, e) end
        end
    end
    local pages = math.max(1, math.ceil(#valid / per))
    if page < 1 then page = 1 end
    if page > pages then page = pages end
    local out, start = {}, (page - 1) * per
    for i = start + 1, math.min(start + per, #valid) do
        table.insert(out, valid[i])
    end
    return out, page, pages, #valid
end

-- Pure: the guild wipe record for ONE guild (RUNDB.guildWipes shape - user-
-- editable SavedVariables, every layer validated). Returns { total, worstKey,
-- worstCount } or nil when there is nothing to show (graceful-empty). Keys
-- match RUNDB.wipes: npcID (number) or "enc:<name>"; ties on worst break
-- deterministically by key string.
function Window.guildSummary(guildWipes, guildName)
    if type(guildWipes) ~= "table" then return nil end
    if type(guildName) ~= "string" or guildName == "" then return nil end
    local tally = guildWipes[guildName]
    if type(tally) ~= "table" then return nil end
    local total, worstKey, worstCount = 0, nil, 0
    for key, n in pairs(tally) do
        local validKey = (type(key) == "number" and key >= 1)
            or (type(key) == "string" and key:match("^enc:.") ~= nil)
        if validKey and type(n) == "number" and n > 0 then
            total = total + n
            if n > worstCount
                or (n == worstCount and tostring(key) < tostring(worstKey)) then
                worstKey, worstCount = key, n
            end
        end
    end
    if total == 0 then return nil end
    return { total = total, worstKey = worstKey, worstCount = worstCount }
end

-- ---------------------------------------------------------------------------
-- Package-registered selftests (pure; run headless AND in-game).
-- ---------------------------------------------------------------------------
table.insert(RUN.selftestChecks, function(check)
    local store = {
        Alpha = { [448] = 3, ["enc:Hogger"] = 5, [3113] = 1,
                  bad = 9, [99] = "junk", ["enc:"] = 7 },
        Beta = "tampered",
        Empty = {},
    }
    check("guild summary totals + worst", (function()
        local s = Window.guildSummary(store, "Alpha")
        return s and s.total == 9 and s.worstKey == "enc:Hogger" and s.worstCount == 5
    end)())
    check("guild summary graceful-empty",
        Window.guildSummary(store, "Nobody") == nil
        and Window.guildSummary(store, "Beta") == nil
        and Window.guildSummary(store, "Empty") == nil
        and Window.guildSummary(nil, "Alpha") == nil
        and Window.guildSummary(store, nil) == nil
        and Window.guildSummary(store, "") == nil)
    check("guild summary worst tie deterministic", (function()
        local s = Window.guildSummary({ G = { [500] = 2, [200] = 2 } }, "G")
        return s and s.total == 4 and s.worstKey == 200 and s.worstCount == 2
    end)())
end)

table.insert(RUN.selftestChecks, function(check)
    local log = {}
    for i = 1, 30 do
        table.insert(log, { npc = 100 + i, t = i, bracket = 10, sum = i })
    end
    table.insert(log, { npc = "tampered", t = 99 })   -- invalid: must be skipped
    table.insert(log, "junk")
    local p1, page1, pages, total = Window.heardPage(log, 1, 14)
    check("heard page newest first", #p1 == 14 and p1[1].npc == 130 and p1[14].npc == 117)
    check("heard page skips invalid", page1 == 1 and pages == 3 and total == 30)
    local p3 = Window.heardPage(log, 3, 14)
    check("heard page tail slice", #p3 == 2 and p3[1].npc == 102 and p3[2].npc == 101)
    local _, clamped = Window.heardPage(log, 99, 14)
    check("heard page clamps past end", clamped == 3)
    local _, floored = Window.heardPage(log, -5, 14)
    check("heard page clamps below 1", floored == 1)
    check("heard page empty-safe", (function()
        local slice, pg, pgs, n = Window.heardPage(nil, 1, 14)
        return #slice == 0 and pg == 1 and pgs == 1 and n == 0
    end)())
    check("heard valid entry gate", Window.validHeard({ npc = 1, t = 0 }) == true
        and Window.validHeard({ npc = 0, t = 0 }) == false
        and Window.validHeard({ npc = 1 }) == false
        and Window.validHeard(nil) == false)
end)

-- Everything below builds the client UI.
if not _G.CreateFrame then return Window end

local GOLD, DIM = "|cffefd488", "|cffb7a988"

-- Options layout drives the checkbox grid; the HOME page height is COMPUTED
-- from the ledger text plus this block at refresh time (Window.refresh), so the
-- window fits its content exactly - no option ever spills past the frame AND no
-- dead gap when the ledger is short (field bug: the glow toggles overflowed the
-- old fixed 588 height). Two columns that flow directly under the ledger.
local OPT_COLS, OPT_ROWH, OPT_CB = 2, 26, 24
local OPT_ROWS = math.ceil(#RUN.Settings.defs / OPT_COLS)
local OPT_BLOCK = 16 + 8 + (OPT_ROWS - 1) * OPT_ROWH + OPT_CB   -- header + gap + rows
local STATS_TOP, HEADER_GAP, BOTTOM_PAD = 36, 14, 16
local HEARD_H = 588   -- the Heard page is a fixed 14-row list

local f = CreateFrame("Frame", "RUNLedgerWindow", UIParent)
f:SetSize(400, 560)   -- initial; Window.refresh sets the real per-page height
f:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
f:SetFrameStrata("DIALOG")
f:SetMovable(true)
f:EnableMouse(true)
f:SetClampedToScreen(true)
f:Hide()

-- drag ANYWHERE on the window (field report: title-bar-only felt broken)
f:RegisterForDrag("LeftButton")
f:SetScript("OnDragStart", function(self) self:StartMoving() end)
f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)

-- ESC closes it like any panel (UISpecialFrames is the standard plain table)
table.insert(_G.UISpecialFrames, "RUNLedgerWindow")

local bg = f:CreateTexture(nil, "BACKGROUND")
bg:SetAllPoints()
bg:SetColorTexture(0.05, 0.04, 0.03, 0.94)
local edge = f:CreateTexture(nil, "BORDER")
edge:SetPoint("TOPLEFT", -1, 1); edge:SetPoint("BOTTOMRIGHT", 1, -1)
edge:SetColorTexture(0.78, 0.64, 0.3, 0.6)
local inner = f:CreateTexture(nil, "ARTWORK")
inner:SetAllPoints(); inner:SetColorTexture(0.05, 0.04, 0.03, 1)
inner:SetDrawLayer("BORDER", 1)

-- title bar = drag handle
local titleBar = CreateFrame("Frame", nil, f)
titleBar:SetPoint("TOPLEFT"); titleBar:SetPoint("TOPRIGHT"); titleBar:SetHeight(30)
titleBar:EnableMouse(true)
titleBar:RegisterForDrag("LeftButton")
titleBar:SetScript("OnDragStart", function() f:StartMoving() end)
titleBar:SetScript("OnDragStop", function() f:StopMovingOrSizing() end)

local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
title:SetPoint("TOP", 0, -9)
title:SetText(GOLD .. "RUN - Account Ledger|r")

-- shared button style: a plain Button + gold fontstring, the house look
local function makeTextButton(parent, text)
    local b = CreateFrame("Button", nil, parent)
    local fs = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fs:SetPoint("CENTER")
    fs:SetText(text)
    b.label = fs
    b:SetSize(math.max(fs:GetStringWidth() + 16, 44), 20)
    b:SetScript("OnEnter", function() if b:IsEnabled() then fs:SetTextColor(1, 0.95, 0.6) end end)
    b:SetScript("OnLeave", function() if b:IsEnabled() then fs:SetTextColor(1, 0.82, 0) end end)
    b.setEnabled = function(on)
        if on then b:Enable(); fs:SetTextColor(1, 0.82, 0)
        else b:Disable(); fs:SetTextColor(0.45, 0.4, 0.33) end
    end
    return b
end

-- the Heard tab button: lives next to the title, above the drag layer like the X
local tabBtn = makeTextButton(f, "Heard >")
tabBtn:SetPoint("TOPLEFT", 8, -5)
tabBtn:SetFrameLevel(titleBar:GetFrameLevel() + 5)

-- the X: lives ABOVE the drag layer so clicks reach it (field bug: the title
-- bar was eating them), with a generous hit box
local close = CreateFrame("Button", nil, f)
close:SetSize(28, 28)
close:SetPoint("TOPRIGHT", -3, -3)
close:SetFrameLevel(titleBar:GetFrameLevel() + 5)
local closeText = close:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
closeText:SetPoint("CENTER")
closeText:SetText("X")
closeText:SetTextColor(1, 0.82, 0)
close:SetScript("OnClick", function() f:Hide() end)
close:SetScript("OnEnter", function() closeText:SetTextColor(1, 0.3, 0.3) end)
close:SetScript("OnLeave", function() closeText:SetTextColor(1, 0.82, 0) end)

local stats = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
stats:SetPoint("TOPLEFT", 14, -36)
stats:SetPoint("RIGHT", f, "RIGHT", -14, 0)
stats:SetJustifyH("LEFT")
stats:SetJustifyV("TOP")
stats:SetSpacing(3)

-- ---------------------------------------------------------------------------
-- Options checkboxes.
-- ---------------------------------------------------------------------------
local OPTION_DEFS = RUN.Settings.defs   -- one list drives every options surface

local homeWidgets = { stats }           -- everything the Heard page hides

local optHeader = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
optHeader:SetPoint("TOPLEFT", stats, "BOTTOMLEFT", 0, -HEADER_GAP)   -- flow under the ledger
optHeader:SetText(GOLD .. "Options|r")
table.insert(homeWidgets, optHeader)

local checks = {}
for i, def in ipairs(OPTION_DEFS) do
    local cb = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
    cb:SetSize(OPT_CB, OPT_CB)
    local col = (i - 1) % OPT_COLS
    local row = math.floor((i - 1) / OPT_COLS)
    cb:SetPoint("TOPLEFT", optHeader, "BOTTOMLEFT", col * 192, -8 - row * OPT_ROWH)
    local label = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("LEFT", cb, "RIGHT", 2, 1)
    label:SetText(def.label)
    cb:SetScript("OnClick", function(self)
        RUN.Settings.set(def.key, self:GetChecked() and true or false)
        if def.key == "expansiveStats" and RUN.Panel then RUN.Panel.refresh() end
        if def.key == "minimapButton" and RUN.MinimapButton then RUN.MinimapButton.refresh() end
    end)
    checks[def.key] = cb
    table.insert(homeWidgets, cb)
    table.insert(homeWidgets, label)
end

-- ---------------------------------------------------------------------------
-- The Heard page: the death-ping network, browsable. Newest-first pages over
-- RUNDB.heardLog (FIFO 200) via Prev/Next - no scroll templates needed.
-- ---------------------------------------------------------------------------
local HEARD_PER_PAGE = 14

local heardText = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
heardText:SetPoint("TOPLEFT", 14, -36)
heardText:SetPoint("RIGHT", f, "RIGHT", -14, 0)
heardText:SetPoint("BOTTOM", f, "BOTTOM", 0, 44)
heardText:SetJustifyH("LEFT")
heardText:SetJustifyV("TOP")
heardText:SetSpacing(3)
heardText:Hide()

local prevBtn = makeTextButton(f, "< Prev")
prevBtn:SetPoint("BOTTOMLEFT", 14, 12)
prevBtn:Hide()
local nextBtn = makeTextButton(f, "Next >")
nextBtn:SetPoint("BOTTOMRIGHT", -14, 12)
nextBtn:Hide()
local pageLabel = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
pageLabel:SetPoint("BOTTOM", 0, 17)
pageLabel:Hide()

local heardWidgets = { heardText, prevBtn, nextBtn, pageLabel }
local mode, heardPageNum = "home", 1

-- e.t is GetTime() (uptime); convert its age to wall clock for HH:MM.
local function fmtHeardWhen(t)
    local up = _G.GetTime and _G.GetTime() or 0
    local now = _G.time and _G.time() or 0
    if _G.date and now > 0 then
        local age = up - t
        if age < 0 then age = 0 end
        return _G.date("%H:%M", now - age)
    end
    return "?"
end

local function heardLine(e)
    local name = RUN.Deathping.npcName(e.npc)
    local noto = RUN.Notoriety.describe(e.npc, "normal")
    local titled = noto.title and (name .. " |cffff5040\"" .. noto.title .. "\"|r") or name
    local bracket = (type(e.bracket) == "number" and e.bracket > 0)
        and (" " .. DIM .. "~L" .. e.bracket .. "|r") or ""
    local mark = e.corro and "|cff6fcf7a[2+]|r" or "|cff857868[?]|r"
    local sender = ""
    if RUN.Settings.get("eulogy") and type(e.sender) == "string" then
        sender = " " .. DIM .. "- " .. e.sender:gsub("|", "") .. "|r"
    end
    local line = DIM .. fmtHeardWhen(e.t) .. "|r  " .. mark .. " " .. titled .. bracket .. sender
    if type(e.words) == "string" and e.words ~= "" then
        -- last words (quoted + dimmed; WoW fontstrings have no inline italics)
        line = line .. "\n        |cffcbbfa3\"" .. e.words:gsub("|", ""):sub(1, 80) .. "\"|r"
    end
    return line
end

local function renderHeard()
    local entries, page, pages, total =
        Window.heardPage(RUN.db().heardLog, heardPageNum, HEARD_PER_PAGE)
    heardPageNum = page
    local lines = { GOLD .. "Deaths heard nearby|r " .. DIM .. "(the RUN network, newest first)|r", " " }
    if total == 0 then
        table.insert(lines, DIM .. "  nothing heard yet - when a RUN player falls")
        table.insert(lines, DIM .. "  near you, the creature's legend grows here.|r")
    else
        for _, e in ipairs(entries) do table.insert(lines, heardLine(e)) end
    end
    heardText:SetText(table.concat(lines, "\n"))
    pageLabel:SetText(DIM .. "page " .. page .. "/" .. pages .. " - " .. total .. " heard|r")
    prevBtn.setEnabled(page > 1)
    nextBtn.setEnabled(page < pages)
end

local function setMode(m)
    mode = m
    local home = (m == "home")
    for _, w in ipairs(homeWidgets) do if home then w:Show() else w:Hide() end end
    for _, w in ipairs(heardWidgets) do if home then w:Hide() else w:Show() end end
    title:SetText(GOLD .. (home and "RUN - Account Ledger" or "RUN - Deaths Heard") .. "|r")
    tabBtn.label:SetText(home and "Heard >" or "< Home")
    tabBtn:SetSize(math.max(tabBtn.label:GetStringWidth() + 16, 44), 20)
    if not home then heardPageNum = 1; renderHeard() end
end

tabBtn:SetScript("OnClick", function()
    setMode(mode == "home" and "heard" or "home")
end)
prevBtn:SetScript("OnClick", function()
    heardPageNum = heardPageNum - 1; renderHeard()
end)
nextBtn:SetScript("OnClick", function()
    heardPageNum = heardPageNum + 1; renderHeard()
end)

-- ---------------------------------------------------------------------------
-- Rendering.
-- ---------------------------------------------------------------------------
local function fmtWhen(t)
    if _G.date and type(t) == "number" and t > 0 then return _G.date("%m/%d %H:%M", t) end
    return "?"
end

local function buildStats()
    local db = RUN.db()
    local lines = {}
    local wanted = Window.mostWanted(db.deaths, db.heard, 4)
    table.insert(lines, GOLD .. "Most Wanted|r " .. DIM .. "(notoriety: yours + heard)|r")
    if #wanted == 0 then
        table.insert(lines, DIM .. "  no legends born yet.|r")
    else
        for i, b in ipairs(wanted) do
            local titled = b.title and (b.name .. " |cffff5040\"" .. b.title .. "\"|r") or b.name
            table.insert(lines, string.format("  %d. %s %s",
                i, titled, DIM .. "tier " .. b.tier .. ", " .. b.total .. " kills|r"))
        end
    end
    table.insert(lines, " ")
    local top = Window.topKillers(db.deaths, 3)
    table.insert(lines, GOLD .. "What killed us" .. "|r " .. DIM .. "(all characters)|r")
    if #top == 0 then
        table.insert(lines, DIM .. "  nothing yet. Long may it stay that way.|r")
    else
        for i, k in ipairs(top) do
            table.insert(lines, string.format("  %d. %s |cffff6060x%d|r %s",
                i, k.name, k.count,
                DIM .. ((k.lastWho and ("last: " .. k.lastWho) or "")
                    .. (k.lastZone and (", " .. k.lastZone) or "") .. "|r")))
        end
    end
    table.insert(lines, " ")
    table.insert(lines, GOLD .. "Recent deaths|r")
    local rec = Window.recent(db.deaths, 3)
    if #rec == 0 then
        table.insert(lines, DIM .. "  none recorded.|r")
    else
        for _, e in ipairs(rec) do
            table.insert(lines, string.format("  %s - %s %s",
                fmtWhen(e.when), e.killer or "unknown cause",
                DIM .. ((e.who and ("[" .. e.who .. (e.level and (" L" .. e.level) or "") .. "]") or "")
                    .. (e.zone and (" " .. e.zone) or "") .. "|r")))
        end
    end
    table.insert(lines, " ")
    table.insert(lines, GOLD .. "Giant Slayers|r " .. DIM .. "(solo wagers won)|r")
    local slays, shown = db.slays, 0
    if type(slays) == "table" then
        for i = #slays, 1, -1 do
            local e = slays[i]
            if RUN.Devil.validSlay(e) then
                shown = shown + 1
                table.insert(lines, string.format("  %s beat %s at ~%d%% %s",
                    e.who or "?", e.name or ("creature #" .. e.npc),
                    math.floor((e.p or 0) * 100 + 0.5),
                    DIM .. "(" .. (RUN.Devil.tierLabel(e.tier) or "wager"):lower() .. ")|r"))
                if shown >= 2 then break end
            end
        end
    end
    if shown == 0 then table.insert(lines, DIM .. "  none yet - find bad odds and RISK IT.|r") end
    table.insert(lines, " ")
    local total = 0
    for _, e in ipairs(db.deaths) do
        if RUN.Attribution.validEntry(e) then total = total + 1 end
    end
    table.insert(lines, string.format(
        "%sTotals|r  deaths: %d  ·  heard nearby: %d  ·  group wipes: %d",
        GOLD, total, RUN.Deathping.heardTotal(), RUN.Wipes.total()))
    -- the guild record (LOCAL + in-guild P2P only; graceful-empty)
    local myGuild = RUN.Guards.call(_G.GetGuildInfo, "player")
    local gsum = (type(myGuild) == "string")
        and Window.guildSummary(db.guildWipes, myGuild) or nil
    if gsum then
        table.insert(lines, string.format(
            "%sGuild record:|r %s wiped %d time%s %s",
            GOLD, myGuild:gsub("|", ""), gsum.total, gsum.total == 1 and "" or "s",
            DIM .. "(worst: " .. RUN.Deathping.wipeKeyName(gsum.worstKey):gsub("|", "")
                .. " x" .. gsum.worstCount .. ")|r"))
    end
    table.insert(lines, DIM .. "Everything above lives in your SavedVariables only.|r")
    return table.concat(lines, "\n")
end

function Window.refresh()
    local text = buildStats()
    stats:SetText(text)
    for key, cb in pairs(checks) do
        cb:SetChecked(RUN.Settings.get(key) and true or false)
    end
    if mode == "heard" then
        f:SetHeight(HEARD_H)
        renderHeard()
    else
        -- HOME page: size the window to the ledger text + the options block, so
        -- it fits exactly (no overflow, no dead gap). GetStringHeight is exact
        -- when laid out; the line-count floor covers the not-yet-shown case.
        local nLines = 1
        for _ in text:gmatch("\n") do nLines = nLines + 1 end
        local lh = stats:GetStringHeight() or 0
        if lh < nLines * 13 then lh = nLines * 13 end
        f:SetHeight(STATS_TOP + lh + HEADER_GAP + OPT_BLOCK + BOTTOM_PAD)
    end
end

function Window.toggle()
    if f:IsShown() then f:Hide() else Window.refresh(); f:Show() end
end

function Window.isShown() return f:IsShown() end

-- ---------------------------------------------------------------------------
-- Nameplate one-click prompt: RUN senses enemies through nameplates, so when
-- they are off at login we offer ONE click to turn them on. The CVar write is
-- unprotected and happens inside the user's hardware click - display-and-
-- advice law intact (the user acts; we only ask). Once per session, max.
-- ---------------------------------------------------------------------------
local promptOffered = false

local function buildPrompt()
    local p = CreateFrame("Frame", "RUNNameplatePrompt", UIParent)
    p:SetSize(340, 104)
    p:SetPoint("TOP", UIParent, "TOP", 0, -180)
    p:SetFrameStrata("DIALOG")
    p:EnableMouse(true)
    p:SetClampedToScreen(true)

    local pbg = p:CreateTexture(nil, "BACKGROUND")
    pbg:SetAllPoints()
    pbg:SetColorTexture(0.05, 0.04, 0.03, 0.94)
    local pedge = p:CreateTexture(nil, "BORDER")
    pedge:SetPoint("TOPLEFT", -1, 1); pedge:SetPoint("BOTTOMRIGHT", 1, -1)
    pedge:SetColorTexture(0.78, 0.64, 0.3, 0.6)
    local pinner = p:CreateTexture(nil, "ARTWORK")
    pinner:SetAllPoints(); pinner:SetColorTexture(0.05, 0.04, 0.03, 1)
    pinner:SetDrawLayer("BORDER", 1)

    local head = p:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    head:SetPoint("TOP", 0, -12)
    head:SetText(GOLD .. "RUN senses enemies through nameplates|r")
    local body = p:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    body:SetPoint("TOP", head, "BOTTOM", 0, -6)
    body:SetPoint("LEFT", 14, 0); body:SetPoint("RIGHT", -14, 0)
    body:SetText(DIM .. "Enemy nameplates are off, so rares can't be sensed"
        .. " before you see them. Enable them now?|r")

    local enable = makeTextButton(p, "[ Enable ]")
    enable:SetPoint("BOTTOMLEFT", 40, 12)
    enable:SetScript("OnClick", function()
        -- the user's hardware click flips the (unprotected) CVar - never us
        if _G.SetCVar then pcall(_G.SetCVar, "nameplateShowEnemies", "1") end
        p:Hide()
        RUN.print("enemy nameplates enabled - RUN can now sense rares near you.")
    end)
    local later = makeTextButton(p, "Not now")
    later:SetPoint("BOTTOMRIGHT", -40, 12)
    later:SetScript("OnClick", function() p:Hide() end)
    return p
end

RUN.on("PLAYER_LOGIN", function()
    if promptOffered then return end
    local v = RUN.Guards.call(_G.GetCVar, "nameplateShowEnemies")
    if v ~= "0" then return end
    promptOffered = true
    buildPrompt():Show()
end)

return Window
