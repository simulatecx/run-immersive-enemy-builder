-- The notoriety glow: a tier-hued effect that EXPANDS around Blizzard's target
-- frame as a creature's rank climbs - the Nemesis ladder made visible. The
-- default frame is never touched (no parenting, no keys written, no art
-- swapped - taint law + the owner directive). OUR frame sits on UIParent and
-- hugs the TargetFrame rect; the effect ESCALATES by tier (owner call
-- 2026-11-05): a blooded tier-1 mob gets a soft halo, a tier-10 legend wears a
-- rotating sigil with sparkles. Tint is Notoriety.colorFor - the same ember ->
-- blood ramp the tooltip, banner, and tier frame already speak.
--
-- Robustness laws honored: built ONLY from always-present Blizzard textures
-- (WHITE8X8 + the portrait soft-mask + the cooldown star), animated with ONLY
-- Rotation + Alpha (the Scale animation API drifted between Classic and modern
-- - avoided on purpose), every periodic re-check routed through the firewall
-- ticker (core/safety.lua). Display-only throughout.

local _, RUN = ...
if not RUN then RUN = _G.RunAdvisor or {}; _G.RunAdvisor = RUN end

local Glow = {}
RUN.Glow = Glow

-- Pure: should the target glow at all? Hostile non-player living creatures with
-- a notoriety tier (>= 1 = at least one recorded kill), behind the tierGlow
-- setting. Classification is irrelevant on purpose: a silver elite's dragon
-- stays Blizzard's; the glow is the EARNED layer on top.
function Glow.shouldGlow(info, tier, enabled)
    if not enabled or type(info) ~= "table" then return false end
    if info.isPlayer or info.dead or not info.hostile then return false end
    return (tonumber(tier) or 0) >= 1
end

-- Pure: the tier -> effect-name escalation (owner-chosen bands, 2026-11-05).
-- Low ranks are quiet; the effect itself shows how feared a creature is. Beam
-- and Beacon are the vertical world-markers held back for the nameplate
-- surface; the target frame uses these seven.
local BANDS = {
    "subtle", "subtle",     -- 1-2  blooded
    "aura", "aura",         -- 3-4  dangerous
    "reticle", "reticle",   -- 5-6  deadly
    "orbit",                -- 7
    "ripple",               -- 8
    "brackets",             -- 9    locked-on
    "sigil",                -- 10   legend (+ sparkles, baked in)
}
function Glow.effectForTier(tier)
    tier = tonumber(tier) or 0
    if tier < 1 then return nil end
    if tier > 10 then tier = 10 end
    return BANDS[tier]
end

-- Pure: a point on a circle/ellipse of radius (rx, ry), 1-based index of count.
-- Shared by every ring-based effect so the layout is headless-tested.
function Glow.ringPoint(i, count, rx, ry)
    count = tonumber(count) or 1
    if count < 1 then count = 1 end
    local a = (2 * math.pi) * ((tonumber(i) or 1) - 1) / count
    return math.cos(a) * (tonumber(rx) or 0), math.sin(a) * (tonumber(ry) or 0)
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
        check("glow effect escalates by tier band", (function()
            local want = { [1]="subtle",[2]="subtle",[3]="aura",[4]="aura",
                           [5]="reticle",[6]="reticle",[7]="orbit",[8]="ripple",
                           [9]="brackets",[10]="sigil" }
            for t = 1, 10 do
                if Glow.effectForTier(t) ~= want[t] then return false end
            end
            return Glow.effectForTier(0) == nil and Glow.effectForTier(nil) == nil
                and Glow.effectForTier(99) == "sigil"   -- clamps to the legend
        end)())
        check("glow ringPoint lands on the circle", (function()
            local function near(a, b) return math.abs(a - b) < 0.001 end
            local x1, y1 = Glow.ringPoint(1, 4, 10, 10)   -- angle 0
            local x2, y2 = Glow.ringPoint(2, 4, 10, 10)   -- angle pi/2
            return near(x1, 10) and near(y1, 0) and near(x2, 0) and near(y2, 10)
        end)())
    end)
end

-- Everything below wires the client; headless harness stops here.
if not _G.CreateFrame then return Glow end

-- Always-present textures (verified on Classic Era + Forever; a one-line swap
-- here is the only change if a future build ever drops one).
local SOFT  = "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask"  -- radial fill
local STAR  = "Interface\\Cooldown\\star4"                        -- soft dot / sparkle
local SHARP = "Interface\\Buttons\\WHITE8X8"                      -- sharp lines

local root = CreateFrame("Frame", "RUNNotorietyGlow", UIParent)
root:SetFrameStrata("BACKGROUND")
root:Hide()

-- ---------------------------------------------------------------------------
-- Build helpers (all additive-blended so the tier tint reads as light).
-- ---------------------------------------------------------------------------
local function dot(parent, size, kind, layer)
    local t = parent:CreateTexture(nil, layer or "ARTWORK")
    t:SetTexture(kind)
    t:SetBlendMode("ADD")
    t:SetSize(size, size)
    return t
end

local function bar(parent, w, h)
    local t = parent:CreateTexture(nil, "ARTWORK")
    t:SetTexture(SHARP)
    t:SetBlendMode("ADD")
    t:SetSize(w, h)
    return t
end

-- A child frame carrying a looping Rotation (degrees<0 counter-rotates).
local function spinner(host, seconds, degrees)
    local f = CreateFrame("Frame", nil, host)
    f:SetAllPoints(host)
    local ag = f:CreateAnimationGroup()
    ag:SetLooping("REPEAT")
    local r = ag:CreateAnimation("Rotation")
    r:SetDegrees(degrees or 360)
    r:SetDuration(seconds or 8)
    r:SetOrigin("CENTER", 0, 0)
    return f, ag
end

-- A looping Alpha breathe on a region.
local function pulse(region, from, to, seconds, delay)
    local ag = region:CreateAnimationGroup()
    ag:SetLooping("BOUNCE")
    local a = ag:CreateAnimation("Alpha")
    a:SetFromAlpha(from)
    a:SetToAlpha(to)
    a:SetDuration(seconds)
    if delay then a:SetStartDelay(delay) end
    return ag
end

local function ringOfDots(parent, count, size, rx, ry, kind)
    local out = {}
    for i = 1, count do
        local d = dot(parent, size, kind or STAR)
        local x, y = Glow.ringPoint(i, count, rx, ry)
        d:SetPoint("CENTER", parent, "CENTER", x, y)
        out[#out + 1] = d
    end
    return out
end

local function append(dst, src) for i = 1, #src do dst[#dst + 1] = src[i] end end

-- ---------------------------------------------------------------------------
-- The effect builders. Each fills `host` and returns { tints = {textures to
-- colour}, ags = {animation groups to play/stop} }.
-- ---------------------------------------------------------------------------
local builders = {}

builders.subtle = function(host)
    local g = dot(host, 118, SOFT, "BACKGROUND")
    g:SetPoint("CENTER")
    return { tints = { g }, ags = { pulse(host, 0.45, 0.85, 1.6) } }
end

builders.aura = function(host)
    local tints = {}
    local fill = dot(host, 96, SOFT, "BACKGROUND"); fill:SetPoint("CENTER")
    tints[#tints + 1] = fill
    local ring, ag = spinner(host, 9, 360)
    append(tints, ringOfDots(ring, 16, 18, 52, 52))
    return { tints = tints, ags = { ag, pulse(host, 0.7, 1.0, 2.0) } }
end

builders.reticle = function(host)
    local tints = {}
    local ring, ag = spinner(host, 6, 360)
    append(tints, ringOfDots(ring, 28, 9, 54, 54))    -- fine ticked ring
    append(tints, ringOfDots(ring, 4, 16, 54, 54))    -- 4 cardinal marks
    return { tints = tints, ags = { ag } }
end

builders.orbit = function(host)
    local tints = {}
    local c = dot(host, 40, SOFT, "BACKGROUND"); c:SetPoint("CENTER")
    tints[#tints + 1] = c
    local ring, ag = spinner(host, 10, 360)
    append(tints, ringOfDots(ring, 20, 12, 64, 22))   -- squashed = horizontal orbit
    return { tints = tints, ags = { ag } }
end

builders.ripple = function(host)
    local tints, ags = {}, {}
    local radii = { 28, 46, 64 }
    for k = 1, 3 do
        local layer = CreateFrame("Frame", nil, host); layer:SetAllPoints(host)
        append(tints, ringOfDots(layer, 16, 10, radii[k], radii[k]))
        local ag = layer:CreateAnimationGroup(); ag:SetLooping("REPEAT")
        local up = ag:CreateAnimation("Alpha")
        up:SetFromAlpha(0.1); up:SetToAlpha(1.0); up:SetDuration(0.7); up:SetOrder(1)
        up:SetStartDelay((k - 1) * 0.35)              -- staggered = travels outward
        local dn = ag:CreateAnimation("Alpha")
        dn:SetFromAlpha(1.0); dn:SetToAlpha(0.1); dn:SetDuration(0.7); dn:SetOrder(2)
        ags[#ags + 1] = ag
    end
    return { tints = tints, ags = ags }
end

builders.brackets = function(host)
    local tints = {}
    local S, len, th = 54, 16, 3
    local corners = { { -1, 1 }, { 1, 1 }, { -1, -1 }, { 1, -1 } }
    for c = 1, #corners do
        local hx, vy = corners[c][1], corners[c][2]
        local h = bar(host, len, th)
        h:SetPoint("CENTER", host, "CENTER", hx * (S - len / 2), vy * S)
        local v = bar(host, th, len)
        v:SetPoint("CENTER", host, "CENTER", hx * S, vy * (S - len / 2))
        tints[#tints + 1] = h; tints[#tints + 1] = v
    end
    return { tints = tints, ags = { pulse(host, 0.6, 1.0, 1.3) } }
end

builders.sigil = function(host)
    local tints, ags = {}, {}
    local center = dot(host, 44, SOFT, "BACKGROUND"); center:SetPoint("CENTER")
    tints[#tints + 1] = center
    local outer, agO = spinner(host, 14, 360)
    append(tints, ringOfDots(outer, 18, 10, 58, 58))
    local inner, agI = spinner(host, 10, -360)         -- counter-rotate
    append(tints, ringOfDots(inner, 8, 14, 36, 36))
    ags[#ags + 1] = agO; ags[#ags + 1] = agI
    local spk = { { 70, 40 }, { -66, 34 }, { 58, -48 }, { -52, -44 } }
    for i = 1, #spk do
        local s = dot(host, 12, STAR, "OVERLAY")
        s:SetPoint("CENTER", host, "CENTER", spk[i][1], spk[i][2])
        tints[#tints + 1] = s
        ags[#ags + 1] = pulse(s, 0.1, 1.0, 0.5 + 0.2 * i, 0.15 * i)   -- twinkle
    end
    return { tints = tints, ags = ags }
end

-- ---------------------------------------------------------------------------
-- The driver: build each effect once (lazily), tint by tier, play on target.
-- ---------------------------------------------------------------------------
local built = {}      -- [name] = { host, tints, ags }
local current = nil   -- { name, st }

local function buildEffect(name)
    local b = builders[name]
    if not b then return nil end
    local host = CreateFrame("Frame", nil, root)
    host:SetAllPoints(root)
    host:Hide()
    local st = b(host)
    st.host = host
    return st
end

local function clearCurrent()
    if not current then return end
    for i = 1, #current.st.ags do current.st.ags[i]:Stop() end
    current.st.host:Hide()
    current = nil
end

local function hideAll()
    clearCurrent()
    root:Hide()
end

local OUT = 16

local function show(tf, name, r, g, b)
    root:ClearAllPoints()
    root:SetPoint("TOPLEFT", tf, "TOPLEFT", -OUT, OUT)
    root:SetPoint("BOTTOMRIGHT", tf, "BOTTOMRIGHT", OUT, -OUT)
    root:Show()
    if current and current.name == name then
        -- same effect, tier colour may have shifted as kills landed: retint
        for i = 1, #current.st.tints do current.st.tints[i]:SetVertexColor(r, g, b) end
        return
    end
    clearCurrent()
    local st = built[name]
    if not st then st = buildEffect(name); built[name] = st end
    if not st then return end
    st.host:Show()
    for i = 1, #st.tints do st.tints[i]:SetVertexColor(r, g, b) end
    for i = 1, #st.ags do st.ags[i]:Play() end
    current = { name = name, st = st }
end

local function evaluate()
    local tf = _G.TargetFrame
    if not (tf and tf.IsShown) then return hideAll() end
    local okShown, shown = pcall(tf.IsShown, tf)
    if not (okShown and shown) then return hideAll() end
    if not RUN.Settings.get("tierGlow") then return hideAll() end
    local info = RUN.Detect.unitInfo("target")
    if not info then return hideAll() end
    local noto = RUN.Notoriety.describe(info.npcID, info.classification)
    if not Glow.shouldGlow(info, noto.tier, true) then return hideAll() end
    local name = Glow.effectForTier(noto.tier)
    if not name then return hideAll() end
    local r, g, b = RUN.Notoriety.colorFor(noto.tier)
    show(tf, name, r, g, b)
end

RUN.on("PLAYER_TARGET_CHANGED", evaluate)

-- Self-healing re-check through the shared firewall ticker (core/safety.lua):
-- kills land MID-fight (the tier - and thus the effect - can rise while you are
-- looking at the creature), targets die, the toggle flips. One guarded,
-- throttled read per second; never a raw per-file OnUpdate.
RUN.ticker("glow", 1, evaluate)

return Glow
