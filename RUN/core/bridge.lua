-- Optional Foresight bridge. RUN is fully standalone; when Foresight is
-- installed AND exposes ForesightAPI.GetCombatProfile (Foresight v0.55.0+),
-- RUN uses the real character survivability/offense from Foresight's model to
-- sharpen its odds - instead of reading the player's LIVE health, which Forever
-- hides as a secret value on PvP realms / restricted contexts (that was the
-- "advice degraded" case). Addon-to-addon, in-game only: nothing leaves the
-- client, no backend, no T&Cs/privacy impact. Everything here is defensive -
-- absent, old, or misbehaving Foresight degrades silently to RUN's own model.

local _, RUN = ...
if not RUN then RUN = _G.RunAdvisor or {}; _G.RunAdvisor = RUN end

local Bridge = {}
RUN.Bridge = Bridge

-- The ForesightAPI table iff present and exposing the profile call, else nil.
function Bridge.foresight()
    local F = _G.ForesightAPI
    if type(F) == "table" and type(F.GetCombatProfile) == "function" then return F end
    return nil
end

-- Pure: validate a combat profile (another addon's output is UNTRUSTED input -
-- shape-check before the odds model touches it). level must be a real number
-- >= 1; the optional numeric fields, when present, must be finite + non-negative.
function Bridge.validProfile(p)
    if type(p) ~= "table" then return nil end
    if type(p.level) ~= "number" or p.level ~= p.level or p.level < 1 then return nil end
    local keys = { "stamina", "attackPower", "spellPower", "armor", "maxHealth", "avoidancePct" }
    for i = 1, #keys do
        local v = p[keys[i]]
        if v ~= nil and (type(v) ~= "number" or v ~= v or v < 0) then return nil end
    end
    return p
end

-- Ask Foresight for the live character combat profile. Returns the validated
-- table or nil. Never throws into the caller.
function Bridge.combatProfile()
    local F = Bridge.foresight()
    if not F then return nil end
    local ok, p = pcall(F.GetCombatProfile)
    if not ok then return nil end
    return Bridge.validProfile(p)
end

-- Selftests (registered; the bridge must fail-closed on junk from the sibling).
if type(RUN.selftestChecks) == "table" then
    table.insert(RUN.selftestChecks, function(check)
        local good = { v = 1, level = 13, stamina = 120, attackPower = 90,
                       spellPower = 0, armor = 400, maxHealth = 537 }
        check("bridge validProfile accepts a good profile", Bridge.validProfile(good) == good)
        check("bridge validProfile rejects junk", (function()
            return Bridge.validProfile(nil) == nil
                and Bridge.validProfile("x") == nil
                and Bridge.validProfile({ level = 0 }) == nil
                and Bridge.validProfile({ level = 13, stamina = -1 }) == nil
                and Bridge.validProfile({ level = 13, attackPower = "a" }) == nil
        end)())
        check("bridge absent Foresight -> nil profile", (function()
            local saved = _G.ForesightAPI
            _G.ForesightAPI = nil
            local r = Bridge.combatProfile()
            _G.ForesightAPI = saved
            return r == nil and Bridge.foresight() == nil
        end)())
    end)
end

return Bridge
