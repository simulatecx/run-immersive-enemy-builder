-- RUN bootstrap: shared namespace, SavedVariables init, event wiring, slash router.
-- House laws: display-and-advice only (never a protected action), Lua 5.1 dialect,
-- never networks, every possibly-secret read through core/guards.lua.

local ADDON, RUN = ...
if not RUN then RUN = _G.RunAdvisor or {}; end
_G.RunAdvisor = RUN

RUN.version = "0.3.0"

-- ---------------------------------------------------------------------------
-- SavedVariables: RUNDB. User-editable data - type-validate everything on load;
-- anything tampered or missing falls back to defaults (untrusted-input law).
-- ---------------------------------------------------------------------------
function RUN.initSavedVariables()
    if type(_G.RUNDB) ~= "table" then _G.RUNDB = {} end
    local db = _G.RUNDB
    db.version = RUN.version
    if type(db.deaths) ~= "table" then db.deaths = {} end
    if type(db.settings) ~= "table" then db.settings = {} end
    -- deaths entries are re-validated at read time by model/attribution.lua
    return db
end

function RUN.db()
    if type(_G.RUNDB) ~= "table" then return RUN.initSavedVariables() end
    return _G.RUNDB
end

-- ---------------------------------------------------------------------------
-- Chat output (one voice).
-- ---------------------------------------------------------------------------
local PREFIX = "|cff8dffc4RUN|r "
function RUN.print(msg)
    local f = _G.DEFAULT_CHAT_FRAME
    if f and f.AddMessage then f:AddMessage(PREFIX .. tostring(msg)) end
end

-- Everything below wires the client; headless harness stops here.
if not _G.CreateFrame then return end

-- ---------------------------------------------------------------------------
-- Event hub. Modules register handlers at load; the hub dispatches.
-- ---------------------------------------------------------------------------
local hub = CreateFrame("Frame", "RUNEventHub")
RUN.eventHandlers = RUN.eventHandlers or {}

function RUN.on(event, handler)
    RUN.eventHandlers[event] = RUN.eventHandlers[event] or {}
    table.insert(RUN.eventHandlers[event], handler)
    hub:RegisterEvent(event)
end

hub:SetScript("OnEvent", function(_, event, ...)
    local handlers = RUN.eventHandlers[event]
    if not handlers then return end
    for i = 1, #handlers do
        local ok, err = pcall(handlers[i], ...)
        if not ok and RUN.debug then RUN.print("handler error (" .. event .. "): " .. tostring(err)) end
    end
end)

RUN.on("ADDON_LOADED", function(name)
    if name == ADDON then RUN.initSavedVariables() end
end)

RUN.on("PLAYER_LOGIN", function()
    RUN.initSavedVariables()
    RUN.print("v" .. RUN.version .. " beta - fully automatic: mouse over an enemy to see its flag and kill rank. "
        .. "/ra is only for options (try /ra set expansiveStats on). Advice only; it never acts for you.")
end)

-- ---------------------------------------------------------------------------
-- Slash router. NOTE: /run itself is Blizzard's built-in script command and can
-- never be taken by an addon - hence /runadvisor with short aliases.
-- ---------------------------------------------------------------------------
_G.SLASH_RUNADVISOR1 = "/runadvisor"
_G.SLASH_RUNADVISOR2 = "/runa"
_G.SLASH_RUNADVISOR3 = "/ra"

_G.SlashCmdList = _G.SlashCmdList or {}
_G.SlashCmdList["RUNADVISOR"] = function(input)
    input = tostring(input or "")
    local cmd, rest = input:match("^%s*(%S*)%s*(.-)%s*$")
    cmd = (cmd or ""):lower()

    if cmd == "" or cmd == "panel" then
        if RUN.Panel then RUN.Panel.toggle() end
    elseif cmd == "odds" then
        if RUN.Panel then RUN.Panel.printOdds() end
    elseif cmd == "mark" then
        if RUN.Waypoint then RUN.Waypoint.markHere("RUN mark") end
    elseif cmd == "clear" then
        if RUN.Waypoint then RUN.Waypoint.clear() end
    elseif cmd == "deaths" then
        if RUN.Attribution then RUN.Attribution.printDeaths() end
    elseif cmd == "set" then
        if RUN.Settings then RUN.Settings.slashSet(rest) end
    elseif cmd == "selftest" then
        local pass, failures = RUN.selftest()
        if #failures == 0 then
            RUN.print("selftest: " .. pass .. "/" .. pass .. " green")
        else
            RUN.print("selftest: " .. pass .. " passed, " .. #failures .. " FAILED:")
            for _, f in ipairs(failures) do RUN.print("  - " .. f) end
        end
    elseif cmd == "status" then
        local s = RUN.Settings and RUN.Settings.all() or {}
        RUN.print("v" .. RUN.version .. " | flags=" .. tostring(s.flags)
            .. " expansiveStats=" .. tostring(s.expansiveStats)
            .. " autoMark=" .. tostring(s.autoMark) .. " recordDeaths=" .. tostring(s.recordDeaths))
        RUN.print("Foresight bridge: " .. ((RUN.Bridge and RUN.Bridge.foresight()) and "connected" or "not present (coarse model)"))
    else
        RUN.print("RUN is automatic - these are just options: /ra set <flags|expansiveStats|autoMark|recordDeaths> <on/off>")
        RUN.print("utilities: /ra (toggle Expansive Enemy Stats) | odds | mark | clear | deaths | status | selftest")
    end
end
