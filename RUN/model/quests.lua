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

-- Everything below reads the client quest log.
if not _G.CreateFrame then return Quests end

local function rebuild()
    local CQ = _G.C_QuestLog
    if not (CQ and CQ.GetNumQuestLogEntries and CQ.GetInfo and CQ.GetQuestObjectives) then return end
    local list = {}
    local ok = pcall(function()
        local n = CQ.GetNumQuestLogEntries()
        for i = 1, n do
            local info = CQ.GetInfo(i)
            if info and not info.isHeader and info.questID then
                local objectives = CQ.GetQuestObjectives(info.questID)
                if type(objectives) == "table" then
                    for _, o in ipairs(objectives) do
                        if o and o.type == "monster" and type(o.text) == "string"
                           and not o.finished then
                            table.insert(list, { text = o.text, title = info.title })
                        end
                    end
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
