-- The notoriety unit frame (per-tier styling) + Civ-style odds readout.
-- OWN frame on UIParent, ANCHORED below Blizzard's TargetFrame - never
-- parented into it, never writing keys onto it (taint law). Two layers:
--   * TIER FRAME (tierFrames option): any titled creature you target gets
--     its earned presentation - tier-coloured border, TIER badge, title.
--   * EXPANSIVE ENEMY STATS (expansiveStats option): adds the win-chance
--     band and the RISK IT wager button (display + record only).

local _, RUN = ...
if not RUN then RUN = _G.RunAdvisor or {}; _G.RunAdvisor = RUN end

local Panel = {}
RUN.Panel = Panel

if not _G.CreateFrame then return Panel end

local Odds = RUN.Odds
local Detect = RUN.Detect

-- ---------------------------------------------------------------------------
-- Frame construction (plain textures; no Blizzard template dependencies).
-- ---------------------------------------------------------------------------
local f = CreateFrame("Frame", "RUNOddsPanel", UIParent)
f:SetSize(250, 118)
f:SetFrameStrata("MEDIUM")
f:Hide()

local border = f:CreateTexture(nil, "BACKGROUND")
border:SetPoint("TOPLEFT", -2, 2)
border:SetPoint("BOTTOMRIGHT", 2, -2)
border:SetColorTexture(0.78, 0.64, 0.3, 0.8)

local bg = f:CreateTexture(nil, "ARTWORK")
bg:SetAllPoints()
bg:SetColorTexture(0.05, 0.04, 0.03, 0.93)

local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
title:SetPoint("TOPLEFT", 10, -8)
title:SetJustifyH("LEFT")

local tierBadge = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
tierBadge:SetPoint("TOPRIGHT", -10, -9)
tierBadge:SetJustifyH("RIGHT")

local epithet = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
epithet:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -1)
epithet:SetJustifyH("LEFT")

local sub = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
sub:SetPoint("TOPLEFT", epithet, "BOTTOMLEFT", 0, -2)
sub:SetPoint("RIGHT", f, "RIGHT", -10, 0)
sub:SetJustifyH("LEFT")
sub:SetTextColor(0.75, 0.68, 0.55)

local band = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
band:SetPoint("TOPLEFT", sub, "BOTTOMLEFT", 0, -5)

local pct = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
pct:SetPoint("LEFT", band, "RIGHT", 8, 0)
pct:SetTextColor(0.9, 0.86, 0.76)

local foot = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
foot:SetPoint("BOTTOMLEFT", 10, 7)
foot:SetPoint("BOTTOMRIGHT", -10, 7)
foot:SetJustifyH("LEFT")

-- RISK IT: the wager button. Writes RUNDB + updates display, nothing else.
local risk = CreateFrame("Button", "RUNRiskButton", f)
risk:SetSize(104, 22)
risk:SetPoint("BOTTOMRIGHT", -8, 24)
risk:Hide()
local riskBg = risk:CreateTexture(nil, "BACKGROUND")
riskBg:SetAllPoints()
riskBg:SetColorTexture(0.35, 0.05, 0.05, 0.9)
local riskEdge = risk:CreateTexture(nil, "BORDER")
riskEdge:SetPoint("TOPLEFT", -1, 1); riskEdge:SetPoint("BOTTOMRIGHT", 1, -1)
riskEdge:SetColorTexture(1, 0.3, 0.25, 0.9)
riskEdge:SetDrawLayer("BACKGROUND", -1)
local riskText = risk:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
riskText:SetPoint("CENTER")
riskText:SetText("RISK IT!")
riskText:SetTextColor(1, 0.45, 0.4)
risk:SetScript("OnEnter", function() riskText:SetTextColor(1, 0.8, 0.75) end)
risk:SetScript("OnLeave", function() riskText:SetTextColor(1, 0.45, 0.4) end)

local current  -- last shown verdict/info (risk click + /ra odds)

risk:SetScript("OnClick", function()
    if current and current.verdict and RUN.Devil then
        RUN.Devil.tryArm(current.verdict)
        Panel.update()
    end
end)

-- Anchor under the Blizzard target frame when it exists; fallback centre-left.
local function anchor()
    f:ClearAllPoints()
    if _G.TargetFrame then
        f:SetPoint("TOP", _G.TargetFrame, "BOTTOM", 0, -4)
    else
        f:SetPoint("LEFT", UIParent, "LEFT", 40, -60)
    end
end

-- ---------------------------------------------------------------------------
-- Rendering.
-- ---------------------------------------------------------------------------
local function crowdLine(c, noto)
    if noto and noto.total > 0 then
        local bits = {}
        if noto.kills > 0 then table.insert(bits, "killed you " .. noto.kills .. "x") end
        if noto.heard > 0 then table.insert(bits, noto.heard .. " deaths heard") end
        return table.concat(bits, " + ")
    end
    if c.known and c.known.name then return "known rare: " .. tostring(c.known.name) end
    return "no recorded kills - yet"
end

local function renderFor(unit)
    local info = Detect.unitInfo(unit)
    if not info or not info.hostile or info.isPlayer or info.dead then
        Panel.hide() return
    end
    local expansive = RUN.Settings.get("expansiveStats")
    local noto = RUN.Notoriety.describe(info.npcID, info.classification)
    local tiered = RUN.Settings.get("tierFrames") and noto.tier >= 1
    if not expansive and not tiered then Panel.hide() return end

    -- tier dressing: the border and badge wear the creature's earned colour
    local r, g, b
    if noto.tier >= 1 then
        r, g, b = RUN.Notoriety.colorFor(noto.tier)
    else
        r, g, b = 0.78, 0.64, 0.3
    end
    border:SetColorTexture(r, g, b, 0.85)

    title:SetText(tostring(info.name or "Unknown"))
    title:SetTextColor(1, 0.95, 0.85)
    if noto.tier >= 1 then
        tierBadge:SetText("TIER " .. noto.tier)
        tierBadge:SetTextColor(r, g, b)
        tierBadge:Show()
    else
        tierBadge:Hide()
    end
    if noto.title then
        epithet:SetText("\"" .. noto.title .. "\"")
        epithet:SetTextColor(r, g, b)
        epithet:Show()
    else
        epithet:SetText("")
    end

    local lvl = info.level == -1 and "??" or tostring(info.level or "?")
    local cls = info.classification ~= "normal" and (" " .. info.classification)
        or (noto.softElite and " notorious" or "")
    sub:SetText("Level " .. lvl .. cls .. (info.notable and "  |cffefd488RARE|r" or ""))

    local verdict = nil
    if expansive then
        verdict = Odds.forUnit(unit)
        if verdict then
            band:SetText(verdict.band)
            band:SetTextColor(Odds.bandColor(verdict.band))
            if verdict.skull then
                pct:SetText("~no chance " .. verdict.tag)
            else
                pct:SetText(string.format("~%d%% to win %s",
                    math.floor(verdict.p * 100 + 0.5), verdict.tag))
            end
            foot:SetText(verdict.degraded and "your health is secret here - advice degraded"
                or crowdLine(verdict.creature, noto))
        end
    else
        band:SetText("")
        pct:SetText("")
        foot:SetText(crowdLine(info, noto))
    end

    current = { info = info, noto = noto, verdict = verdict }

    -- the wager button: solo, odds under 50%, nothing armed yet
    local showRisk = false
    if expansive and verdict and RUN.Settings.get("riskButton") and RUN.Devil then
        if RUN.Devil.armed() then
            riskText:SetText("WAGER ARMED")
            showRisk = true
        elseif RUN.Devil.tierForOdds(verdict.p) then
            riskText:SetText("RISK IT!")
            showRisk = true
        end
    end
    if showRisk then risk:Show() else risk:Hide() end

    anchor()
    f:Show()

    RUN.Waypoint.autoMarkFor(info)
end

-- Public wrapper: a silent error here cost us a field bug once - never again.
function Panel.showFor(unit)
    local ok, err = pcall(renderFor, unit)
    if not ok then
        Panel.lastErr = tostring(err)
        f:Hide()
    end
end

-- Force-show with dummy data: splits "frame doesn't render" from "data path".
function Panel.test()
    border:SetColorTexture(1, 0.33, 0.24, 0.85)
    title:SetText("RUN panel self-check")
    title:SetTextColor(1, 0.95, 0.85)
    tierBadge:SetText("TIER 8"); tierBadge:SetTextColor(1, 0.33, 0.24); tierBadge:Show()
    epithet:SetText("\"the Final Mistake\""); epithet:SetTextColor(1, 0.33, 0.24); epithet:Show()
    sub:SetText("Level 13 notorious")
    band:SetText("RISKY")
    band:SetTextColor(Odds.bandColor("RISKY"))
    pct:SetText("~52% to win (p)")
    foot:SetText("frame renders fine - if live odds never show, it is the data path")
    risk:Hide()
    anchor()
    f:Show()
    if _G.C_Timer and _G.C_Timer.After then
        _G.C_Timer.After(6, function() Panel.update() end)
    end
    RUN.print("panel self-check shown (6s). "
        .. (Panel.lastErr and ("last panel error: " .. Panel.lastErr) or "no recorded panel errors.")
        .. " Live frame needs a hostile target + (tierFrames w/ a titled enemy, or expansiveStats).")
end

function Panel.hide() f:Hide() end

function Panel.refresh()
    if _G.UnitExists and _G.UnitExists("target") then Panel.update() else Panel.hide() end
end

function Panel.update()
    local exists = RUN.Guards.call(_G.UnitExists, "target")
    if exists then
        Panel.showFor("target")
    else
        Panel.hide()
    end
end

function Panel.toggle()
    local now = not RUN.Settings.get("expansiveStats")
    RUN.Settings.set("expansiveStats", now)
    RUN.print("Expansive Enemy Stats " .. (now and "on - win-chance shows on tooltips and under your target" or "off"))
    Panel.update()
end

function Panel.printOdds()
    local v = Odds.forUnit("target") or Odds.forUnit("mouseover")
    if not v then RUN.print("no hostile target or mouseover to judge.") return end
    local c = v.creature
    RUN.print(string.format("%s (L%s %s): %s, ~%d%% to win %s",
        tostring(c.name), c.level == -1 and "??" or tostring(c.level),
        c.classification, v.band, math.floor(v.p * 100 + 0.5), v.tag))
end

-- ---------------------------------------------------------------------------
-- Events.
-- ---------------------------------------------------------------------------
RUN.on("PLAYER_TARGET_CHANGED", function()
    Panel.update()
end)

RUN.on("UNIT_HEALTH", function(unit)
    if unit == "player" and f:IsShown() then Panel.update() end
end)

RUN.on("UPDATE_MOUSEOVER_UNIT", function()
    if not RUN.Settings.get("expansiveStats") then return end
    if RUN.Guards.call(_G.UnitExists, "target") then return end  -- target wins
    local info = Detect.unitInfo("mouseover")
    if info and info.hostile and info.notable and not info.dead then
        Panel.showFor("mouseover")
        if _G.C_Timer and _G.C_Timer.After then
            _G.C_Timer.After(5, function()
                if not RUN.Guards.call(_G.UnitExists, "target") then Panel.hide() end
            end)
        end
    end
end)

RUN.on("PLAYER_ENTERING_WORLD", function() Panel.update() end)

return Panel
