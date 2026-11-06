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

    -- ---- the sightings harvest ----
    check("sighting records notable", (function()
        local db = RUN.db()
        local saved = db.sightings
        db.sightings = nil
        local ok = D.recordSighting({ npcID = 5786, name = "Snagglefang",
            classification = "rare" }, 1413, 0.44, 0.61)
        local s = D.sightingFor(5786)
        local result = ok and s and s.name == "Snagglefang" and s.mapID == 1413
        db.sightings = saved
        return result
    end)())
    check("sighting rejects normals", (function()
        local db = RUN.db()
        local saved = db.sightings
        db.sightings = nil
        local ok = D.recordSighting({ npcID = 3113, name = "Kolkar",
            classification = "normal" })
        db.sightings = saved
        return ok == false
    end)())
    check("sighting lookup nil-safe", D.sightingFor(nil) == nil
        and D.sightingFor(999991) == nil)
    check("npcName prefers sighting over id", (function()
        local db = RUN.db()
        local saved = db.sightings
        db.sightings = { [5786] = { name = "Snagglefang", classification = "rare" } }
        local n = RUN.Deathping.npcName(5786)
        db.sightings = saved
        return n == "Snagglefang"
    end)())

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
    check("heard total sums", (function()
        local db = RUN.db()
        local saved = db.heard
        db.heard = { [448] = 2, [3113] = 3, bad = "junk" }
        local t = DP.heardTotal()
        db.heard = saved
        return t == 5
    end)())

    -- ---- the Account Ledger (pure aggregation) ----
    local W = RUN.Window
    local journal = {
        { when = 1, killer = "Hogger", npc = 448, who = "Alta", zone = "Elwynn" },
        { when = 2, killer = "Hogger", npc = 448, who = "Beta", zone = "Elwynn" },
        { when = 3, killer = "a fall" },
        { when = 4, killer = "Bruuz", npc = 3113, who = "Alta", zone = "Barrens" },
        { when = "tampered" },
        { when = 5 },  -- unknown cause: valid entry, no killer - excluded from top list
    }
    check("ledger top killers sorted", (function()
        local top = W.topKillers(journal, 5)
        return #top == 3 and top[1].name == "Hogger" and top[1].count == 2
            and top[1].lastWho == "Beta"
    end)())
    check("ledger top respects cap", #W.topKillers(journal, 1) == 1)
    check("ledger top empty-safe", #W.topKillers(nil, 5) == 0)
    check("ledger recent newest first", (function()
        local rec = W.recent(journal, 3)
        return #rec == 3 and rec[1].when == 5 and rec[2].when == 4
    end)())
    check("ledger recent skips invalid", (function()
        for _, e in ipairs(W.recent(journal, 10)) do
            if e.when == "tampered" then return false end
        end
        return true
    end)())

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

    -- ---- notoriety (the Nemesis layer) ----
    local N = RUN.Notoriety
    check("tier 0 below first blood", N.tierFor(0) == 0)
    check("tier thresholds", N.tierFor(1) == 1 and N.tierFor(2) == 2 and N.tierFor(5) == 3
        and N.tierFor(10) == 4 and N.tierFor(25) == 6 and N.tierFor(99) == 9
        and N.tierFor(100) == 10 and N.tierFor(5000) == 10)
    check("title deterministic", N.titleFor(448, 4) == N.titleFor(448, 4))
    check("title exists tiers 1-10", (function()
        for t = 1, 10 do if type(N.titleFor(448, t)) ~= "string" then return false end end
        return true
    end)())
    check("title nil below tier 1", N.titleFor(448, 0) == nil)
    check("title varies by npc", (function()
        for id = 1, 12 do
            if N.titleFor(id, 4) ~= N.titleFor(id + 1, 4) then return true end
        end
        return false
    end)())
    check("soft elite: deadly normal", N.isSoftElite("normal", 3) == true)
    check("soft elite: not below tier 3", N.isSoftElite("normal", 2) == false)
    check("soft elite: never elites/rares", N.isSoftElite("elite", 9) == false
        and N.isSoftElite("rare", 9) == false)
    check("notoriety describe blends", (function()
        local db = RUN.db()
        local sd, sh = db.deaths, db.heard
        db.deaths = { { when = 1, killer = "Hogger", npc = 448 } }
        db.heard = { [448] = 4 }
        local d = N.describe(448, "normal")
        db.deaths, db.heard = sd, sh
        return d.total == 5 and d.tier == 3 and d.softElite == true
            and type(d.title) == "string"
    end)())
    check("tier colors returned", select("#", N.colorFor(5)) == 3)

    -- ---- deathping companions: acks, last words, hello, heard log ----
    check("ack roundtrip", DP.decodeAck(DP.encodeAck(12345)) == 12345)
    check("ack garbage rejected", DP.decodeAck("RDA1:lol") == nil and DP.decodeAck(nil) == nil)
    check("words sanitize strips", DP.sanitizeWords(" |cffRUN|r: hi ") == "cffRUNr, hi")
    check("words sanitize caps 80", #DP.sanitizeWords(string.rep("a", 200)) == 80)
    check("words sanitize empty -> nil", DP.sanitizeWords("  ") == nil and DP.sanitizeWords(nil) == nil)
    check("words roundtrip", (function()
        local d = DP.decodeWords(DP.encodeWords(777, "tell my guild i loved them"))
        return d and d.sum == 777 and d.words == "tell my guild i loved them"
    end)())
    check("hello roundtrip", DP.decodeHello(DP.encodeHello("0.6.0")) == "0.6.0")
    check("hello garbage rejected", DP.decodeHello("RVH1:evil") == nil and DP.encodeHello("x") == nil)
    check("version newer", DP.newer("0.7.0", "0.6.9") and DP.newer("1.0.0", "0.9.9")
        and not DP.newer("0.6.0", "0.6.0") and not DP.newer("0.5.9", "0.6.0"))
    check("heard log fifo cap", (function()
        local log = {}
        for i = 1, 12 do DP.pushHeard(log, { sum = i }, 10) end
        return #log == 10 and log[1].sum == 3 and log[10].sum == 12
    end)())
    check("corroborate distinct senders", (function()
        local e = { acks = 0 }
        local a = DP.corroborate(e, "Peer1")
        DP.corroborate(e, "Peer1")              -- duplicate must not count
        local b = DP.corroborate(e, "Peer2")
        return a == false and b == true and e.acks == 2 and e.corro == true
    end)())
    check("ack rate override", (function()
        local state = {}
        for i = 1, 30 do
            if not DP.allowSender(state, "me", i, 30) then return false end
        end
        return DP.allowSender(state, "me", 31, 30) == false
    end)())
    check("decode exposes sum", (function()
        local d = DP.decode(DP.encode(3113, 1465, 10))
        return type(d.sum) == "number"
    end)())

    -- ---- mode classification + flag line titles ----
    check("mode hc wins", A.classifyMode(true, "Player-1096-ABC") == "hc")
    check("mode pvp on player blow", A.classifyMode(false, "Player-1096-ABC") == "pvp")
    check("mode pve default", A.classifyMode(false, "Creature-0-1-1-1-448-X") == "pve"
        and A.classifyMode(false, nil) == "pve")
    check("flagLine with title", T.flagLine({ label = "Elite" }, { label = "Deadly" }, 5, 0,
        "the Widowmaker") == "Elite \"the Widowmaker\" - Deadly (killed you 5x)")
    check("flagLine title only lead", T.flagLine(nil, { label = "Deadly" }, 5, 0,
        "the Widowmaker") == "\"the Widowmaker\" - Deadly (killed you 5x)")

    -- ---- the Devil wager (pure state machine) ----
    local V = RUN.Devil
    check("wager tier giant slayer", V.tierForOdds(0.18) == "giantslayer")
    check("wager tier underdog", V.tierForOdds(0.40) == "underdog")
    check("wager refused above 50", V.tierForOdds(0.55) == nil and V.tierForOdds(nil) == nil)
    check("wager arm solo only", V.arm({ npc = 448, p = 0.2, solo = false }, 100) == nil)
    check("wager arm shape", (function()
        local a = V.arm({ npc = 448, name = "Hogger", p = 0.2, solo = true }, 100)
        return a and a.tier == "giantslayer" and a.npc == 448 and a.t == 100
    end)())
    check("wager won on solo kill", (function()
        local a = V.arm({ npc = 448, p = 0.2, solo = true }, 100)
        return V.resolve(a, { type = "kill", npc = 448, solo = true }, 150) == "won"
    end)())
    check("wager not won grouped", (function()
        local a = V.arm({ npc = 448, p = 0.2, solo = true }, 100)
        return V.resolve(a, { type = "kill", npc = 448, solo = false }, 150) == nil
    end)())
    check("wager lost to the beast", (function()
        local a = V.arm({ npc = 448, p = 0.2, solo = true }, 100)
        return V.resolve(a, { type = "death", npc = 448 }, 150) == "lost"
    end)())
    check("wager abandoned on other death", (function()
        local a = V.arm({ npc = 448, p = 0.2, solo = true }, 100)
        return V.resolve(a, { type = "death", npc = 999 }, 150) == "abandoned"
    end)())
    check("wager expires", (function()
        local a = V.arm({ npc = 448, p = 0.2, solo = true }, 100)
        return V.resolve(a, { type = "kill", npc = 448, solo = true }, 500) == "abandoned"
    end)())
    check("slay entry validation", V.validSlay({ when = 1, npc = 448, p = 0.2 }) == true
        and V.validSlay({ when = 1 }) == false and V.validSlay(nil) == false)

    -- ---- wipes (pure core) ----
    local WP = RUN.Wipes
    check("wipe at 80 percent", WP.isWipe({ 100, 101, 102, 103 }, 5, 105) == true)
    check("no wipe below 80", WP.isWipe({ 100, 101 }, 5, 105) == false)
    check("no wipe solo", WP.isWipe({ 100 }, 1, 100) == false)
    check("wipe window expires", WP.isWipe({ 10, 11, 12, 13 }, 5, 100) == false)
    check("wipe counts record", (function()
        local db = RUN.db()
        local saved = db.wipes
        db.wipes = nil
        WP.record(448); WP.record(448); WP.record("enc:Hogger")
        local a, b, t = WP.countFor(448), WP.countFor("enc:Hogger"), WP.total()
        db.wipes = saved
        return a == 2 and b == 1 and t == 3
    end)())

    -- ---- most wanted board ----
    check("most wanted merges + sorts", (function()
        local deaths = {
            { when = 1, killer = "Hogger", npc = 448 },
            { when = 2, killer = "Hogger", npc = 448 },
            { when = 3, killer = "Bruuz", npc = 3113 },
        }
        local heard = { [448] = 3, [9999] = 1 }
        local top = RUN.Window.mostWanted(deaths, heard, 5)
        return #top == 3 and top[1].npc == 448 and top[1].total == 5
            and top[1].tier == 3 and type(top[1].title) == "string"
            and top[3].name == "creature #9999"
    end)())

    -- ---- settings: defaults + validation ----
    local S = RUN.Settings
    check("settings default flags on", S.get("flags") == true)
    check("settings default expansiveStats off", S.get("expansiveStats") == false)
    check("settings default nearbyPing on", S.get("nearbyPing") == true)
    check("settings default pingNormal off", S.get("pingNormal") == false)
    check("settings default pingElite on", S.get("pingElite") == true)
    check("settings default pingUnique on", S.get("pingUnique") == true)
    check("settings default shareDeaths on", S.get("shareDeaths") == true)
    check("settings default minimapButton on", S.get("minimapButton") == true)
    check("settings default pingQuest on", S.get("pingQuest") == true)
    check("settings default heardAlerts on", S.get("heardAlerts") == true)
    check("settings default tierFrames on", S.get("tierFrames") == true)
    check("settings default riskButton on", S.get("riskButton") == true)
    check("settings default eulogy OFF", S.get("eulogy") == false)
    check("settings default lastWords on", S.get("lastWords") == true)
    check("settings defs cover all keys", (function()
        local covered = {}
        for _, def in ipairs(S.defs) do covered[def.key] = true end
        for k in pairs(S.defaults) do
            if not covered[k] then return false end
        end
        return true
    end)())
    check("settings unknown key nil", S.get("nope") == nil)
    check("settings set/get", (function()
        local before = S.get("autoMark")
        S.set("autoMark", false)
        local mid = S.get("autoMark")
        S.set("autoMark", before)
        return mid == false
    end)())
    check("settings type-validated", S.set("autoMark", "garbage") == false)

    -- ---- bridge: the Foresight probe is defensive (new GetCombatProfile contract) ----
    check("bridge foresight probe", RUN.Bridge.foresight() == nil or _G.ForesightAPI ~= nil)
    check("bridge profile nil-safe", RUN.Bridge.combatProfile() == nil or _G.ForesightAPI ~= nil)

    -- ---- version sync ----
    check("version set", type(RUN.version) == "string" and RUN.version:match("^%d+%.%d+%.%d+$") ~= nil)

    -- ---- package-registered checks (parallel-build law: packages add their
    -- own checks from their OWN files via RUN.selftestChecks) ----
    if type(RUN.selftestChecks) == "table" then
        for i = 1, #RUN.selftestChecks do
            local ok, err = pcall(RUN.selftestChecks[i], check)
            if not ok then
                table.insert(failures, "registered-check error: " .. tostring(err))
            end
        end
    end

    return pass, failures
end

return RUN.selftest
