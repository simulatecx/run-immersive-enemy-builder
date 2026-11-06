"""Client-path smoke harness - the coverage the pure-logic gate can't give.

run_tests.py loads every file with _G.CreateFrame UNDEFINED, so all client
code returns early at `if not _G.CreateFrame then return end` - frames, event
handlers, hooks, and tickers never execute. The Forever launch crash lived in
exactly that blind spot: one RUN Lua error the headless gate could never see.

This harness mocks enough of the WoW client API to LOAD the client paths and
DRIVE them - file load-time setup, the lifecycle events (login, entering
world, nameplates, target change, combat log), the registered tickers, and
the tooltip hook. Any error surfaces with the file it came from, reproducing
what /ra diag would show in game. Gates BOTH flavors.

Usage: python client_smoke.py
"""

from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).parent.parent
ADDON_DIR = ROOT / "RUN"
TOCS = [ADDON_DIR / "RUN.toc", ADDON_DIR / "RUN_Vanilla.toc"]


def toc_files(toc: Path) -> list[Path]:
    files = []
    for line in toc.read_text(encoding="utf-8-sig").splitlines():
        line = line.strip()
        if not line or line.startswith("##"):
            continue
        files.append(ADDON_DIR / line.replace("\\", "/"))
    return files


# The mock WoW client. Realistic returns for the APIs RUN depends on; a
# chainable mock frame for widget methods. Deliberately NOT all-permissive on
# globals: an unguarded call to an undefined API surfaces as a real error
# (that is the class of launch-day bug we are hunting).
MOCK = r"""
local _G = _G

-- A faithful "secret value" (Forever 12.x): on the live client, touching a
-- secret with comparison / arithmetic / concatenation ERRORS - the exact
-- failure the headless gate and Classic Era never see. issecretvalue detects
-- it via rawequal (no metamethod), mirroring the client. Any RUN code that
-- compares or concatenates a secret field WITHOUT going through core/guards
-- reproduces the launch error here.
local SECRET = setmetatable({}, {
    __eq = function() error("attempt to compare a secret value", 2) end,
    __lt = function() error("attempt to compare a secret value", 2) end,
    __le = function() error("attempt to compare a secret value", 2) end,
    __concat = function() error("attempt to concatenate a secret value", 2) end,
    __add = function() error("attempt to perform arithmetic on a secret value", 2) end,
    __sub = function() error("attempt to perform arithmetic on a secret value", 2) end,
})
_G.__SECRET = SECRET
_G.issecretvalue = function(v) return rawequal(v, SECRET) end
_G.__secretsOn = false   -- flipped by the harness for the "restricted" pass

-- A widget mock: real SetScript/RegisterEvent storage (so events + OnUpdate
-- can be driven), everything else chainable so no widget call errors.
local function newFrame(name)
    local f = { __scripts = {}, __events = {}, __name = name }
    function f:SetScript(e, fn) self.__scripts[e] = fn end
    function f:GetScript(e) return self.__scripts[e] end
    function f:HookScript(e, fn)
        local prev = self.__scripts[e]
        self.__scripts[e] = function(...)
            if prev then prev(...) end
            fn(...)
        end
    end
    function f:RegisterEvent(ev) self.__events[ev] = true end
    function f:RegisterUnitEvent(ev) self.__events[ev] = true end
    function f:UnregisterEvent(ev) self.__events[ev] = nil end
    function f:UnregisterAllEvents() self.__events = {} end
    function f:IsShown() return true end
    function f:IsVisible() return true end
    function f:IsEnabled() return true end
    function f:GetName() return self.__name end
    -- measurement methods return NUMBERS (the real client does): a chainable
    -- table here would mask real bugs AND fake ones, so pin the types.
    function f:GetStringWidth() return 50 end
    function f:GetStringHeight() return 12 end
    function f:GetWidth() return 120 end
    function f:GetHeight() return 20 end
    function f:GetFrameLevel() return 1 end
    function f:GetScale() return 1 end
    function f:GetEffectiveScale() return 1 end
    function f:GetTop() return 400 end
    function f:GetBottom() return 380 end
    function f:GetLeft() return 100 end
    function f:GetRight() return 220 end
    function f:GetCenter() return 160, 390 end
    function f:GetNumPoints() return 0 end
    setmetatable(f, { __index = function(t, k)
        -- unknown widget method: chainable no-op returning the frame
        return function(...) return t end
    end })
    if name then _G[name] = f end
    return f
end

_G.CreateFrame = function(ftype, name, parent, template) return newFrame(name) end

-- Core UI globals RUN anchors to.
_G.UIParent = newFrame("UIParent")
_G.WorldFrame = newFrame("WorldFrame")
_G.Minimap = newFrame("Minimap")
_G.GameTooltip = newFrame("GameTooltip")
_G.TargetFrame = newFrame("TargetFrame")
_G.UISpecialFrames = {}

-- Clock / scheduler.
_G.GetTime = function() return 1000.0 end
_G.time = function() return 1762300000 end
_G.date = function(fmt) return "2026-11-04 19:00:00" end
local timers = {}
_G.C_Timer = {
    After = function(delay, fn) timers[#timers + 1] = fn end,
    __flush = function() for i = 1, #timers do pcall(timers[i]) end; timers = {} end,
}

-- Unit API - a live hostile elite target (the common path).
_G.UnitExists = function(u) return u == "target" or u == "mouseover" or u == "player" end
_G.UnitName = function(u) if u == "player" then return "Wookie" end return "Sunscale Screecher" end
_G.UnitCanAttack = function(a, b) return true end
_G.UnitIsDead = function(u) return false end
_G.UnitIsPlayer = function(u) return false end
_G.UnitLevel = function(u) return 15 end
_G.UnitClassification = function(u) return "elite" end
_G.UnitGUID = function(u)
    if u == "player" then return "Player-4830-00ABCDEF" end
    return "Creature-0-4830-0-11-7024-0000ABCDEF"
end
_G.UnitHealth = function(u) if _G.__secretsOn then return SECRET end return 150 end
_G.UnitHealthMax = function(u) if _G.__secretsOn then return SECRET end return 200 end
_G.UnitClass = function(u) return "Warrior", "WARRIOR" end

-- Group / guild / zone.
_G.IsInGroup = function() return false end
_G.IsInRaid = function() return false end
_G.IsInGuild = function() return false end
_G.GetNumGroupMembers = function() return 0 end
_G.GetGuildInfo = function(u) return nil end
_G.GetZoneText = function() return "Durotar" end
_G.GetRealZoneText = function() return "Durotar" end

-- Combat log: a SWING_DAMAGE to the player (positional, as RUN indexes it).
-- Under restricted contexts the amount + destGUID come back secret, as on the
-- live client, so an unguarded touch of either reproduces the launch error.
_G.CombatLogGetCurrentEventInfo = function()
    local amount = _G.__secretsOn and SECRET or 42
    local destGUID = _G.__secretsOn and SECRET or "Player-4830-00ABCDEF"
    return 1762300000.0, "SWING_DAMAGE",
        false,
        "Creature-0-4830-0-11-7024-0000ABCDEF", "Sunscale Screecher", 0x10a48, 0,
        destGUID, "Wookie", 0x511, 0,
        amount, 0, 1, 0, nil, nil, false, false, false
end

-- Nameplates.
local plate = newFrame("NamePlate1")
plate.namePlateUnitToken = "nameplate1"
_G.C_NamePlate = {
    GetNamePlates = function() return { plate } end,
    GetNamePlateForUnit = function(u) return plate end,
}

-- Map / tracking / vignettes (presence-detected by RUN).
_G.C_Map = {
    GetBestMapForUnit = function(u) return 1413 end,
    SetUserWaypoint = function(p) end,
    CanSetUserWaypointOnMap = function(m) return true end,
    GetUserWaypoint = function() return nil end,
}
_G.UiMapPoint = { CreateFromCoordinates = function(m, x, y) return {} end }
_G.C_SuperTrack = { SetSuperTrackedUserWaypoint = function(b) end }
_G.C_VignetteInfo = nil
_G.C_GameRules = { IsHardcoreActive = function() return false end }
_G.C_Secrets = { ShouldUnitHealthMaxBeSecret = function(u) return _G.__secretsOn end }

-- Chat / channels (death-ping transport).
_G.GetChannelName = function(n) return 0 end
_G.JoinTemporaryChannel = function(n) return end
_G.C_ChatInfo = {
    RegisterAddonMessagePrefix = function(p) return true end,
    SendAddonMessage = function(...) return true end,
}
_G.GetCursorPosition = function() return 0, 0 end
_G.GetCVar = function(k) return "1" end
_G.SetCVar = function(k, v) end
_G.PlaySound = function(id) end
_G.SOUNDKIT = { RAID_WARNING = 8959 }

-- Quest log (modern path present -> Forever side).
_G.C_QuestLog = {
    GetNumQuestLogEntries = function() return 1 end,
    GetInfo = function(i) return { isHeader = false, questID = 50, title = "Raptor Thieves" } end,
    GetQuestObjectives = function(qid)
        return { { type = "monster", text = "Sunscale Screecher slain: 0/12", finished = false } }
    end,
}

-- Modern Settings + tooltip pipeline (presence-detected).
_G.Settings = nil   -- absent -> RUN falls back to the Ledger surface (era-safe path)
local ttCallbacks = {}
_G.Enum = { TooltipDataType = { Unit = 2 } }
_G.TooltipDataProcessor = {
    AddTooltipPostCall = function(kind, fn) ttCallbacks[#ttCallbacks + 1] = fn end,
    __fire = function()
        local tt = _G.GameTooltip
        tt.GetUnit = function(self) return "Sunscale Screecher", "target" end
        for i = 1, #ttCallbacks do ttCallbacks[i](tt) end
    end,
}
_G.BackdropTemplateMixin = {}
_G.TomTom = nil
"""


def gate_toc(toc: Path):
    """Load one TOC's files with the client mock ACTIVE, then drive the
    lifecycle. Returns an error list (empty = green)."""
    from lupa import LuaRuntime

    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.execute(MOCK)
    loader = lua.eval(
        "function(code, name)\n"
        "  local f, err = (load or loadstring)(code, name)\n"
        "  if not f then error(name .. ': ' .. tostring(err)) end\n"
        "  return f\n"
        "end"
    )
    shared = lua.table()
    lua.globals().RUNDB = lua.table()
    errors: list[str] = []

    # Phase 1 - LOAD every file with the client paths live.
    for path in toc_files(toc):
        try:
            chunk = loader(path.read_text(encoding="utf-8"), "@" + path.name)
            chunk("RUN", shared)
        except Exception as err:
            errors.append(f"LOAD {path.name}: {err}")
            return errors  # a load error cascades; stop and report it

    # Phase 2 - drive the lifecycle + tickers + tooltip, collect swallowed
    # errors from the firewall ring AND any that escape the direct calls.
    driver = lua.eval(r"""
function(RUN)
    local fired = {}
    local function fire(event, ...)
        local hs = RUN.eventHandlers and RUN.eventHandlers[event]
        if not hs then return end
        for i = 1, #hs do
            local ok, err = pcall(hs[i], ...)
            if not ok then fired[#fired + 1] = event .. ": " .. tostring(err) end
        end
    end
    local function drive(label)
        fire("ADDON_LOADED", "RUN")
        fire("PLAYER_LOGIN")
        fire("PLAYER_ENTERING_WORLD")
        if _G.C_Timer and _G.C_Timer.__flush then _G.C_Timer.__flush() end
        fire("QUEST_LOG_UPDATE")
        fire("QUEST_ACCEPTED", 50)
        fire("NAME_PLATE_UNIT_ADDED", "nameplate1")
        fire("PLAYER_TARGET_CHANGED")
        fire("UPDATE_MOUSEOVER_UNIT")
        fire("UNIT_HEALTH", "target")
        fire("UNIT_COMBAT", "player", "WOUND", 0, 10, 0)
        fire("COMBAT_LOG_EVENT_UNFILTERED")
        -- a received death-ping over the addon channel (strict-decoded path)
        fire("CHAT_MSG_ADDON", "RUN1", "RDP1:7024:1413:10:" ..
            tostring(RUN.Deathping.fletcher16("7024:1413:10")), "CHANNEL", "Someone")
        fire("CHAT_MSG_SAY", "for the Horde", "Wookie")
        fire("NAME_PLATE_UNIT_REMOVED", "nameplate1")
        fire("PLAYER_DEAD")
        -- every registered ticker (glow, plates, alert-hide, nearby-prune),
        -- each run twice so the throttle + repeat path both execute
        if RUN.Safety and RUN.Safety.jobs then
            for _, j in ipairs(RUN.Safety.jobs()) do
                local ok, err = pcall(j.fn)
                if not ok then fired[#fired + 1] = label .. " ticker " .. tostring(j.name)
                    .. ": " .. tostring(err) end
            end
        end
        if _G.TooltipDataProcessor and _G.TooltipDataProcessor.__fire then
            local ok, err = pcall(_G.TooltipDataProcessor.__fire)
            if not ok then fired[#fired + 1] = label .. " tooltip: " .. tostring(err) end
        end
    end

    -- Seed the EXACT on-screen state from the launch-crash screenshots:
    -- Expansive Enemy Stats ON, targeting a NOTORIOUS mob (npc 7024 with a
    -- high crowd count -> a real tier), so the odds panel, the tier frame,
    -- and the target glow all draw their full path (not the tier-0 short-cut).
    local db = RUN.db()
    db.settings = db.settings or {}
    db.settings.expansiveStats = true
    db.settings.tierGlow = true
    db.settings.tierFrames = true
    RUN.gen = RUN.gen or {}
    RUN.gen.crowdCounts = RUN.gen.crowdCounts or {}
    RUN.gen.crowdCounts[7024] = { total = 25 }   -- tier ~6, "Infamous"-class

    -- Pass 1: open world (no secrets). Pass 2: RESTRICTED context - unit
    -- health + combat-log amounts come back secret, the channel is joined,
    -- exactly the live-Forever shape the beta/headless never produced.
    _G.__secretsOn = false
    drive("open")
    _G.__secretsOn = true
    _G.GetChannelName = function(n) return 5 end
    drive("restricted")

    -- Build-coverage sweep: walk the target through every rank band so EVERY
    -- glow effect builder constructs (its textures + animations) and the
    -- effect-switching logic (clear old, play new) runs across all of them.
    _G.__secretsOn = false
    if RUN.gen and RUN.gen.crowdCounts then
        local totals = { 1, 5, 15, 40, 60, 80, 100 }   -- tiers 1,3,5,7,8,9,10
        for _, tot in ipairs(totals) do
            RUN.gen.crowdCounts[7024] = { total = tot }
            local ok, err = pcall(function() fire("PLAYER_TARGET_CHANGED") end)
            if not ok then fired[#fired + 1] = "glow band " .. tot .. ": " .. tostring(err) end
        end
    end

    -- Glow option branches: the normal-enemy mark gate + the unlocked
    -- positioning/drag path (owner asks 2026-11-05).
    local db = RUN.db()
    db.settings.markNormal = false
    _G.UnitClassification = function(u) return "normal" end
    local ok1, e1 = pcall(function() fire("PLAYER_TARGET_CHANGED") end)   -- should suppress
    if not ok1 then fired[#fired + 1] = "glow normal-gate: " .. tostring(e1) end
    db.settings.glowLocked = false
    local ok2, e2 = pcall(function() fire("PLAYER_TARGET_CHANGED") end)   -- unlocked placeholder
    if not ok2 then fired[#fired + 1] = "glow unlocked: " .. tostring(e2) end
    if RUN.Glow and RUN.commands and RUN.commands["glow"] then
        local ok3, e3 = pcall(RUN.commands["glow"])                        -- /ra glow toggle
        if not ok3 then fired[#fired + 1] = "glow cmd: " .. tostring(e3) end
    end
    _G.UnitClassification = function(u) return "elite" end
    db.settings.glowLocked = true
    db.settings.markNormal = true

    local swallowed = {}
    if RUN.Safety and RUN.Safety.recent then
        for _, e in ipairs(RUN.Safety.recent()) do
            swallowed[#swallowed + 1] = e.where .. ": " .. e.err
        end
    end
    return fired, swallowed
end
""")
    fired, swallowed = driver(shared)
    for e in (list(fired.values()) if fired is not None else []):
        errors.append(f"EVENT/TICKER {e}")
    for e in (list(swallowed.values()) if swallowed is not None else []):
        errors.append(f"FIREWALL-SWALLOWED {e}")
    return errors


def main() -> int:
    try:
        from lupa import LuaRuntime  # noqa: F401
    except ImportError:
        print("SMOKE RED: lupa not installed (pip install lupa)")
        return 1

    any_red = False
    for toc in TOCS:
        if not toc.exists():
            print(f"SMOKE RED: {toc.name} missing")
            return 1
        errors = gate_toc(toc)
        if errors:
            any_red = True
            print(f"SMOKE RED [{toc.name}]: {len(errors)} client-path error(s):")
            for e in errors:
                print("  - " + e)
        else:
            print(f"client smoke green [{toc.name}]: load + lifecycle + tickers + tooltip clean")
    return 1 if any_red else 0


if __name__ == "__main__":
    sys.exit(main())
