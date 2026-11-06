-- The notoriety glow: a tier-hued effect that marks your target as a creature's
-- rank climbs - the Nemesis ladder made visible. It is a FREE, user-positioned
-- overlay (owner call 2026-11-05): it never anchors into Blizzard's frames,
-- because custom unit-frame UIs (ConsolePort, ElvUI, ...) move or hide them -
-- so instead it sits where YOU drag it (unlock with /ra glow), saved per
-- character, at a strata ABOVE the standard frames (never hidden behind them).
-- The default frame is never touched (no parenting, no keys, no art swap -
-- taint law). The effect ESCALATES by tier (1-2 subtle ... 10 sigil+sparkles),
-- tinted Notoriety.colorFor (ember -> blood) and retinted live as kills land.
--
-- Robustness laws: built ONLY from always-present textures (WHITE8X8 + the
-- portrait soft-mask + the cooldown star) and ONLY Rotation+Alpha animations
-- (the Scale-anim API drifted between Classic and modern - avoided); every
-- periodic re-check + drag handler routed through the firewall (core/safety).
-- Display-only. DEATHS ARE ALWAYS TRACKED (model/attribution) regardless of
-- any glow/mark option here - the overlay is presentation, not recording.

local _, RUN = ...
if not RUN then RUN = _G.RunAdvisor or {}; _G.RunAdvisor = RUN end

local Glow = {}
RUN.Glow = Glow

-- Pure: should the target glow at all? Hostile non-player living creatures with
-- a notoriety tier (>= 1 = at least one recorded kill). Classification is
-- irrelevant HERE on purpose; the normal-enemy opt-out is a separate display
-- gate (Glow.markable) so a silver elite's dragon stays Blizzard's.
function Glow.shouldGlow(info, tier, enabled)
    if not enabled or type(info) ~= "table" then return false end
    if info.isPlayer or info.dead or not info.hostile then return false end
    return (tonumber(tier) or 0) >= 1
end

-- Pure: may we draw the overlay on this classification? NORMAL-classification
-- enemies are suppressed when markNormal is off (owner ask: "not mark normal
-- enemies at all") - deaths are still tracked, this gates DISPLAY only.
function Glow.markable(tierOfClass, markNormal)
    if tierOfClass == "normal" and not markNormal then return false end
    return true
end

-- Pure: the tier -> effect-name escalation (owner-chosen bands, 2026-11-05).
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
function Glow.ringPoint(i, count, rx, ry)
    count = tonumber(count) or 1
    if count < 1 then count = 1 end
    local a = (2 * math.pi) * ((tonumber(i) or 1) - 1) / count
    return math.cos(a) * (tonumber(rx) or 0), math.sin(a) * (tonumber(ry) or 0)
end

-- Pure: validate a saved drag position - the shared core helper (init.lua)
-- does the work; this stays as the glow's named entry point + selftest target.
function Glow.validGlowPos(p)
    return RUN.validAnchorPos(p)
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
        check("glow markable gates normals only on opt-out", (function()
            return Glow.markable("normal", false) == false   -- suppressed
                and Glow.markable("normal", true) == true     -- marked
                and Glow.markable("elite", false) == true     -- elites always mark
                and Glow.markable("unique", false) == true
        end)())
        check("glow effect escalates by tier band", (function()
            local want = { [1]="subtle",[2]="subtle",[3]="aura",[4]="aura",
                           [5]="reticle",[6]="reticle",[7]="orbit",[8]="ripple",
                           [9]="brackets",[10]="sigil" }
            for t = 1, 10 do
                if Glow.effectForTier(t) ~= want[t] then return false end
            end
            return Glow.effectForTier(0) == nil and Glow.effectForTier(nil) == nil
                and Glow.effectForTier(99) == "sigil"
        end)())
        check("glow ringPoint lands on the circle", (function()
            local function near(a, b) return math.abs(a - b) < 0.001 end
            local x1, y1 = Glow.ringPoint(1, 4, 10, 10)
            local x2, y2 = Glow.ringPoint(2, 4, 10, 10)
            return near(x1, 10) and near(y1, 0) and near(x2, 0) and near(y2, 10)
        end)())
        check("glow validGlowPos accepts good, rejects bad", (function()
            local good = Glow.validGlowPos({ point = "CENTER", x = 10, y = -20 })
            return good ~= nil
                and Glow.validGlowPos({ point = "NOPE", x = 0, y = 0 }) == nil
                and Glow.validGlowPos({ point = "CENTER", x = 99999, y = 0 }) == nil
                and Glow.validGlowPos({ point = "CENTER", x = "a", y = 0 }) == nil
                and Glow.validGlowPos("junk") == nil
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

-- The overlay: a fixed-size, free-floating, movable frame ABOVE the standard
-- frames (HIGH strata, never behind them). Mouse is OFF while locked so it
-- never eats a click; ON only while unlocked, for dragging.
local root = CreateFrame("Frame", "RUNNotorietyGlow", UIParent)
root:SetSize(150, 150)
root:SetFrameStrata("HIGH")
root:SetMovable(true)
root:EnableMouse(false)
root:RegisterForDrag("LeftButton")
root:Hide()

local label = root:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
label:SetPoint("TOP", root, "BOTTOM", 0, -2)
label:SetText("RUN rank glow - drag me, then /ra glow to lock")
label:Hide()

-- ---------------------------------------------------------------------------
-- Build helpers (additive-blended so the tier tint reads as light).
-- ---------------------------------------------------------------------------
local function dot(parent, size, kind, layer, blend)
    local t = parent:CreateTexture(nil, layer or "ARTWORK")
    t:SetTexture(kind); t:SetBlendMode(blend or "ADD"); t:SetSize(size, size)
    return t
end

local function bar(parent, w, h)
    local t = parent:CreateTexture(nil, "ARTWORK")
    t:SetTexture(SHARP); t:SetBlendMode("ADD"); t:SetSize(w, h)
    return t
end

local function spinner(host, seconds, degrees)
    local f = CreateFrame("Frame", nil, host)
    f:SetAllPoints(host)
    local ag = f:CreateAnimationGroup(); ag:SetLooping("REPEAT")
    local r = ag:CreateAnimation("Rotation")
    r:SetDegrees(degrees or 360); r:SetDuration(seconds or 8); r:SetOrigin("CENTER", 0, 0)
    return f, ag
end

local function pulse(region, from, to, seconds, delay)
    local ag = region:CreateAnimationGroup(); ag:SetLooping("BOUNCE")
    local a = ag:CreateAnimation("Alpha")
    a:SetFromAlpha(from); a:SetToAlpha(to); a:SetDuration(seconds)
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
-- The effect builders. Each fills `host` and returns { tints = {}, ags = {} }.
-- ---------------------------------------------------------------------------
local builders = {}

-- All effects are ADDITIVE (SetBlendMode "ADD") on purpose: a light glow you
-- see THROUGH, never a solid disc that blocks the view (owner 2026-11-05).
-- Moderate alphas keep it present but translucent.
builders.subtle = function(host)
    local g = dot(host, 110, SOFT, "BACKGROUND"); g:SetPoint("CENTER")
    return { tints = { g }, ags = { pulse(host, 0.45, 0.75, 1.6) } }
end

builders.aura = function(host)
    local tints = {}
    local fill = dot(host, 90, SOFT, "BACKGROUND"); fill:SetPoint("CENTER"); fill:SetAlpha(0.6)
    tints[#tints + 1] = fill
    local ring, ag = spinner(host, 9, 360)
    append(tints, ringOfDots(ring, 16, 16, 52, 52))
    return { tints = tints, ags = { ag, pulse(host, 0.55, 0.8, 2.0) } }
end

builders.reticle = function(host)
    local tints = {}
    local ring, ag = spinner(host, 6, 360)
    append(tints, ringOfDots(ring, 28, 9, 54, 54))
    append(tints, ringOfDots(ring, 4, 15, 54, 54))
    return { tints = tints, ags = { ag } }
end

builders.orbit = function(host)
    local tints = {}
    local c = dot(host, 38, SOFT, "BACKGROUND"); c:SetPoint("CENTER"); c:SetAlpha(0.6)
    tints[#tints + 1] = c
    local ring, ag = spinner(host, 10, 360)
    append(tints, ringOfDots(ring, 20, 12, 64, 22))
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
        up:SetStartDelay((k - 1) * 0.35)
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
    local center = dot(host, 42, SOFT, "BACKGROUND"); center:SetPoint("CENTER"); center:SetAlpha(0.6)
    tints[#tints + 1] = center
    local outer, agO = spinner(host, 14, 360)
    append(tints, ringOfDots(outer, 18, 10, 58, 58))
    local inner, agI = spinner(host, 10, -360)
    append(tints, ringOfDots(inner, 8, 14, 36, 36))
    ags[#ags + 1] = agO; ags[#ags + 1] = agI
    local spk = { { 70, 40 }, { -66, 34 }, { 58, -48 }, { -52, -44 } }
    for i = 1, #spk do
        local s = dot(host, 12, STAR, "OVERLAY")
        s:SetPoint("CENTER", host, "CENTER", spk[i][1], spk[i][2])
        tints[#tints + 1] = s
        ags[#ags + 1] = pulse(s, 0.1, 1.0, 0.5 + 0.2 * i, 0.15 * i)
    end
    return { tints = tints, ags = ags }
end

-- ---------------------------------------------------------------------------
-- Positioning: saved per character (RUNDB.ui.glowPos), else a neutral default.
-- Never hard-anchors into a Blizzard frame.
-- ---------------------------------------------------------------------------
local moving = false

local function applyAnchor()
    if moving then return end   -- never fight an in-progress drag
    root:ClearAllPoints()
    local db = RUN.db()
    local pos = Glow.validGlowPos(db.ui and db.ui.glowPos)
    if pos then
        root:SetPoint(pos.point, UIParent, pos.point, pos.x, pos.y)
    else
        root:SetPoint("CENTER", UIParent, "CENTER", 0, 160)   -- visible, off the player
    end
end

local function applyLock()
    local locked = RUN.Settings.get("glowLocked")
    root:EnableMouse(not locked)
    if locked then label:Hide() else label:Show() end
    return locked
end

root:SetScript("OnDragStart", function(self)
    RUN.safeCall("glow-drag", function()
        if RUN.Settings.get("glowLocked") then return end
        moving = true
        self:StartMoving()
    end)
end)
root:SetScript("OnDragStop", function(self)
    RUN.safeCall("glow-drop", function()
        self:StopMovingOrSizing()
        moving = false
        local p, _, _, x, y = self:GetPoint()
        local db = RUN.db()
        if type(db.ui) ~= "table" then db.ui = {} end
        db.ui.glowPos = { point = tostring(p or "CENTER"),
                          x = math.floor((tonumber(x) or 0) + 0.5),
                          y = math.floor((tonumber(y) or 0) + 0.5) }
    end)
end)

-- ---------------------------------------------------------------------------
-- The effect driver: build each effect once (lazily), tint by tier, play.
-- ---------------------------------------------------------------------------
local built = {}
local current = nil

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
    label:Hide()
    root:Hide()
end

local function show(name, r, g, b)
    if current and current.name == name then
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
    if not RUN.Settings.get("tierGlow") then return hideAll() end
    -- UNLOCKED = positioning mode: always show a placeholder you can drag,
    -- even with no target, so the overlay is findable.
    if not applyLock() then
        applyAnchor()
        root:Show()
        label:Show()
        show("reticle", RUN.Notoriety.colorFor(6))
        return
    end
    -- LOCKED = live mode: show the real effect only for a notorious target.
    local info = RUN.Detect.unitInfo("target")
    if not info then return hideAll() end
    local noto = RUN.Notoriety.describe(info.npcID, info.classification)
    if not Glow.shouldGlow(info, noto.tier, true) then return hideAll() end
    if not Glow.markable(RUN.Detect.tierOf(info.classification),
                         RUN.Settings.get("markNormal")) then
        return hideAll()
    end
    local name = Glow.effectForTier(noto.tier)
    if not name then return hideAll() end
    applyAnchor()
    root:Show()
    local r, g, b = RUN.Notoriety.colorFor(noto.tier)
    show(name, r, g, b)
end

-- Re-evaluate on demand (e.g. after /ra move flips the lock), firewall-wrapped.
function Glow.refresh()
    RUN.safeCall("glow-eval", evaluate)
end

-- /ra glow: unlock to drag, lock to save. The lock/unlock the owner asked for.
RUN.commands = RUN.commands or {}
RUN.commands["glow"] = function()
    local locked = not RUN.Settings.get("glowLocked")
    RUN.Settings.set("glowLocked", locked)
    if locked then
        RUN.print("rank glow LOCKED - position saved.")
    else
        RUN.print("rank glow UNLOCKED - drag it where you want (over your target "
            .. "frame), then /ra glow to lock.")
        if not RUN.Settings.get("tierGlow") then
            RUN.print("note: the glow is off - turn it on with /ra set tierGlow on.")
        end
    end
    RUN.safeCall("glow-eval", evaluate)
end

RUN.on("PLAYER_TARGET_CHANGED", evaluate)

-- Self-healing re-check through the firewall ticker (core/safety.lua): kills
-- land MID-fight (the tier - and the effect - can rise while you look), targets
-- die, options flip, a drag ends. One guarded read per second.
RUN.ticker("glow", 1, evaluate)

return Glow
