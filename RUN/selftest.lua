-- RUN selftest: pure-logic checks that run identically headless (lupa harness)
-- and in-game via /ra selftest. THE ship gate for addon-logic changes.

local _, RUN = ...
if not RUN then RUN = _G.RunAdvisor or {}; _G.RunAdvisor = RUN end

function RUN.selftest()
    local pass, failures = 0, {}
    local function check(label, cond)
        if cond then pass = pass + 1 else table.insert(failures, label) end
    end

    -- ---- guards ----
    local G = RUN.Guards
    check("guards.number passthrough", G.number(42) == 42)
    check("guards.number nil->missing", select(2, G.number(nil)) == "missing")
    check("guards.number string rejected", G.number("42") == nil)
    check("guards.call missing api", select(2, G.call(nil)) == "missing-api")
    check("guards.call error swallowed", G.call(function() error("boom") end) == nil)
    check("guards.call result", G.call(function() return 7 end) == 7)
    check("guards.select picks nth", G.select(2, function() return "a", "b" end) == "b")

    -- ---- detect: GUID parsing ----
    local D = RUN.Detect
    check("guid creature", D.npcIdFromGUID("Creature-0-1465-0-2105-448-000043F59F") == 448)
    check("guid vehicle", D.npcIdFromGUID("Vehicle-0-1465-0-2105-9001-000043F59F") == 9001)
    check("guid player rejected", D.npcIdFromGUID("Player-1096-06C5D8A1") == nil)
    check("guid garbage rejected", D.npcIdFromGUID("not a guid") == nil)
    check("guid nil rejected", D.npcIdFromGUID(nil) == nil)
    check("notable rare", D.isNotable("rare") == true)
    check("notable rareelite", D.isNotable("rareelite") == true)
    check("notable normal false", D.isNotable("normal") == false)
    check("notable elite false", D.isNotable("elite") == false)

    -- ---- odds: bounds, monotonicity, bands, honesty ----
    local O = RUN.Odds
    local even = O.compute({ playerLevel = 10, creatureLevel = 10, classification = "normal" })
    check("odds even-level normal is FIGHT", even.band == "FIGHT")
    check("odds p bounded", even.p > 0 and even.p < 1)
    check("odds tag always (p)", even.tag == "(p)")

    local function p(delta, cls)
        return O.compute({ playerLevel = 10, creatureLevel = 10 + delta, classification = cls }).p
    end
    check("odds monotonic in level", p(-3, "normal") > p(0, "normal")
        and p(0, "normal") > p(3, "normal") and p(3, "normal") > p(6, "normal"))
    check("odds classification ordering", p(0, "normal") > p(0, "rare")
        and p(0, "rare") > p(0, "elite") and p(0, "elite") > p(0, "rareelite"))
    check("odds skull -> FLEE", O.compute({ playerLevel = 10, creatureLevel = -1,
        classification = "normal" }).band == "FLEE")
    check("odds worldboss -> FLEE", O.compute({ playerLevel = 60, creatureLevel = 60,
        classification = "worldboss" }).band == "FLEE")
    check("odds low health hurts", O.compute({ playerLevel = 10, creatureLevel = 10,
        classification = "normal", healthFrac = 0.35 }).p < even.p)
    check("odds secret health degrades", O.compute({ playerLevel = 10, creatureLevel = 10,
        classification = "normal", healthKnown = false }).degraded == true)
    check("odds crowd deadliness bends down", O.compute({ playerLevel = 10, creatureLevel = 10,
        classification = "rare", deadliness = 1 }).p
        < O.compute({ playerLevel = 10, creatureLevel = 10, classification = "rare" }).p)
    local far = O.compute({ playerLevel = 10, creatureLevel = 40, classification = "rareelite" })
    check("odds floor holds", far.p >= 0.01)

    -- ---- attribution: pure picker ----
    local A = RUN.Attribution
    local buf = {
        { t = 100, name = "Wolf", npc = 299 },
        { t = 104, name = "Kolkar Marauder", npc = 3113 },
    }
    local picked = A.pick(buf, 105)
    check("attribution picks last hit", picked and picked.npc == 3113)
    check("attribution window expires", A.pick(buf, 120) == nil)
    check("attribution empty buffer", A.pick({}, 100) == nil)
    local env = A.pick({ { t = 99, env = "Falling" } }, 100)
    check("attribution env wins", env and env.env == "Falling")
    check("attribution env name", A.envName("Falling") == "a fall")
    check("attribution env unknown tolerated", A.envName("Mystery") ~= nil)
    check("attribution entry validation", A.validEntry({ when = 1, killer = "x" }) == true
        and A.validEntry({ when = "bad" }) == false and A.validEntry(nil) == false)

    -- ---- data: empty-safe rares + overrides merge ----
    check("rares table exists", type(RUN.gen) == "table" and type(RUN.gen.rares) == "table")
    check("rares merged empty-safe", type(RUN.raresMerged()) == "table")
    RUN.overrides.rares[999999] = { name = "Test Rare", classification = "rare" }
    check("overrides win on merge", RUN.raresMerged()[999999].name == "Test Rare")
    RUN.overrides.rares[999999] = nil

    -- ---- settings: defaults + validation ----
    local S = RUN.Settings
    check("settings default panel", S.get("panel") == true)
    check("settings unknown key nil", S.get("nope") == nil)
    check("settings set/get", (function()
        local before = S.get("autoMark")
        S.set("autoMark", false)
        local mid = S.get("autoMark")
        S.set("autoMark", before)
        return mid == false
    end)())
    check("settings type-validated", S.set("autoMark", "garbage") == false)

    -- ---- bridge: absent Foresight degrades ----
    check("bridge nil without Foresight", RUN.Bridge.foresight() == nil or _G.ForesightAPI ~= nil)
    check("bridge verdict nil-safe", RUN.Bridge.dangerVerdict(123, {}) == nil or _G.ForesightAPI ~= nil)

    -- ---- version sync ----
    check("version set", type(RUN.version) == "string" and RUN.version:match("^%d+%.%d+%.%d+$") ~= nil)

    return pass, failures
end

return RUN.selftest
