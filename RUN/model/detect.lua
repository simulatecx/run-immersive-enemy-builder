-- Detection: who is the hostile in front of you? Pure helpers (GUID parsing,
-- notability) are headless-testable; the unit readers are guard-layered client code.
-- Events are wired by ui/panel.lua; this module only reads and classifies.

local _, RUN = ...
if not RUN then RUN = _G.RunAdvisor or {}; _G.RunAdvisor = RUN end

local Detect = {}
RUN.Detect = Detect

-- ---------------------------------------------------------------------------
-- Pure: npcID from a unit GUID. Creature GUIDs look like
-- "Creature-0-1465-0-2105-448-000043F59F": type, then 4 numeric fields, npcID 6th.
-- Returns npcID (number) or nil for players/pets/items/malformed.
-- ---------------------------------------------------------------------------
function Detect.npcIdFromGUID(guid)
    if type(guid) ~= "string" then return nil end
    local unitType, npc = guid:match("^([A-Za-z]+)%-%d+%-%d+%-%d+%-%d+%-(%d+)%-")
    if not unitType then return nil end
    if unitType ~= "Creature" and unitType ~= "Vehicle" then return nil end
    return tonumber(npc)
end

-- Pure: is this classification worth a heads-up (auto-mark, mouseover preview)?
local NOTABLE = { rare = true, rareelite = true, worldboss = true }
function Detect.isNotable(classification)
    return NOTABLE[classification] == true
end

-- Pure: ping tier groups (the options model). normal-kind mobs are one group,
-- elites another, and rares + rare elites + bosses are all "unique".
local TIERS = {
    minus = "normal", trivial = "normal", normal = "normal",
    elite = "elite",
    rare = "unique", rareelite = "unique", worldboss = "unique",
}
function Detect.tierOf(classification)
    return TIERS[classification] or "normal"
end

-- Everything below reads the client.
if not _G.CreateFrame then return Detect end

local Guards = RUN.Guards

-- Read everything the odds model needs about a unit, through Guards. Fields that
-- come back secret/missing are nil - the odds model degrades honestly.
function Detect.unitInfo(unit)
    if not Guards.call(_G.UnitExists, unit) then return nil end
    local info = {}
    info.unit = unit
    info.name = Guards.call(_G.UnitName, unit)
    info.hostile = Guards.call(_G.UnitCanAttack, "player", unit) and true or false
    info.dead = Guards.call(_G.UnitIsDead, unit) and true or false
    info.isPlayer = Guards.call(_G.UnitIsPlayer, unit) and true or false
    info.level = Guards.number(Guards.call(_G.UnitLevel, unit))          -- -1 = skull
    info.classification = Guards.call(_G.UnitClassification, unit) or "normal"
    info.guid = Guards.call(_G.UnitGUID, unit)
    info.npcID = Detect.npcIdFromGUID(info.guid)
    info.healthMax = Guards.number(Guards.call(_G.UnitHealthMax, unit))  -- may be secret
    info.notable = Detect.isNotable(info.classification)
    -- enrich from the rares table when we know this npc (empty-safe)
    if info.npcID and RUN.raresMerged then
        local known = RUN.raresMerged()[info.npcID]
        if known then info.known = known end
    end
    return info
end

-- The player's own state for the odds model (guarded; secrets tolerated).
function Detect.playerInfo()
    local p = {}
    p.level = Guards.number(Guards.call(_G.UnitLevel, "player"))
    p.health = Guards.number(Guards.call(_G.UnitHealth, "player"))
    p.healthMax = Guards.number(Guards.call(_G.UnitHealthMax, "player"))
    return p
end

return Detect
