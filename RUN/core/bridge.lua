-- Optional Foresight bridge. RUN is fully standalone; when Foresight is installed
-- AND exposes ForesightAPI.GetDangerVerdict (a future Foresight release), RUN uses
-- its real survivability/EHP/TTK model instead of the coarse heuristic. Everything
-- here is defensive: absent, old, or misbehaving Foresight degrades silently.

local _, RUN = ...
if not RUN then RUN = _G.RunAdvisor or {}; _G.RunAdvisor = RUN end

local Bridge = {}
RUN.Bridge = Bridge

-- Returns the ForesightAPI table iff present and shaped right, else nil.
function Bridge.foresight()
    local F = _G.ForesightAPI
    if type(F) == "table" and type(F.GetDangerVerdict) == "function" then return F end
    return nil
end

-- Ask Foresight for a verdict about npcID in context ctx. Returns a table
-- { p = 0..1, band = "FIGHT"|"RISKY"|"FLEE", source = "foresight" } or nil.
function Bridge.dangerVerdict(npcID, ctx)
    local F = Bridge.foresight()
    if not F then return nil end
    local ok, v = pcall(F.GetDangerVerdict, npcID, ctx)
    if not ok or type(v) ~= "table" then return nil end
    if type(v.p) ~= "number" or v.p < 0 or v.p > 1 then return nil end
    return { p = v.p, band = v.band, source = "foresight" }
end

return Bridge
