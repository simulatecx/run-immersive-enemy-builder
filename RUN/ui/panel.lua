-- The odds panel: a Civ-style "can I take it?" readout. OWN frame on UIParent,
-- ANCHORED below Blizzard's TargetFrame - never parented into it, never writing
-- keys onto it (taint law). Shows band + ~% (p) + what we know about the creature.
-- Display only: nothing here can act on your behalf.

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
f:SetSize(240, 92)
f:SetFrameStrata("MEDIUM")
f:Hide()

local bg = f:CreateTexture(nil, "BACKGROUND")
bg:SetAllPoints()
bg:SetColorTexture(0.05, 0.04, 0.03, 0.88)

local border = f:CreateTexture(nil, "BORDER")
border:SetPoint("TOPLEFT", -1, 1)
border:SetPoint("BOTTOMRIGHT", 1, -1)
border:SetColorTexture(0.78, 0.64, 0.3, 0.55)
local inner = f:CreateTexture(nil, "ARTWORK")
inner:SetAllPoints()
inner:SetColorTexture(0.05, 0.04, 0.03, 1)
inner:SetDrawLayer("BORDER", 1)

local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
title:SetPoint("TOPLEFT", 10, -8)
title:SetPoint("TOPRIGHT", -10, -8)
title:SetJustifyH("LEFT")

local sub = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -2)
sub:SetPoint("RIGHT", f, "RIGHT", -10, 0)
sub:SetJustifyH("LEFT")
sub:SetTextColor(0.75, 0.68, 0.55)

local band = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
band:SetPoint("TOPLEFT", sub, "BOTTOMLEFT", 0, -6)

local pct = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
pct:SetPoint("LEFT", band, "RIGHT", 8, 0)
pct:SetTextColor(0.9, 0.86, 0.76)

local foot = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
foot:SetPoint("BOTTOMLEFT", 10, 7)
foot:SetPoint("BOTTOMRIGHT", -10, 7)
foot:SetJustifyH("LEFT")

-- Anchor under the Blizzard target frame when it exists; fallback to centre-left.
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
local current  -- last shown verdict (for /ra odds)

local function crowdLine(c)
    -- Phase E surfaces the real killcount here; today the honest placeholder.
    if c.known and c.known.name then
        return "known rare: " .. tostring(c.known.name)
    end
    return "crowd killcount arrives with the crowd wave"
end

function Panel.showFor(unit)
    local v = Odds.forUnit(unit)
    if not v then Panel.hide() return end
    local c = v.creature
    current = v

    title:SetText(tostring(c.name or "Unknown"))
    local lvl = c.level == -1 and "??" or tostring(c.level or "?")
    local cls = c.classification ~= "normal" and (" " .. c.classification) or ""
    sub:SetText("Level " .. lvl .. cls .. (c.notable and "  |cffefd488RARE SPOTTED|r" or ""))

    band:SetText(v.band)
    band:SetTextColor(Odds.bandColor(v.band))
    if v.skull then
        pct:SetText("~no chance " .. v.tag)
    else
        pct:SetText(string.format("~%d%% to win %s", math.floor(v.p * 100 + 0.5), v.tag))
    end
    foot:SetText(v.degraded and "your health is secret here - advice degraded" or crowdLine(c))

    anchor()
    f:Show()

    RUN.Waypoint.autoMarkFor(c)
end

function Panel.hide() f:Hide() end

function Panel.refresh()
    if _G.UnitExists and _G.UnitExists("target") then Panel.update() else Panel.hide() end
end

function Panel.update()
    -- The panel IS part of Expansive Enemy Stats; the passive layer is the
    -- tooltip flags (ui/tooltip.lua), which need no option and no command.
    if not RUN.Settings.get("expansiveStats") then Panel.hide() return end
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
    Panel._marked = nil
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
