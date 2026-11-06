-- RUN shared skin: depth without custom art. One helper every RUN frame routes
-- through so panels read as FINISHED, not flat rectangles - a gradient fill
-- (dark top -> darker bottom), a soft drop-shadow for lift, a thin accent
-- border, and a top highlight bevel ("lit from above"). All from always-present
-- textures; the gradient is cross-flavor-safe (new SetGradient, SetGradientAlpha
-- fallback, flat if neither). Branded art can later swap in behind this same
-- helper with no caller changes. Display-only.

local _, RUN = ...
if not RUN then RUN = _G.RunAdvisor or {}; _G.RunAdvisor = RUN end

local Skin = {}
RUN.Skin = Skin

local SOFT = "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask"   -- soft radial (shadow)

-- Cross-version vertical gradient on a texture. New clients take SetGradient
-- with CreateColor; older take SetGradientAlpha; neither -> a flat mid fill.
local function gradient(tex, r1, g1, b1, a1, r2, g2, b2, a2)
    tex:SetColorTexture(1, 1, 1, 1)
    if tex.SetGradient and _G.CreateColor then
        local ok = pcall(tex.SetGradient, tex, "VERTICAL",
            _G.CreateColor(r1, g1, b1, a1), _G.CreateColor(r2, g2, b2, a2))
        if ok then return end
    end
    if tex.SetGradientAlpha then
        local ok = pcall(tex.SetGradientAlpha, tex, "VERTICAL", r1, g1, b1, a1, r2, g2, b2, a2)
        if ok then return end
    end
    tex:SetColorTexture((r1 + r2) / 2, (g1 + g2) / 2, (b1 + b2) / 2, (a1 + a2) / 2)
end
Skin.gradient = gradient

-- Apply the panel skin to a frame. (ar,ag,ab) tints the border - pass a tier
-- colour for a themed edge, or omit for RUN gold. Returns the border texture so
-- callers can retint it live (e.g. per notoriety tier). Idempotent-ish: call
-- once per frame at construction.
function Skin.panel(frame, ar, ag, ab)
    ar, ag, ab = ar or 0.82, ag or 0.67, ab or 0.33   -- RUN gold default
    if not frame or not frame.CreateTexture then return nil end

    -- Soft drop-shadow: two dark radial rings, outset behind the frame = lift.
    for i = 1, 2 do
        local s = frame:CreateTexture(nil, "BACKGROUND", nil, -8 + (i - 1))
        s:SetTexture(SOFT)
        s:SetVertexColor(0, 0, 0, 0.32 / i)
        local o = 6 + i * 7
        s:SetPoint("TOPLEFT", frame, "TOPLEFT", -o, o)
        s:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", o, -o)
    end

    -- Accent border: a 1px colour rim that the gradient fill sits on top of.
    local border = frame:CreateTexture(nil, "BACKGROUND", nil, -2)
    border:SetColorTexture(ar, ag, ab, 0.9)
    border:SetPoint("TOPLEFT", frame, "TOPLEFT", -1, 1)
    border:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 1, -1)
    frame.runBorder = border

    -- Gradient fill (dark top -> darker bottom) covering the interior.
    local bg = frame:CreateTexture(nil, "BACKGROUND", nil, -1)
    bg:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    bg:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    gradient(bg, 0.11, 0.09, 0.08, 0.97, 0.035, 0.03, 0.025, 0.98)

    -- Top highlight bevel: a faint light hairline along the top inner edge.
    local hi = frame:CreateTexture(nil, "BORDER")
    hi:SetColorTexture(1, 0.97, 0.9, 0.07)
    hi:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
    hi:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -1)
    hi:SetHeight(1)

    return border
end

-- Retint a skinned frame's border (e.g. to the current notoriety tier colour).
function Skin.setBorder(frame, r, g, b, a)
    if frame and frame.runBorder then
        frame.runBorder:SetColorTexture(r, g, b, a or 0.9)
    end
end

-- Headline polish: outline + soft shadow so title text pops off the gradient.
function Skin.title(fs)
    if not fs or not fs.GetFont then return end
    local font, size, flags = fs:GetFont()
    if font and (not flags or not flags:find("OUTLINE")) then
        pcall(fs.SetFont, fs, font, size or 13, "OUTLINE")
    end
    pcall(fs.SetShadowColor, fs, 0, 0, 0, 0.85)
    pcall(fs.SetShadowOffset, fs, 1, -1)
end

-- Selftest (registered): the skin helper is present + shaped. The real textures
-- are exercised by the client-smoke harness skinning every frame at load.
if type(RUN.selftestChecks) == "table" then
    table.insert(RUN.selftestChecks, function(check)
        check("skin helper present", type(RUN.Skin) == "table"
            and type(RUN.Skin.panel) == "function"
            and type(RUN.Skin.setBorder) == "function"
            and type(RUN.Skin.title) == "function")
    end)
end

return Skin
