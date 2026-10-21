-- The notoriety system (Nemesis-inspired, platform-honest): enemies that kill
-- players GROW. Kills are per-SPECIES (npcID) - WoW cannot persist one spawn
-- across sessions - so the species itself becomes the adversary: it climbs a
-- 10-tier ladder, earns a deterministic title, and at tier 3+ a NORMAL mob
-- becomes a "soft elite": banner treatment even though the game calls it
-- trivial. Counts blend your journal (fact) + deaths heard (live crowd);
-- the server-verified baked count joins the same ladder in the crowd phase.
-- Pure throughout: fully headless-tested.

local _, RUN = ...
if not RUN then RUN = _G.RunAdvisor or {}; _G.RunAdvisor = RUN end

local Notoriety = {}
RUN.Notoriety = Notoriety

-- Kills required to REACH each tier (1..10).
local THRESHOLDS = { 1, 2, 5, 10, 15, 25, 40, 60, 80, 100 }

-- Tier colours: ember -> blood as the legend grows.
local TIER_COLORS = {
    [0] = { r = 0.7, g = 0.7, b = 0.7 },
    { r = 0.95, g = 0.85, b = 0.55 }, { r = 1.0, g = 0.78, b = 0.42 },
    { r = 1.0, g = 0.70, b = 0.35 }, { r = 1.0, g = 0.62, b = 0.30 },
    { r = 1.0, g = 0.55, b = 0.28 }, { r = 1.0, g = 0.48, b = 0.26 },
    { r = 1.0, g = 0.40, b = 0.25 }, { r = 1.0, g = 0.33, b = 0.24 },
    { r = 1.0, g = 0.27, b = 0.23 }, { r = 1.0, g = 0.20, b = 0.20 },
}

function Notoriety.tierFor(total)
    total = tonumber(total) or 0
    local tier = 0
    for i = 1, #THRESHOLDS do
        if total >= THRESHOLDS[i] then tier = i else break end
    end
    return tier
end

function Notoriety.thresholdFor(tier)
    return THRESHOLDS[tier]
end

-- Deterministic title: same npcID -> same name, forever, for everyone.
function Notoriety.titleFor(npcID, tier)
    tier = tonumber(tier) or 0
    if tier < 1 then return nil end
    if tier > 10 then tier = 10 end
    local pool = RUN.Titles and RUN.Titles[tier]
    if type(pool) ~= "table" or #pool == 0 then return nil end
    local id = tonumber(npcID) or 0
    local idx = ((id * 97 + tier * 131) % #pool) + 1
    return pool[idx]
end

function Notoriety.colorFor(tier)
    local c = TIER_COLORS[tier] or TIER_COLORS[0]
    return c.r, c.g, c.b
end

-- A normal-tier mob that has proven itself deadly is a SOFT ELITE: it earns
-- the banner real elites get. (Elites/rares already have their dragons.)
function Notoriety.isSoftElite(classification, tier)
    return RUN.Detect.tierOf(classification) == "normal" and (tonumber(tier) or 0) >= 3
end

-- The one-stop readout for a creature: total kills, tier, title, soft-elite.
function Notoriety.describe(npcID, classification)
    local kills = RUN.Attribution.killsBy(npcID)
    local heard = RUN.Deathping.heardBy(npcID)
    local total = kills + heard
    local tier = Notoriety.tierFor(total)
    return {
        kills = kills, heard = heard, total = total, tier = tier,
        title = Notoriety.titleFor(npcID, tier),
        softElite = Notoriety.isSoftElite(classification, tier),
    }
end

return Notoriety
