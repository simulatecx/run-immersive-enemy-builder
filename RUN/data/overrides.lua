-- Hand-curated corrections over data/generated/rares.lua (overrides win on merge).
-- This is the ONLY data file meant to be edited by hand. Crowd data reaches here
-- exclusively via reviewed changes - never automatically.

local _, RUN = ...
if not RUN then RUN = _G.RunAdvisor or {}; _G.RunAdvisor = RUN end

RUN.overrides = RUN.overrides or {}
RUN.overrides.rares = RUN.overrides.rares or {
    -- [npcID] = { name = "...", classification = "rare", zone = 0, x = 0, y = 0 },
}

-- Merged view: generated base with overrides applied on top.
function RUN.raresMerged()
    local out = {}
    local gen = (RUN.gen and RUN.gen.rares) or {}
    for id, e in pairs(gen) do out[id] = e end
    for id, e in pairs(RUN.overrides.rares) do out[id] = e end
    return out
end

return RUN.overrides
