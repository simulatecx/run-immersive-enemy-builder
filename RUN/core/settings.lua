-- RUN settings: one spine, type-validated on every read (RUNDB is user-editable).
-- The addon is PASSIVE by design - everything below influences automatic
-- behaviour (mouseover flags, tooltips, marks); /ra set is just the lever.

local _, RUN = ...
if not RUN then RUN = _G.RunAdvisor or {}; _G.RunAdvisor = RUN end

local Settings = {}
RUN.Settings = Settings

Settings.defaults = {
    flags = true,            -- mouseover/target tooltip flags: Elite / Rare / Boss + kill rank
    expansiveStats = false,  -- Expansive Enemy Stats: your win-chance on the tooltip + the odds panel
    autoMark = true,         -- drop a map waypoint at your feet when a rare appears
    minimapPins = true,      -- tier-coloured minimap blip where a rare/elite was seen
    recordDeaths = true,     -- local journal of what killed you (never leaves your machine)
    nearbyPing = true,       -- master switch for all nearby pings
    quietInstances = true,   -- mute RUN's pop-up notifications in dungeons/raids (data still tracked)
    pingNormal = false,      -- nearby ping for normal mobs (off: too chatty; on = total awareness)
    pingElite = true,        -- nearby ping for elites (gold dragon)
    pingUnique = true,       -- nearby ping for rares, rare elites and bosses
    pingQuest = true,        -- nearby ping for named QUEST targets (Bruuz etc.), any classification
    questPlates = true,      -- gold QUEST TARGET tag on a quest-named mob's nameplate
    shareDeaths = true,      -- in-game anonymous death-ping to other RUN users (no name; opt-out)
    minimapButton = true,    -- the minimap button (opens the Account Ledger / options)
    heardAlerts = true,      -- banner when a notable creature claims another victim nearby
    strictTrust = false,     -- publicly-shown heard counts use only corroborated pings (2+ witnesses)
    eulogy = true,           -- show the fallen's CHARACTER name on heard deaths - the Hardcore
                             -- "who died to what" (display-only; the name already rides the
                             -- addon-message transport regardless; never realm/account/guild)
    lastWords = true,        -- your final public chat line rides your death-ping (Hardcore classic)
    deathFeed = true,        -- the scrolling feed of deaths heard over the channel (Hardcore-style)
    feedLocked = true,       -- lock the death feed in place; unlock (/ra move) to drag it
    tierFrames = true,       -- tier-styled unit frame for titled enemies (the Nemesis frame)
    tierGlow = true,         -- the tier-escalating rank effect for your target (ember -> blood)
    glowLocked = true,       -- lock the rank glow in place; unlock (/ra glow or /ra move) to drag it
    panelLocked = true,      -- lock the odds/FIGHT panel in place; unlock (/ra move) to drag it
    markNormal = true,       -- draw the overlay on NORMAL-classification enemies (deaths tracked regardless)
    riskButton = true,       -- the RISK IT wager button on the odds frame (solo, <50% odds)
}

-- One ordered list drives every options surface (Ledger checkboxes + the ESC
-- settings panel). Labels are plain sentences; keys match defaults above.
Settings.defs = {
    { key = "flags",          label = "Tooltip flags + kill ranks" },
    { key = "expansiveStats", label = "Expansive Enemy Stats" },
    { key = "nearbyPing",     label = "Nearby pings (master)" },
    { key = "quietInstances", label = "Quiet in dungeons & raids" },
    { key = "pingQuest",      label = "Ping quest targets" },
    { key = "questPlates",    label = "Quest flag on nameplates" },
    { key = "pingUnique",     label = "Ping rares and bosses" },
    { key = "pingElite",      label = "Ping elites" },
    { key = "pingNormal",     label = "Ping normal enemies" },
    { key = "autoMark",       label = "Auto map-mark rares" },
    { key = "minimapPins",    label = "Minimap blips for rares/elites" },
    { key = "recordDeaths",   label = "Record my deaths" },
    { key = "shareDeaths",    label = "Share anonymous death-pings" },
    { key = "heardAlerts",    label = "Banner notable heard deaths" },
    { key = "strictTrust",    label = "Strict trust (corroborated only)" },
    { key = "eulogy",         label = "Name the fallen (eulogy mode)" },
    { key = "lastWords",      label = "Broadcast my last words" },
    { key = "deathFeed",      label = "Death feed (deaths heard)" },
    { key = "feedLocked",     label = "Lock death feed position" },
    { key = "tierFrames",     label = "Tier frames for titled enemies" },
    { key = "tierGlow",       label = "Rank glow (notoriety effect)" },
    { key = "glowLocked",     label = "Lock rank glow position" },
    { key = "panelLocked",    label = "Lock odds panel position" },
    { key = "markNormal",     label = "Mark normal enemies" },
    { key = "riskButton",     label = "RISK IT wager button" },
    { key = "minimapButton",  label = "Minimap button" },
}

local function store()
    local db = RUN.db()
    if type(db.settings) ~= "table" then db.settings = {} end
    return db.settings
end

-- Type-validated read: anything missing or of the wrong type falls back to default.
function Settings.get(key)
    local def = Settings.defaults[key]
    if def == nil then return nil end
    local v = store()[key]
    if type(v) ~= type(def) then return def end
    return v
end

function Settings.set(key, value)
    if Settings.defaults[key] == nil then return false end
    if type(value) ~= type(Settings.defaults[key]) then return false end
    store()[key] = value
    return true
end

function Settings.all()
    local out = {}
    for k in pairs(Settings.defaults) do out[k] = Settings.get(k) end
    return out
end

-- "/ra set expansiveStats on"
function Settings.slashSet(rest)
    local key, val = tostring(rest or ""):match("^(%S+)%s+(%S+)$")
    if not key or Settings.defaults[key] == nil then
        local keys = {}
        for k in pairs(Settings.defaults) do table.insert(keys, k) end
        table.sort(keys)
        RUN.print("set <key> <on/off>; keys: " .. table.concat(keys, ", "))
        return
    end
    local on = (val == "on" or val == "true" or val == "1")
    Settings.set(key, on)
    RUN.print(key .. " = " .. (on and "on" or "off"))
    if RUN.Panel and RUN.Panel.refresh then RUN.Panel.refresh() end
end

return Settings
