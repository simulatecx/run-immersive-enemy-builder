-- RUN bootstrap: shared namespace, SavedVariables init, event wiring, slash router.
-- House laws: display-and-advice only (never a protected action), Lua 5.1 dialect,
-- never networks, every possibly-secret read through core/guards.lua.

local ADDON, RUN = ...
if not RUN then RUN = _G.RunAdvisor or {}; end
_G.RunAdvisor = RUN

RUN.version = "0.8.0"

-- THE one season constant (WP-G / RUN-G). Every crowd payload stamps this tag;
-- rollups and ladders key by it, so flipping it is the whole in-addon "reset" -
-- old-season data is never touched. Tag shape is schema-locked: lowercase
-- [a-z0-9], max 8 ("s0", "s1", ...; a Classic-fork season would take its own
-- prefix, e.g. "c1"). FLIP PROCEDURE (owner-gated; full runbook docs/SEASONS.md):
--   1) python pipeline/season_archive.py --dry-run           (count what moves)
--   2) python pipeline/season_archive.py --archive --season s0 --next s1 --yes
--      (backup -> copy to seasonArchive/ -> read-back; deletes NOTHING)
--   3) bump THIS constant to the new tag
--   4) redeploy the web ladders' default-season to match
RUN.season = "s0"

-- Parallel-build law: packages integrate through registries, never by editing
-- another package's files. New slash subcommands register in RUN.commands;
-- new selftest checks register in RUN.selftestChecks (run by selftest.lua).
RUN.commands = RUN.commands or {}
RUN.selftestChecks = RUN.selftestChecks or {}

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
    if type(db.ui) ~= "table" then db.ui = {} end
    if type(db.heardLog) ~= "table" then db.heardLog = {} end
    if type(db.heardStrict) ~= "table" then db.heardStrict = {} end
    if type(db.slays) ~= "table" then db.slays = {} end
    if type(db.wipes) ~= "table" then db.wipes = {} end
    if type(db.sightings) ~= "table" then db.sightings = {} end
    if type(db.guildWipes) ~= "table" then db.guildWipes = {} end
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

    if cmd == "" then
        if RUN.Panel then RUN.Panel.toggle() end
    elseif cmd == "panel" then
        if RUN.Panel then RUN.Panel.test() end
    elseif cmd == "odds" then
        if RUN.Panel then RUN.Panel.printOdds() end
    elseif cmd == "mark" then
        if RUN.Waypoint then RUN.Waypoint.markHere("RUN mark") end
    elseif cmd == "clear" then
        if RUN.Waypoint then RUN.Waypoint.clear() end
    elseif cmd == "deaths" then
        if RUN.Attribution then RUN.Attribution.printDeaths() end
    elseif cmd == "log" or cmd == "stats" or cmd == "options" then
        if RUN.Window then RUN.Window.toggle() end
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
        local st = RUN.Attribution and RUN.Attribution.stats
        if st then
            RUN.print(string.format(
                "attribution: %d combat-log events (%d damage to you, %d secret), fallback used %dx%s",
                st.cleu, st.mine, st.secret, st.fallbackUsed,
                st.lastErr and (" | last error: " .. st.lastErr) or ""))
        end
        if RUN.Panel and RUN.Panel.lastErr then
            RUN.print("panel last error: " .. RUN.Panel.lastErr)
        end
        if RUN.Quests then
            RUN.print("quest targets tracked: " .. RUN.Quests.targetCount())
        end
        if RUN.Deathping and RUN.Deathping.channelJoined then
            RUN.print("death-ping channel: "
                .. (RUN.Deathping.channelJoined() and "joined (rundeathping)" or "not joined yet"))
        end
    elseif RUN.commands and type(RUN.commands[cmd]) == "function" then
        local ok, err = pcall(RUN.commands[cmd], rest)
        if not ok then RUN.print("command error: " .. tostring(err)) end
    else
        RUN.print("RUN is automatic - the minimap button (or /ra log) opens the Account Ledger & options.")
        RUN.print("utilities: /ra (toggle Expansive Enemy Stats) | log | panel | odds | mark | clear | deaths | set <key> <on/off> | status | diag | selftest")
    end
end

-- ---------------------------------------------------------------------------
-- /ra diag: the one-shot field readout - every verification hook in one go.
-- ---------------------------------------------------------------------------
RUN.commands["diag"] = function()
    local nCommands = 0
    for _ in pairs(RUN.commands or {}) do nCommands = nCommands + 1 end
    local nChecks = type(RUN.selftestChecks) == "table" and #RUN.selftestChecks or 0
    RUN.print("diag: v" .. RUN.version .. " | registries: " .. nCommands
        .. " commands, " .. nChecks .. " package selftest checks")

    local hookMode = "none (flags cannot inject)"
    if _G.TooltipDataProcessor and _G.Enum and _G.Enum.TooltipDataType then
        hookMode = "TooltipDataProcessor"
    elseif _G.GameTooltip and _G.GameTooltip.HookScript then
        hookMode = "HookScript fallback"
    end
    local S = _G.Settings
    local escPanel = (S and S.RegisterVerticalLayoutCategory and S.RegisterProxySetting
        and S.CreateCheckbox and S.RegisterAddOnCategory)
        and "API present (registered at login)"
        or "API absent (the Ledger is the options surface)"
    RUN.print("panel last error: "
        .. ((RUN.Panel and RUN.Panel.lastErr) and RUN.Panel.lastErr or "none")
        .. " | tooltip hook: " .. hookMode)
    RUN.print("ESC options: " .. escPanel)

    local joined = RUN.Deathping and RUN.Deathping.channelJoined
        and RUN.Deathping.channelJoined() or false
    local log, size, corro = RUN.db().heardLog, 0, 0
    if type(log) == "table" then
        size = #log
        for i = 1, #log do
            local e = log[i]
            if type(e) == "table" and e.corro then corro = corro + 1 end
        end
    end
    local np = RUN.Guards.call(_G.GetCVar, "nameplateShowEnemies")
    RUN.print("death-ping channel: " .. (joined and "joined (rundeathping)" or "not joined")
        .. " | heard log: " .. size .. " entries (" .. corro .. " corroborated)")
    RUN.print("enemy nameplates CVar: " .. tostring(np)
        .. ((np == "0") and " - RUN senses enemies through nameplates; enable them (key V)" or ""))
end
