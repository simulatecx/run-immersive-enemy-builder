-- The minimap button: the zero-command door into the Account Ledger. Standard
-- minimap-button pattern (a Button parented to Minimap, positioned on the
-- ring, draggable around it) - the same construction every minimap-button
-- addon uses; we only ANCHOR and never write keys onto Minimap itself.

local _, RUN = ...
if not RUN then RUN = _G.RunAdvisor or {}; _G.RunAdvisor = RUN end

local MinimapButton = {}
RUN.MinimapButton = MinimapButton

if not _G.CreateFrame then return MinimapButton end

local RADIUS = 105
local atan2 = math.atan2 or function(y, x) return math.atan(y, x) end

local function savedAngle()
    local db = RUN.db()
    if type(db.ui) ~= "table" then db.ui = {} end
    local a = db.ui.minimapAngle
    if type(a) ~= "number" then a = 2.4 end   -- upper-left by default
    return a
end

local btn = CreateFrame("Button", "RUNMinimapButton", _G.Minimap)
btn:SetSize(31, 31)
btn:SetFrameStrata("MEDIUM")
btn:SetFrameLevel(8)
btn:RegisterForClicks("LeftButtonUp")
btn:RegisterForDrag("LeftButton")
btn:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

local icon = btn:CreateTexture(nil, "ARTWORK")
icon:SetSize(19, 19)
icon:SetPoint("CENTER", -1, 1)
icon:SetTexture("Interface\\Icons\\Ability_Rogue_Sprint")
icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

local border = btn:CreateTexture(nil, "OVERLAY")
border:SetSize(53, 53)
border:SetPoint("TOPLEFT")
border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

local function place()
    local a = savedAngle()
    btn:ClearAllPoints()
    btn:SetPoint("CENTER", _G.Minimap, "CENTER",
        math.cos(a) * RADIUS, math.sin(a) * RADIUS)
end

local function dragUpdate()
    local mx, my = _G.Minimap:GetCenter()
    local cx, cy = _G.GetCursorPosition()
    local scale = _G.Minimap:GetEffectiveScale()
    cx, cy = cx / scale, cy / scale
    local db = RUN.db()
    if type(db.ui) ~= "table" then db.ui = {} end
    db.ui.minimapAngle = atan2(cy - my, cx - mx)
    place()
end

btn:SetScript("OnDragStart", function(self) self:SetScript("OnUpdate", dragUpdate) end)
btn:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)

btn:SetScript("OnClick", function()
    if RUN.Window then RUN.Window.toggle() end
end)

btn:SetScript("OnEnter", function(self)
    local tt = _G.GameTooltip
    if not tt then return end
    tt:SetOwner(self, "ANCHOR_LEFT")
    tt:AddLine("RUN", 0.94, 0.83, 0.53)
    tt:AddLine("Click: account ledger & options", 1, 1, 1)
    tt:AddLine("Drag: move this button", 0.7, 0.66, 0.55)
    tt:Show()
end)
btn:SetScript("OnLeave", function()
    if _G.GameTooltip then _G.GameTooltip:Hide() end
end)

function MinimapButton.refresh()
    if RUN.Settings.get("minimapButton") then
        place()
        btn:Show()
    else
        btn:Hide()
    end
end

RUN.on("PLAYER_LOGIN", function() MinimapButton.refresh() end)

return MinimapButton
