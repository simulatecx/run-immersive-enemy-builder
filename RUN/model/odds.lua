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

    -- Readiness scales the odds. Foresight's character profile (survivability +
    -- offense) is preferred - it never needs the secret live health, so it also
    -- clears the "degraded" case. Else your current-health fraction. Else, when
    -- health is secret and Foresight is absent, say so instead of pretending.
    local degraded = false
    local readiness = tonumber(ctx.readiness)
    local hf = tonumber(ctx.healthFrac)
    if readiness and readiness > 0 then
        p = p * (readiness ^ 0.45)   -- gentle + bounded: sharpen, never invincible
    elseif hf and hf > 0 and hf <= 1 then
        p = p * (hf ^ 0.7)
    elseif hf == nil and ctx.healthKnown == false then
        degraded = true
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

-- Pure: a character-readiness multiplier (~1.0 = typical for level) from a
-- Foresight combat profile. BOUNDED + gentle - Foresight sharpens the odds, it
-- never lets a geared character read as invincible. The per-level baselines are
-- presumed classic scaling (hence the (p) tag stays). Returns nil without a
-- profile, so the caller falls back to the live-health path.
function Odds.readiness(profile)
    if type(profile) ~= "table" then return nil end
    local level = tonumber(profile.level) or 1
    if level < 1 then level = 1 end

    -- survivability: prefer real max health (0 when secret), else stamina.
    local hp = tonumber(profile.maxHealth) or 0
    local survive
    if hp > 0 then
        survive = hp / (60 + level * 55)      -- rough expected HP for the level
    else
        local sta = tonumber(profile.stamina) or 0
        survive = sta / (20 + level * 4)      -- rough expected stamina for the level
    end

    local off = (tonumber(profile.attackPower) or 0) + (tonumber(profile.spellPower) or 0)
    local offense = off / (10 + level * 8)    -- rough expected offense for the level

    if survive <= 0 then survive = 1 end
    if offense <= 0 then offense = 1 end
    local r = 0.55 * survive + 0.45 * offense
    if r < 0.5 then r = 0.5 elseif r > 1.6 then r = 1.6 end
    return r
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

    -- Foresight's character profile sharpens the odds when present (and never
    -- needs secret live health). Absent -> fall back to the live-health path.
    local profile = RUN.Bridge and RUN.Bridge.combatProfile and RUN.Bridge.combatProfile() or nil
    local readiness = profile and Odds.readiness(profile) or nil

    local healthFrac, healthKnown = nil, true
    if not readiness then
        if me.health and me.healthMax and me.healthMax > 0 then
            healthFrac = me.health / me.healthMax
        else
            healthKnown = false
        end
    end

    local verdict = Odds.compute({
        playerLevel = me.level or (profile and profile.level),
        creatureLevel = c.level,
        classification = c.classification,
        healthFrac = healthFrac,
        healthKnown = healthKnown,
        readiness = readiness,
    })
    verdict.creature = c
    verdict.source = readiness and "foresight" or "coarse"
    return verdict
end

-- Selftests (registered; the Foresight-readiness math must be bounded + clear
-- the degraded case, and must never fire without a profile).
if type(RUN.selftestChecks) == "table" then
    table.insert(RUN.selftestChecks, function(check)
        check("odds readiness nil without a profile", Odds.readiness(nil) == nil
            and Odds.readiness("x") == nil)
        check("odds readiness is bounded, strong > weak", (function()
            local weak = Odds.readiness({ level = 13, stamina = 10, attackPower = 10 })
            local strong = Odds.readiness({ level = 13, maxHealth = 5000, attackPower = 2000 })
            return weak >= 0.5 and weak <= 1.6 and strong <= 1.6 and strong > weak
        end)())
        check("odds readiness clears the degraded case", (function()
            -- secret health + a Foresight readiness -> NOT degraded
            local v = Odds.compute({ playerLevel = 13, creatureLevel = 13,
                classification = "normal", healthKnown = false, readiness = 1.0 })
            return v.degraded == false and v.p > 0
        end)())
        check("odds still degrades with no profile + secret health", (function()
            local v = Odds.compute({ playerLevel = 13, creatureLevel = 13,
                classification = "normal", healthKnown = false })
            return v.degraded == true
        end)())
        check("odds readiness lifts a strong character's win chance", (function()
            local lo = Odds.compute({ playerLevel = 13, creatureLevel = 13,
                classification = "normal", readiness = 0.6 })
            local hi = Odds.compute({ playerLevel = 13, creatureLevel = 13,
                classification = "normal", readiness = 1.5 })
            return hi.p > lo.p
        end)())
    end)
end

return Odds
