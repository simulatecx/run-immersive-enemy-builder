-- The notoriety glow: a light tier-hued halo that EXPANDS around Blizzard's
-- target frame when your target has a body count. The default frame is never
-- touched - no parenting, no keys written, no art swapped (taint law + the
-- owner directive: never impact the stock unit frame). OUR frame sits on
-- UIParent BEHIND the target frame and hugs its rect; two additive rings
-- fade outward, tinted by Notoriety.colorFor - the same ember -> blood ramp
-- the tooltip, banner, and tier frame already speak. Display-only.

local _, RUN = ...
if not RUN then RUN = _G.RunAdvisor or {}; _G.RunAdvisor = RUN end

local Glow = {}
RUN.Glow = Glow

-- Pure: should the target glow? Hostile non-player living creatures with a
-- notoriety tier (>= 1 means at least one recorded kill), behind the
-- tierGlow setting. Classification is irrelevant on purpose: a silver
-- elite's dragon stays Blizzard's; the glow is the EARNED layer on top.
function Glow.shouldGlow(info, tier, enabled)
    if not enabled or type(info) ~= "table" then return false end
    if info.isPlayer or info.dead or not info.hostile then return false end
    return (tonumber(tier) or 0) >= 1
end

-- Selftests (registered; run headless and in-game).
if type(RUN.selftestChecks) == "table" then
    table.insert(RUN.selftestChecks, function(check)
        local mob = { name = "Sunscale Screecher", hostile = true, dead = false,
                      isPlayer = false }
        check("glow lights a tiered hostile", Glow.shouldGlow(mob, 1, true)
            and Glow.shouldGlow(mob, 10, true))
        check("glow stays off below tier 1", Glow.shouldGlow(mob, 0, true) == false
            and Glow.shouldGlow(mob, nil, true) == false)
        check("glow respects the toggle", Glow.shouldGlow(mob, 4, false) == false)
        check("glow skips players/dead/friendly", (function()
            local player = { hostile = true, dead = false, isPlayer = true }
            local dead = { hostile = true, dead = true, isPlayer = false }
            local friendly = { hostile = false, dead = false, isPlayer = false }
            return Glow.shouldGlow(player, 5, true) == false
                and Glow.shouldGlow(dead, 5, true) == false
                and Glow.shouldGlow(friendly, 5, true) == false
        end)())
        check("glow nil-safe", Glow.shouldGlow(nil, 5, true) == false
            and Glow.shouldGlow("junk", 5, true) == false)
    end)
end

-- Everything below wires the client; headless harness stops here.
if not _G.CreateFrame then return Glow end

local glow = CreateFrame("Frame", "RUNNotorietyGlow", UIParent)
glow:SetFrameStrata("BACKGROUND")   -- always UNDER the stock frame's art
glow:Hide()

-- One ring = four additive strips hugging the glow rect, outset outward.
-- Two rings at falling alpha fake a soft halo with plain textures only
-- (house style: no Blizzard template/texture-path dependencies).
local tints = {}
local function ring(outset, thick, alpha)
    local function strip()
        local t = glow:CreateTexture(nil, "BACKGROUND")
        t:SetColorTexture(1, 1, 1, alpha)
        t:SetBlendMode("ADD")
        tints[#tints + 1] = t
        return t
    end
    local top = strip()
    top:SetPoint("BOTTOMLEFT", glow, "TOPLEFT", -outset, outset)
    top:SetPoint("BOTTOMRIGHT", glow, "TOPRIGHT", outset, outset)
    top:SetHeight(thick)
    local bottom = strip()
    bottom:SetPoint("TOPLEFT", glow, "BOTTOMLEFT", -outset, -outset)
    bottom:SetPoint("TOPRIGHT", glow, "BOTTOMRIGHT", outset, -outset)
    bottom:SetHeight(thick)
    local left = strip()
    left:SetPoint("TOPRIGHT", glow, "TOPLEFT", -outset, outset + thick)
    left:SetPoint("BOTTOMRIGHT", glow, "BOTTOMLEFT", -outset, -(outset + thick))
    left:SetWidth(thick)
    local right = strip()
    right:SetPoint("TOPLEFT", glow, "TOPRIGHT", outset, outset + thick)
    right:SetPoint("BOTTOMLEFT", glow, "BOTTOMRIGHT", outset, -(outset + thick))
    right:SetWidth(thick)
end
ring(2, 3, 0.5)     -- inner: reads as the edge catching heat
ring(5, 5, 0.22)    -- outer: the fading halo ("expands")

local function hide() glow:Hide() end

local function evaluate()
    local tf = _G.TargetFrame
    if not (tf and tf.IsShown) then return hide() end
    local okShown, shown = pcall(tf.IsShown, tf)
    if not (okShown and shown) then return hide() end
    if not RUN.Settings.get("tierGlow") then return hide() end
    local info = RUN.Detect.unitInfo("target")
    if not info then return hide() end
    local noto = RUN.Notoriety.describe(info.npcID, info.classification)
    if not Glow.shouldGlow(info, noto.tier, true) then return hide() end
    local r, g, b = RUN.Notoriety.colorFor(noto.tier)
    for i = 1, #tints do tints[i]:SetVertexColor(r, g, b) end
    glow:ClearAllPoints()
    glow:SetPoint("TOPLEFT", tf, "TOPLEFT", 0, 0)
    glow:SetPoint("BOTTOMRIGHT", tf, "BOTTOMRIGHT", 0, 0)
    glow:Show()
end

RUN.on("PLAYER_TARGET_CHANGED", evaluate)

-- Self-healing re-check through the shared firewall ticker (core/safety.lua):
-- kills land MID-fight (the tier can rise while you are looking at the
-- creature), targets die, the toggle flips. One guarded, throttled unitInfo
-- read per second - never a raw per-file OnUpdate that could spam the client.
RUN.ticker("glow", 1, evaluate)

return Glow
