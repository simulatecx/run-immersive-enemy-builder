-- Quest-target nameplate badge: the flag EMBEDDED on the enemy. When a kill
-- quest in your log names a mob ("Bruuz slain: 0/1"), that mob's nameplate
-- wears a gold QUEST TARGET tag the whole time it is on screen - no mouseover
-- needed, no one-shot banner to miss. Recognition belongs to model/quests.lua
-- (one matcher, both quest-log API shapes - era included); this file ONLY
-- displays. Badges are OUR frames anchored to the plate, never parented to
-- Blizzard's (taint law); the sweep self-heals on quest progress and the
-- questPlates toggle. Display-only throughout.

local _, RUN = ...
if not RUN then RUN = _G.RunAdvisor or {}; _G.RunAdvisor = RUN end

local Plates = {}
RUN.Plates = Plates

-- Pure: should this unit's plate wear the badge? Hostile non-player living
-- units named by an unfinished kill quest, behind the questPlates setting.
function Plates.shouldFlag(info, questTitle, enabled)
    if not enabled or type(info) ~= "table" then return false end
    if info.isPlayer or info.dead or not info.hostile then return false end
    return questTitle ~= nil and questTitle ~= false
end

-- Selftests (registered; run headless and in-game).
if type(RUN.selftestChecks) == "table" then
    table.insert(RUN.selftestChecks, function(check)
        local mob = { name = "Bruuz", hostile = true, dead = false, isPlayer = false }
        check("plates flag quest-named hostile", Plates.shouldFlag(mob, "Bruuz Must Die", true))
        check("plates respect the toggle", Plates.shouldFlag(mob, "Bruuz Must Die", false) == false)
        check("plates skip non-targets", Plates.shouldFlag(mob, nil, true) == false)
        check("plates skip players/dead/friendly", (function()
            local player = { name = "Alta", hostile = true, dead = false, isPlayer = true }
            local dead = { name = "Bruuz", hostile = true, dead = true, isPlayer = false }
            local friendly = { name = "Bruuz", hostile = false, dead = false, isPlayer = false }
            return Plates.shouldFlag(player, "t", true) == false
                and Plates.shouldFlag(dead, "t", true) == false
                and Plates.shouldFlag(friendly, "t", true) == false
        end)())
        check("plates nil-safe", Plates.shouldFlag(nil, "t", true) == false
            and Plates.shouldFlag("junk", "t", true) == false)
    end)
end

-- Everything below wires the client; headless harness stops here.
if not _G.CreateFrame then return Plates end

local pool = {}     -- [plateFrame] = our badge frame (reused across plate recycling)
local active = {}   -- [unit token] = plateFrame currently evaluated for that unit

local function badgeFor(plate)
    local b = pool[plate]
    if b then return b end
    b = CreateFrame("Frame", nil, UIParent)   -- own frame, never parented to the plate
    b:SetSize(120, 14)
    b:SetFrameStrata("MEDIUM")
    local txt = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    txt:SetPoint("CENTER")
    txt:SetText("QUEST TARGET")
    txt:SetTextColor(1.0, 0.82, 0.0)          -- the tooltip's quest gold
    b:Hide()
    pool[plate] = b
    return b
end

local function plateFor(unit)
    local NP = _G.C_NamePlate
    if not (NP and NP.GetNamePlateForUnit) then return nil end
    local ok, plate = pcall(NP.GetNamePlateForUnit, unit)
    if ok then return plate end
    return nil
end

local function evaluate(unit)
    local plate = plateFor(unit)
    if not plate then return end
    local info = RUN.Detect.unitInfo(unit)
    local quest = info and RUN.Quests.isTarget(info.name) or nil
    if Plates.shouldFlag(info, quest, RUN.Settings.get("questPlates")) then
        local b = badgeFor(plate)
        b:ClearAllPoints()
        b:SetPoint("BOTTOM", plate, "TOP", 0, 2)
        b:Show()
        active[unit] = plate
    else
        local b = pool[plate]
        if b then b:Hide() end
        active[unit] = nil
    end
end

RUN.on("NAME_PLATE_UNIT_ADDED", evaluate)
RUN.on("NAME_PLATE_UNIT_REMOVED", function(unit)
    local plate = active[unit]
    if plate and pool[plate] then pool[plate]:Hide() end
    active[unit] = nil
end)

-- The self-healing sweep through the shared firewall ticker (core/safety.lua):
-- once a second, re-evaluate every visible plate. Covers quest progress
-- ("8/8" unflags), newly accepted quests flagging mobs already on screen,
-- deaths, and the questPlates toggle - without a raw per-file OnUpdate.
-- Bounded work: a handful of frames per tick.
local function sweep()
    local NP = _G.C_NamePlate
    if not (NP and NP.GetNamePlates) then return end
    local ok, plates = pcall(NP.GetNamePlates)
    if not ok or type(plates) ~= "table" then return end
    for i = 1, #plates do
        local p = plates[i]
        local unit = p and (p.namePlateUnitToken or (p.UnitFrame and p.UnitFrame.unit))
        if unit then evaluate(unit) end
    end
end
RUN.ticker("plates", 1, sweep)

return Plates
