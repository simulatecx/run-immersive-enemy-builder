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
    recordDeaths = true,     -- local journal of what killed you (never leaves your machine)
    nearbyPing = true,       -- banner + sound when a rare is sensed near you
    shareDeaths = true,      -- in-game anonymous death-ping to other RUN users (no name; opt-out)
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
