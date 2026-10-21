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
    check("choose prefers cleu hit", select(2, A.choose({ npc = 1 }, { npc = 2, t = 100 }, 100)) == "cleu")
    check("choose fresh fallback", (function()
        local hit, how = A.choose(nil, { npc = 2, t = 95 }, 100)
        return hit and hit.npc == 2 and how == "fallback"
    end)())
    check("choose stale fallback -> unknown", select(2, A.choose(nil, { npc = 2, t = 80 }, 100)) == "unknown")
    check("choose nothing -> unknown", select(2, A.choose(nil, nil, 100)) == "unknown")
    check("guards isSecret plain false", G.isSecret("hello") == false and G.isSecret(nil) == false)
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

    -- ---- kill ranking (the passive mouseover layer) ----
    check("rank 0 kills -> none", A.rankForKills(0) == nil)
    check("rank 1 kill -> Blooded", A.rankForKills(1).label == "Blooded")
    check("rank 3 kills -> Dangerous", A.rankForKills(3).label == "Dangerous")
    check("rank 6 kills -> Deadly", A.rankForKills(6).label == "Deadly")
    check("rank 12 kills -> Infamous", A.rankForKills(12).label == "Infamous")
    check("rank garbage tolerated", A.rankForKills("junk") == nil)
    check("killsBy counts npc matches", (function()
        local db = RUN.db()
        local saved = db.deaths
        db.deaths = {
            { when = 1, killer = "Hogger", npc = 448 },
            { when = 2, killer = "Hogger", npc = 448 },
            { when = 3, killer = "a fall" },
            { when = "tampered", npc = 448 },  -- invalid entry must not count
        }
        local n = A.killsBy(448)
        db.deaths = saved
        return n == 2
    end)())
    check("killsBy nil npc -> 0", A.killsBy(nil) == 0)

    -- ---- tooltip flag layer (pure) ----
    local T = RUN.Tooltip
    check("flag rare", T.flagFor("rare").label == "Rare (silver dragon)")
    check("flag rareelite", T.flagFor("rareelite") ~= nil)
    check("flag worldboss", T.flagFor("worldboss") ~= nil)
    check("flag normal -> none", T.flagFor("normal") == nil)
    check("flagLine flag+rank", T.flagLine({ label = "Elite" }, { label = "Deadly" }, 5)
        == "Elite - Deadly (killed you 5x)")
    check("flagLine flag only", T.flagLine({ label = "Rare (silver dragon)" }, nil, 0)
        == "Rare (silver dragon)")
    check("flagLine rank only", T.flagLine(nil, { label = "Blooded" }, 1)
        == "Blooded - killed you 1x")
    check("flagLine nothing -> nil", T.flagLine(nil, nil, 0) == nil)

    -- ---- death-ping: checksum, wire format, rate limit, heard counts ----
    local DP = RUN.Deathping
    check("fletcher16 deterministic", DP.fletcher16("abc") == DP.fletcher16("abc"))
    check("fletcher16 differs", DP.fletcher16("abc") ~= DP.fletcher16("abd"))
    check("fletcher16 range", (function()
        local v = DP.fletcher16("Snagglefang")
        return type(v) == "number" and v >= 0 and v <= 65535
    end)())
    check("deathping roundtrip", (function()
        local msg = DP.encode(3113, 1465, 10)
        local d = DP.decode(msg)
        return d and d.npc == 3113 and d.mapID == 1465 and d.bracket == 10
    end)())
    check("deathping tamper rejected", (function()
        local msg = DP.encode(3113, 1465, 10)
        return DP.decode(msg:gsub("3113", "9999", 1)) == nil
    end)())
    check("deathping garbage rejected", DP.decode("RDP1:lol:1:2:3") == nil
        and DP.decode(nil) == nil and DP.decode("hello") == nil)
    check("deathping bad npc rejected", DP.encode(0, 1, 1) == nil)
    check("deathping rate limit", (function()
        local state = {}
        for i = 1, 5 do
            if not DP.allowSender(state, "Spoofy", i) then return false end
        end
        return DP.allowSender(state, "Spoofy", 6) == false
            and DP.allowSender(state, "Honest", 6) == true
    end)())
    check("heard counts", (function()
        local db = RUN.db()
        local saved = db.heard
        db.heard = nil
        DP.recordHeard(448); DP.recordHeard(448)
        local n = DP.heardBy(448)
        db.heard = saved
        return n == 2
    end)())
    check("heard nil npc -> 0", DP.heardBy(nil) == 0)

    -- ---- nearby ping: tiers, titles, gates, rank line ----
    check("tier normal", D.tierOf("normal") == "normal" and D.tierOf("trivial") == "normal")
    check("tier elite", D.tierOf("elite") == "elite")
    check("tier unique", D.tierOf("rare") == "unique" and D.tierOf("rareelite") == "unique"
        and D.tierOf("worldboss") == "unique")
    check("tier unknown -> normal", D.tierOf("weird") == "normal")
    check("title rare", RUN.Nearby.titleFor("rare") == "RARE NEARBY")
    check("title rareelite", RUN.Nearby.titleFor("rareelite") == "RARE ELITE NEARBY")
    check("title boss", RUN.Nearby.titleFor("worldboss") == "BOSS NEARBY")
    check("title elite", RUN.Nearby.titleFor("elite") == "ELITE NEARBY")
    check("title normal", RUN.Nearby.titleFor("normal") == "ENEMY NEARBY")
    check("gate normal -> pingNormal", RUN.Nearby.settingFor("normal") == "pingNormal")
    check("gate elite -> pingElite", RUN.Nearby.settingFor("elite") == "pingElite")
    check("gate rare -> pingUnique", RUN.Nearby.settingFor("rare") == "pingUnique"
        and RUN.Nearby.settingFor("worldboss") == "pingUnique")
    check("gate quest overrides tier", RUN.Nearby.gateFor({ quest = "Bruuz Must Die",
        classification = "normal" }) == "pingQuest")
    check("gate no quest falls through", RUN.Nearby.gateFor({ classification = "elite" })
        == "pingElite")
    check("title quest target", RUN.Nearby.bannerTitle({ quest = "x",
        classification = "normal" }) == "QUEST TARGET NEARBY")

    -- ---- quest targets (pure matcher) ----
    local Q = RUN.Quests
    Q.setTargets({ { text = "Bruuz slain: 0/1", title = "Bruuz Must Die" },
                   { text = "Sunscale Screecher slain: 3/8", title = "Screechers" } })
    check("quest target prefix match", Q.isTarget("Bruuz") == "Bruuz Must Die")
    check("quest target case-insensitive", Q.isTarget("bruuz") == "Bruuz Must Die")
    check("quest target multiword", Q.isTarget("Sunscale Screecher") == "Screechers")
    check("quest non-target nil", Q.isTarget("Plainstrider") == nil)
    check("quest partial word no match", Q.isTarget("Sunscale") == nil
        and Q.isTarget("Sun") == nil and Q.isTarget("Bru") == nil)
    check("quest nil-safe", Q.isTarget(nil) == nil and Q.isTarget("") == nil)
    check("quest count", Q.targetCount() == 2)
    Q.setTargets({})
    check("quest cleared", Q.isTarget("Bruuz") == nil and Q.targetCount() == 0)
    check("nearby rankline none", RUN.Nearby.rankLine(0, 0) == "no recorded kills yet")
    check("nearby rankline kills+heard", RUN.Nearby.rankLine(2, 3)
        == "Deadly - killed you 2x + 3 deaths heard")
    check("flagLine heard only", T.flagLine(nil, { label = "Dangerous" }, 0, 2)
        == "Dangerous - 2 player deaths heard")
    check("flagLine kills+heard", T.flagLine({ label = "Elite" }, { label = "Deadly" }, 2, 3)
        == "Elite - Deadly (killed you 2x + 3 heard)")

    -- ---- settings: defaults + validation ----
    local S = RUN.Settings
    check("settings default flags on", S.get("flags") == true)
    check("settings default expansiveStats off", S.get("expansiveStats") == false)
    check("settings default nearbyPing on", S.get("nearbyPing") == true)
    check("settings default pingNormal off", S.get("pingNormal") == false)
    check("settings default pingElite on", S.get("pingElite") == true)
    check("settings default pingUnique on", S.get("pingUnique") == true)
    check("settings default shareDeaths on", S.get("shareDeaths") == true)
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
