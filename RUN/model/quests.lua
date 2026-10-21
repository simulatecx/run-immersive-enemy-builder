-- Quest targets: named enemies your quest log wants dead (the Bruuz case).
-- We read the player's own quest objectives ("Bruuz slain: 0/1") and match
-- unit names against them - so a quest-named mob flags on the tooltip and
-- pings as QUEST TARGET even though its classification is just "normal".
-- Pure matcher headless-tested; the quest-log reader is client-side.

local _, RUN = ...
if not RUN then RUN = _G.RunAdvisor or {}; _G.RunAdvisor = RUN end

local Quests = {}
RUN.Quests = Quests

local index = {}   -- { { text = lowered objective text, title = quest title } }

-- Pure: install the objective list (tests seed this directly). Where the text
-- matches the "X slain: n/m" shape we extract the EXACT mob name; otherwise we
-- keep the whole text for boundary-prefix fallback (other locales/formats).
function Quests.setTargets(list)
    index = {}
    if type(list) ~= "table" then return end
    for i = 1, #list do
        local e = list[i]
        if type(e) == "table" and type(e.text) == "string" and e.text ~= "" then
            local lowered = e.text:lower()
            local exact = lowered:match("^(.-)%s+slain:%s*%d+/%d+$")
            table.insert(index, {
                text = lowered,
                name = exact,                      -- nil when the shape is unfamiliar
                title = tostring(e.title or ""),
            })
        end
    end
end

function Quests.targetCount()
    return #index
end

-- Pure: is this unit name a quest target? EXACT name match when the objective
-- parsed cleanly ("Sunscale" must never match "Sunscale Screecher slain");
-- boundary-prefix fallback only for unparsed formats. Returns the title or nil.
function Quests.isTarget(name)
    if type(name) ~= "string" or name == "" then return nil end
    local lowered = name:lower()
    for i = 1, #index do
        local e = index[i]
        if e.name then
            if e.name == lowered then return e.title end
        elseif e.text:find(lowered, 1, true) == 1 then
            local nextChar = e.text:sub(#lowered + 1, #lowered + 1)
            if nextChar == "" or nextChar == " " or nextChar == ":" then
                return e.title
            end
        end
    end
    return nil
end

-- ---------------------------------------------------------------------------
-- Pure era-parse helpers. Classic Era (1.15.x) keeps the OLD quest-log shape:
-- global GetNumQuestLogEntries() plus GetQuestLogTitle(index) multi-returns
-- (title, level, suggestedGroup, isHeader, isCollapsed, isComplete,
-- frequency, questID). C_QuestLog.GetQuestObjectives(questID) DOES exist on
-- era; C_QuestLog.GetInfo does NOT. Detection is by API PRESENCE below,
-- never by version numbers. These helpers are pure so the headless gate
-- covers both quest-log paths identically.
-- ---------------------------------------------------------------------------

-- Pure: normalize one era GetQuestLogTitle row. Returns questID, title for a
-- real quest entry; nil for headers/garbage. isHeader tolerates true or 1
-- (older clients return 1/nil where newer return booleans).
function Quests.normalizeEraEntry(title, isHeader, questID)
    if type(title) ~= "string" or title == "" then return nil end
    if isHeader then return nil end
    if type(questID) ~= "number" or questID <= 0 then return nil end
    return questID, title
end

-- Pure: append every unfinished monster objective to out as { text, title }.
-- Shared by BOTH quest-log paths (modern C_QuestLog.GetInfo and the era
-- GetQuestLogTitle shape) so the matcher sees identical input either way.
function Quests.monsterObjectives(objectives, title, out)
    if type(objectives) ~= "table" or type(out) ~= "table" then return out end
    for _, o in ipairs(objectives) do
        if type(o) == "table" and o.type == "monster" and type(o.text) == "string"
           and not o.finished then
            table.insert(out, { text = o.text, title = title })
        end
    end
    return out
end

-- Selftest coverage for the era shim (parallel-build law: checks register
-- from the OWNING file via RUN.selftestChecks, never by editing selftest.lua).
RUN.selftestChecks = RUN.selftestChecks or {}
table.insert(RUN.selftestChecks, function(check)
    local qid, qtitle = Quests.normalizeEraEntry("Bruuz Must Die", false, 1234)
    check("era entry normalized", qid == 1234 and qtitle == "Bruuz Must Die")
    check("era entry header rejected", Quests.normalizeEraEntry("The Barrens", true, 777) == nil
        and Quests.normalizeEraEntry("The Barrens", 1, 777) == nil)
    check("era entry bad questID rejected", Quests.normalizeEraEntry("Q", false, 0) == nil
        and Quests.normalizeEraEntry("Q", false, "77") == nil
        and Quests.normalizeEraEntry(nil, false, 77) == nil)
    local out = Quests.monsterObjectives({
        { type = "monster", text = "Bruuz slain: 0/1", finished = false },
        { type = "item", text = "Chen's Empty Keg: 0/3", finished = false },
        { type = "monster", text = "Sunscale Screecher slain: 8/8", finished = true },
    }, "Bruuz Must Die", {})
    check("era objectives keep unfinished monsters only", #out == 1
        and out[1].text == "Bruuz slain: 0/1" and out[1].title == "Bruuz Must Die")
    check("era objectives nil-safe", Quests.monsterObjectives(nil, "t", {}) ~= nil
        and #Quests.monsterObjectives("junk", "t", {}) == 0)
    -- the matcher behaves identically when fed through the era collector
    Quests.setTargets(out)
    check("era path feeds matcher", Quests.isTarget("Bruuz") == "Bruuz Must Die"
        and Quests.isTarget("Sunscale Screecher") == nil)
    Quests.setTargets({})
    check("era check leaves matcher clean", Quests.targetCount() == 0)
end)

-- Everything below reads the client quest log. Two shapes, detected by API
-- presence: modern (Forever/mainline) C_QuestLog.GetInfo(index), or era
-- (Classic 1.15.x) GetQuestLogTitle(index). Both feed
-- C_QuestLog.GetQuestObjectives(questID), which exists on both clients.
if not _G.CreateFrame then return Quests end

local function rebuild()
    local CQ = _G.C_QuestLog
    if not (CQ and CQ.GetQuestObjectives) then return end
    local modern = CQ.GetNumQuestLogEntries and CQ.GetInfo
    local era = (not CQ.GetInfo) and type(_G.GetQuestLogTitle) == "function"
        and type(_G.GetNumQuestLogEntries) == "function"
    if not (modern or era) then return end
    local list = {}
    local ok = pcall(function()
        if modern then
            local n = CQ.GetNumQuestLogEntries()
            for i = 1, n do
                local info = CQ.GetInfo(i)
                if info and not info.isHeader and info.questID then
                    Quests.monsterObjectives(CQ.GetQuestObjectives(info.questID), info.title, list)
                end
            end
        else
            -- era: first return of global GetNumQuestLogEntries() counts log
            -- lines INCLUDING collapsed headers; normalizeEraEntry filters.
            local n = _G.GetNumQuestLogEntries()
            for i = 1, (tonumber(n) or 0) do
                local title, _, _, isHeader, _, _, _, questID = _G.GetQuestLogTitle(i)
                local id, qt = Quests.normalizeEraEntry(title, isHeader, questID)
                if id then
                    Quests.monsterObjectives(CQ.GetQuestObjectives(id), qt, list)
                end
            end
        end
    end)
    if ok then Quests.setTargets(list) end
end

-- Debounced rebuild: quest log updates come in bursts.
local pending = false
local function queueRebuild()
    if pending then return end
    pending = true
    if _G.C_Timer and _G.C_Timer.After then
        _G.C_Timer.After(1, function() pending = false; rebuild() end)
    else
        pending = false
        rebuild()
    end
end

RUN.on("PLAYER_LOGIN", queueRebuild)
RUN.on("QUEST_LOG_UPDATE", queueRebuild)
RUN.on("QUEST_ACCEPTED", queueRebuild)
RUN.on("QUEST_REMOVED", queueRebuild)

return Quests
