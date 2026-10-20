-- The odds model: P(you win) against the creature in front of you.
-- BETA = the coarse standalone heuristic only: level delta + classification +
-- your current health. Everything it says is classic-presumed, so every output
-- carries "(p)" and a wide band - bands over points, honesty over precision
-- (we influence permadeath decisions). The Foresight bridge and the crowd
-- killcount calibration sharpen this in later phases; both hooks exist and are
-- empty-safe. Pure Lua: fully headless-testable.

local _, RUN = ...
if not RUN then RUN = _G.RunAdvisor or {}; _G.RunAdvisor = RUN end

local Odds = {}
RUN.Odds = Odds

-- Classification penalties (classic-presumed toughness ordering:
-- normal < rare < elite < rareelite << worldboss).
local PENALTY = {
    minus = -0.3, trivial = -0.3, normal = 0.0,
    rare = 0.35, elite = 0.8, rareelite = 1.3,
    worldboss = 99,
}

local function clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

-- ctx: { playerLevel, creatureLevel (-1 = skull), classification,
--        healthFrac (0..1 or nil when secret/unknown) }
-- Returns { p = 0..1, band = "FIGHT"|"RISKY"|"FLEE", tag = "(p)",
--           skull = bool, degraded = bool }
function Odds.compute(ctx)
    ctx = ctx or {}
    local pl = tonumber(ctx.playerLevel) or 1
    local cl = tonumber(ctx.creatureLevel) or pl
    local skull = (cl == -1)
    if skull then cl = pl + 10 end
    local delta = cl - pl

    local penalty = PENALTY[ctx.classification or "normal"]
    if penalty == nil then penalty = 0 end

    -- Logistic over level delta and classification. At equal level a normal mob
    -- sits ~75% (you have abilities, it mostly doesn't); each level it has on you
    -- costs steeply; classification shifts the whole curve down.
    local z = 1.1 - 0.28 * delta - penalty
    local p = 1 / (1 + math.exp(-z))

    -- Your current health scales the odds: walking in at 40% is not the same fight.
    local degraded = false
    local hf = tonumber(ctx.healthFrac)
    if hf and hf > 0 and hf <= 1 then
        p = p * (hf ^ 0.7)
    elseif hf == nil and ctx.healthKnown == false then
        degraded = true  -- secret health: say so instead of pretending
    end

    -- Crowd calibration hook (phase E): a rare with a big real-world body count
    -- bends the curve down. Empty-safe today.
    local deadliness = tonumber(ctx.deadliness)
    if deadliness and deadliness > 0 then
        p = p * (1 - clamp(deadliness, 0, 1) * 0.25)
    end

    p = clamp(p, 0.01, 0.99)
    if skull or (ctx.classification == "worldboss") then p = 0.01 end

    local band
    if p >= 0.65 then band = "FIGHT"
    elseif p >= 0.35 then band = "RISKY"
    else band = "FLEE" end

    return { p = p, band = band, tag = "(p)", skull = skull, degraded = degraded }
end

-- Band -> display colour (r, g, b).
function Odds.bandColor(band)
    if band == "FIGHT" then return 0.42, 1.0, 0.6 end
    if band == "RISKY" then return 1.0, 0.68, 0.3 end
    return 1.0, 0.38, 0.38
end

-- Client wrapper: build ctx from live units via Detect, prefer the Foresight
-- bridge when it exists, else the coarse model. Headless harness never calls this.
function Odds.forUnit(unit)
    if not RUN.Detect or not RUN.Detect.unitInfo then return nil end
    local c = RUN.Detect.unitInfo(unit)
    if not c or not c.hostile or c.isPlayer or c.dead then return nil end
    local me = RUN.Detect.playerInfo()

    -- Foresight's real model first (future bridge; nil today).
    if c.npcID and RUN.Bridge then
        local v = RUN.Bridge.dangerVerdict(c.npcID, { level = me.level })
        if v then v.creature = c; v.tag = "" return v end
    end

    local healthFrac, healthKnown = nil, true
    if me.health and me.healthMax and me.healthMax > 0 then
        healthFrac = me.health / me.healthMax
    else
        healthKnown = false
    end

    local verdict = Odds.compute({
        playerLevel = me.level,
        creatureLevel = c.level,
        classification = c.classification,
        healthFrac = healthFrac,
        healthKnown = healthKnown,
    })
    verdict.creature = c
    verdict.source = "coarse"
    return verdict
end

return Odds
