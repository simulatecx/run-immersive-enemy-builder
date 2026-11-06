-- The nearby-rare banner: a top-centre flash + sound when something notable is
-- close. Own frame on UIParent (taint law); display-only; auto-hides.

local _, RUN = ...
if not RUN then RUN = _G.RunAdvisor or {}; _G.RunAdvisor = RUN end

local Alert = {}
RUN.Alert = Alert

if not _G.CreateFrame then return Alert end

local f = CreateFrame("Frame", "RUNAlertBanner", UIParent)
f:SetSize(460, 64)
f:SetPoint("TOP", UIParent, "TOP", 0, -140)
f:SetFrameStrata("HIGH")
f:Hide()

-- Shared skin: gradient fill + soft shadow + accent border (retinted per tier
-- in Alert.show via Skin.setBorder).
RUN.Skin.panel(f)

local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
title:SetPoint("TOP", 0, -10)
title:SetTextColor(0.94, 0.83, 0.53)
RUN.Skin.title(title)

local sub = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
sub:SetPoint("TOP", title, "BOTTOM", 0, -4)
sub:SetTextColor(0.9, 0.86, 0.76)

-- Auto-hide via the shared firewall ticker (core/safety.lua) instead of a raw
-- per-frame OnUpdate: the banner only needs a few checks a second to drop on
-- time, and routing it through RUN.ticker keeps every periodic surface guarded.
local hideAt = 0
RUN.ticker("alert-hide", 0.2, function()
    if f:IsShown() and _G.GetTime and _G.GetTime() > hideAt then f:Hide() end
end)

-- Show the banner for ~6s with a raid-warning sound. Optional colour (the
-- notoriety tier tint): title + edges take it, so a tier-9 legend LOOKS like
-- a tier-9 legend.
function Alert.show(titleText, subText, r, g, b)
    r, g, b = r or 0.94, g or 0.83, b or 0.53
    title:SetText(tostring(titleText or ""))
    title:SetTextColor(r, g, b)
    RUN.Skin.setBorder(f, r, g, b)   -- the tier tint rides the accent border
    sub:SetText(tostring(subText or ""))
    hideAt = (_G.GetTime and _G.GetTime() or 0) + 6
    f:Show()
    local sk = _G.SOUNDKIT
    if _G.PlaySound then pcall(_G.PlaySound, (sk and sk.RAID_WARNING) or 8959) end
end

return Alert
