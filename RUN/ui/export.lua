-- The share-link window (WP-B): ONE copyable editbox. The addon never networks;
-- the user copies this link (Ctrl+C) and pastes it into their browser - that
-- paste is the consent act. Read-only box (typing re-asserts the link), click
-- or focus selects everything, ESC closes. Own frame on UIParent (taint law).

local _, RUN = ...
if not RUN then RUN = _G.RunAdvisor or {}; _G.RunAdvisor = RUN end

local Export = {}
RUN.Export = Export

-- Everything below wires the client; headless harness stops here.
if not _G.CreateFrame then return Export end

local frame = nil

local function build()
    if frame then return frame end
    frame = CreateFrame("Frame", "RUNExportFrame", _G.UIParent,
        _G.BackdropTemplateMixin and "BackdropTemplate" or nil)
    frame:SetSize(560, 130)
    frame:SetPoint("CENTER", _G.UIParent, "CENTER", 0, 140)
    frame:SetFrameStrata("DIALOG")
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(f) f:StartMoving() end)
    frame:SetScript("OnDragStop", function(f) f:StopMovingOrSizing() end)
    if frame.SetBackdrop then
        frame:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true, tileSize = 32, edgeSize = 32,
            insets = { left = 8, right = 8, top = 8, bottom = 8 },
        })
    end

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -16)
    title:SetText("RUN crowd share")
    local hint = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hint:SetPoint("TOP", title, "BOTTOM", 0, -6)
    hint:SetText("Ctrl+C to copy, then paste into your browser. Nothing is sent until you do.")

    local box = CreateFrame("EditBox", "RUNExportEditBox", frame, "InputBoxTemplate")
    box:SetSize(508, 24)
    box:SetPoint("TOP", hint, "BOTTOM", 0, -12)
    box:SetAutoFocus(false)
    box:SetScript("OnEscapePressed", function() frame:Hide() end)
    box:SetScript("OnEnterPressed", function(b) b:HighlightText() end)
    box:SetScript("OnEditFocusGained", function(b) b:HighlightText() end)
    box:SetScript("OnMouseUp", function(b) b:HighlightText() end)
    box:SetScript("OnChar", function(b)
        -- read-only: any typing re-asserts the link and re-selects it
        b:SetText(frame.link or "")
        b:HighlightText()
    end)
    frame.box = box

    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -6, -6)

    _G.UISpecialFrames = _G.UISpecialFrames or {}
    table.insert(_G.UISpecialFrames, "RUNExportFrame")   -- ESC closes
    frame:Hide()
    return frame
end

-- Show a link in the copyable box (called by /ra share).
function Export.show(link)
    if type(link) ~= "string" or link == "" then return end
    local f = build()
    f.link = link
    f.box:SetText(link)
    f:Show()
    f.box:SetFocus()
    f.box:HighlightText()
end

return Export
