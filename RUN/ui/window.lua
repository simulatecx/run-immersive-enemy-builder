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

-- Everything below builds the client UI.
if not _G.CreateFrame then return Window end

local GOLD, DIM = "|cffefd488", "|cffb7a988"

local f = CreateFrame("Frame", "RUNLedgerWindow", UIParent)
f:SetSize(400, 500)
f:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
f:SetFrameStrata("DIALOG")
f:SetMovable(true)
f:EnableMouse(true)
f:SetClampedToScreen(true)
f:Hide()

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

local close = CreateFrame("Button", nil, f)
close:SetSize(22, 22)
close:SetPoint("TOPRIGHT", -5, -5)
local closeText = close:CreateFontString(nil, "OVERLAY", "GameFontNormal")
closeText:SetPoint("CENTER")
closeText:SetText("X")
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
local OPTION_DEFS = {
    { key = "flags",          label = "Tooltip flags + kill ranks" },
    { key = "expansiveStats", label = "Expansive Enemy Stats" },
    { key = "nearbyPing",     label = "Nearby pings (master)" },
    { key = "pingQuest",      label = "Ping quest targets" },
    { key = "pingUnique",     label = "Ping rares && bosses" },
    { key = "pingElite",      label = "Ping elites" },
    { key = "pingNormal",     label = "Ping normal enemies" },
    { key = "autoMark",       label = "Auto map-mark rares" },
    { key = "recordDeaths",   label = "Record my deaths" },
    { key = "shareDeaths",    label = "Share anonymous death-pings" },
    { key = "minimapButton",  label = "Minimap button" },
}

local optHeader = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
optHeader:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 14, 178)
optHeader:SetText(GOLD .. "Options|r")

local checks = {}
for i, def in ipairs(OPTION_DEFS) do
    local cb = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
    cb:SetSize(24, 24)
    local col = (i - 1) % 2
    local row = math.floor((i - 1) / 2)
    cb:SetPoint("TOPLEFT", f, "BOTTOMLEFT", 14 + col * 192, 170 - row * 26)
    local label = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("LEFT", cb, "RIGHT", 2, 1)
    label:SetText(def.label)
    cb:SetScript("OnClick", function(self)
        RUN.Settings.set(def.key, self:GetChecked() and true or false)
        if def.key == "expansiveStats" and RUN.Panel then RUN.Panel.refresh() end
        if def.key == "minimapButton" and RUN.MinimapButton then RUN.MinimapButton.refresh() end
    end)
    checks[def.key] = cb
end

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
    local top = Window.topKillers(db.deaths, 6)
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
    local rec = Window.recent(db.deaths, 6)
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
    local total = 0
    for _, e in ipairs(db.deaths) do
        if RUN.Attribution.validEntry(e) then total = total + 1 end
    end
    table.insert(lines, string.format("%sTotals|r  deaths recorded: %d  ·  deaths heard nearby: %d",
        GOLD, total, RUN.Deathping.heardTotal()))
    table.insert(lines, DIM .. "Everything above lives in your SavedVariables only.|r")
    return table.concat(lines, "\n")
end

function Window.refresh()
    stats:SetText(buildStats())
    for key, cb in pairs(checks) do
        cb:SetChecked(RUN.Settings.get(key) and true or false)
    end
end

function Window.toggle()
    if f:IsShown() then f:Hide() else Window.refresh(); f:Show() end
end

function Window.isShown() return f:IsShown() end

return Window
